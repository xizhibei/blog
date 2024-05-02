---
title: 磁盘缓存：从一次文件丢失问题说起
date: 2020-11-21 14:50:30
tags: [Linux]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/153
---
<!-- en_title: disk-cache-start-with-a-file-missing-problem -->

如果你遇到了这样的问题：

刚往你的 Linux 机器中，写入了个文件，然后直接断电重启，发现文件只剩下了空壳，即产生了一个没有内容，大小为 0 的文件。

那么，你遇到了磁盘缓存问题，或者更确切的说法是掉电导致的磁盘缓存丢失问题。

### 什么是磁盘缓存

我们在小学二年级学过（是的，我也是天天给毕导视频点赞的），在 Linux 系统（实际上是任何操作系统）中，磁盘读写都是有缓存的，因为这种缓存往往有利于系统的读写加速，毕竟我们大部分场景下遇到的都是多读少写，因此，用暂时用不到的内存来当缓存，空间换时间是非常值得的。

缓存的作用原理是，当你读了一个文件，Linux 会先检查内存中的缓存有没有对应的内容，没有才会去读磁盘上的内容，然后会先将磁盘上的内存读到内存中，再返回给用户。这样，下一次读的时候，就不用再次从磁盘中读了，这样就会大大减少文件读的时间。

如果你这时候往这个文件中写了新的内容，Linux 会往缓存中写，而不是直接往磁盘里写，这样，你写文件的时间就会大大减少。只是，写过的缓存会被 Linux 标记为脏了，也就是所谓的内存脏页，Linux 会周期性地收集所有内存脏页，排序整理，然后往磁盘中真正写入，这就是所谓的回写（writeback），也可以叫做刷盘。

所以，我们的问题的原因就找到了：因为突然掉电时，造成了内存中的脏页来不及刷入磁盘，导致数据丢失。

这里说个题外话：这个缓存有多大呢？我们来随便看个 Linux 系统的内存。

```bash
$ free -m
      total      used      free      shared  buff/cache   available
Mem:   7822      2062       197          20        5563        5384
Swap:     0         0         0
```

我们可以看到，第五列的名称是 `buff/cache` ，表示这个系统缓存占用了 5563 MB 的内存，几乎是大部分内存（其实 buffer 与 cache 还是有一定区别的<sup>[1]</sup>，但是在我们今天讨论的问题中，可以一起对待），但最后一列 available 告诉我们，缓存也是可用的，当你的应用申请内存时，Linux 就会清理缓存，让出内存给你的应用<sup>[2]</sup>。

至于这些缓存具体用来了干什么，不是今天的主题，这里就略过了，你可以自己做实验<sup>[3]</sup>。

```bash
To free pagecache:
	echo 1 > /proc/sys/vm/drop_caches
To free reclaimable slab objects (includes dentries and inodes):
	echo 2 > /proc/sys/vm/drop_caches
To free slab objects and pagecache:
	echo 3 > /proc/sys/vm/drop_caches
```

让我们回到开头提到的问题，看看如何解决。

### 如何解决

目前的解决方案有两种，可以单独使用，也可以一起使用。

第一种是 `open` 文件的时候，加上 `O_SYNC` 标志，表示这个文件写的操作需要直接刷盘，也就是说每次调用 `write` 之后，文件数据和元数据都会写入磁盘，或者调用 `fsync/fdatasync/sync` 这几个系统调用，效果是一样的。

不过这种方案的缺点是很明显的，即所有写操作的延迟都会大大增加，不建议在频繁写的地方使用。（ `O_DIRECT` 不在考虑范围之内，如果你做的是数据库才可以考虑，不然造成的后果是你无法承受的。）

第二种就是内核参数大法，通过调整内核缓存相关的参数来进行调优，这种方法相对于第一种会温和一些，可以做到尽量不影响系统性能。

下面就具体说说跟当前这个问题涉及到的几个内核参数。

### 缓存相关的内核参数

大家回想下小学三年级学过的**虚拟内存**相关的内核参数，对的，就在 `/proc/sys/vm/` 这个目录下，有我们需要的参数。

当然了，三年级的同学都知道还有 sysctl 这个工具，我们可以直接获取所需要的名称以及对应的值，具体涉及到的有如下几个：

```bash
$ sysctl -a | grep dirty
vm.dirty_background_bytes = 0
vm.dirty_background_ratio = 10
vm.dirty_bytes = 0
vm.dirty_expire_centisecs = 3000
vm.dirty_ratio = 20
vm.dirty_writeback_centisecs = 500
vm.dirtytime_expire_seconds = 43200
```

下面我们来一一解释：<sup>[4], [5], [6]</sup>

`vm.dirty_background_bytes` 以及 `vm.dirty_background_ratio` 是用来表示脏内存「软」阈值，一旦超过这个阈值，系统后台刷盘进程就会开始运行，将脏数据刷到磁盘上，增大这个值就会增加缓存大小，反之亦然。`bytes` 与 `ratio` 的区别就在于前者是绝对值，后者是相对值（内存的百分比），下面同理；

`vm.dirty_bytes` 以及 `vm.dirty_ratio` 是用来表示脏内存「硬」阈值，一旦脏数据到达了这个阈值，系统就会阻塞所有 I/O 操作，然后进行刷盘。这个值受磁盘写的速度影响非常大，假如磁盘写很慢，就不能设置太低，否则就会让整个系统卡住比较长的时间了；

`vm.dirty_expire_centisecs` 是用来表示脏数据的时间阈值，一旦超过这个阈值，就表示对应的脏数据应该刷盘了，减少这个值会减少遇到掉电丢数据问题的概率；

`vm.dirty_writeback_centisecs` 是用来表示内核检查脏数据的运行间隔，单位是厘秒（秒的百分之一），与 `vm.dirty_expire_centisecs` 配合起来使用，减少这个值也会进一步减少遇到掉电丢数据问题的概率，**但是多少都会影响系统的性能**；

`vm.dirtytime_expire_seconds` 这个主要是给 lazytime inode 设置的过期时间，比如 inode 只是更新了 atime，这种更新非常频繁的数据就没必要短时间就更新，而且负责刷盘的是另外一个专门的 dirtytime writeback 进程，因此这个的默认时间比较长：12 小时，这个就不建议调整了，作用不大；

具体如何调整，就可以按照机器的磁盘读写速度、内存大小以及具体应用场景来平衡系统 IO 性能、数据安全与成本这三者之间的关系（毕竟有钱的情况下，磁盘换 SSD、加大内存以及买个 UPS 就能搞定这些问题了，嗯，有钱真好）。

### Ref

1.  [What is the difference between buffer and cache memory in Linux?][1]
2.  [Help! Linux ate my RAM!][2]
3.  [Experiments and fun with the Linux disk cache][3]
4.  [linux kernel doc - sysctl vm][4]
5.  [networking - Adjust linux disk flush intervals to avoid blocking user processes - Super User][5]
6.  [Better Linux Disk Caching & Performance with vm.dirty_ratio][6]

[1]: https://stackoverflow.com/questions/6345020/what-is-the-difference-between-buffer-and-cache-memory-in-linux

[2]: https://www.linuxatemyram.com/

[3]: https://www.linuxatemyram.com/play.html

[4]: https://www.kernel.org/doc/Documentation/sysctl/vm.txt

[5]: https://superuser.com/questions/1057007/adjust-linux-disk-flush-intervals-to-avoid-blocking-user-processes

[6]: https://lonesysadmin.net/2013/12/22/better-linux-disk-caching-performance-vm-dirty_ratio/


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/153 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
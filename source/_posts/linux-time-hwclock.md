---
title: Linux 时间之 hwclock
date: 2021-05-01 23:30:02
tags: [Linux]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/169
---
<!-- en_title: linux-time-hwclock -->

Linux 中，有好些个工具是跟时间相关的，最近工作遇到了它们，于是打算写几篇与 Linux 时间相关的文章。

今天先说说 `hwclock` 这个工具，估计也就玩物联网的朋友会用到了，因为这个工具往往只是用来保持硬件设备的时间的，但是前大多数设备往往都是联网的，也就是用的 NTP。

另外，Ubuntu 15.04 之后就用 `systemd` 来管理时间了，它里面自带的 `timedatectl` 工具取代了 `hwclock`，不过本质上是差不多的内容，这里就不多说了。

### 介绍

当设备无法联网的时候，RTC 就会变得非常重要，系统的时间将会依靠纽扣电池的能量来维持。如果设备需要经常开关机，那么就会更加依赖 RTC 来保持设备时间的同步。

它的原理很简单，就是用纽扣电池驱动 RTC（Real-Time Clock）芯片来保持设备断电时候的时间，这样当设备重启的时候，就能直接从 RTC 恢复时间了。

首先让我们来看看 `hwclock` 的帮助信息：

    Usage:
     hwclock [function] [option...]

    Time clocks utility.

    Functions:
     -r, --show           display the RTC time
         --get            display drift corrected RTC time
         --set            set the RTC according to --date
     -s, --hctosys        set the system time from the RTC
     -w, --systohc        set the RTC from the system time
         --systz          send timescale configurations to the kernel
     -a, --adjust         adjust the RTC to account for systematic drift
         --predict        predict the drifted RTC time according to --date

    Options:
     -u, --utc            the RTC timescale is UTC
     -l, --localtime      the RTC timescale is Local
     -f, --rtc <file>     use an alternate file to /dev/rtc0
         --directisa      use the ISA bus instead of /dev/rtc0 access
         --date <time>    date/time input for --set and --predict
         --delay <sec>    delay used when set new RTC time
         --update-drift   update the RTC drift factor
         --noadjfile      do not use /etc/adjtime
         --adjfile <file> use an alternate file to /etc/adjtime
         --test           dry run; implies --verbose
     -v, --verbose        display more details

     -h, --help           display this help
     -V, --version        display version

下面来说说，如何使用这个命令来解决我们常见的两个问题。

### 时间同步

首先要分清两个时间，一个是硬件时间，也就是在 RTC 等硬件芯片中的时间，另一个是系统时间，也就是系统内核中的时间。

为了同步时间，用到它的两个参数就够了：

1.  在关机前，将时间从系统写入 RTC：`hwclock --systohc`
2.  在开机时，将时间从 RTC 写回系统：`hwclock --hctosys`

其实这步做完就可以完成离线状态下的时间同步了。设备能够在大多数情况下，达到设备时间保持与真实时间同步。

但，如果设备的时间精确性很重要，那么你就需要用到它的矫正功能了。

### 误差矫正

其实 RTC 的工作依赖于一块 `32.768kHz` 的晶振，也就是一块石英晶体，然而，石英晶体是不稳定的，尤其在温度变化的时候，就会变得有误差，这个误差每天可以达到一秒或更多。

![RTC 受温度影响的误差](https://blog.xizhibei.me/media/16144968619674/16198584907844.jpg)

上图来自[1]，可以从图中看到，温度过低或者过高都会导致偏差增大，而我们的设备一般是无法放在一个恒温环境下的，于是每天必然造成误差。

如何矫正这个误差呢？有硬件方案，也有软件方案。

硬件方案，德州仪器公司给了一个方案<sup>[1]</sup>，可以直接用温度传感器来补偿 RTC 的精度，由于对硬件这块儿不熟悉，也说不出个所以然，只是明显的，硬件成本会增加一些。

软件方案就会朴实很多，**因为我们可以假设这个设备所处的环境不变，硬件时间与系统时间的偏差是系统性的，简单点说，就是每隔一段固定的，它们之间时间的偏差其实是一致的**<sup>[2]</sup>。于是，我们用软件工程的角度来低成本地校准，也就是 `hwclock` 的校准功能。

它会用到一个文件 `adjfile`，用来记录校准的状态，不过先需要解释下 `adjfile` 的格式，它默认是 `/etc/adjtime`，它的内容包含 3 行文本<sup>[3]</sup>：

-   第一行，包含三个值：
    -   系统时间每天偏移量（秒）
    -   上次调整时间 (Unix 时间戳)
    -   校正状态
-   第二行：上次校准时间 (Unix 时间戳)
-   第三行："UTC" 或者 "LOCAL"（一般只会用 UTC，别用 LOCAL 给自己添堵）

校准的用法也非常简单：

不过在开始之前，首先你需要确认 Linux 内核没有激活自动同步系统时间到硬件时间，不然会被 NTP 的 _11 分钟模式_ 自动同步<sup>[2]</sup>。具体就是运行 `adjtimex --print` 或者 `adjtimex`，看它的 status 值，看看有没有 `UNSYNC`，有就是不同步，或者需要自己计算下 `status & 0x40`，为 `1` 表示不同步<sup>[2]、[4]</sup>。

1.  （如果自动同步是激活状态）关闭且禁用 ntp 后台进程，且不会随系统启动；
2.  手动同步一次系统时间;
3.  同步系统时间至 RTC：`hwclock --systohc`，这时候，`/etc/adjtime` 里面的时间戳将会更新，但是偏移量为 0;
4.  关机，等待至少一天；
5.  开机，然后马上手动同步一次系统时间，然后让 hwclock 同步到 RTC 的同时，自动计算偏差 `hwclock --systohc --update-drift`；
6.  查看以及确认`/etc/adjtime` 里面的偏移量；
7.  （如果自动同步是激活状态）启动且启用 ntp 后台进程

### Ref

1.  [Implementing a Temperature Compensated RTC, PDF][1]
2.  [hwclock - time clocks utility][2]
3.  [adjtime - information about hardware clock setting and drift factor][3]
4.  [torvalds/linux:include/uapi/linux/timex.h][4]

[1]: https://www.ti.com/lit/ml/slap107/slap107.pdf

[2]: https://man7.org/linux/man-pages/man8/hwclock.8.html

[3]: https://man7.org/linux/man-pages/man5/adjtime.5.html

[4]: https://github.com/torvalds/linux/blob/9f4ad9e425a1d3b6a34617b8ea226d56a119a717/include/uapi/linux/timex.h


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/169 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
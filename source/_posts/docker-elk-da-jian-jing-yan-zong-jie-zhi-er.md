---
title: Docker ELK 搭建经验总结之二
date: 2016-05-12 11:09:39
tags: [docker,ELK]
author: xizhibei
---
运维了这么些日子的 ELK，解决了些问题，总结如下：
### 禁止内存换出 memlock

在 docker 中运行 elasticsearch 有个很大的问题就是

``` yml
bootstrap.mlockall: true
```

这个选项不起作用，总是会报错，后来查了一下，在普通机器上需要运行这个命令：

``` bash
ulimit -l unlimited
```

但是如果你在 docker 里面运行这个命令，会报错，提示无权限

解决方法是在运行的时候设置 ulimit，我用的 docker-compose，于是可以这样设置：

``` yml
   environment:
      ES_HEAP_SIZE: 4g
      MAX_LOCKED_MEMORY: unlimited
      MAX_OPEN_FILES: 131070
    ulimits:
      memlock: 9223372036854775807 #2^63 - 1 as unlimited
```

需要说明下的是，docker 的 ulimit 选项不支持 string，那么你可以设置一个足够大的数字，比如 int64 的最大值即可。
### 系统 IO 瓶颈

在运行一段时间后，发现我设置的 redis broker 每隔一段时间就会溢出，然后数据被 drop 掉，这段时间 es 的索引速度也几乎降到 0，查看 hot threads 以及 iostat 之后看到几乎被 merge 线程占满。

``` bash
curl localhost:9200/_nodes/hot_threads
```

这时候解决方案是，要不换 SSD，要不限制 merge，我毫不犹豫的选择了后者。。。SSD 太贵了。。。

可以考虑设置如下：

``` yml
indices.store.throttle.type: merge
indices.store.throttle.max_bytes_per_sec: 20mb
indices.merge.scheduler.max_thread_count: 1
```

具体数值可以按需调整，我调整之前，ES(2.3.1) 默认是

``` yml
indices.store.throttle.type: none
indices.store.throttle.max_bytes_per_sec: 10gb
indices.merge.scheduler.max_thread_count: 9
```
#### 参考

https://www.elastic.co/guide/en/elasticsearch/reference/current/index-modules-merge.html
https://www.elastic.co/guide/en/elasticsearch/guide/current/indexing-performance.html


***
原链接: https://github.com/xizhibei/blog/issues/12

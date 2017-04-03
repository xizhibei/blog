---
title: Docker ELK 搭建
date: 2016-04-22 23:53:18
tags: [docker,ELK]
author: xizhibei
---
记得上次说到的 #1 中提到，需要搭建 ELK 来实现数据需求，其实还有另一个需求：日志系统。

联系到最近一直在看的 docker，我就直接用它来部署了，申请了台 8 核 16G 机器，CentOS7，其实 ELK 还是得深入看看，毕竟 docker 只是用来部署，而不是帮你解决日志系统的问题。

项目地址在这里：https://github.com/xizhibei/docker-elk

目前的系统架构已经完全不跟 fork 之前的项目一样了，简单介绍下：
### 基础结构

`logstash => elasticsearch => kibana`
这个最简单，对于项目的早期来说，请求量不高，完全够了。
### 加 Broker

`logstash-shipper => broker => logstash-indexer => elasticsearch => kibana`
等用户量与请求量大了一个量级，就需要有一个 broker 来扛冲击了，比如用 redis，rabbitmq 之类的，当请求量突然增加，或者 ES 临时扛不住了，broker 就可以暂时缓解下。

如果使用 redis 的话，就得忍受数据丢失的可能了，一般来说使用 channel 来做的，然后你必须设置一个参数：

> client-output-buffer-limit pubsub 4gb 2gb 30

不然的话，redis 会卡住，然后 shipper 无法传送数据，indexer 无法接收数据，整个 ELK 就卡住了。

如果需要保证不丢失数据，可以换成 rabbitmq 或者 kafka 之类的。
### 加 load balancer

上面说到的，日志来源都可以是 UDP，ELK 即使挂了也不会影响，但是如果对于数据丢失无法忍受，则需要换成 TCP，以及进一步使用 load balancer + 多个 logstash shipper。
#### 这些天运维的经验
1. docker 中 ES，如果在一台机器上与其它应用共享，则必须设置 mem limit，比如在我的机器中就设置为 8G，然后 heap size 可以设置为一半（官方推荐），不然 ES 会把所有内存吞干净，让整个系统非常卡；
2. ES 轻易不要随便重启或更新，恢复会非常慢；
3. redis 不要用 list，用了之后，redis 在内存满的时候直接卡死，不会清楚，而且会 dump 到磁盘上，重启恢复也会非常慢，必须手动删掉；
4. 如果用了 redis 的 channel，redis 的 output 的 workers 只能设置为 1，不然 subpub 的 buffer 不会删掉，redis 内存一直在涨；


***
原链接: https://github.com/xizhibei/blog/issues/6

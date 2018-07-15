---
title: Node.js RabbitMQ 任务队列排错小记
date: 2017-06-11 14:36:58
tags: [Node.js,RabbitMQ, 重构]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/51
---
这周五解决了挺有意思的一个 Bug。

### 背景
由于长期以来，在我们的 Node.js 服务端项目中，离线任务大部分用的是 kue，这是个轻量级的任务队列，[之前](https://github.com/xizhibei/blog/issues/15) 也有过介绍。而周五那天我正准备将之前的 kue 队列重构成 RabbitMQ 的队列的相关代码上线。

RabbitMQ 任务队列是我基于 amqplib 实现的，在生产环境跑了半年有余，没什么大问题。

但是，按照墨菲定理，你最担心的事情总会发生，或者说：出来混迟早是要还的。

### 悲剧
结果，明明在预发布环境测试没问题的，却在正式环境完全不起作用，一直在报 `EPIPE` 的错误，并且在之后 ack 时报 `channel closed` 的错误。

同时，RabbitMQ 管理后台看到，任务队列在一直堆积，已经累计了 5k 的任务量，可能你会觉得不多，但是如果告诉你，每个任务需要执行 1 到 20 分钟不等呢？

显然，先是把我吓了一跳，不过又马上镇定下来，毕竟处理过的线上事故大于十个手指能数的数量了。

### 回滚
冷静想了想，这个离线任务里的业务虽说重要，但一时的任务堆积关系不是很大，而且任务会重新创建，回滚到旧代码就行，于是我将所有的代码一键回滚。

现在，改来找问题原因了。

### 寻找
按照目前的所掌握的信息，似乎还不能定位问题所在，大致能确定的是：TCP 连接有问题，导致 ack 数据写到了已经关闭的 sockets 上面了，才会导致 `EPIPE` 的错误。

##### TCP 连接为什么会关闭连接？

一般来说，TCP 正常的关闭，会有四次握手：
>『我要关了哈』
>『好的』，『我也要关了』
>『恩，拜拜』

而不正常的错误，会有 `ECONNRESET` 或者 `Connection reset by peer` 之类的错误提示，`EPIPE` 的话，一般是对方主动关闭，而没有通知到我方。

于是，原因显然是需要在对方机器上去找，因此登录到 RabbitMQ 的机器上查看日志，果然，发现了非常多的错误日志：

> =ERROR REPORT==== 9-Jun-2017::16:07:39 ===
> closing AMQP connection <0.9305.6670> (X.X.X.1:33647 -> X.X.X.2:5672):
> missed heartbeats from client, timeout: 60s

这是什么意思呢？关键信息是最后一行，**missed heartbeats from client, timeout: 60s** 。

很明显，超过默认 heartbeats timeout 的时间了，于是 RabbitMQ 认为这个客户端已经不行了，所以主动断了连接。

好了，那么继续下一步。

##### 为什么会出现 heartbeats timeout ?
在 RabbitMQ 官方文档上 [1] 找到这样的解释：在 server 3.0 以及之后的版本中，client 以及 server 会协商一个 timeout 值，默认是 60s （3.5.5 之前是 580s），回过头来看服务器版本，已经大于 3.5.5，（其实看日志也知道了），也就是 60s。

server 每隔 timeout / 2 就会发送一个心跳包，如果都错过，就会认为这客户端没救了，会主动关闭连接，然后客户端需要重新连接。

于是，兴奋地赶紧设置下 heartbeat 时间，来个 3600s。

很明显，问题没那么简单，错误还是在出现。

回过头来，再看看文档，注意 **『协商』** 这两个字，也就是说，结果不是我设置了就能成功的，server 该怎么做还是怎么做，于是 60s 的默认 timeout 不能通过 client 来修改。

但是这会儿我又不敢修改了，server 的 timeout 是全局的 [2]，如果改了就意味着所有的连接都是这个数了，这可太危险了。

整理下思路，看看手头上已有的信息，于是把眼光放到了 client。

##### 为什么会超过默认 heartbeats timeout 的时间？
其实这会儿，答案已经呼之欲出了：

** 事件循环太长导致 **

Node.js 不同于其它正常语言，它是单进程模型，没有所谓的进程并发，即使底层的线程也是为了异步 io。

也就是说，一旦一个事件里面的 CPU 被占满，其它 io 操作都会在事件队列中等待，导致事件循环过长。而在这个问题中，它的表现就是：client 的心跳包所在的事件，无法通过 TCP 这样的网络 io 操作发送至 server。

这才明白，我重构的部分是 CPU 密集型的任务，这恰恰是 Node.js 最软肋的地方。

### 解决
显然对于 CPU 密集型任务，我们一般有这几种方案：

1. fork 一个进程去处理，父进程负责 RabbitMQ 通信，子进程负责跑任务；
1. setImmediate，分拆 CPU 任务；
1. 换语言，用 Go，Rust 或者 Python 之类的语言去处理；

那么，为了尽快解决线上的问题，第一个就是我们的选择：最快，最直接。

### 总结
1. staging 环境不一致问题需要解决；
1. 重构有风险，入坑需谨慎；
1. 造轮子可以，测试需完善；

### Ref
1. https://www.rabbitmq.com/heartbeats.html
2. https://www.rabbitmq.com/configure.html


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/51 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
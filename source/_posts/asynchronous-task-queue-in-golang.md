---
title: Golang 中的异步任务队列
date: 2019-07-15 15:12:00
tags: [Golang,RabbitMQ,架构]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/115
---
<!-- en_title: asynchronous-task-queue-in-golang -->

在一些常见的场景中，如果遇到了某些请求特别耗时间，为了不影响其它用户的请求以及节约服务器资源，我们通常会考虑使用异步任务队列去解决，这样可以快速地处理请求、只返回给用户任务创建结果，等待任务完成之后，我们再告知用户任务的完成情况。

对于 Golang，我们可以通过 Worker pool 异步处理任务，在大多数情况下，如果不在意数据丢失以及服务器性能足够，我们就没有必要考虑别的方案，毕竟这样实现非常简单。

接下来我们先来说说如何用 Worker pool 解决异步任务的问题。

<!-- more -->

### Worker pool

Worker pool，也有叫做 Goroutine pool 的，都是指用 Go channel 以及 Goroutine 来实现的任务队列。Go channel 本质上就是一个队列，因此用作任务队列是很自然的。

在我们不用 Go channel 的时候，我们也许会使用这样的方式来处理异步任务：

```go
for i := 0;i < 100;i++ {
    go func() {
      // process job  
    }()
}
```

这样的方式是不推荐的，因为在请求量到达一定程度，系统处理不过来的时候，会造成 Goroutine 的爆炸，拖慢整个系统的运行，甚至程序的崩溃，数据也就完全丢失了。

如果我们用简单的方式，可以看看接下来的例子：一个发送者（也叫做生产者），一个接受者（也叫做消费者，或者 Worker）：

```go
type Job struct {...}
jobChan := make(chan Job)
quit := make(chan bool)
go func() {
    select {
			case job := <-jobChan:
			case <- quit:
			return
	  }
}()

for i := 0;i < 100;i++ {
    jobChan <- Job{...}
}
close(jobChan)
quit <- true
```

如果 Worker 不够，我们可以增加，这样可以并行处理任务：

```go
for i := 0;i < 10;i++ {
    go func() {
        for job := range jobChan {
            // process job
        }
    }()
}
```

这样，一个非常简单的 Worker pool 就完成了，只是，它对任务的处理还会有问题，比如无法设置超时、无法处理 panic 错误等。

实际上，目前已经有很多的开源库可以帮你实现了，以 **worker pool** 为关键词在 GitHub 上可以搜到一大堆：

-   <https://github.com/Jeffail/tunny>
-   <https://github.com/gammazero/workerpool>

那么，它们的缺点呢？

很明显，它们的缺点就在于**缺乏管理**，可以说是完全不管任务的结果，即使我们加日志输出也只是为了简单监控，更要命的就是进程重启的时候，比如进程挂了，或者程序更新，都会导致**数据丢失**，毕竟生产者与消费者在一个进程中的时候，会互相影响（抢占 CPU 与内存资源）。因此前面我也说了，在不管这两个问题的时候，可以考虑用。

如果数据很重要（实际上，我认为用户上传的业务数据都重要，不能丢失），为了解决这些问题，我们必须换一种解决方案。

### 分布式异步任务队列

接下来再说说异步的分布式任务队列，其实我在之前提过几次：

1.  [Node.js RabbitMQ 任务队列排错小记](https://github.com/xizhibei/blog/issues/51)
2.  [轻量级消息队列 Kue 的一些使用总结](https://github.com/xizhibei/blog/issues/15)

要用到这个工具的时候，我们大致有以下几个需求：

-   分布式：生产者与消费者隔离；
-   数据持久化：在程序重启的时候，不丢失已有的数据；
-   任务重试：会有任务偶然失败的场景，重试是最简单的方式，但需要保证任务的执行时是冪等的；
-   任务延时：延迟执行，比如 5 分钟后给用户发红包；
-   任务结果的临时存储，可用于储存；
-   任务处理情况监控：及时发现任务执行出错情况；

对于 Python 来说，有个大名鼎鼎的 [Celery][celery]，它完全包含上面的功能。它包含两个比较重要的组件：一个是**消息队列**，比如 Redis/RabbitMQ 等，[Celery][celery] 中叫做 **Broker**，然后还需要有数据库，用于存储任务状态，叫做 **Result Backend**。

显然对于 Go 也有很多不错的开源库，其中一个学 [Celery][celery] 的是 [Machinery][machinery]，它目前能满足大部分需求，而且一直在积极维护，也是我们团队目前在用的。

它目前支持的 Broker 有 AMQP(RabbitMQ)、Redis、AWS SQS、GCP Pub/Sub，目前对国内同行来说，RabbitMQ 或者 Redis 会相对比较合适。

另外它还支持几个高级用法：

1.  Groups：允许你定义多个并行的任务，在最后取任务结果的时候，可以一起返回；
2.  Chords：允许你定义一个回调任务，在 Group 任务执行完毕后执行对应的回调任务；
3.  Chains：允许你定义串行执行的任务，任务将会被串行执行；

说了优点，再说说它的缺点：

1.  任务监控支持不够，目前只有分布式追踪 opentracing 的支持，假如我要使用 prometheus，会比较困难，它的自定义错误处理过于简单，连上下文都不给你；
2.  传入的参数目前只支持非常简单的参数，不支持 struct、map，还得定义参数的类型，这样的方式会将这个库限制在 Golang 世界中，而无法拓展适用于其它语言；

### P.S.

其实对于 Goroutine 的方案，在以下两种情况下，可以考虑使用：

1.  必须同步返回给用户请求结果；
2.  服务器资源足够，仅仅用 Worker pool 就能降低请求的响应时长到可接受范围；

这两种方案都会返回请求结果，失败的情况下靠客户端重新请求来解决数据丢失的问题。

### P.P.S. 广告

之前我为我们团队实现了一个 Node.js 任务队列：[Blackfyre](https://github.com/xizhibei/blackfyre)，目前还是一直在使用的，其实其中的一部分的实现思路就是来自于 [Machinery][machinery] 以及 [Celery][celery]，欢迎试用。

[machinery]: https://github.com/RichardKnop/machinery

[celery]: https://github.com/celery/celery


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/115 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
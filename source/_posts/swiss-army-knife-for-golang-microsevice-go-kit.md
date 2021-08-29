---
title: Go kit：Golang 微服务的瑞士军刀
date: 2018-05-27 23:21:27
tags: [微服务,Golang,架构]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/78
---
<!-- en_title: swiss-army-knife-for-golang-microsevice-go-kit -->

上上周去旅游了，写了篇自己都觉得比较水的文章，这周补上一篇。 :P

近几个月开始将现有的 Node.js 服务重构为 Golang 服务，其实这个计划去年就开始制定，并且在很长一段时间里面都在准备基础：

-   设施：自动化运维，日志以及监控；
-   知识：Golang、框架微服务架构的设计以及业务的梳理；

接下来先从介绍开始。

### Go kit 简介

Go kit 是一系列由 Go 的包组成的工具集，并且是生产级别的，完全适应于任何公司与组织的业务。

#### 架构：三个层次

-   Transport layer：通信层，这里可以用各种不同的通信方式，如 HTTP REST 接口或者 gRPC 接口（这是个很大的优点，方便切换成任何通信协议）；
-   Endpoint layer：终端层，类似于 Controller，里面主要实现各种接口的 handler，负责 req／resp 格式的转换（同时也是被吐槽繁杂的原因所在）；
-   Service layer：服务层，也就是实现业务逻辑的地方；

从下面的架构图来看，它其实很简单明了。其中可以注意下中间件：类似于常见框架中的中间件模式，通常用来记录日志、限制频率、负载均衡以及分布式追踪等等，主要在 Endpoint 以及 Service 中实现。

![](https://gokit.io/faq/onion.png)

#### 依赖注入

太多的经验告诉我们，各个模块之间应该是 **低耦合，高内聚**，于是，Go kit 鼓励你在 main 函数里面实现所有的组装，所有的模块的依赖都需要通过参数传入其它模块，减少甚至消灭所有全局状态，从根本上避免技术债务。

同时还有个很大的好处：便于测试，只要 mock 传入的依赖参数即可。

> This keeps dependencies explicit, which stops a lot of technical debt before it starts.
> 这样保持依赖明确后，可以帮助我们阻止很多不必要的技术债务。

### Go kit 的缺点

[Eyal Posener](https://github.com/posener) 这位老哥在他的博客 [为什么我建议不要使用 go-kit](https://gist.github.com/posener/330c2b08aaefdea6f900ff0543773b2e) 中写到三点原因：

> 1.  框架太繁琐，每个接口的代码太多，太啰嗦；
> 2.  难理解，主要体现在 Go kit 的三层模型；
> 3.  `interface{}` API 太蛋疼，在 Endpoint 层，每个 endpoint 都需要重复类似的转换代码；

同时，也可以看看其他人对这篇文章的看法：[Reddit 上的讨论](https://www.reddit.com/r/golang/comments/5tesl9/why_i_recommend_to_avoid_using_the_gokit_library/)。

我很同意讨论区 Morgahl 的看法：架构领域是没有银弹的，所有的架构都是需要取舍（trade-off）的，关键还是得将架构跟自己公司的业务结合起来做选择。

而 Go kit 的缺点也可以用其它方式来弥补:

1.  利用工具生成代码；
2.  怎么说呢，其它的框架还有更多概念，Go kit 算少了；
3.  同 1，而且也可以考虑把公共代码抽出来；

总之， Go kit 给你完全的自由来做任何事情，从我看来，最大的缺点就是你需要花费比较大的精力来定制自己的框架，而这时间却是我们自己愿意花费的，而它在其中扮演的角色就是微服务的瑞士军刀：提供各种方便的工具，让我们能够打造适应自己业务的框架。

### Why Go kit

最后说说我们为什么选 go-kit 作为开发 Golang 微服务的基础。

其实严格来说，它不算是框架，而只是一个 toolkit（工具包），他不会像其它微服务框架，如 [Micro](https://micro.mu/) 加入太多的限制，因为框架本身就是包含了框架开发者的思路、想法与理念的。

而 Go kit 恰恰相反，它不算是一个框架，而是框架的底层，用它的话来说：

> Micro wants to be a platform; Go kit, in contrast, wants to integrate into your platform.
> Micro 希望成为一个平台，而 Go kit 希望成为你的平台的一部分。

这句话可以这么理解：**你可以用 Go kit 做适应自己平台的框架，因为框架总是在尝试做适应任何人的业务平台，而不是专门适应你的业务平台。** 这也是我们选择它的最大理由。

其实放眼望去，几乎每个公司做大了之后，都会做自己的轮子，为什么呢？有人可能会说是为了 KPI，为了向外输出技术，输出影响力，这个没有问题，但是我认为真正的原因在于**没有一个框架是能真正适应所有的业务，总会有框架满足不了业务的时候。**

另外，其实还有个考虑的点，也是给我们留了后路：假如以后换成其他框架，在 Go kit 良好的架构下，我们只需要把 Transport 以及 Endpoint 层剥离，留下 Service 就可以方便集成到新的框架下面了。

### Ref

1.  <https://peter.bourgon.org/go-best-practices-2016/>
2.  <https://gokit.io/faq/>
3.  <https://peter.bourgon.org/applied-go-kit>


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/78 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
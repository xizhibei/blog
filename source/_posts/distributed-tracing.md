---
title: 分布式追踪
date: 2018-04-07 15:08:47
tags: [Node.js, 微服务, 监控]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/74
---
<!-- en_title: distributed-tracing -->

其实今天的文章算是 [APM 以及 Node.js 探针原理](https://github.com/xizhibei/blog/issues/40) 的续篇，在去年介绍了一些原理之后，其实还有很多地方没有说清楚。

不过，开头还是先介绍下分布式追踪。

### 简单介绍
分布式追踪在微服务领域非常重要，因为服务一旦多了，就涉及到性能瓶颈分析与线上问题排查、服务之间的关系梳理等等，这在单体应用的时候，非常简单，你甚至[在本地就能解决](https://github.com/xizhibei/blog/issues/57)，但是在一个比较大的公司内部，就需要团队与团队，部门与部门之间的合作才能解决，于是用传统这种的方案就很难解决了，在几十上百服务中一个个排查试试可真得累死人，而且找到问题的概率很低。

那么，它跟我们说的 APM 有什么关系呢？APM 的作用是监控应用性能，但是当一个应用被拆成分布式应用的时候，只是单独监控每个应用就不能达到我们想要的效果了。毕竟我们最重要的监控，就是监控一些涉及到 APP 频繁请求后端的 API 以及对应的请求链路，这些请求是用户直接能感受到的（充值购买之类的就不用提了，肯定是第一位的），当响应时长升高，或者错误率上升，是会直接影响用户体验的。这时候必然需要一个标准，来将所有的 APM 数据汇总，统一显示，方便我们监控以及查找定位问题。

再来说说业界的一些实现，Google 的 Dapper、Twitter 的 Zipkin、新美大的 MTrace 以及阿里的 Eagle Eye。简单来说，他们就是开源版本的 APM 实现，你完全能使用这些开源版本的 APM 来监控你的分布式应用。

接下来再说说 opentracing 这个项目，拿他的身份来说就不简单，**[CNCF](https://www.cncf.io/) 成员项目 **，虽然看起来成立时间也挺短的，但是潜力无限。

它的目标很简单，不是想做出一个牛逼的产品取代业界的各种实现，它只想联合开源界的所有优秀分布式组件，来做一个标准，毕竟相比于大家都各自重复造轮子，还不如大家联合起来，遵从同一个标准，把这个盘子做大。这样的话，以后你在你的中间件项目中加入 opentracing 的支持了之后，所有使用了 opentracing 相关工具的团队，就能跟你的项目无缝结合，这是不是很美好？

现在回到 APM，作为整个分布式应用中对你最重要的一部分，你就可以在你自己开发的分布式项目中，加入 opentracing 支持了。

在这里需要特别介绍下符合 opentracing 的一个实现，[jaeger](https://jaegertracing.netlify.com/)，主要是因为它有 Node.js 的 client：[jaeger-client-node](https://github.com/jaegertracing/jaeger-client-node)，它提供了 opentracing 的 tracer 实现，但是不能像 newrelic 那样在项目入口文件中 require 就行了，需要你手工侵入代码，非常不优雅。

目前我知道的只有一个项目有点符合要求：[opentracing-auto](https://github.com/RisingStack/opentracing-auto) ，只是不稳定，不建议在生产环境使用，而且当前使用的人也不够多，也没有 koa 的支持。

**APM 中包含分布式追踪，但实现 Node.js 应用分布式追踪的重点还是 CLS**。

### CLS 续
其实我写完那篇文章后过了不久，[Node.js 官方就给出了实现](https://github.com/nodejs/node/pull/12892)，并且在 CLS 那个项目中，也提到了[这件事情](https://github.com/othiym23/node-continuation-local-storage/issues/118)。

他们提到的东西就是 `async_hooks`，只是它需要在 Node.js 8.2.1 以及之后的版本中才能使用，并且目前是实验阶段，不稳定。而在这之前其实也有一个模块 `async_wrap` 也提供了类似的功能，但是没有以正常的方式对外暴露，也没有文档，你必须使用 `process.binding('async_wrap')` 的方式。

而完整的历史在 [cls-hooked 这个模块的 readme](https://github.com/jeff-lewis/cls-hooked#readme) 有提到 (cls-hooked 是 continuation-local-storage 的一个 fork)：

> 1. First implementation was called AsyncListener in node v0.11 but was removed from core prior to Nodejs v0.12
> 2. Second implementation called AsyncWrap, async-wrap or async_wrap was included to Nodejs v0.12.
>    1. AsyncWrap is unofficial and undocumented but is currently in Nodejs versions 6 & 7
>    2. cls-hooked uses AsyncWrap when run in Node < 8.
> 3. Third implementation and offically Node-eps accepted AsyncHooks (async_hooks) API was included in Nodejs v8. :) The latest version of cls-hooked uses async_hooks API when run in Node >= 8.2.1


简单翻译如下：

> 1. 第一次实现在 node v0.11 的时候叫做 AsyncListener，之后在 v0.12 的版本里呗移除了；
> 2. 第二次实现叫做 AsyncWrap，async-wrap 或者叫 async_wrap，在 v0.12 的时候被引入了；
>    1. AsyncWrap 是非官方的，也没有相应的文档记录，但是在版本 6 跟 7 中是可用的；
>    2. cls-hooked 在 node 版本低于 8 的时候使用了 AsyncWrap；
> 3. 第三次实现被 Node-eps(Node.js Enhancement Proposals) 接受了，叫做 AsyncHooks (async_hooks) 它的 API 被包含在了 node 8 版本中。 最新版本的 cls-hooked 使用了 async_hooks API 当版本大于等于 8.2.1；

但是，正如我之前在文章中提到过的，这个模块[对性能还是有影响的](https://github.com/bmeurer/async-hooks-performance-impact)。

这要看你对性能跟监控能力的权衡，相信用一小部分的性能损失来换取更全面以及清晰的监控是值得的。

### P.S.
其实分布式追踪也可以完全不侵入的，就是说完全不用像 newrelic 一样，因为分布式追踪的时候，主要是追踪网络请求，那么我们就可以在网络层面去截取流量来追踪了，对的，加密流量也是可以做到的。

而且，业界也有解决方案，比如 Service Mesh 的 SideCar 模式。他就是使用一个组件的方式跟你的应用绑定，代理掉你的所有网络请求，因此追踪也可以由它去做了。

这东西很大，点到为止，之后有机会再细说。

### Ref
1. [Dapper](https://bigbully.github.io/Dapper-translation/)
2. [分布式会话跟踪系统架构设计与实践](https://tech.meituan.com/mt-mtrace.html)
3. [微服务架构下，如何实现分布式跟踪？](http://www.infoq.com/cn/articles/how-to-realize-distributed-tracking)



***
原链接: https://github.com/xizhibei/blog/issues/74

![知识共享许可协议](https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png "署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）")

本文采用 [署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh) 进行许可。

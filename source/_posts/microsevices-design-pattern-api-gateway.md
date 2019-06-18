---
title: 微服务设计模式之API 网关
date: 2018-07-15 16:34:40
tags: [DevOps,Node.js,微服务,架构]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/82
---
<!-- en_title: microsevices-design-pattern-api-gateway -->

### 简介

API 网关是目前非常成熟的一种微服务与外界通讯方式的一种选型，当前你的架构是从单体架构 `Monolithic` 迁移过来的时候，你会发现新的服务无法很好地从旧有系统中接管流量。

这个接管，或者说迁移的过程很复杂，也很危险，一般我们也会从小流量的非核心服务开始拆，拆分完之后，你就会发现问题了：流量怎么导到新服务上面去呢？

<!-- more -->

一种选择是在原服务上将数据转发至新服务，但是这也有问题：新服务其实相当于没有完全拆分出去，当任何一方出问题的时候，其它服务也会受影响。

另一种选择是会从软负载均衡上修改配置来达到拆分的目的，但是配置的管理是个大难题，一旦出了问题，影响的可能就是某个机房或者整站的服务稳定。另外，当拆分越来越多的时候，问题也随之而增加：复杂度太高，每次修改都是提心吊胆。

于是，API 网关就可以承担这个关键角色了，它将所有的微服务结合在一起，对外屏蔽细节（外部不需要知道是哪些微服务提供了数据），作为一个单点对外提供服务。不知道你想起了什么没有，对，就是设计模式中的经典：**Facade 模式**。

![](http://microservices.io/i/apigateway.jpg)

同时还有一种差异版本：**BFF**，也就是为每个客户端单独建立不同的 API 网关。

![](http://microservices.io/i/bffe.png)

好了，既然 API 网关那么好，接下来该怎么做呢？当然是挑选合适的网关了。

### 选型需求

在挑选之前，我们需要明确自己的需求，我们需要的网关它至少需要有以下核心功能：

1.  强悍的负载均衡能力；
2.  支持动态服务管理服务，最好能跟服务发现结合在一起；
3.  支持故障控制：健康检查、限流、熔断、重试；
4.  详细的监控指标（比如支持 Prometheus）；
5.  日志聚合（其实这个应该说是基本功能）；

附加功能：

1.  支持分布式追踪，支持 Opentracing；
2.  金丝雀发布，灰度发布，A/B 测试；
3.  统一认证：JWT，OAuth，Basic auth 等；
4.  HTTP 缓存；
5.  请求、返回内容的显示以及修改；
6.  请求限制：机器人检测、黑白 IP 名单；

### 几个推荐选型

个人认为，网关作为微服务架构里面的基石应用，应该选用接近底层以及性能比较高的语言去实现，比如 C/C++，Golang 以及 Rust 等。

目前比较成熟以及用的比较广泛的网关有以下几种：

-   [GitHub - Kong/kong](https://github.com/Kong/kong)：基于 OpenResty 那一套做的，依赖于 Nginx 强悍的性能，添加了动态服务管理功能，以及插件机制，语言是 lua ，假如自己拓展需要学习新语言；
-   [GitHub - TykTechnologies/tyk](https://github.com/TykTechnologies/tyk)：用 Golang 实现的网关，如果团队使用 Golang 技术栈，到时可以考虑下；
-   [GitHub - Netflix/zuul](https://github.com/Netflix/zuul)：用 Java 实现的网关，目前看来只适合 Java 技术栈；

这里抛开最后一个不谈，其中前两个是目前用得比较广泛的，这两者几乎就是市场的老大与老二了。

除了以上几个，另外还有几个网关值得留意：

-   [fagongzi/gateway](https://github.com/fagongzi/gateway)：国人用 Golang 实现的的 gateway，可以看看，假如东西确实很不错，再加上之后能运营好，做成收费服务，前途可期；
-   [hellofresh/janus](https://github.com/hellofresh/janus)：也是让人眼前一亮的网关，比如支持 Opentracing 以及 HTTP/2；

### Kong vs Tyk

关于两者的比较，有好事者在两个产品的社区里面发了相同的帖子（大家好好学习这位同学，非常机智）：

-   <https://discuss.konghq.com/t/api-gateway-comparison-kong-vs-tyk/534>
-   <https://community.tyk.io/t/comparison-between-tyk-and-kong/2364>

Kong 的社区回复：

> 1.  Kong 的功能丰富、插件齐全；
> 2.  进可当做 Ingress 接管入口中央集权制，退可当 Mesh 去中心化分封制；
> 3.  Nginx + lua 性能杠杠的，扛起了全球 10% 的流量，连 CloudFlare 跟我们用的都是一样的技术栈，而且 lua 也很容易学习；
> 4.  市场上独领风骚；
> 5.  基准测试中是最快的；
> 6.  心动了没，赶紧找我们销售；

Tyk 的社区回复：

> 1.  客户支持快；
> 2.  Kong 的插件只能用 lua 写，Tyk 则不然，lua、Python、JS 统统支持，另外 插件里面的 gRPC 也是支持的；
> 3.  Kong 依赖于 Nginx，假如 Nginx 出了 bug，他们很难修复，Tyk 则不然，全部技术栈都是他们可控的；
> 4.  两者的性能差不多，2k qps 完全不是问题，能满足大部分需求；
> 5.  Kong 的 UI 是企业版才有的，Tyk 免费用；
> 6.  我们不靠 VC 支持，玩的是长线战略；

然后再看看一个『第三方』的测评：

> 这里插一句：之所以打引号，是因为觉得他们的图表是偏向于 Kong 的，在那个最明显的对比图中，如果不仔细看，会以为 Kong 的性能是 Tyk 的两倍。

<https://www.bbva.com/en/api-gateways-kong-vs-tyk/>

从结果来看，Kong 的性能更胜一筹：超出约 **25%**，而 Tyk 在去掉一些插件之后的性能也能增加 **20%** 左右。

因此，性能上的考量不是非常重要了，而且你也完全可以通过增加更多的节点来获取更高的整体性能。

而在 stackoverflow 的一个帖子中，发现大家还是力挺 Tyk 的：

<https://stackoverflow.com/questions/46769814/is-there-a-comprehensive-comparison-between-tyk-vs-kong>

很显然，因为 Kong  的先发优势（2011 年成立 [3]）以及站在了 Nginx 这个巨人的肩膀上，发展非常迅速，目前使用人数以及社区都远远高于 Tyk。Tyk（2015 年成立 [3]） 作为老二，在没有资本压力的情况下，在努力运营社区、维护社区的关系，这点还是不错的。而 Kong 的话，商业气息更重一些，具体就表现在了非常关键的管理界面上：如果你不付钱，那你只能用开源社区的版本。

### 其它

#### 收费

不知道你注意到了什么，我这个过程中其实很看重的一点就是商业支持：**我不相信一个长久无法获利的工具能够非常优秀，因为这不利于这个项目的长期发展，好东西还是得花钱的**。

#### 测试

你需要一个 **Echo server**，简单来说，就是把请求包含的内容给你返回回来，同时还包含所在实例、进程的信息等等。然后，通过在 CI 中直接拉起这一堆镜像，用脚本测试，对比返回结果即可。

最后，在 CD 中将测试过的配置发布至准生产环境、生产环境即可。

**Echo Server** 可以拿 Node.js 举例：

```js
import path from 'path'
import os from 'os'
import Koa from 'koa'
import Promise from 'bluebird';

const app = new Koa()

app.poweredBy = false
app.proxy = true

app.use(async (ctx, next) => {
    const { delay } = ctx.query;
    await Promise.delay(delay || 50)
    ctx.set('X-Backend', `${os.hostname()}-${process.pid}`);
    ctx.body = {
        delay, 
        headers: ctx.headers,
    };
});

const port = process.env.PORT || 8000
app.listen(port)
console.log('Running site at: http://localhost:%d', port)

export default app
```

这段代码中，我加入了 `delay` 参数，方便对网关进行性能测试。

#### 监控

之前可以用 [GitHub - yciabaud/kong-plugin-prometheus: Prometheus metrics exporter for Kong API management](https://github.com/yciabaud/kong-plugin-prometheus)，但最近的 [0.14.0 版本](https://github.com/Kong/kong/blob/master/CHANGELOG.md#0140---20180705)，官方集成了自己的 [Promethus](https://github.com/xizhibei/blog/issues/54) 监控，因此上面的这个监控插件得拜拜了。

Tyk 的监控是包含在工具套件里面的，如果要使用它们的东西，你得注册获取免费的 license，并且免费版本只能使用一个 gateway 节点，由于怕它们的销售骚扰，赖得注册去测试了。

#### Kong 的 UI

目前除了官方企业版才提供的管理界面，目前有以下两个选择

-   [GitHub - PGBI/kong-dashboard: Dashboard for managing Kong gateway](https://github.com/PGBI/kong-dashboard)
-   [GitHub - pantsel/konga: More than just another GUI to Kong Admin API](https://github.com/pantsel/konga)

### Ref

1.  [API gateway pattern](http://microservices.io/patterns/apigateway.html)
2.  [Building Microservices: Using an API Gateway](https://www.nginx.com/blog/building-microservices-using-an-api-gateway/)
3.  [API Gateways: Kong vs. Tyk | 4-Traders](http://www.4-traders.com/BANCO-BILBAO-VIZCAYA-ARGE-69719/news/API-Gateways-Kong-vs-Tyk-25590337/)


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/82 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
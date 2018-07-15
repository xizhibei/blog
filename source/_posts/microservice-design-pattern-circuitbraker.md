---
title: 微服务设计模式之断路器
date: 2018-06-03 16:23:28
tags: [Golang,Node.js, 微服务, 架构]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/79
---
<!-- en_title: microservice-design-pattern-circuitbraker -->

记得小时候，有次自己用手拿了两根铁丝插进插座（别问为什么，我在探索真理……），于是至今仍然记得那种全身酥麻以及恶心的感觉，但是幸好时间不长，两秒之后就停了，然后我家就停电了——对的：空气开关起作用了，我的小命就这么留下来了。

<!-- more -->

那时候一度痴迷，研究了我的救命恩人的原理，原来啊，一开始我们是用保险丝的，一旦电流过大，保险丝就会温度升高，然后熔断，因此它一般是用低熔点的材料制成，同时呢，电阻也不会太高，不然很容易就熔断了。只是每次这样熔断等待人去更换效率就太低了，于是诞生了空气开关，原理就是电磁铁，电流过大就会切断电源，但是之后只需要人重新合上开关就行了，不用像以前那样每次都需要更换保险丝。

那么，接下来就引出了今天的话题，来说说断路器，显然，不是要继续说家里面的那个空气开关，但是，它们的原理是一样的：都是通过切断连接来保护后端服务，防止事故蔓延扩大，拯救服务（生命）。

![断路器](https://xizhibei.github.io/media/15270876869993/15280107601120.jpg)


### 原理
软件行业里面的断路器原理其实跟电气行业里的基本一致，只是，它可以自动恢复，当然，也可以人为干预。

前者的电流强度对于后者的错误率，后者通常也会设置一个超时时间，把这个超时时间作为一种比较主要的错误类型。前者遇到电流强度超过一定阈值后自动切断电路，而后者也可以在错误率达到一定阈值后切断数据连接：直接返回错误。

后面的关键来了：后者由于是提供在线服务的，它不能被动地等待人去主动合上开关，而是会主动检测服务是否恢复，没有恢复的话，继续等待，而一旦恢复，他就会自己合上开关，恢复对外服务，详细请看下图（来自[1]）。

![断路器原理](https://xizhibei.github.io/media/15270876869993/15280108056665.jpg)

从这个状态图可以看到，断路器有三种状态：` 关闭、开放、半开放 `。

- 最开始处于关闭状态，一旦检测到错误到达一定阈值，便转为开放状；
- 这时候会有个 reset timeout，即开始准备恢复了，转移到半开放状态；
- 尝试放行一部分请求到后端，一旦检测成功便回归到关闭状态，即恢复服务；


不要小瞧了这个非常简单的原理，它符合 `fail fast` 这个架构设计准则，而不是一直慢慢 fail，等到 fail 一定程度后才让运维人员知道情况，其实也就我们常说的做事原则：** 不要隐瞒问题，而是应该尽快暴露问题 **。

具体的实例不能放出来，但是可以简单描述：在没有使用断路器之前，我们的某个功能依赖的数据库假如压力上升了，就会影响其它所有的服务，最严重的一次，导致整站响应时长最高上升达到 15s ，过了 4，5 个小时才完全恢复，在我们的监控上体现的就是一次过山车。这个过程中就是因为数据库压力太大，而前端用户在发生超时之后不断重试，进一步导致了数据库压力上升。
而后来将那个功能加上断路器之后，至今只发生一次事故，并且 10 分钟就自动恢复了，前端用户几乎无感知。

### Go kit 中的断路器
目前 Go kit 提供了三个选项：

- [hystrix-go](github.com/afex/hystrix-go/hystrix)
- [go breaker](github.com/sony/gobreaker)
- [handdy breaker](github.com/streadway/handy/breaker)

尝试下来，目前还是 hystrix-go 最合适，一个是它提供的功能最符合 [1] 中的设计，另一个是这个原始工具 Hystrix 是在 Netflix OSS 中最初提供的，经过 Java 界长时间验证，是目前最成熟的设计。

使用也很简单，在 Go kit 中配置好，直接在 Endpoint 层就可以使用了：

```go
hystrix.ConfigureCommand(name, hystrix.CommandConfig{
	RequestVolumeThreshold: cb.RequestVolumeThreshold,
	ErrorPercentThreshold:  cb.ErrorPercentThreshold,
	MaxConcurrentRequests:  cb.MaxConcurrentRequests,
	SleepWindow:            cb.SleepWindow,
	Timeout:                cb.Timeout,
})

endpoint = circuitbreaker.Hystrix(name)(endpoint)
```

这里的参数需要说明一下

1. RequestVolumeThreshold: 请求量阈值，在达到这个阈值之前，即使达到了错误阈值也不会进入 Open 状态；
2. ErrorPercentThreshold:  错误阈值；
3. MaxConcurrentRequests:  经过断路器的最大并发数，这个值可以参考 ` 最高峰每秒请求数 x 99 百分位请求响应时间 `；
4. SleepWindow:            需要花费多少时间；
5. Timeout:                请求的超时时间，这个值建议设置为 99.5 百分位的请求时长；

具体的还可以参考[3]。

### Node.js 中的断路器

目前找到了两个比较合适的：

- https://github.com/awolden/brakes
- https://bitbucket.org/igor_sechyn/hystrixjs

试用后觉得前者 brakes 设计更好，简洁易用，并且功能更多：

- Slave Circuits 可以用来创建多个共享状态的断路器，这点在调用外部接口的时候特别试用，因为往往外部主机一挂那基本就是全部接口不可用；
- 健康检查功能，这点其实比半开放状态更适合，不需要通过放行来测试后端服务是否正常了；

使用也很简单，但是建议在使用的时候直接封装在客户端对外调用逻辑里面，上层调用不需要知道有断路器的存在。

### Ref
1. https://martinfowler.com/bliki/CircuitBreaker.html
2. http://throwable.coding.me/2017/10/15/hystrix/
3. https://github.com/Netflix/Hystrix/wiki



***
首发于 Github issues: https://github.com/xizhibei/blog/issues/79 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
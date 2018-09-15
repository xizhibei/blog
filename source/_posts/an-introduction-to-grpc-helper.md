---
title: 如何在 Node.js 中更优雅地使用 gRPC：grpc-helper
date: 2018-09-09 15:18:59
tags: [Node.js,TypeScript,gRPC]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/86
---
<!-- en_title: an-introduction-to-grpc-helper -->

在上一篇的 [gRPC 的介绍以及实践](https://github.com/xizhibei/blog/issues/84) 中，而在文末，我简单介绍了给 Node.js 做的 [grpc-helper](https://github.com/xizhibei/grpc-helper)，但是现在，我觉得得用一篇完整的博客来好好介绍，毕竟还是想要给大家用的，以下我会介绍我实现这个工具的过程，以及我的一些实现思路。

<!-- more -->

其实在这之前，我看了[官方的讨论](https://github.com/grpc/grpc-node/issues/54)，而且也调研了当中提到一些帮助类工具，比如 [grpc-caller](https://github.com/bojand/grpc-caller)，因该说我不太喜欢这种 API 风格，不够简单明了，并且也没有我想要的一些高级功能。
另外就是 [rxjs-grpc](https://github.com/kondi/rxjs-grpc) 了，只是它是基于 RxJS 来做的，如果你对它不熟悉，怕是也难以选择（当然，可以了解下，号称是[可取代 Promise 的](https://rxjs-cn.github.io/rxjs5-ultimate-cn/content/why-rxjs.html)）。

因此我想了想，除了最重要的 Promise API 功能（毕竟 callback 的风格早就应该被淘汰了），我想要的功能主要有：

1. ** 服务发现 **：比如支持 DNS 服务发现，其它的可以是 consul etcd 等；
2. ** 客户端负载均衡 **：支持 Round roubin 负载均衡；
3. ** 健康检查 **：支持上游的健康检查，剔除不健康的后端以及重新加入健康的后端
4. ** 断路器 **：一旦上游出错了，能够及时断开；
5. ** 监控指标 **：能够提供监控指标，方便发现以及处理问题；

好了，相信你也应该看出来了，我想要的无非就是 ** 负载均衡加上 Promise API**，因为上面的几点都是一个负载均衡器应该做的事情。

实现的话，还是用 TypeScript，不明白的可以看看我之前的介绍：[使用 TypeScript 开发 NPM 模块](https://github.com/xizhibei/blog/issues/68)。

### Promise API
于是首先是需要提供一个非常简便的 Promise API 接口，我们都知道 grpc 以客户端以及服务端是否使用了流分成了四种风格的接口：

- Unary：客户端 & 服务端没有流；
- Client stream：客户端有流，服务端没有流；
- Server stream：客户端没有流，服务端有流；
- Bidi stream：客户端 & 服务端都有流；

而在这四种接口中，只有 Unary 以及 Client stream 有返回值 callback 风格的接口，这从设计上也符合一致性的风格，只是我们不喜欢用而已。

因此，一开始，我是这么设计的：

将 callback 风格的

```js
client.SayHello({name: 'foo'}, (err, rst) => {
  ...
});
```

变为

```js
const res = await client.SayHello({name: 'foo'});
```

但是我忽略了服务端返回的 **status** 以及 **metadata**，应该说大部分情况下，只是 **response** 就能满足大部分需求，但是我做的是一个比较基础的库，那就应该提供完整的功能，于是，我加入了下设计：

```js
const call = client.SayHello({name: 'foo'}, (err, rst) => {
  ...
});

call.on('status', (status) => {});
call.on('metadata', (metadata) => {});

const peer = call.getPeer();
```

变为

```js
const { message, status, metadata, peer } = await client.SayHello({name: 'foo'});
```

这样也就非常简单明了了，实现起来也不难，我同时提供了 `resolveFullResponse` 参数，默认为 false，这样，大部分情况下，如果不需要 status 之类的返回值，只需要第一种设计，那基本上也不需要改动参数。 

同时，我还参考了 @murgatroid99 在 [官方讨论](https://github.com/grpc/grpc-node/issues/54) 中的设计，将 Client stream 接口也改成了 Promise 风格的接口：

```js
const stream = new stream.PassThrough({ objectMode: true });

const promise = helper.SayMultiHello(stream);

stream.write({ name: 'foo1' });
stream.write({ name: 'foo2' });
stream.write({ name: 'foo3' });
stream.end();

const result = await promise; // { message: 'hello foo1,foo2,foo3' }
```

### 负载均衡
应该说这是一个现代的负载均衡器应该做的事情，我参考了 [grpc-go](https://github.com/grpc/grpc-go) 的设计，引入了 Resolver Watcher 以及 Balancer 几个抽象接口。

- Resolver：目前主要是 static 以及 dns，static 即直接解析服务端的地址，而 dns 则是利用 Node.js 的 dns.resolveSrv 解析 Srv 记录（具体使用场景可参考[这里](https://github.com/xizhibei/blog/issues/84)）；
- Watcher：即实时 watch 服务发现，及时更新服务端的记录；
- Balancer：即实现 Round robin 负载均衡算法，挑选可用的服务端；

而在[上次的文章中](https://github.com/xizhibei/blog/issues/84)，我也提到了 grpc-node 中，现在还没有实现负载均衡能力，而且它目前的实现，还不能很方便的提供给我们很方便定制这个功能的接口，于是，目前能做的便是直接给每个服务端生成一个 client，然后在这个基础之上进行负载均衡的实现。

于是，最初的设计是：

```js
class Helper() {
  constructor() {
    const resolver = new Resolver(addr);
    const clientCreator = new ClientCreator()
    this.lb = new Balancer(resolver, clientCreator);
    this.lb.start();
  }
  getClient() {
    return this.lb.get();
  }
}
const helper = new Helper();
helper.getClient().SayHello()
```

但是显然这样不够简便，于是我直接在 helper 的 constructor 中加入了这些方法，使得初始化之后直接将方法绑定到 helper 上面：

```js
each(methodNames, method => {
  this[method] = (...args) => {
    const client = this.lb.get(); // 从 balancer 获取 client
    return client[method](...args);
  };
});
```

于是，我们最终的 API 就很简单了：

```js
helper.SayHello()
```

其它的负载均衡功能限于篇幅不再详细介绍，可参考源码实现。

### 其它功能
主要是监控指标以及全局 deadline，我直接使用了 grpc-node 提供 interceptors，拿监控指标举例：

```js
const histogram = new promClient.Histogram({
  name: 'grpc_response_duration_seconds',
  help: 'Histogram of grpc response in seconds',
  labelNames: ['peer', 'method', 'code'],
});

export function getMetricsInterceptor() {
  return function metricsInterceptor(options, nextCall) {
    const call = nextCall(options);

    const endTimer = histogram.startTimer({
      peer: call.getPeer(),
      method: options.method_definition.path,
    });

    const requester = (new grpc.RequesterBuilder())
        .withStart(function(metadata: grpc.Metadata, _listener: grpc.Listener, next: Function) {
          const newListener = (new grpc.ListenerBuilder())
            .withOnReceiveStatus(function(status: grpc.StatusObject, next: Function) {
              endTimer({
                code: status.code,
              });
              next(status);
            }).build();
          next(metadata, newListener);
        }).build();

    return new grpc.InterceptingCall(call, requester);
  };
}
```

你也可以根据自己的需求，禁用默认的监控指标，创建 helper 的时候将 `metrics` 设置为 `false`，然后将自己实现的 interceptors 传入 grpcOpts 即可：

```js
const helper = new GRPCHelper({
  packageName: 'helloworld',
  serviceName: 'Greeter',
  protoPath: path.resolve(__dirname, './hello.proto'),
  sdUri: 'dns://_grpc._tcp.greeter',
  metrics: false,
  grpcOpts: {
    interceptors: [you-metrics-interceptor-here]
  }
});
```

### 总结
好了，总体来说，这个工具的实现不复杂，但是需要花费挺多精力去具体实现，同时我也觉得如果不在这里给这个工具好好宣传一下的话，很容易就会变成只有我自己使用的一个工具，一些问题也不会发现，工具本身也无法进一步发展。

同时，我也相信，我这个工具最终会被官方的功能所取代，但是如果官方能够采用或者参考我的设计的话，那也是不错的结果。

另外，工具现在正在我们的测试环境中使用，正式环境也有部分在使用，所以各位如果有机会也不妨试试。

最后，给个 [Star](https://github.com/xizhibei/grpc-helper) 也是极好的 :P 。

***
首发于 Github issues: https://github.com/xizhibei/blog/issues/86 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
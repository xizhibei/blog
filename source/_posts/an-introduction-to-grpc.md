---
title: gRPC 的介绍以及实践
date: 2018-08-12 15:51:23
tags: [Golang,Node.js,gRPC, 基础知识]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/84
---
<!-- en_title: an-introduction-to-grpc -->

gRPC 是个通用、高性能的开源 RPC 框架。它可以高效地连接单个或多个数据中心的服务。另外也可以支持可插拔的负载均衡、追踪、健康检查以及认证。最后，它也能应用于分布式计算的最后一公里来连接各种设备、手机应用、浏览器与后端服务。[1]

这里可以留意下最后一句话，这句话的意思是：你可以使用 gRPC 来取代现有的 RESTful 接口。事实上，已经有很多案例这么做了：以关键词『gRPC iOS』或者『gRPC Android』去 Google 一下就会发现很多案例。

<!-- more -->

### 基础知识
它所依赖的东西，有两个：HTTP2 以及 Protocol buffer（当然了，其它协议也是支持的，比如 JSON，但是默认推荐的就是 PB ），较于 JSON on HTTP/HTTPS 相当于 PB on HTTP2。

照例，开课前必须得先复习这两个基础知识。

#### HTTP2
先介绍下 HTTP2，它是针对 1.x 是替代，而不是重写，它的方法、状态码、语义等都与 1.x 保持一致，专注于性能的提升，最大的目的是客户端与服务端只用一个连接 [2]；

它提供了如多路复用、双向流、服务器推送、请求优先级、首部压缩等等机制来达到节省带宽、降低 TCP 连接开销的目的，简单来说，HTTP2 采用的协议能大大提升通信效率。

这里只是简单略过，之后有时间会展开再划一划重点。

#### Protocol buffer
它是 Google 旗下的一款平台无关，语言无关，可扩展的序列化结构数据格式。同时也是 IDL(Interface Definition Language)，其实可以将它与 JSON、XML 对比来说，其实它就是一种序列化的协议，通过强制定义数据类型，它的效率其实是超过 json 的，因为不需要像 json 那样动态解析类型。

这一点很重要，gRPC 以此为基础，也就意味着客户端与服务端必须都使用同一份或者互相兼容的 proto 文件。

对应的好处也很明显，大家不用维护冗长的 RESTful API 文档了，直接将加过注释的 proto 文件扔给对方就行了。千万不要小看这一点，多少问题就是因为文档不清楚导致的，与其费劲心思让工程师维护一份有可能两边不一致的 API 文档，还不如强制一份 proto 文件，减少出问题的可能性，从这点说，proto 文件其实就是一个强规范的以及方便的文档。

可能你会觉得 PB 强类型也会显得不灵活，两边的通信层可能会需要加上很多转换逻辑，但 gRPC 支持根据 proto 文件生成客户端或服务端，等于帮我们省去了很多的编写通用代码时间。

### gRPC 的数据交互方式
在 gRPC 中，是支持流的，也就是一连串的数据，这其实也是靠 HTTP2 的特性。

- Unary RPCs，一次请求，一次返回，没有流，这是最常用的方式：
```proto
rpc SayHello(HelloRequest) returns (HelloResponse){
}
```

- Server streaming RPCs，客户端发送单次请求，服务端会返回一连串的数据，比如服务端向客户端推送站内即时消息：
```proto
rpc LotsOfReplies(HelloRequest) returns (stream HelloResponse){
}
```

- Client streaming RPCs，客户端会发送一连串的数据到服务端，服务端返回单次数据，比如发送实时日志：
```proto
rpc LotsOfGreetings(stream HelloRequest) returns (HelloResponse) {
}
```

- Bidirectional streaming RPCs，双向流，两边各自会发送一连串的数据，比如实时语音通话以及一些游戏场景中：
```proto
rpc BidiHello(stream HelloRequest) returns (stream HelloResponse){
}
```

### 实践

#### Golang 中如何使用

[官方的例子](https://grpc.io/docs/quickstart/go.html) 中，是根据 proto 文件生成，这个工具是必须得有的：

```bash
go get -u github.com/golang/protobuf/{protoc-gen-go,proto}
protoc service.proto --go_out=plugins=grpc:.
```

与 [go-kit](https://github.com/xizhibei/blog/issues/78) 配合起来使用是极佳的，因为同时还能支持其它协议。

以下两个项目可以着重看看：

- [go-grpc-middleware](https://github.com/grpc-ecosystem/go-grpc-middleware)： 一些现成的中间件，认证、日志、分布式追踪跟重试等等；
- [grpc-gateway](https://github.com/grpc-ecosystem/grpc-gateway)：一个 protoc 的插件，可以将 gRPC 接口转换为对外暴露 RESTful API 的工具，同时还能生成 swagger 文档；

#### Node.js 中如何使用	
由于是动态语言，所以直接加载即可，还是参考 [官方的例子](https://grpc.io/docs/quickstart/node.html)。

当用在客户端的时候，由于往往使用的是 Unary Call，也就是没有流存在，这时候 Node.js 生成的是 callback 风格的，显然已经过时了，可以参考如下代码的思路做一次 Promise 封装。

```js
const Service = grpc.load(protoPath)[packageName][serviceName];
const methods = _.keys(Service.prototype).filter(m => _.isFunction(Service.prototype[m]));

let _client = new Service(host, grpcCredentials, grpcOpts)
_client = Promise.promisifyAll(client);

const client = {}
_.each(methods, m => client[m] = _client[`${m}Async`].bind(_client));
```

另外，安装 grpc 的 npm 包的时候，会从被墙的 Google storage 取数据，因此多半会失败，fallback 到本地编译，显然会拖慢安装速度，因此建议搭建代理来解决。

在 ~/.npmrc 下添加如下配置即可（淘宝的那个 grpc 镜像不行，跟这个包需要的地址无法映射）。

```
grpc_node_binary_host_mirror=http://your-proxy-server
```

#### 负载均衡
- 集中式负载均衡：
由于是基于 HTTP2，于是靠外部负载均衡都是可以的，而且是相对简单的，比如 Nginx 以及 traefik，都实现了 HTTP2 的负载均衡。

- 进程内负载均衡：
进程内，也就是客户端的进程内负载均衡也是可以的，而且由于少了一层外部负载均衡，性能也会有所提升。同时，客户端负载均衡需要进行动态服务发现，即将服务解析为每个服务端的地址，需要依靠外部服务发现，比如 etcd、consul 等，而如果是在 k8s 中使用，可以使用 DNS 的 srv 记录实现负载均衡，另外，[这是 gRPC 是原生支持的](https://github.com/grpc/proposal/blob/master/A5-grpclb-in-dns.md)。

- 独立进程负载均衡：
其实也属于客户端，只不过这样可以将服务发现以及负载均衡相关的逻辑抽出来，变为本地调用，支持任何语言实现的客户端，同时也是简化了客户端的实现（对了，其实就是 Service Mesh 的核心思想）。


#### DNS 服务发现负载均衡
如果没有听说过，简单说下，就是通过 k8s 的 Headless service （就是没有 Cluster IP 的 service）来实现。

假如你有如下的 service：

```yaml
apiVersion: v1
kind: Service
metadata:
  name: foo
  namespace: bar
spec:
  selector:
    name: busybox
  clusterIP: None # 重点
  ports:
    - name: http
      port: 1234 
      targetPort: 1234
```

然后在一个有 dig 工具的 docker container 中运行以下命令后:

```bash
dig srv  _http._tcp.foo.bar.svc.cluster.local
```

会发现类似下面的输出（部分）：

```
;; QUESTION SECTION:
;_http._tcp.foo.bar.svc.cluster.local. IN SRV

;; ANSWER SECTION:
_http._tcp.foo.bar.svc.cluster.local. 30 IN SRV 10 33 1234 3166346562643838.foo.bar.svc.cluster.local.
_http._tcp.foo.bar.svc.cluster.local. 30 IN SRV 10 33 1234 6134356136303531.foo.bar.svc.cluster.local.
_http._tcp.foo.bar.svc.cluster.local. 30 IN SRV 10 33 1234 3866623563306661.foo.bar.svc.cluster.local.

;; ADDITIONAL SECTION:
3166346562643838.foo.bar.svc.cluster.local. 30 IN A 10.233.67.245
6134356136303531.foo.bar.svc.cluster.local. 30 IN A 10.233.68.21
3866623563306661.foo.bar.svc.cluster.local. 30 IN A 10.233.71.141
```

可以发现这个 foo 的服务有 3 个 pod，给出了分别对应的 IP 以及对应端口是 1234。于是通过将服务地址配置为服务端地址后，就可以很简单地实现负载均衡了。

另外，很遗憾的，Node.js 的 grpc 底层用的 C++ addon 模块虽然有负载均衡能力，但是 [还没有在 node 层面实现相关的胶合代码](https://groups.google.com/forum/#!topic/grpc-io/Uaq3K3TDDjU)，但是 [grpc-go](https://github.com/grpc/grpc-go) 是实现的了。


#### Health check
健康检查建议要实现，尤其是依靠客户端负载均衡的，而且官方也已经定了 [健康检查的协议](https://github.com/grpc/grpc/blob/master/doc/health-checking.md)

如果是在依赖于服务发现的负载均衡中，健康检查最好是让外部服务发现去做，比如 consul 就支持 [gRPC 的健康检查协议](https://www.consul.io/api/agent/check.html#grpc)。这样做的话，可以避免客户端太多的情况下，每个客户端都需要做健康检查，发送太多健康检查请求，挤占带宽以及影响服务端性能。

最后，是不是被这些要做的事情给搞头大了？没事，请允许我在这插个无耻的广告：我将 Node.js 的 [grpc](https://github.com/grpc/grpc-node/blob/master/packages/grpc-native-core) 做了个封装，实现了 Unary call 的 Promise 化，以及服务发现、负载均衡、健康检查、断路器等。正在开发中，欢迎提意见，详情请看：[xizhibei/grpc-helper](https://github.com/xizhibei/grpc-helper)。

### Ref
1. [gRPC](https://grpc.io/about/)
2. [HTTP2](https://http2.github.io/)
3. [Protocol Buffers](https://developers.google.com/protocol-buffers/)

***
首发于 Github issues: https://github.com/xizhibei/blog/issues/84 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
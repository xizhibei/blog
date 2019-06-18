---
title: 如何优雅重加载 Web 应用
date: 2019-06-03 15:37:42
tags: [DevOps,Golang,Node.js]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/108
---
<!-- en_title: how-to-graceful-reload-web-app -->

但凡在各种环境中，尤其是生产环境中部署过应用的，比如更新应用或者配置，就会了解到，应用的重启或者升级多少都会影响用户访问，那这种影响会到什么程度呢？

### 影响用户的重启

从**表面**上看，轻则是页面不能正常加载，让用户以为是网络不好（事实上，这也经常成为服务器出问题的背锅原因，有的 APP 则直接在前端硬编码报错信息，所有的错误统一显示：网络出错了，请重试）。
重则影响用户的支付流程，导致用户放弃支付，更严重的则是用户支付过程中处理数据不当的话，就会丢失数据，导致对账失败。

而从**本质**上看，如果你在浏览器中调试的时候，这种错误会在调试窗口显示 `net::ERR_CONNECTION_REFUSED`，原因就是端口被释放了，这也就是告诉我们，重启过程中的一段时间里，由于后续程序无法快速建立监听，会导致 TCP 链接被短时间断开，端口监听也会被释放，导致数据包无法送达，正在使用中的连接也会被打断，就会导致这个现象。

所以，我们该如何解决？回过头看这个过程，我们就需要达到的目标无非就是**用户无感知**，那对于我们就有两种方案：一种是把这个责任交给现有的成熟负载均衡器，另一种是自己用操作系统提供的 API 自己实现自我升级。

### 自我升级方案

目前已经有多个社区的基础库可以帮助实现了，比如 Golang，我们至少有以下几个<sup>[1]</sup>：

-   <https://github.com/cloudflare/tableflip>
-   <https://github.com/alext/tablecloth>
-   <https://github.com/astaxie/beego/grace>
-   <https://github.com/facebookgo/grace> （已经停止维护，项目只读）
-   <https://github.com/crawshaw/littleboss>

实际上，看源码后自己实现也可以，因为原理是一致的，升级的大致过程就是以下：

1.  启动进程，运行 Web 服务，监听相关的端口；
2.  接收到 Reload 命令，运行新程序，运行并等待服务可用；
3.  新子程序出错时，直接报错，退出 Reload 步骤；
4.  没有问题则继续，旧进程退出，新进程接管流量；

这种方案就是非常常见的方案，只是在这个过程中，同一时间只允许一个升级，不然就会出现问题。其实还有个方案，如果是针对自己无法修改的程序，可以参考 Github 为 HAProxy 开发的 multibinder<sup>[2]</sup>。

### 负载均衡方案

这种方案是最简单的，因为负载均衡器可以接管流量，负责升级过程：当新进程准备完成时，把旧 Web 应用的流量切换到新 Web 应用，然后不断升级剩余的应用，这在 Kubernetes 或者 Docker Swarm 中叫做 [**Rolling Upgrade**][4]，这个过程会非常顺滑，可以达到让用户无感知。

另外，有的负载均衡器自己就实现了自我升级的，比如 Nginx，我们用 `nginx -t reload` 这个命令就能让 Nginx 重新加载配置，这个过程中，它就进行了自我升级。

而在 Node.js 中，有 pm2 提供给我们的 [Graceful shutdown][3] 方案，即通过进程内通信的方式，让我们能够在关闭时提前关闭数据库等连接，以及启动的时候等数据库连接等完成后再继续。这种方式可以让我们自己在 Cluster 模式中，进行应用的优雅升级，只是，它做得不够好（2.x 版本的时候）：

1.  升级过程中，不会判断新程序有没有准备完毕，一旦超时还是会继续升级，这在之前导致了非常多的线上问题；
2.  升级无法控制速度，升级速度很快，于是我们可以看到监控画面上，过山车似的一上一下，这实际上是不好的，因为这就表示我们的重启影响到了部分用户；

新版本 (3.x) ，还没用过，但是看[文档][3]，它提供了 `–parallel` 这个参数，能让我们自己控制并行升级数量了，也就是能控制升级速度了，配合 **Graceful shutdown** 的功能，应该能够缓解。

但更好的方案的话，还是得用 Kubernetes 提供的 [**Rolling Upgrade**][4] 功能，这在我之前的实践中，可以观察到明显的对比，即新方案上了之后，每次升级监控上的响应时长波动会很小。

### Ref

1.  [Graceful upgrades in Go][1]
2.  [GLB part 2: HAProxy zero-downtime, zero-delay reloads with multibinder][2]

[1]: https://blog.cloudflare.com/graceful-upgrades-in-go/

[2]: https://github.blog/2016-12-01-glb-part-2-haproxy-zero-downtime-zero-delay-reloads-with-multibinder/

[3]: https://pm2.io/doc/en/runtime/best-practices/graceful-shutdown/

[4]: https://kubernetes.io/docs/tutorials/kubernetes-basics/update/update-intro/


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/108 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
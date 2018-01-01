---
title: 关于 pm2 的弱项
date: 2016-04-20 12:05:19
tags: [Docker,Node.js]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/4
---
### 部署 deploy

由于我们线上项目全部部署在高配主机上，使用的是 pm2 部署，于是当我刚接手的时候，十几台主机全部用 pm2 部署的意义不知你是否明白，每台部署至少 1 分钟，然后串行部署，于是开始部署之后，可以很悠闲地去喝杯茶了

解决方案么，可以考虑用 ansible，chef，puppet 之类的工具，我用 ansible 部署之后，1-2 分钟就可以全部部署完毕。
### 负载均衡 load balance

为了图方便，我们会在主机上部署的时候使用多个 cluster，但是 pm2 的负载均衡很弱。

我在测试环境粗略试过，在一台 16 核 16G 主机上，1000QPS，pm2 部署 10 个 cluster（同一个端口），然后用 haproxy+10 个 node 进程（占用不同端口），性能提升 10 倍以上。

由于这个测试很粗略，测试报告就不写了，只是从理论上也可以想明白，毕竟 pm2 不是专门负责 load balance 的，用一个专门的 LB 去处理的话，肯定可以提升性能。

因此解决方案可以考虑 docker + 负载均衡 (如 haproxy)，对于我们来说，目前项目人手太少，不太可能使用 Mesos 或 Kubernetes 之类的编排管理工具，docker swarm 的话，可以考虑，因为简单一些比较容易上手，只是也会比较废精力，暂时不考虑。

所以，我觉得对于我们这样的小团队来说，可以采用简单点的方案，使用 ansible+docker compose 来实现，即在每台机器上用相同的 docker-compose 部署 haproxy+app。
#### 一些后话

最近一直在看有关 docker 的东西，对于 docker，我觉得的确是个好东西，只是，当我们把一项新技术引入到现有的团队的时候，需要考虑更多的东西。

比如，它到底能解决什么痛点，生态圈如何，上手难度如何，运维成本多少，简单来说：算算引入的成本与收益。我们很容易犯的错误就是， 拿着一把锤子，然后看什么都是钉子。


***
原链接: https://github.com/xizhibei/blog/issues/4

![知识共享许可协议](https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png "署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）")

本文采用 [署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh) 进行许可。

---
title: Kubernetes 排错之 HTTP 429
date: 2018-03-11 13:12:10
tags: [Linux,kubernetes]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/72
---
<!-- en_title: kubernetes-troubleshotting-http-429 -->

### 背景
1. 我们线上的 k8s 集群是使用 ansible 安装的 [1]，使用的是 coreos 提供的 hyperkube 镜像中的可执行文件（其实之前也提到过类似的：[CentOS 7 使用 ansible 搭建 kubernetes](https://github.com/xizhibei/blog/issues/47)）；
2. 跑的应用主要是线上离线任务，属于即使挂掉一阵也不会影响到正常业务的那种，部署了 15 个 Deployment；
3. 部署的 Etcd 使用 docker 部署，使用 systemd 管理；
4. 一旦更新了应用配置，就会自动更新在相应的 namespace 中所有的 Deployment;

### 起因
一直以来，我们用的线上 k8s 非常稳定，但是在春节期间，出现一个很奇怪的问题，那天同事在更新代码后，需要更新线上的应用，之后突然发现本地电脑执行 kubectl 一直返回 timeout 错误。

这时候，我登录 k8s master 节点机器开始查找问题，发现 kubectl 也不能使用了，这就意味着 APIServer 的接口出错了，查看监控，果然是出问题之后的监控数据全部消失了。

然后用 `docker logs <APIServer docker instance id>` 查看日志，发现大量的 `http status code 429` 错误，这个 `HTTP 429` 代表的意思就是请求太频繁，导致服务器来不及处理请求了。也就是说，当前的 APIServer 接口到达处理极限了。

### 简单处理
为了尽快处理问题，先将机器重启，结果，还是没法解决，反而是 AVG CPU load 超过 1 了，平时也就零点几，这显然是太高了。

考虑了一会儿，我觉得应该将整个 k8s 集群重新安装，恩，果然没事了，可以安心过春节了。

但是同时，由于处理太着急，一些日志也没有保留，导致无法定位真正的问题。

### 一些准备
原因总结下来，很大一部分原因是监控没有做好，报警也没有发挥作用。

因此，我在接下来的时间里，连续部署了两套监控报警系统

- [netdata](https://github.com/firehol/netdata)
- [prometheus](https://prometheus.io)

其实 prometheus 在之前的文章中提过，只是没做好报警：[监控利器之 Prometheus](https://github.com/xizhibei/blog/issues/54) 以及 [在 k8s 中部署 Prometheus](https://github.com/xizhibei/blog/issues/55)

事实证明，这还是挺管用的，因为部署并且测试完后的当天，问题又出现了。。。

### 再次出现问题
收到报警，集群 APIServer HTTP 错误率到达 100%，细看还是那个 429 的 HTTP 错误，打开 master 节点的 netdata 监控图表，发现了有两个报警，提示： `TCP listen overflow`。

TCP 相关的基础知识就不再赘述了 [2]，这里只说一点：TCP 的 backlog 就是一个处理队列，当有新连接请求（SYN 包）来的时候，就会把请求放在 backlog 中等待处理，而假如这个队列太小又或者并发请求数又太高，就会出现这个问题。

于是直接将 TCP backlog 的数值调高，从 128 提高到 256。

```bash
echo 256 > /proc/sys/net/ipv4/tcp_max_syn_backlog
```

观察一阵后，问题还是存在，那么原因很显然不是这个。

于是继续观察 netdata 数据，从最上面的图表看到最下面，当看到 ETCD 这一栏监控数据的时候，发现了问题，内存从发生问题的时间点之后，几分钟内一路飙升至 500M，并一直保持不变，但是目前机器的内存使用率并没有超过 50% 。

于是我做了这么个推测：我使用的部署脚本中，会不会有参数定死了 500 M 呢？

于是查看 Etcd 启动文件：

```bash
#!/bin/bash
/usr/bin/docker run \
  --restart=on-failure:5 \
  --env-file=/etc/etcd.env \
  --net=host \
  -v /etc/ssl/certs:/etc/ssl/certs:ro \
  -v /etc/ssl/etcd/ssl:/etc/ssl/etcd/ssl:ro \
  -v /var/lib/etcd:/var/lib/etcd:rw \
    --memory=512M \
    --oom-kill-disable \
      --blkio-weight=1000 \
    --name=etcd1 \
  quay.io/coreos/etcd:v3.2.4 \
  /usr/local/bin/etcd \
  "$@"
```

命令的参数中的：`--memory=512M` 以及 `--oom-kill-disable` 引起了我的注意，这两个参数一个是限制了最大内存，另一个限制了 OOM 的时候不杀掉 Etcd，于是会出现由 OOM 造成的卡死，那么问题原因应该也就是这个了。

好了，改成 1024M，重启，问题解决。

### 原因深度分析

1. 为什么 API 返回 100% HTTP error ？因为 APIServer 是建立在 Etcd 这个数据库之上的，数据库挂了，APIServer 也就不行了；
2. 为什么有 TCP overflow？显然是 APIServer 无法处理任何请求了，导致 TCP 的 backlog 队列一直在排队，超过之后就会 overflow，而此时调整 TCP backlog 并不能解决问题；
3. 为什么出现这个线上故障？在开头的背景介绍里面应该能看出来了，由于更新了太多的 deployments，瞬间增加了大量请求，而给 Etcd 的内存又不够导致的；

### 总结
有两方面的原因：

- 一是集群的监控没有做好；
- 另一个是部署的时候，没有对 Etcd 很重视，而在之后如果还要继续往 k8s 里面增加更多的服务的话，就需要单独部署 Etcd 集群，并提高相应的机器配置；

### Ref
1. [kubespray](https://github.com/kubernetes-incubator/kubespray)
1. [How TCP backlog works in Linux](https://veithen.github.io/2014/01/01/how-tcp-backlog-works-in-linux.html)



***
原链接: https://github.com/xizhibei/blog/issues/72

![知识共享许可协议](https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png "署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）")

本文采用 [署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh) 进行许可。

---
title: 网络测速工具 iperf
date: 2020-01-13 19:56:04
tags: [DevOps,kubernetes]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/129
---
<!-- en_title: speed-test-tool-iperf -->

在我们日常的网络相关实践中，有个常见的需求便是，测试网速。

如果只是为了测试自己所在位置的网速，那么，我们可以直接打开网页，直接开始测试即可，比如著名的 [SpeedTest](https://www.speedtest.cn/) 。

然而，如果你的需求是测试两台机器之间的网速，那么，我们就需要用其它的更专业的工具来测试了。

也就是今天要介绍的 iperf。

### 简介

目前它的大版本是 3，对应的命令行名称是 `iperf3`。

它的自我介绍是『A TCP, UDP, and SCTP network bandwidth measurement tool』，简单直接，其实就是测试网络带宽的。

### 安装

由于是个比较古老的工具，目前已经可以在大多数操作系统中直接安装了。

```bash
brew install iperf3 # MacOS
sudo apt install iperf3 # Ubuntu
sudo yum install iperf3 # CentOS
```

或者，也可以使用 Docker：

```bash
docker search iperf3
```

然后从中挑选一个即可，我挑了个版本比较新的：

```bash
docker pull mlabbe/iperf3
```

需要注意的是，这种情况下，测出的速率可能无法真实反映网速，毕竟经过了 Docker 的虚拟层。

### 使用

由于这种测速是测两台机器之间的网速，我们需要部署两个点，一台用来当做服务器，另一台用来当做客户端。

对于服务端需要注意，需要确保本地的 5201 端口没有被其它进程占用：

```bash
netstat -nltp | grep 5201
```

如果端口被占用，可以另外指定端口。

然后，就可以开始测试了：

-   服务端：`iperf3 -s` （或者 `iperf3 -p <port> -s`）;
-   客户端：`iperf3 -c <server-address>`（或者 `iperf3 -p <port> -c <server-address>`）;

然后，你可以同时在两个端的输出中，看到类似于下面的输出：

    Connecting to host 192.168.1.102, port 5201
    [  7] local 192.168.1.101 port 51365 connected to 192.168.1.102 port 5201
    [ ID] Interval           Transfer     Bitrate
    [  7]   0.00-1.00   sec  49.7 MBytes   416 Mbits/sec
    [  7]   1.00-2.00   sec  49.7 MBytes   417 Mbits/sec
    [  7]   2.00-3.00   sec  49.1 MBytes   412 Mbits/sec
    [  7]   3.00-4.00   sec  49.7 MBytes   417 Mbits/sec
    [  7]   4.00-5.00   sec  43.3 MBytes   363 Mbits/sec
    [  7]   5.00-6.00   sec  45.7 MBytes   383 Mbits/sec
    [  7]   6.00-7.00   sec  43.8 MBytes   368 Mbits/sec
    [  7]   7.00-8.00   sec  40.8 MBytes   341 Mbits/sec
    [  7]   8.00-9.00   sec  41.8 MBytes   351 Mbits/sec
    [  7]   9.00-10.00  sec  42.4 MBytes   356 Mbits/sec
    - - - - - - - - - - - - - - - - - - - - - - - - -
    [ ID] Interval           Transfer     Bitrate
    [  7]   0.00-10.00  sec   456 MBytes   382 Mbits/sec                  sender
    [  7]   0.00-10.01  sec   456 MBytes   382 Mbits/sec                  receiver

    iperf Done.

从输出来看，我们可以看到，iperf3 以最高速度（默认 TCP 连接）测试了我本地两个点之间的带宽，测试了 10 秒，平均速度为 382 Mbits/sec，也就是 47.75 Mbytes/sec，我测试的时候是 WiFi 网络，这个速值基本反映了我本地网络的带宽。

### 更多的应用场景

##### 测试本地公网速率

你可以用别人提供的 iperf3 服务器来测试，比如 [Public iPerf3 servers](https://iperf.fr/iperf-servers.php)，其实这就相当于开头提到的 SpeedTest 了。

##### 测试 Kubernetes 各个节点之间的网速

这个需求挺常见的，尤其是有可能遇到 Kubernetes 内网络问题的时候，毕竟你部署的地方，不知道会不会有节点之间网速问题。所以你可以直接看这个项目 [Pharb/kubernetes-iperf3](https://github.com/Pharb/kubernetes-iperf3)。

它的原理，可以简单描述下：

1.  将 iperf3 server 部署在 master 节点上；
2.  将 iperf3 client 部署在所有节点上，包括 master，并保持空转（即睡眠状态）；
3.  最后用 kubectl 获取所有的 client，依次执行测试命令；

##### 其它

测试 VPN、P2P 网络等，另外，它还可以测试 UDP、SCTP 协议。

相信你也应该看出来了，它也非常适合于虚拟网络的测试，因为这样可以测试虚拟之后带来的网络损耗等问题。


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/129 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
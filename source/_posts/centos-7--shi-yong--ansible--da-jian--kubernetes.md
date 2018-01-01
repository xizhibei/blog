---
title: CentOS 7 使用 ansible 搭建 kubernetes
date: 2017-05-06 15:48:32
tags: [ansible,Docker,kubernetes]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/47
---
一直以来，我使用的是 rancher，它提供的 k8s 集群非常棒，基于 docker 镜像安装，免去了很多的安装配置细节，如果对于 k8s 的运行原理不想太深入了解、图方便快捷或者只是想尝试功能，那么它会让你绝对满意：在界面上点击配置下就能搭建起一个集群了。

但是这次我就需要自己真正在机器上搭建起一个原生的集群，折腾下自己。众所周知，k8s 的安装，绝对是个坑，尤其是国内，不翻墙基本上就没戏，对比国外的技术环境，瞬间觉得，国内的技术环境下，能做出好的世界性项目绝对不容易，当然 GFW 除外。

好了，吐槽结束，下面开始正题。

### 工具准备
首先是代理或者 VPN，这个没的说，不然很多东西都得浪费一整天去下载。

其次是机器，一般来说，4 台机器就差不多就可以搭建一个 k8s 环境：1 台 master，3 台 node。目前，我手里面只有 CentOS 7.2 (内核版本：3.10.0-123.4.4.el7.x86_64)，接下来的例子也是以它为例来讲解。

最后是安装工具：ansible，我提到过很多次，是 IaaS 的代表工具之一。还有要用到的代码：https://github.com/kubernetes/contrib/tree/master/ansible 。

### 技术准备
如果不了解 k8s 就直接开始安装的话，会有问题，或者说，出了问题之后，你很难去解决。

在这里不方便多说，请移步文档：https://kubernetes.io 。

然后是 ansible，如果不了解具体的搭建过程，相信你会有种不安全感。

好吧，知道你懒，我简单解释下 **playbooks/deploy-cluster.yml**：

这里面是 k8s 经典的搭建步骤：首先搭建 etcd 集群，然后是 docker, 然后是网路层，一般使用 flannel（当然，也有 opencontrail 以及 contiv，但是我没尝试过），最后才是 k8s 层。

这个过程中要部署的模块如下：

- master:
	- etcd
	- flannel
	- kube-apiserver
	- kube-controller-manager
	- kube-scheduler
- node:
	- etcd
	- docker
	- flannel
	- kubelet
	- kube-proxy


### 一些修改
添加 inventory/inventory 文件：

```ini
[masters]
master1.example.k8s.cluster

[nodes]
node[1:3].example.k8s.cluster

[etcd]
node[1:3].example.k8s.cluster
```

其实这个项目是有不少问题的，害得我一直无法安装成功，其中一个问题我提交了一个 [commit](https://github.com/xizhibei/contrib/commit/0b76b9233a0944330cf1e928a89b00e721846f99) 去修改，但是目前还没被合并进主分支。你可以参照着修改。
 
另外，它提供的 flannel role 问题也不少，在 CentOS7 下没有修改 docker 的 options，导致一度 k8s pod 的 IP 地址有问题。这里需要说明下：如果你了解 k8s 控制 docker 集群网络的原理，这个问题很容易解决，** 因为它就是通过 flannel 之类的网络层工具，用 docker 的 bip 参数去把 cluster 的节点串联起来 **。
 
因此，我提供的临时解决方案是直接在 /etc/systemd/system/docker.service.d/ 中加入如下 drop in 配置文件：
 
```conf
# docker-option.conf
[Service]
EnvironmentFile=-/run/flannel/docker
# DOCKER_NETWORK_OPTIONS="--bip=172.16.0.1/24 --ip-masq=true --mtu=1404"
ExecStart=/usr/bin/dockerd $DOCKER_NETWORK_OPTIONS
```

另外，就是 针对实际项目的配置修改了：

```yml
# inventory/group_vars/all.yml

# 代理配置
http_proxy: "<your proxy here>"
https_proxy: "<your proxy here>"
no_proxy: "127.0.0.1,localhost,get.daocloud.io"

# yum 源下，包名不是 docker
docker_package_name: "docker-engine"

# 使用 国内 daocloud 提供的 yum 源，不用翻墙
docker_source_type: "custom-repository"
docker_repository_baseurl: "https://get.daocloud.io/docker/yum-repo/main/centos/$releasever/"
docker_repository_gpgkey: "https://get.daocloud.io/docker/yum/gpg"

# 1.6.* 有较多不兼容的修改，导致无法配置成功，而 1.5.6 是 目前 GCE 上的默认版本
kube_version: 1.5.6

# packageManager 会有依赖包问题，我测试下来一直无法安装成功
kube_source_type: github-release

# 默认的 443 会有 bind 权限问题
kube_master_api_port: 8443

# 以下两个都建议关闭，按照 dashboard 这个项目的说明来安装：https://github.com/kubernetes/dashboard
kube_ui: false
kube_dash: false
```
 
的确，这个 kubernetes/contrib 目前很烂，这么多子项目都堆在一起，维护的又不是很好，但是，大部分还是可以用的，所以也就凑合着用吧。

### 开始搭建

```bash
cd scripts
./deploay-cluster.sh
```

有问题欢迎交流。


***
原链接: https://github.com/xizhibei/blog/issues/47

![知识共享许可协议](https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png "署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）")

本文采用 [署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh) 进行许可。

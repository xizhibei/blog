---
title: Gitlab 的部署与维护
date: 2017-11-05 14:43:13
tags: [DevOps,Docker,Gitlab]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/61
---
<!-- en_title: the-deployment-and-maintenance-of-gitlab -->

一直以来，我没有总结过 Gitlab 的部署，而在以前的文章中，我不止一次提到关于 Gitlab 在我们整个交付流程中起到的基础性作用，以及它为整个公司的开发带来的巨大效率提升：

- [使用 docker runner 加速 gitlab CI&CD](https://github.com/xizhibei/blog/issues/49)
- [持续交付的实践与思考](https://github.com/xizhibei/blog/issues/42)
- [Git 协作流程](https://github.com/xizhibei/blog/issues/39)
- [CI 系统搭建](https://github.com/xizhibei/blog/issues/26)

那么作为一个在公司起基础作用的东西，我们应该如何去对待它？

> 有钱就花钱，没钱就认怂，能花钱的，就不要花时间。

下面开始认怂。

### 准备工作
首先，你需要有一台机器。

然后，看下 Gitlab 官方对应的配置列表（链接请看下面的 Ref）。一般来说，中小公司（人员 500 以下），2 核 4G 就够，硬盘可以大一些： 500 G。

### 部署
我在之前学习 Docker 的过程中，直接用到了这个项目中的部署方式：https://github.com/sameersbn/docker-gitlab （Hats off，非常感谢他做的工作，给我省了好多事）。

这种部署方式非常方便，配置下 docker-compose.yaml 然后运行即可。

其中需要注意的几点在于：

- 如果你的服务是暴露出来给公司里大家一起用的，那么端口可以使用『默认』的端口：80,443,22 ，如果使用其它端口，就会显得很丑；
- 尽量申请正规的 HTTPS 证书然后配置，毕竟代码是你们的核心资产；
- 给日志提供外部挂载，方便问题查找；

#### Gitlab 架构
好了，回到这个过程中，知道它干了什么还是挺重要的。

在这里，一共有三个镜像，Redis, PostgreQL 还有 Gitlab，前两个没啥可以说的，关键是第三个镜像，里面包含了挺多的内容，其实有点是 Docker 镜像的『反模式』了。

当你用 htop 之类的命令查看时，会发现以下几个进程：

- supervisor
- nginx
- sshd
- cron

你应该能够理解，毕竟也是我们常用的工具；而后面是 Gitlab 独有的：

- unicorn: Gitlab 自身的 Web 服务器，属于 Ruby 领域的东西了，里面跑的 Gitlab 主进程，用来处理网略请求;
- [gitlab-workhorse](https://gitlab.com/gitlab-org/gitlab-workhorse): 代理服务器，用来处理大的 HTTP 请求，比如文件上传下载，Git Push/Pull ;
- [gitaly](https://gitlab.com/gitlab-org/gitaly): RPC 服务，处理 Gitlab 所有的 Git 处理请求；
- [sidekiq](https://github.com/mperham/sidekiq): 后台任务服务；
- [mail_room](https://github.com/tpitale/mail_room): 处理邮件请求，当你回复有些 Gitlab 的邮件时，Gitlab 会靠这个服务来执行一些操作；
- [Gitlab_shell](https://github.com/gitlabhq/gitlab-shell): 处理在 22 端口中，你用到的 Git 交互命令；

我们来看看 Gitlab 的架构图（来自 [Gitlab 官方](https://docs.gitlab.com/ce/development/architecture.html)）：

![](https://docs.google.com/drawings/d/1fBzAyklyveF-i-2q-OHUIqDkYfjjxC4mq5shwKSZHLs/pub?w=987&h=797)

把这个图看懂，以后处理这方面的问题的时候，你也会更得心应手了。


### 部署 Docker Registry

官方其实没有给出非常方便的部署方式，需要很蛋疼得去配置一些东西，具体请看 [这里](https://github.com/sameersbn/docker-gitlab/blob/master/docs/container_registry.md) 。

我提几个关键的点：

- 从前 @sameersbn 以前可能会让你在服务上直接暴露 5000 端口，在 Registry 那里配置好 HTTPS 证书，然后转发即可，新的做法是直接在 Gitlab 里面的 nginx 中配置好转发，因此者证书配置就换到 Gitlab 中去配置了，它会负责将请求从内部转发到 Registry，这样你使用的 Docker 镜像也不用带上丑陋的 5000 端口了；
- 如果你申请的是泛域名 HTTPS 证书，可以与 Gitlab 本身的 HTTPS 证书中一起使用；
- 按照新的配置方式，你只需将 registry.example.com 与 gitlab.example.com 解析到同一个地方即可；
- 如果遇到 Gitlab 中的 Registry 页面发生 500 错误，请检查下 HTTPS 证书的权限，确保证书是可读的；

### HTTPS 证书
这个步骤其实挺关键，还是那句话，为了代码安全，尽量去购买正规的 HTTPS 证书，也可以省点部署与维护的时间。

将证书命名为 gitlab.key 与 gitlab.crt，放到 Gitlab home 目录下的 certs 文件夹下即可。同时，为了加强 HTTPS 的安全性，还可以配置 PFS 与 HSTS：

- PFS: 即完全向前保密 (Perfect Forward Secrecy)，可保证即使你每次的 HTTPS 会话密钥不相同，简单来说就是即使黑客破解了你当前这次会话的内容的密钥，但是这个密钥不能破解下次的会话，他需要重新破解。在这里，你使用命令 `openssl dhparam -out dhparam.pem 2048` 生成文件，放到上面提到的 certs 文件夹中即可；
- HSTS: 即严格传输保密 (HTTP Strict Transport Security)，这个配置会告诉浏览器，在一个未来长期时间内，这个网站只能被 HTTPS 请求。在这里，可以用 `NGINX_HSTS_MAXAGE` 去配置，一般你开启了 HTTPS 之后，就会使用默认值 `31536000`；

### Ref:
- https://docs.gitlab.com/ce/install/requirements.html
- https://docs.gitlab.com/ce/install/installation.html
- https://docs.gitlab.com/ce/development/architecture.html
- https://about.gitlab.com/2016/04/12/a-brief-history-of-gitlab-workhorse/
- https://adairjun.github.io/2016/12/20/gitlab/
- http://blog.justwd.net/2014/01/perfect-forward-secrecy/


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/61 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
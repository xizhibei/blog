---
title: 善用工具，节约时间
date: 2019-04-22 11:31:42
tags: [工作方法, 总结]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/104
---
<!-- en_title: save-time-by-tools -->

这个月似乎忙得晕头转向了，一到该写的日子，什么灵感都没，于是拖了一天，最后打算总结下自己的一些 DevOps 技巧以及比较好用的工具。

### 工具列表
#### Gitlab CI
这是必须的内容，每个我经手的项目，必须要有 CI 功能，其中会选择性加入代码静态检查以及单元测试等步骤，另外就是编译打包 Docker 镜像步骤，方便之后的部署。

目前还是使用 Gitlab 为主，至于 GitHub 就更爽了，有 [一堆的 CI 服务可用][1]。

之前写了不少 Gitlab CI 相关的内容，不妨看看：

- [使用 docker runner 加速 gitlab CI&CD](https://github.com/xizhibei/blog/issues/49)
- [持续交付的实践与思考](https://github.com/xizhibei/blog/issues/42)
- [Git 协作流程](https://github.com/xizhibei/blog/issues/39)
- [CI 系统搭建](https://github.com/xizhibei/blog/issues/26)
- [Gitlab 的部署与维护](https://github.com/xizhibei/blog/issues/61)

#### IM 平台
代码一旦 Push，如果还要不断去刷网页查看 CI 进度的话，未免太傻了，于是，可以利用大部分代码托管平台的 Webhook 功能，实时发送信息至各个 IM 平台即可。

国内有钉钉与企业微信，对于钉钉来说，它做了 Gitlab、GitHub 等的适配，简直太爽，而企业微信这点做得太烂了，需要自己做个工具进行转发。

国外有 Slack 等，GitHub、Gitlab 完美支持，非常爽。

于是，Push 完代码，喝杯茶，慢慢等待 CI 通过即可，不要小看这点时间，正所谓集腋成裘，慢慢就会节约很多时间了。

#### [Git Auto Deploy][2]
这是在测试环境部署项目的另一种比较方便的工具，简单解释下：也就是利用 Webhook，再收到通知后，会更新本地的 Git 项目，然后执行一些命令，而这些命令一般就是部署的命令。

正式环境一般不推荐用，毕竟太简陋了。

#### Docker Compose
这是单机测试环境中最方便的 Docker 部署工具了，我会专门建一个 Git 项目用于存放它的配置文件，方便追踪所有的配置更改，也不容易出错。

然后还需要放几个脚本，用来一键部署，比如建一个 `dc.sh`。

```bash
#!/usr/bin/env bash

docker-compose ${@:1}
```

这样的话，可以少打几个字，一键启动：

```bash
$ ./dc.sh up -d
```

最后在 Readme 中，写一些注意事项，如何操作等，会很方便同事过来帮忙，或者换项目的时候方便交接。相信我，在同事看到你那么完善的文档以及脚本后，留下的只会是好印象，而且也节约了你给对方讲解的时间。

#### Docker 镜像
假如你使用了 Docker 来跑 CI 任务，那还是有必要编译几个常用的镜像，比如那个 CI 编译过程中，需要的一些工具都可以提前准备好，这样可以节约不少的 CI 时间。

#### 科学上网工具
这是必须的，很多内容只能通过科学上网的方式获取，尤其是 Go 项目的编译，官方包的获取就会被和谐掉，于是就只能死等到 CI 一个小时超时后才能知道失败了。

这方面的内容不方便在这里多说，不然你们只能通过科学上网的方式来看我的博客了。

### 总结
假如工作中，一旦发现了重复的工作，或者需要等待的工作，建议就花点时间想想如何节约，磨刀不误砍柴工的道理大家都懂，但不是谁都能意识到自己可以花时间去节约时间的。

提高工作效率的方式有很多，我觉得很多的时间都是通过点滴的积累而节约的，一旦节约的时间多了，效率也会相应提高不少；而效率高了，就会有更多的时间去学习其它知识，以及工具，从而节约更多的时间，一个良性循环就此建立。

[1]: https://github.com/marketplace/category/continuous-integration
[2]: https://github.com/olipo186/Git-Auto-Deploy

***
首发于 Github issues: https://github.com/xizhibei/blog/issues/104 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
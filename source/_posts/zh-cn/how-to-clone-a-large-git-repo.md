---
title: 如何克隆一个大 Git 项目
date: 2020-02-10 12:38:14
tags: [工作方法,基础知识,Git]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/131
---
<!-- en_title: how-to-clone-a-large-git-repo -->

用 Git 克隆新项目，可以说是每个工程师必备的基础技能，然而，当你遇到克隆过程中的各种各样问题的时候，可知道如何处理？

### 遇到问题

某天在工作中，小 A 像往常一样要克隆一个新项目到本地，于是你熟练地敲下

```bash
git clone git://github.com:example/awesome-project
```

然后很悲催的，小 A 发现它告诉你这个项目有几个 G：

    Cloning into 'awesome-project'...
    remote: Enumerating objects: 17400, done.
    remote: Counting objects: 100% (17400/17400), done.
    remote: Compressing objects: 100% (11300/11300), done.
    Receiving objects:  1% (2351/127770), 40.57 MiB | 8.00 KiB/s

### Depth 命令参数

好不容易等了几个小时，进度只有 20%。于是，小 A 请教身边的大牛，他告诉小 A 如果不是很在意历史，其实可以用 depth 参数，这样会快很多。

```bash
git clone --depth=1 git://github.com:example/awesome-project
```

但是小 A 是想要全部克隆下来，然后大牛告诉小 A ，用 `depth` 参数克隆的项目，是可以恢复全部历史的。

于是小 A 开始尝试，发现需要下载的内容少了好多：

    Cloning into 'awesome-project'...
    remote: Enumerating objects: 200, done.
    remote: Counting objects: 100% (200/200), done.
    remote: Compressing objects: 100% (200/200), done.
    Receiving objects:  1% (1/188), 1.01 MiB | 80.00 KiB/s

之后，大牛给小 A 发来了 clone 之后的操作步骤：

```bash
git fetch --unshallow
git pull --all
```

但是这速度怎么回事，好慢。

### 代理

大牛瞥了一眼小 A 的屏幕，转头告诉小 A ，用代理会快好多。

然后小 A 又去折腾代理去了，回来之后测试：

```bash
git config --global http.proxy=http://172.0.0.1:7777
git clone --depth=1 git://github.com:example/awesome-project
```

但是小 A 发现，为何代理似乎不起作用：

    Cloning into 'awesome-project'...
    remote: Enumerating objects: 200, done.
    remote: Counting objects: 100% (200/200), done.
    remote: Compressing objects: 100% (200/200), done.
    Receiving objects:  1% (1/188), 0.56 MiB | 40.00 KiB/s

大牛这时候提醒小 A，在他克隆的时候，用的是 git 协议的项目地址，实际上是 ssh 协议，因此不能用 http proxy 来达到这个目的。

大牛手把手教小 A 在 `~/.ssh/config` 中，加入如下的配置（这时候注意，用的是本地的 socks 代理，而不是上面的 http 代理）：

    Host gitlab.com
        ProxyCommand=nc -X 5 -x 127.0.0.1:7778 %h %p
        HostName gitlab.com
        User git

重试尝试，发现速度快了很多：

    Cloning into 'awesome-project'...
    remote: Enumerating objects: 200, done.
    remote: Counting objects: 100% (200/200), done.
    remote: Compressing objects: 100% (200/200), done.
    Receiving objects:  1% (1/188), 20.13 MiB | 800.00 KiB/s

小 A 愉快地等着，看着进度一点一点变多。

然而，命运总是喜欢跟小 A 开玩笑，等到了 99% 的时候，

    Cloning into 'awesome-project'...
    remote: Enumerating objects: 200, done.
    remote: Counting objects: 100% (200/200), done.
    remote: Compressing objects: 100% (200/200), done.
    fatal: The remote end hung up unexpectedly1.95 GiB | 772.00 KiB/s    
    fatal: early EOF
    fatal: index-pack failed

于是，小 A 想打人。

### `core.compress` 配置

小 A 又焦虑了，这是咋回事。

看着一盘大牛忙碌的样子，打算自己去解决，搜索一阵后，在 StackOverflow 上发现了[答案](https://stackoverflow.com/questions/21277806/fatal-early-eof-fatal-index-pack-failed)：其实这种问题，很有可能是 Git 服务器的内存不够了，导致压缩传输数据失败，服务器直接挂了。

于是，小 A 看了看 [Git config 文档](https://git-scm.com/docs/git-config)：

> core.compression
> An integer -1..9, indicating a default compression level. -1 is the zlib default.
> 0 means no compression, and 1..9 are various speed/size tradeoffs, 9 being slowest.
> If set, this provides a default to other compression variables, such as core.looseCompression and pack.compression.

就尝试设置这个参数：

```bash
git config --global core.compression=0
```

也就是取消压缩，这样的话，项目可以不经过压缩就直接传输。

### 总结与反思

终于克隆成功了。

然而打开编辑器，看了看项目中的一些文件，小 A 头都大了：这项目的维护者水平堪忧，为什么放上一堆明明可以通过编译生成的可执行文件跟压缩文件？大牛可是教我们不能把这些东西放在项目里面的。

原因似乎也找到了：太多不必要的大文件也放在了项目里，导致项目庞大臃肿，克隆的时候遇到那么多问题，都是这些文件导致的。

那，如果你是这类项目的维护者，该如何去改善？且听下回分解。


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/131 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
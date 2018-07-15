---
title: 自动化你的 Hexo 博客创作流程
date: 2018-01-14 20:10:35
tags: [Node.js, 工作方法]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/67
---
<!-- en_title: automate-the-creating-flow-of-your-hexo-blog -->

[从前年开始，我开始用 GitHub issues 写博客](https://github.com/xizhibei/blog/issues/34)，写到去年的时候，逐渐意识到，GitHub issues 还是有一定不足的，比如一个很关键的点：无法查看有多少人看了你的博客文章之类的运营数据，所以那得使用 Google analysis 之类的分析工具。

于是，为了嵌入 Google analysis，又开始折腾博客系统，之前折腾过 Jelly 之类的，只是让我发现了 [Hexo](https://hexo.io/)，一个目前被使用得非常广泛，非常流行的博客系统。

几个明显的优点：

- 使用 Node.js 开发，使用简便，并且可方便改造；
- 社区活跃，文档以及使用人数非常多，目前 star 已经 2w 多；
- 插件丰富，可自定义开发；

从此一发不可收拾，于是，就想着，怎么能把 GitHub 上面的 issues 随时迁移到 Hexo 上面，没什么研究其它项目，就自己撸了个简单的工具：[github-issues-to-hexo](https://github.com/xizhibei/github-issues-to-hexo)，其中原理就是利用 GitHub 的 REST api 以及 hexo 的目录以及文章结构来生成 Hexo 的文章，之后就可以直接使用 Hexo 生成以及发布了。

用了一段时间，问题来了，这个过程中很多的手工操作，是否可以用工具自动化呢？

当然可以，毕竟我是 [** 信奉自动化一切的男人 **](https://github.com/xizhibei/blog/issues/42)，能让机器自动化的，绝对不浪费自己的时间。

在继续之前，先做个约定，我们把含有 markdown 格式文件的博客文章的 Hexo 项目叫做 ** 博客源码项目 **，以及这个项目中的 issues 列表叫做 **Issues 博客 **，最后把含有 Hexo 生成后的内容的项目叫做 ** 网页博客项目 **。

### 关于 GitHub pages
一般来说，GitHub 会给每个项目提供 pages 功能，即你可以将静态内容上传，然后 GitHub 会自动发布 pages 内容，然后你可以用 `https://{your-name}.github.io/your-repo` 这样的地址来访问网页。而这其中有一个特殊的项目，假如你把项目的名称设置为 `{your-name}.github.io` 的话，那么会分配一个特殊的地址：`https://{your-name}.github.io`，是不是很有意思？对了，于是我们就可以建一个这样的项目用来存放 ** 网页博客项目 **，这样的话，你就可以用 `https://{your-name}.github.io` 当做你的博客地址了。

### 迁移
首先，需要安装工具，记得 Node.js 版本需要在 8 以及以上，因为其中用到了 `ES7 async/await` 特性：

```bash
npm i github-issues-to-hexo -g
```

然后，进入你的 ** 博客源码项目 ** 所在目录，生成你的专属模板：

```bash
github-issues-to-hexo init template.md
```

这个模板的内容你是可以随意修改的，其实这个模板使用的是 [mustache](https://github.com/janl/mustache.js) 语法，打开默认模板你就可以看到大概的内容了，具体的一些变量可以参考 [GitHub 开发文档](https://developer.github.com/v3/issues/)。

```md
---
title: {{ post.title }}
date: {{ date }}
tags: [{{ tags }}]
author: {{ post.user.login }}
---
{{ &post.body }}

***
Sync From: {{ &post.html_url }}
```

再然后就可以开始迁移了：

```bash
github-issues-to-hexo -u username -r repo -t ./template.md
```

顺利的话，就可以在 `source/_posts/` 目录下面看到一些生成的 markdown 文档了。需要注意的是，如果你的文章名称是汉字的话，这些文件的命名是直接使用拼音命名的，如果需要英文文件名，你需要在每个 issue 的 ** 开头 ** 假如如下的注释：

```
<!-- en_title: your-english-post-name -->
```

这个工具还会继续改进，如果有意见或者建议之类的，欢迎留言或者 [直接提交 issue](https://github.com/xizhibei/github-issues-to-hexo/issues)。

### 发布
在 ** 博客源码项目 ** 中，我们使用 `hexo-deployer-git` 这个插件来将我们生成的静态网页内容全部上传至 ** 网页博客项目 **。

配置很简单，在 ** 博客源码项目 ** 里面 `_config.yml` 配置如下即可（记得将内容替换成你自己的）：

```yml
deploy:
  type: git
  repo: git@github.com:xizhibei/xizhibei.github.io
  branch: master
  name: your-name
  email: your-email
```

### 主题安装
主题代码不适合放到 ** 博客源码项目 ** 里面，那不属于博客代码本身，那是可以随时下载获取的东西，并且当主题更新了，你也不能立马更新，因此，将主题作为 git 的 sub module 是比较合适的。

比如在我的 ** 博客源码项目 ** 里面，用到了 maupassant 这个主题，我就可以这样处理：

```bash
git submodule add https://github.com/tufu9441/maupassant-hexo themes/maupassant
```

这条命令执行后，就会在当前项目下生成一个 .gitmodules 文件，里面的内容如下：

```
[submodule "themes/maupassant"]
  path = themes/maupassant
  url = https://github.com/tufu9441/maupassant-hexo
    branch = master
```

### 自动化
Travis CI 可谓业界良心，给我们提供了非常方便的 CI 自动化功能，于是我们就可以利用这个工具来自动化地发布博客了，但是有个问题就是，CI 是不会有你博客项目的写入权限的，你必须给它配置可写入的地址，同时还不能影响你本地的手工发布，因此，这里需要一些特殊的处理。

比如，上面的配置中，我使用的是 ssh 地址，这样的话，本地 push 是不会有问题的，但是在 CI 环境中的话，就需要用到 `https://${GH_TOKEN}@github.com/xizhibei/xizhibei.github.io` 这样的形式来部署到我的 ** 网页博客项目 ** 上去。

- 首先，你需要在自己的 [GitHub Token Setting](https://github.com/settings/tokens) 页面生成自己的 Private Token，用来让 Travis Ci 有权限向你的网页博客项目推送静态网页的提交；
- 其次，用你的 GitHub 账号登录 https://travis-ci.org/ ，同步自己的项目，最后在 `Environment Variables` 中创建一个环境变量，名称为 GH_TOKEN，值为上一步的 Private Token；
- 最后，在博客项目中使用如下 `.travis.yml`；

```yml
language: node_js

node_js:
  - "8"

branches:
  only:
    - master 
before_install:
  - npm install -g hexo-cli

install:
  - npm install

script:
  # 这两步便是将作为 sub module 的主题下载下来
  - git submodule init
  - git submodule update
  - hexo generate
  # 下面这步挺重要，会将 _config.yml 的 repo 地址替换为有权限写入的地址，
  # 毕竟 Travis CI 公开项目的运行日志是公开的
  # 而你不能因此泄露自己的 Private Token
  - sed -i''"/^ *repo/s~git@github\.com:~https://${GH_TOKEN}@github.com/~" _config.yml
  # --silent 参数就是为了不把 token 打印出来，可明白？
  - hexo deploy --silent
```

### 不足之处 & 总结
目前有一个比较纠结的点，在 issues 发布之后，不能触发自动化发布过程，需要手动把 issues 迁移下，提交后才能进入自动化发布过程。

但是，相信这个过程也是可以解决的，比如开发个 GitHub 插件，当有 issues 发布的时候就触发自动化过程。当然了，CI 步骤中需要加入 issues 同步到 Hexo 的步骤。

另外呢，就可能需要改动流程了，比如我可以在本地写好文章，然后在 CI 步骤中加入新建 issues 功能。

不知你是否注意到，整个步骤中，我是先有将博客网页化的需求（目标），然后制定了手工的流程，再然后才引入或制作工具进行优化，最后才引入自动化。

其实，这也是工作中，我总结出的方法：

> 一开始，需要想清楚目标，然后制定大概的工作流程，再然后用工具去优化每个流程的效率并进行一些调整，最后，才是将固定不变的，并且可以不由人来处理的步骤自动化。（显然，写作是不可能自动化的 :P）

自动化反而是最后才引入的，一开始的目标才是最重要的。

### 广告
当你生成静态页面的时候，那些网页页面中可能会有链接是指向到你 **Issues 博客 ** 中的某个 issue 的，但是如果让看你博客的用户直接跳转到 GitHub issues 可能会打断他们的浏览过程，这是我在 Google analysis 意识到的问题，于是我做了个小工具，可以将你每个 issue 里面的 issue link 转成 Hexo 博客的永久链接。

具体可以看这里：	[hexo-filter-github-issue-link](https://github.com/xizhibei/hexo-filter-github-issue-link)



***
首发于 Github issues: https://github.com/xizhibei/blog/issues/67 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
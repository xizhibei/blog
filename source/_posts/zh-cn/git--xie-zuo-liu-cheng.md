---
title: Git 协作流程
date: 2017-02-04 16:53:45
tags: [DevOps,Gitlab]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/39
---
### 前言
在使用 SVN 的时代，一旦一个文件被锁定，其他人都无法修改的情况时常出现，着实让人头痛。Git 横空出世之后，大家因为它带来的便捷性非常有价值纷纷改为这个：它有一系列非常有意义的功能：回滚与重复修改、强大的分支以及 tag 管理、更清晰的历史修改追踪等等。只是，Git 也是由人来使用的，当单个人使用时，无论怎么折腾都没事，而当多人合作开发的时候，就会有各种各样的问题，比如由于 Git 的灵活性，所带来的分支管理与协作流程的问题。

### Git Flow
这是最常见的协作流程，并且它已经有现成的工具支持：`git flow`，简单来说，就是把分支分为：

- **master**：主分支，用于追踪线上生产环境的代码；
- **develop**：开发分支，用于追踪开发环境的代码；
- **feature/a-new-feature**：特性分支，用于不用人员开发新功能，从 develop 开始，结束后合并至 develop 分支；
- **hotfix/vx.x.1**：热修复分支，用于紧急修复上线，从 master 开始，结束后合并至 develop 与 master 分支，并打上 hotfix tag ；
- **release/vx.0.0**：预发布分支，从 develop 开始，结束后合并至 develop 与 master 分支，并打上 release tag ；

这个模型还是很有用了，将分支管理规范起来，多人协作很方便。只是，实际使用中，会有一些问题：

- ** 繁琐 **，尤其是热修复的时候，因此有时候热修复分支会被滥用：上线小功能也会用热修复。另外，有时候开发人员也会犯错：合并代码出错，忘记合并回 develop，刚在本地合并完，发现已经落后于线上的代码；
- 当团队使用线上 Git 管理工具的时候，就会有点麻烦了：与 `Pull/Merge request` 以及 `Code Review` 配合起来不方便，一般我们很鸡肋地让开发人员 feture 分支合并到 develop 的时候，以及 hotfix 分支合并到 master 分支的时候做 `Pull/Merge request` 以及 `Code Review`；
- 与 CI & CD 流程配合起来不方便，当 hotfix 与 release 分支合并回 develop 分支的时候，按照 CI 的理论，你是应该重新 build 的，只是，这样会显得很多余；

### Github flow
其实你不妨观察下 Github 上的各种开源项目，就会很容易发现他们使用的流程很简单：只有 master 这个长期存在的分支，以及其他的 feature 分支。所有的 feature 分支都会向 master 分支合并，`Code Review` 以及 `Pull request` 在这个过程能很好的结合在一起。

只是，由于太简单，因此有些需求点，它做不到：代码部署的问题，即 master 的代码不代表生产环境的代码，即无法追踪。

### Gitlab flow
Gitlab flow 算是这三者里面，最适合使用 gitlab 管理工具的团队使用的流程：它引入了一个概念叫做：`Upstream first`。

简单来说，它就是在 `Github flow` 的基础上，分别引入不同的 downstream 分支策略：

##### 生产环境分支策略
对于像手机应用一样的项目，再添加一个 production 分支即可，production 为 master 的 downstream 分支，所有合并到 master 的代码，如果需要发布，则合并到 production，用以追踪，（很明显，手机应用需要提交审核，这时候我们也需要合并代码至 master）；

##### 多环境分支策略
对于使用 CI & CD 的后端项目来说，可以在上面的基础上引入了 pre-production 分支，用于追踪预发布以及生产环境。即 master 为 pre-production 的 upstream，而 pre-production 为 production 的 upstream ；

##### 发布分支策略
而对于发布软件来说，可以直接在 master 下面，设置多个不同的发布分支，比如各种开源软件：node、mongodb 等。当每次发布新版本时，都会创建一个分支，然后如果有修改的话，也只是继续在 master 上修改，修改完后 `cherry pick` 到对应的发布分支上。

### P.S. 我的思考
其实这么一一说下来，选择就很明显了，尤其我之前提到过 [CI 系统搭建](https://github.com/xizhibei/blog/issues/26)。

所以我继续谈谈，Gitlab flow 如何跟自动化结合起来：

比如后端服务器项目，当然选择的是 ** 多环境分支策略 **，那么，当有新代码合并到 pre-production 以及 production 的时候，就可以利用 `webhook`，通知相应的服务器，自动把代码 pull 下来，执行 `pre hook` 、重启应用以及 `post hook` ，这个过程就相当于部署到相应的环境中去。而所谓的 ** 分支追踪 **，也就是为了达到这个目的：** 将对应的分支以及各种对应的环境中的代码保持同步 **。

顺便推荐个工具：[Git-Auto-Deploy](https://github.com/olipo186/Git-Auto-Deploy)。

另外，Gitlab 还提供了 environment 功能，可以在 `.gitlab-ci.yml` 中配置，然后直接点击按钮，就可以自动的把代码合并到  pre-production 以及  pre-production 合并到 production 中去。具体可以参考 [这个](https://github.com/everpeace/concourse-gitlab-flow) 。

说了这么多，其实也就是想说明：一个规范的流程多么重要，以及当一个流程规范了之后，就可以把重复执行的部分交给机器去做，也就是自动化。 

### Reference
1. http://docs.gitlab.com/ee/workflow/gitlab_flow.html
2. http://nvie.com/posts/a-successful-git-branching-model/
3. http://scottchacon.com/2011/08/31/github-flow.html
4. http://www.ruanyifeng.com/blog/2015/12/git-workflow.html



***
首发于 Github issues: https://github.com/xizhibei/blog/issues/39 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
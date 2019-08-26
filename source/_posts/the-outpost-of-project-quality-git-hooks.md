---
title: 项目质量的前哨部队：Git hooks
date: 2019-08-12 15:35:44
tags: [DevOps,基础知识,工作方法]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/117
---
<!-- en_title: the-outpost-of-project-quality-git-hooks -->

我在之前[持续交付的实践与思考](https://github.com/xizhibei/blog/issues/42)中提到过，为了提高项目的**内建质量**，我们需要**尽可能早地发现以及解决问题**，这对于任何一个开发团队来说，都是非常重要的事情，尽管它不紧急。目前我们在开源世界中有了各种各样的工具来帮助我们减少错误、提高项目代码的质量，利用它们，可以让你把这件事情真正做好。

<!-- more -->

### 前言

在以往持续交付的实践中，我们会多依赖于 CI 去发现问题，事实上，从推送代码提交到 CI 流程跑完再通知你结果，整个过程起码需要几分钟以上，这样就会导致整个提交过程中，发现问题到解决问题的流程相对长了些，一旦这个步骤如果需要多次返工，就会明显降低工作效率，更悲观的情况下，如果到了大家推送提交代码的高峰期，就意味着你推送的提交可能需要排队等待 CI 的空闲时间。这样的事情，一旦遇到了，就要引起警惕（来自过来人的劝告）。

其实是有解决方案的，因为在这其中，有一处可利用的机会有时候会被我们忽略，那就是在代码提交的过程前后。这个提交前甚至可以是编码的时候，在编码时，IDE 会在你每次保存文件的时候进行静态的语法检查、跑单元测试等，只是由于编辑器能提供的检查是有限的，它需要在尽可能短的时间里给你反馈，因此一些耗时的检查操作它会忽略而不去执行，但这不代表这个步骤可以完全丢给 CI 去做，你还有一个可以利用的机会，那就是在执行 `git commit` 的时候。

于是，今天要说的主角就可以出场了，它就是我们项目质量的前哨部队：Git hooks。

### Git hooks 是如何起作用的

对于 git 项目，它在初始化的时候，就会给你在 `.git/hooks` 这个目录下，生成好全部的 hooks 样例（是的，不需要安装其它内容）：

-   applypatch-msg.sample
-   commit-msg.sample
-   fsmonitor-watchman.sample
-   post-update.sample
-   pre-applypatch.sample
-   pre-commit.sample
-   pre-push.sample
-   pre-rebase.sample
-   pre-receive.sample
-   prepare-commit-msg.sample
-   update.sample

这些样例中，只要将 `.sample` 后缀改掉后就能起作用，不过在这之前，最好先看下内容，了解下它的作用，利用好它们，你就可以做到很多有趣的功能（不过这次主要谈谈如何提高项目代码质量）。其实每个文件都是可执行的，因此你可以用任何语言去实现这些功能，实践中，以脚本语言居多，毕竟实现简单。

另外，`git help hooks` 也能告诉你，这些文件的作用是什么。

### Git hooks 可以做什么

首先，你需要想好自己的目标。

#### Pre commit

Pre commit 在这其中对我们来说最重要的，这个 hook 是我们经常使用的功能，就如我在上面提到，我们可以在将要提交代码时，即 pre commit 的时候，进行全面的代码静态检查以及单元测试，来防止多次提交后 CI 失败的返工，提高工作效率。

另外专门推荐下 [pre-commit] 这个工具，这个是专门用于在 `pre-commit` 阶段，目前说到的功能它都能做到，并且实现了非常简便的拓展，可以复用一些常见的操作。

配置使用了友好的 Yaml 格式，下面是我们团队使用的的一个样例，用在 Golang 项目中。

```bash
# .pre-commit-config.yaml
- repo: https://github.com/pre-commit/pre-commit-hooks
  rev: v2.3.0
  hooks:
  - id: check-json
- repo: https://github.com/dnephin/pre-commit-golang
  rev: master
  hooks:
    - id: go-fmt
    - id: go-vet
    - id: go-lint
- repo: local
  hooks:
  - id: generate-docs
    name: Generate docs
    pass_filenames: false
    entry: make docs
    files: \.go$
    language: system
    types: [text]
```

从配置中可以看出，我们复用了 <https://github.com/pre-commit/pre-commit-hooks> 以及 <https://github.com/dnephin/pre-commit-golang> 这两个项目提供的现成检查步骤，并且还加上了自己实现的简单文档生成步骤。

其它内容可以参考项目的文档，就在它的官网里面。

另外，对于 Node.js 项目，也可以试试 <https://github.com/typicode/husky。>

#### Pre push

你还可以依据开发团队的需求以及规范来决定，比如，你的团队规定不允许将代码直接推送到远端，那就可以利用 pre push 来检查分支，来避免这个问题，而不是等待你去发现分支推错了。

[githooks] 上有个例子，假如有同事将要代码直接推送 master 的时候，就会将这个行为直接推送到群聊 @所有人，然后报错退出，这显然有点粗暴，但是目的也就达到了，对于有些刚入行的菜鸟来说，可能需要这么来一次才能真正学会如何正确推送分支。

#### Commit msg

这个一般是与 git commit message 的模板一起使用：

```bash
git config commit.template .git-message-template
```

然后通过 `commit-msg` 这个 hook 检查 commit message 是否符合你们团队的规范。

下面是一个比较流行的模板格式，最初来自于 [AngularJS]：

```bash
#     <type>(<scope>): <subject>
#     <BLANK LINE>
#     <body>
#     <BLANK LINE>
#     <footer>
```

### 总结

简单介绍了三个比较常用的 git hooks，你也可以用其它的 hooks 来实现各种各样的需求，[githooks] 上也说了，**限制你的，只有想象力**。

回想起来，之前实行过很多的团队规范，一直没有落地的真正原因就在于此：我们没有完善的工具以及流程来保障实施，而完全依赖于人的勤奋，以及自控力，这显然是比较违背人性的。这点我们必须承认：**依赖于流程与工具，而不是人，才能让项目的质量得到保障。**

一旦有了工具的保障，各种比较良好的规范也就能更好的实施，而不是最后沦为团队成员口中，三天两头换规范的样子。

### Ref

1.  [Customizing-Git-Git-Hooks](https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks)
2.  [githooks]

[pre-commit]: http://pre-commit.com

[githooks]: https://githooks.com/

[AngularJS]: https://github.com/angular/angular/blob/master/CONTRIBUTING.md


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/117 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
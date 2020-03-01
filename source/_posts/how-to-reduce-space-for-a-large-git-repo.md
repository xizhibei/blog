---
title: 如何给 Git 大项目瘦身
date: 2020-02-23 23:13:09
tags: [Git,工作方法]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/132
---
<!-- en_title: how-to-reduce-space-for-a-large-git-repo -->

在上回，我在 [如何克隆一个大 Git 项目](https://github.com/xizhibei/blog/issues/131) 说到，遇到了克隆大项目的时候，如果遇到问题该如何解决，这次我们来继续聊聊，假如你是这种项目的维护者，该如何改善。

### 问题分析

相信你也看到了如果你维护的是一个大项目，会给那些新加入的参与者带来什么样的麻烦了。

那么，有什么方法可以解决这个问题呢？我们不妨先来看看大项目往往是什么原因造成的：

1.  的确是个有历史大项目，像 Google 自己的大项目，相信这种情况下，你们会有自己的解决方案；
2.  放了太多不必要的文件，这种的话，也有方案，下面听我介绍；

所谓不必要的文件是什么呢？

像 C++ 的静态、动态库，Node.js 项目的 node_modules 目录，Golang 项目的 vender 目录，以及一些压缩文件、图片文件，甚至是可执行文件等等。这些文件的特点就是，占用空间大，并且可以通过下载、编译等方式重新创建，因此往往不需要放到项目中，但是也挡不住有同学为了省时间而把它们加进去。

这确实会有好处，比如下载可能会遇到网络问题，放在项目中可以跳过下载，加快项目的初始化；而一些第三方库文件，放在项目中也可以大大减少重新编译的时间。

不过我认为，可以有更好的方案，比如搭建自己的代理服务以及缓存服务。就看你们自己取舍了，毕竟维护这些服务也需要耗费精力。

假如你认为那些文件不必要放在项目中了，问题就会紧接着来了：已有的项目中，已经有了很多不必要的文件了，该怎么办？可以删掉，不过这时候，Git 萌新们会发现即使删了，项目库还是那么大。对的，因为你删掉的文件还是存在 Git 提交历史中。

这时候，有难度的做法，使用 Git 本身提供的 `filter-branch`<sup>[1], [2]</sup>：

```bash
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch path_to_file" \
  --prune-empty --tag-name-filter cat -- --all
```

这个命令会将你 Git 项目中 `path_to_file` 这个路径下的所有历史记录删除，包括分支与标签，并且因此操作而变为空的提交也会被删除。

不过，你也有更简单的方法，来看个好工具：[BFG repo cleaner](https://rtyley.github.io/bfg-repo-cleaner/) 。

下载安装后，命令非常简单：

```bash
bfg --delete-files path_to_file
```

### 进阶用法

而如果你嫌麻烦，或者觉得这些文件还是非要放在项目中，你还可以用 **[git-lfs](https://github.com/git-lfs/git-lfs)**。

什么是 lfs：它是 Large File Storage 的缩写，是 Git 的一个插件，专门用来给大文件设置版本，用来追踪的。而它的原理也是非常简单，把大文件替换成一个含有原来文件 hash 字符串的文件，这样就可以大大缩小文件占用空间，并且也可以与代码分开存储，加快传输速度。

安装的话，目前各个平台都有支持，直接用包管理工具安装即可。

安装之后，先开启本地项目的 git-lfs 支持，比如，我们打算把之后所有的 zip 文件放到 lfs 中，那么我们就需要：

```bash
git lfs track "*.zip"
```

然后，本地仓库会在 `.gitattributes` 文件（没有会新创建）中添加如下的一行：

    *.zip filter=lfs diff=lfs merge=lfs -text

这就意味着，你可以通过 git-lfs 来追踪这个 zip 文件的变动了，git-lfs 的存储不会与仓库存储在一起，而是另外存储，并且由于大文件的克隆全部变成了文件的上传下载，克隆的速度可以大大加快。

另外，BFG repo cleaner 也支持你把现有的项目中匹配的大文件转为 git-lfs ，用 `--convert-to-git-lfs` 这个参数即可，下面是我用过的一个例子：

```bash
# 建议复制一份后再测试
java -jar /path/to/bfg/bfg-1.13.0.jar --convert-to-git-lfs '*.{a,dylib,zip,gz,tgz,so,so.*,png,jpg}' /path/to/my/repo/.git

cd /path/to/my/repo/
git reflog expire --expire=now --all && git gc --prune=now --aggressive
git push -f
```

由于 BFG repo cleaner 不会修改你的 HEAD，因此最好你将本地仓库现有的大文件全部加入到 git-lfs 中，提交一次，这样不需要继续修改就可提交。

其实 git-lfs 本身也提供了 `git lfs migrate import --include="*.psd" --everything` 这样的命令，但是我尝试过，无论是速度还是效果，都不如 BFG repo cleaner，假如有成功的可以交流以下。

### Ref

1.  [Rewrite branches][1]
2.  [Removing sensitive data from a repository][2]

[1]: https://git-scm.com/docs/git-filter-branch

[2]: https://help.github.com/en/github/authenticating-to-github/removing-sensitive-data-from-a-repository


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/132 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
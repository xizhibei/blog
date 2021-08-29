---
title: Git 之消失的文件
date: 2021-07-11 23:15:16
tags: [Git]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/177
---
<!-- en_title: the-missing-files-in-git -->

今天来跟大家分享一个有趣的事情，在开始之前，想问问大家如何在 Git 中，如何在 Git 项目中，让一个文件消失？或者说，对 Git 来说不可见？

似乎很简单对不对？用 .gitignore 文件不就可以了。对，你说的没错，只是除了这个方法呢？

### 演示

接下来如果你如果想尝试这个方法，请别在你的真实项目中操作，搞坏了我可没法负责。

```bash
mkdir test_git_repo
cd test_git_repo
git init
```

到这里没什么奇怪的对么，好，在 test_git_repo 这个目录里面继续。

```bash
mkdir hidden_path
cd hidden_path
git init
```

然后在 hidden_path 中创建一个提交。

```bash
echo 1 > 1.txt
git add .
git commit -m "Init [hidden_path]"
```

回到上层目录，同样创建一个提交。

```bash
cd .. # test_git_repo
git add .
git commit -m "Init [test_git_repo]"
```

好了，关键的一步来了，把 hidden_path 中的 .git 文件夹删掉。

```bash
rm -rf hidden_path/.git
```

最终，我们的魔法操作来了：

```bash
echo test > hidden_path/test.txt
echo test > test.txt
```

当你用 `git status`，你会发现这样的输出：

    On branch master
    Untracked files:
      (use "git add <file>..." to include in what will be committed)

            test.txt

    nothing added to commit but untracked files present (use "git add" to track)

即使进到 hidden_path 去查看 `git status` 也是一样。奇怪了，hidden_path/test.txt 这个文件哪里去了？

而当你用 ls 查看的时候，却发现那个文件还是存在的，但是它却在当前的 git 项目中「消失」了。你也可以测试看看，无论你往这个文件夹里面写任何文件，它都会「消失」。

好了，接下来，让我们把消失的文件找回来。

```bash
git rm --cached hiddle_path
git add .
```

这时候再来看 `git stauts`，你就会发现消失的文件回来了：

    On branch master
    Changes to be committed:
      (use "git reset HEAD <file>..." to unstage)

            deleted:    hiddle_path
            new file:   hiddle_path/1.txt
            new file:   hiddle_path/test.txt

### 原理

相信熟悉 git 的同学已经看出来了，就是因为 git submodule 。

其实这个「小技巧」是我在处理一个不那么熟悉 git 的同事问题时候发现的，当时也是很奇怪，检查了很多次有没有把那个文件夹加入到 .gitignore 里面去，在反复查看好多遍，并且确认整个项目中只有这一个 .gitignore 文件之后，才考虑到是 git submodule 的问题。因为我发现了同事提交了一个空文件夹，大家应该知道，git 是不支持提交空文件夹的，而且查看 git 历史也会发现这个问题。

问了同事才明白，同事不小心把外部依赖拷贝进项目并且提交了，他这样做相当于在主项目 git 中添加了一个 submodule 文件，这个文件在文件系统中会被替换成一个文件夹。本来如果他继续提交的话，我们也会很容易发现这是个 submodule，但是同事接下来的的骚操作就是他直接把 submodule 的 .git 删掉，然后又提交一次，于是结果就是这个 submodule 文件会被当前的主项目 git 给忽略了，因为它的 file mode 依然是 160000，还是会被 git 当作 submodule 处理。<span>[1]</span>

这里提一下：
file mode 160000 在 git 中的意义是：git 会认为你在记录一个**提交**，作为另一个项目的目录入口，而不是一个文件夹或者文件。<span>[2]</span>

因此，删掉 submodule 的 .git 目录后，对应的 commit 永远不会改变，也就相当于这个目录下的所有文件都会被 git 忽略。

### Ref

1.  [How do git submodules work?][1]
2.  [7.11 Git Tools - Submodules][2]

[1]: https://matthew-brett.github.io/curious-git/git_submodules.html

[2]: https://git-scm.com/book/en/v2/Git-Tools-Submodules


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/177 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
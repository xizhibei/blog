---
title: 穷人的程序性能分析器
date: 2021-01-10 17:38:26
tags: [C/C++,工具]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/158
---
<!-- en_title: poor-mans-profiler -->

标题是直接翻译自 Poor man's profiler，也可以叫做**最简陋的程序性能分析方法**。

这种程序性能分析分析方式还是非常有意思的，第一次见到它时在 [Stack Overflow 的一个问答](https://stackoverflow.com/questions/375913/how-can-i-profile-c-code-running-on-linux)里面，本以为最高票答案的方式会介绍一个非常牛逼的工具，哪知道他介绍的却是一种朴实无华的 Profiler 方式。

我本来也直接跳过了这个回答，觉得太不靠谱了，但是在一一尝试了 gperf、vargrind、perf 等未果之后（主要是因为程序在开发板上，这些工具都没法很好地支持），于是我尝试了下这个方案，不出所料的，居然真解决了我的问题，很简单的几个步骤就找出程序的性能瓶颈所在。

### 介绍

这里就简单挑重点，翻译下作者 Mike Dunlavey 的回答：

> 在调试的时候，停住几次程序，每次停止后，检查下调用堆栈。如果有代码占用了整个程序一定比例的 CPU 时间，那么你就有较大的可能性会在这几次查看堆栈的时候发现它们。
>
> 当然，你也许有多个不同大小的性能问题，如果你解决了其中一个，那么剩下的占用的 CPU 时间就会变大，也就会变得更容易发现。这种放大效应，当遇到多个问题交织在一起的时候，可以成为真正的加速因子。

显然，这种方式过于简陋了，导致被许多人质疑，作者就花费了不少时间来跟人辩论。

首先是说，其他的那些高级工具，给出的调用关系图有两个很大的缺点，一个是无法给出指令级别，另外还会在遇到递归时给出让人费解的统计。

另外的一些针对大家提出的问题，统一用贝叶斯统计来进行了理论上的解释，总的来说还是非常令人信服的。

最后作者把用 perf 等工具测量所有的程序调用过程叫做测量，而用 Poor man's profiler 叫做程序调用栈采样。这两种分析方式的区别在于：前者是**水平**的，它会告诉你那些步骤所花费的时间，后者是**垂直**的，它会告诉你程序在此刻在做什么，如果你第二次发现它还在做这件事，那就意味着这就是瓶颈了。

这其实就跟领导为了了解属下是不是在认真工作（找出公司运作瓶颈），领导不可能在每个人背后装个摄像头来监控（perf 工具测量），进行视察工作（采样）一样，第一次抓到你在摸鱼，领导可能不会说什么，人之常情，可以原谅，但是第二次再抓到你摸鱼，那他就会认为你这个人肯定是在一直偷懒了，你就是性能瓶颈了（嗯，这么说来领导们才是精通程序调试的大牛 :P）。

### 具体步骤

上面只是说了原理，这里就说说，如何在实践中使用，我们就用最简单的 gdb 来做：

1.  首先是启动 gdb： `gdb --attach $(pidof your-app)`
2.  然后关闭 gdb 打印数据的分页配置：`set pagination 0`，这样就可以让 gdb 输出所有的分页了，当然你也可以不管，手动查看；
3.  等 gdb 加载完程序以及依赖的动态库，就可以继续运行了：`continue`；
4.  等个几秒，手动 `CTRL-C` 暂停程序；
5.  输入 `bt` 即 `backtrace`，就能看到当前程序停住的调用栈了，当然，如果是多线程的程序，你可能需要看所有线程的调用栈：`thread apply all bt`；
6.  重复 3、4、5 步骤几次，统计下程序经常停住的地方了，如果同一个指令在多次采用中出现，你就几乎能发现你程序的性能问题所在了；

熟悉这个流程后，你也可以写个脚本来进行自动化。但是其中你需要了解两个关键的地方：

一个关键地方是在上面的步骤中，我们采取的是手动 `CTRL-C` 暂停程序，但是在脚本里面，你很难这么去干，于是你可以用 `TRAP` 信号来达到同样的效果，具体就是 `kill -TRAP $(pidof your-app)`。

另一个关键地方就是，`kill` 需要自动执行，为达到这个目的，我们还需要 bash 脚本的另外一个技巧，即多进程，在任何一条命令最后加上 `&` 就可以将这个命令放到后台去执行，于是你可以配合 `sleep` 命令来达到这个目的，即最终拼凑出类似于这样的命令：`sh -c "sleep 5 && kill -TRAP $(pidof your-app)" &` ，这条命令不会阻塞下面其他的命令，并且在 5 秒之后，执行 kill 命令。

最终，我们可以写出一个类似于下面的脚本（抄袭的原脚本在 [Poor man's profiler](http://poormansprofiler.org/)）

```bash
#!/bin/bash

set -e

nsamples=5
sleeptime=25
gdb_cmd_file="/tmp/gdb-cmd.sh"
gdb_log_file="/tmp/gdb.log"

pid=$(pidof your-app)

echo "set pagination 0" >> $gdb_cmd_file

# 把 gdb 命令写入文件，然后用 gdb 的 -x 参数执行
# 40 秒是为了等待 gdb 加载完成，然后每次累加 $sleeptime
for i in $(seq 1 $nsamples); do
  sleep_for=$(expr $i \* $sleeptime + 40)
  sh -c "sleep $sleep_for && kill -TRAP $pid" &

  echo "continue" >> $gdb_cmd_file
  echo "thread apply all bt" >> $gdb_cmd_file
done

# 日志写入文件与终端
gdb --attach $pid -x $gdb_cmd_file --batch | tee $gdb_log_file

# 统计结果
cat $gdb_log_file | \
awk '
  BEGIN { s = ""; }
  /^Thread/ { print s; s = ""; }
  /^\#/ { if (s != "" ) { s = s "," $4} else { s = $4 } }
  END { print s }' | \
sort | uniq -c | sort -r -n -k 1,1
```

### 总结

果然是一种低成本且效率高的方法，几乎可以说是朴实无华了。

### Ref

1.  <http://poormansprofiler.org/>
2.  <https://stackoverflow.com/questions/375913/how-can-i-profile-c-code-running-on-linux>
3.  <https://stackoverflow.com/questions/1777556/alternatives-to-gprof>


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/158 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
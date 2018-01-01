---
title: Node.js 性能分析之火焰图
date: 2017-09-09 15:35:52
tags: [Node.js]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/57
---
<!-- en_title:node-js-profiling-tool-flamegraph -->

往往，在我们的开发过程的以下两个场景中，我们会需要去分析应用的性能。

1. 开发时候优化程序；
2. 线上排查问题；

往往，如果不是线上出了问题，我们不会想要去进行性能分析 :P，所以其实你只会面对第二个场景。话说回来，其实这两个场景的相关处理方式也非常类似，我接下来会做个总结，当然了，得先从介绍相关的工具开始。

### Node.js 性能分析工具
主要的分析对象就是内存以及 CPU，而最著名的几个工具莫过于 **v8-profiler** 以及 **flamegraph**，当然了，从 Node.js 4.4.0 开始，[Node.js 自带了分析工具](https://nodejs.org/en/docs/guides/simple-profiling/)。其它的，可以看 [这里](https://github.com/thlorenz/v8-perf/issues/4)。

对于 Node.js 自带的分析工具：

1. 启动相关应用的时候，node 需要带上 `--prof` 参数；
1. 再做相关的性能测试，结束后，能在 node 运行目录下生成 `isolate-0xnnnnnnnnnnnn-v8.log` 的文件；
1. 然后再运行 `node --prof-process isolate-0xnnnnnnnnnnnn-v8.log > processed.txt` ；
1. 最后打开 processed.txt 文件，就能看到相关的结果了；

显然，它只能做 CPU 分析。

而 v8-profiler 两者都能做： CPU profiler 以及分析 heap，heap 的快照跟比较也不在话下。

不过，它需要进行一些编码操作，目前我在开发过程中尝试过以下两种方法：

#### Linux SIGUSR1 信号


```js
const fs = require('fs');
const profiler = require('v8-profiler');

let profileData;
let startProfile = false;

process.on('SIGUSR1', () => {
    if (startProfile) {
        console.log('Dumping data...');
        profileData = profiler.stopProfiling();
        console.log(profileData.getHeader());
        return profileData.export((err, result) => {
            if (err) {
                console.log(err);
            } else {
                fs.writeFileSync('profileData.cpuprofile', result)
                console.log('Dumping data done');
            }
            profileData.delete();
            profileData = null;
            startProfile = false;
        });
    }
    console.log('Start profile...');
    profiler.startProfiling('p1');
    startProfile = true;
})

```

使用 `kill -s SIGUSR1 PID` 开始采集数据，再运行一次结束并生成 cpuprofile 文件。

#### API 接口
比如，你在调试一个基于 express 的 web 应用：

```js
const profiler = require('v8-profiler');

app.get('/profile', (req, res) => {
  const duration = req.query.duration || 30;
  profiler.startProfiling('profile sample');
  setTimeout(() => {
    const profileData = profiler.stopProfiling();
    console.log(profileData.getHeader());
    return profileData.export((err, result) => {
       if (err) {
           console.log(err);
       } else {
           fs.writeFileSync('profileData.cpuprofile', result)
           console.log('Dumping data done');
       }
       profileData.delete();
       res.send('Done');
   }, duration * 1000);
  })
});
```

显然，当你在 Windows 下的时候，你只能选择第二种，需要注意的是：** 假如你的应用是 CPU 密集型，当出现 100% CPU 的时候，有可能你是得不到 cpuprofile 文件的 **，具体为什么，当做你的思考题 :P。

不管怎么做，v8-profiler 提供的方式还是非常灵活的，生成的文件是一个 json 文件，这个文件可以直接导入 chrome 的 JavaScript profiler 去查看，也可以利用 flamegraph 这个工具来生成火焰图。

### 火焰图
提到火焰图，就不得不提这个项目：[brendangregg/FlameGraph](https://github.com/brendangregg/FlameGraph)，现在网络上几乎你能看到的火焰图都是用这个工具来生成的。

#### npm flamegraph
而 node 也有一个 flamegraph 包可以用来帮助你更简单处理（显然，它是基于上面这个项目进一步开发的。）：

```bash
npm install flamegraph -g
flamegraph -t cpuprofile -f profileData.cpuprofile.cpuprofile -o fg.svg
```

生成的 svg 文件可以直接在浏览器中查看，这个图的看法简单介绍下：

![](http://www.brendangregg.com/FlameGraphs/example-dtrace.svg)
图片来自上面的 FlameGraph 项目。

1. X 轴不表示时间刻度，而表示时间长度，也就是占用的 CPU 时间；
1. Y 轴从上到下，越接近底部表示越接近系统的底层，对于 Node.js 来说，上层是 js 代码，下层是 C 代码；
1. 每一层上，每个条幅越宽，表示它在整个运行周期中，占用的 CPU 越多；
1. 点击任何一个条幅，图像会自动将它置于最底部，同时只留下它之上的条幅，并且放大至全图；

** 一般来说，你只需要注意标示出你程序相关的最宽条幅即可，因为往往它就是程序中存在的瓶颈。**

#### Linux perf
另外，Node.js 其实还有另外一个参数 `--perf-basic-prof`，可以配合 Linux 上的 perf 或者 systemtap 工具来画火焰图。

限于篇幅，这里只简单说下 perf：

1. 安装 perf: `yum install perf -y`；
2. 下载 Flamegraph： `git clone https://github.com/brendangregg/FlameGraph`；
3. 首先启动应用： `node --perf-basic-prof app.js`，这步操作会生成一个 /tmp/perf-PID.map 的文件；
4. 确认应用的 pid，然后运行 perf，采集 60s 的数据：`perf record -F 99 -p PID -g -- sleep 60`；
5. 修改 map 文件权限：`chown root /tmp/perf-PID.map`，然后你才能继续下一步 `perf script > out.perf`，这一步就是会读取 /tmp/perf-PID.map 这个文件，才能生成 out.perf 文件；
6. 最后就可以使用 Flamegraph 来生成火焰图了：`./FlameGraph/stackcollapse-perf.pl --kernel < ./out.perf | ./FlameGraph/flamegraph.pl --color=js --hash> ./fg.svg`

这个图与上面生成的图是类似的，其中需要说明下的是 map 文件是用来将 Node.js 程序内的代码映射到内存地址空间。显然， perf 这个工具只能获取 Node.js 进程内部的内存地址，毕竟 js 是个解释性的语言。

顺便提一句，/tmp/perf-PID.map 这个文件会不断增长，如果你是在线上排查在本地无法复现的问题，你可能需要个大点的硬盘了。

### Ref:
- https://zhuanlan.zhihu.com/p/27147421
- http://dmdgeeker.com/post/flamegraph/
- https://nodejs.org/en/blog/uncategorized/profiling-node-js/



***
原链接: https://github.com/xizhibei/blog/issues/57

![知识共享许可协议](https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png "署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）")

本文采用 [署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh) 进行许可。

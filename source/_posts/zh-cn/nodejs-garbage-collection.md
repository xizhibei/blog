---
title: Node.js 垃圾回收
date: 2018-04-22 16:02:30
tags: [Node.js,监控,面试]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/75
---
<!-- en_title: nodejs-garbage-collection -->

话说，在很久以前的程序界，是没有内存垃圾回收这种说法的，大家习惯于被 C 以及 C++ 的内存问题各种花式吊打。

直到有一天，John McCarthy 大神 1959 年在 LISP 中实现了内存垃圾回收，大家才惊奇的地发现：『居然还有这种操作？』。
正如 iPhone 出来之后重新定义了手机，内存垃圾回收的出现无异于重新定义了高级语言。

好，接下来开始聊聊 Node.js 里面的 GC。

### Nodejs GC

网上各种文章都会告诉你 Node.js 中类似于下面的这种内存垃圾回收原理[1][3]：

> 在 Node 中，内存是 v8 负责管理的，而在程序的 heap 空间中，主要分为 New Space 与 Old Space。一般在 New Space 中的被称为新生代，大概有 1-8 MB 大小，大多数的内存分配都是在这里，按照统计来说，大约 80% 的内存垃圾都会被回收掉，而没有被回收掉的则进入了 Old Space 中，被称为老生代数据，这里面的数据大小限制为 ~0.7GB（32 位机器）以及 ~1.4GB （64 位机器）。
> 至于回收方式，搜寻（Scavenge）清除法，快，作用于新生代；而标记清除法（Mark-Sweep）、标记整理 (Mark-Compact)、增量标记（Incremental Marking）相对来说慢，作用于老生代。
> 无论哪种回收，都会产生 『stop-the-world』 现象，也就是停止其它代码执行，但是一般来说时间够短，不会让你明显察觉到。
> Node 在服务端很容易有大内存，因此 v8 在之后引入的增量标记（Incremental Marking）方式，把标记分段执行，每一段都控制在 5ms 左右，尽量避免影响到程序执行。

下面说下与此非常相关的知识点：

1.  当内存使用上升过快来不及被回收，或者根本无法被回收的时候，Node.js 容易出现崩溃现象（OOM，即 Out of memory），这时候可以调整 node 的参数 `--max-old-space-size`，单位是 MB。
2.  Buffer 既不是在 New Space 也不是在 Old Space，而是在 Node 的 C++ 层面申请的，大小不受 v8 的限制。

### 内存泄露

GC 再好，也会有它的副作用，比如内存泄露，Node.js 如果使用了闭包，一不小心就很容易出现内存泄露，下面的代码来自[1][2]：

```js
var theThing = null
var replaceThing = function () {
  var originalThing = theThing
  var unused = function () {
    if (originalThing)
      console.log("hi")
  }
  theThing = {
    longStr: new Array(1000000).join('*'),
    someMethod: function () {
      console.log(someMessage)
    }
  };
};
setInterval(replaceThing, 1000)
```

每过一秒钟，`theThing` 就会被覆盖，但是 `unused` 却处于 `someMethod` 的闭包 context 内，因此即使它没有被调用过，它也会阻止它里面包含的 `originalThing` 被回收，形成了一个完整的引用链：`someMethod` -> `unused` -> `originalThing` -> `theThing`，第一次调用后，`theThing` 变成了一个闭包，并且是全局变量而不会被回收，所以当再次执行后，又会有新的部分加到这个引用链上。因而每次 `replaceThing` 被调用的时候，都会让这个引用链变的更长，由此造成了内存不断泄露。

怎么找出这种问题？我之前在 [Node.js 性能分析之火焰图](https://github.com/xizhibei/blog/issues/57) 中也提到过，用 heapdump 或者 v8-profiler 都能实现。

### 监控

好了，那么在平时的运维中如何及时发现以及定位这种问题？

很显然，你需要一些 v8 内存的指标，一个是 node 自带的 `process.memoryUsage()`，另一个是 gc 数据，可以看看 node v8 参数里与 gc 相关的参数： `node --v8-options | grep gc`。

另外还有个挺有用的模块： [gcstats](https://github.com/dainis/node-gcstats)，它用 C++ 实现了 v8 层面的 gc 监控。

假如你用的是 prometheus，那么你可以使用这个模块：[node-prometheus-gc-stats](https://github.com/SimenB/node-prometheus-gc-stats)。

### 面试

我们在面试中，有时候会给出这样的场景题：

> 给你一台 1 核 1 G 的机器，如何不利用数据库本身的聚合功能来实现一个含有一亿行数据的简单统计，如求和？

这道题其中就很考验对 Node.js 的理解以及经验了，假如候选人提到了 stream 模块，那基本上就算答对了。

只是，假如你把思考过程说给面试官听的话，效果会更好：

> 比如问清每行数据大小（不给的话就自己估计），一亿行数据，按小了假设，每行数据在内存中有 100 bytes 大小，那么一亿大概需要 10G 内存，显然这台机器的内存不够用。
> 如果分成 10~20 次计算也是可以的，只是这样会造成数据库翻页取数据的性能问题以及 Node.js 本身垃圾回收的问题，因为这些数据很大会被放在老生代，回收很慢，导致计算也非常慢。
> 因此可以考虑用 Node.js 的 stream 模块，不会占用太多内存，处理好的话大部分数据都会在新生代中被回收掉，并且对于数据库来说，一次性地持续取出也不会对数据库造成翻页的问题，计算速度也应该比前一种方法快。

看，这个过程中，你至少展示了你解决问题的能力、良好的沟通能力、对 Node.js 内存垃圾回收的深刻理解以及在数据库性能调优方面的经验。

面试官会肯定给你 💯 的。

### Ref

[1]\: [Node.js Garbage Collection Explained](https://blog.risingstack.com/node-js-at-scale-node-js-garbage-collection/)
[2]\: [Understanding Garbage Collection and Hunting Memory Leaks in Node.js](https://blog.codeship.com/understanding-garbage-collection-in-node-js/)
[3]\: [深入理解 Node.js 垃圾回收与内存管理](https://www.jianshu.com/p/4129a3fce7bb)


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/75 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
---
title: APM 以及 Node.js 探针原理
date: 2017-02-18 22:34:34
tags: [Node.js]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/40
---
### 关于 APM

APM 能帮企业以及应用开发者提供很多帮助，它的功能集中在监控、分析、优化上面，从应用中部署探针直接采集信息，集中处理，从多维度形成报告，简而言之：** 相当于给了一副看到应用程序不足的眼镜 **。

多余的不再赘述，可以看文末参考链接。

### 几个选择
目前几个好用的，并且支持 Node.js 应用的:

- NewRelic
- OneAPM
- Tingyun

从好用程度来说，NewRelic 秒杀全部，只是国内的 APM 其实也发展起来了，有着本地化的优势，能给国内企业一些本地化的解决方案，NewRelic 天高皇帝远，也是有着这方面的弊端的。

目前我们的服务器端监控用的 NewRelic，选择原因主要是强大、速度快、细节清楚。而手机上 APP 的 APM 选择的 Tingyun，因为它本地化优势很明显。

选择的时候不妨多试用比较，从自身需求出发去考察与筛选。

好了，非常简单的介绍了下，不难发现，对于 APM 来说，很重要的一点在于数据的采集，也就是需要部署探针去采集应用的各项数据，那么，探针是如何实现的？

### Node.js 探针原理
说明细节之前，不妨来做个小题目：** 如何记录一个函数的运行时间？**。

不卖关子，很简单，写个函数，直接包装下即可：

```js
function a() {...}

// 同步
function b() {
  const start = Date.now();
  a();
  const time = Date.now() - start();
}

// 异步
function b() {
  const start = Date.now();
  return a()
    .finally(() => {
      const time = Date.now() - start();
    })
}
```

现在你已经会做 APM 了，对的，不是开玩笑，原理即是如此。

当然了，实际做的时候，会有很多复杂的实现在那，比如，如何非侵入性地部署这个探针，以及如何在一次请求过程链中记录多个被调用函数的 metrics 等等。

众所周知，Node.js 由于它的异步原理，没有向有线程模型的同步语言中的 **『线程本地存储』**，因此不是能很简单的不侵入代码，而做到记录每次请求的所有过程的，那么，现有的 APM 探针是如何做到的？

首先可以看看这个项目：[async-listener](https://github.com/othiym23/async-listener)。

简单介绍下，就是把所有的 Node.js 基础模块中每个异步函数中 callback 参数做个包装，即针对以下这几个事件做成 hook，就相当于一个 async listener 了：

- **create**: 进入了 Node.js 的事件队列；
- **before**: 出了事件队列，马上要执行之前；
- **after**: 执行完毕了；
- **error**: 出错，执行的函数 throw error；

举个例子，比如 `fs.writeFile(file, callback)`，包装之后：

```js
fs.writeFile = function wrapWriteFile(file, callback) {
  asyncListener.create();
  process.addListener('uncaughtException', asyncListener.error);
  
  function callbackWrap(err, rst) {
    asyncListener.before();
    callback(err, rst);
    asyncListener.after();
  }
  fs.writeFile(file, (err, content) => {
    callbackWrap(err, content);
  });
}

```

于是每当一个异步函数执行时，对应的 hook 都会把相应的 metrics 记录到一个专门的 storage 中，而这个 storage 在整个调用过程中是共享的，所以最后就可以发送至专门的处理中心去了。

对了，利用这个原理，还可以做很多有意思的事情，比如 [Continuation-Local Storage](https://github.com/othiym23/node-continuation-local-storage)。

#### P.S.1
到目前为止，async-listener 这个项目只是作为一个 monkey patch 的存在，官方至今没有实现，他们给出的解释也很简单：实现这个功能需要损失一定的性能，难度比较高。回到探针上面，其实探针也会让你的应用损失一定的性能，只是这个损失不会很大，而换来的效果收益确是远远高于这个损失的。

#### P.S.2
再扯一点，async listener 只是针对所有的 Node.js 基础模块做了包装，那么，它是如何在我们自己实现的模块中共享的呢？

这是基础知识点，留给你了。

提示：Node.js 异步的特性来自于何处？传染性是什么意思？

### Background Transcation
上面提到的探针，都是直接帮你把每次 Web Transcation 记录下来，那么，如何记录一些离线任务？

基本上，如果官方不提供 wrap 的话，只能自己侵入性的部署探针了，接下来以 NewRelic 为例：

文档在 [这里](https://github.com/newrelic/node-newrelic) ，一开始文档里面没有很清楚的使用方法说明，也没有发现其它网站上现成可直接参考的例子，最后我还是从它的源码中发现了 [例子](https://github.com/newrelic/node-newrelic/blob/master/examples/api/background-transactions/example4-promises.js)。

首先是函数定义：

```js
/*
 * 开始 Transcation
 * @param name Transcation name
 * @param [group] Transcation group name, default: NodeJs
 * @param handle 要被追踪的函数
 */
newrelic.createBackgroundTransaction(name, [group], handle)

// 结束 Transcation，一定需要再结束的时候调用，不然整个 Transcation 会超时
newrelic.endTransaction()
```

然后是以 [Automattic/kue](https://github.com/Automattic/kue) 为具体的例子：

```js
const newrelic = require('newrelic');
const queue = require('kue').createQueue();

/*
 * @return Promise
 */
function aLongBgJob() {
  ...
}

const TRAN_NAME = 'example';
queue.process(TRAN_NAME, (job, done) => {
  const wrapedJob = newrelic.createBackgroundTransaction(TRAN_NAME, aLongBgJob);
  aLongBgJob(job.data)
  .then(function(result) {
    newrelic.endTransaction()；
    done();
  })
  .catch(function(error) {
    newrelic.noticeError(error)；
    newrelic.endTransaction()；
    done();
  })；
})
```

当然了，最好是针对这些任务队列框架做个中间件 wrap 适配，统一处理，这里只是举个例子。

另外，千万记得不可以这样：

```js
aLongBgJob = newrelic.createBackgroundTransaction(TRAN_NAME, aLongBgJob);
```

这样做的话，aLongBgJob 会被反复 wrap ，如果调用次数多的话，相当于被包装了很多次，于是会导致调用栈溢出，最后拖垮整个应用，别问我怎么知道的🙈。

其它两家的没找到文档，代码里面似乎也不明显。

### Reference
1. http://www.infoq.com/cn/articles/depth-2016-overview-of-apm
2. http://www.infoq.com/cn/articles/tingyun-cto-interview
3. http://www.infoq.com/cn/articles/oneapm-hexiaoyang-interview



***
首发于 Github issues: https://github.com/xizhibei/blog/issues/40 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
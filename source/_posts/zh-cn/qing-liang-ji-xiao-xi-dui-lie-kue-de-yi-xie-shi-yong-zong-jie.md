---
title: 轻量级消息队列 Kue 的一些使用总结
date: 2016-05-24 22:32:07
tags: [Node.js]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/15
---
最早接触 kue 是在 0.7 之前的版本，功能很少，很弱，但还是很好用的，那时候找过一些其他的消息队列，如 rabbitmq，kafka 之类的，但是都觉得太重了，跟 nodejs 的融合还是不太合适。

找着找着，就找到了 tj 大神搞的 kue，基于 redis 的 subpub 做的优先级消息队列，适合做一些离线任务，比如统计运算、发邮件消息以及异步业务逻辑。

建议初次使用多看看文档，把一些方法全部记下来作为模板，比如创建第一个任务的时候：

``` js
queue.create(YOUR_FIRST_JOB, jobData)
.removeOnComplete(true)
.priority('normal')
.attempts(5)
.backoff( {delay: 60*1000, type:'exponential'} )
.ttl(ms('1h'))
.save();
```
### 几个坑
##### 文档

文档很弱，继承了一贯懒的作风，很多不明白的地方还是看代码来的快，如果你发现文档中没有的内容，或者写错的内容，尽快提交 pr，我上次给改了文档，2 个月才给 merge。
##### 延时任务

不能自动执行延时任务，必须执行一个周期性检查（记得是 500ms，也可以自定义）的方法，然后还不能在多个进程中执行，不然会有 race condition 出现，即同一时刻同时执行同一个任务。
新的版本中 kue 自动处理，已经没有这个问题了。
##### 任务堵塞

还有一旦 redis 的连接不稳定，或者没有处理好 throw error，就会出现任务永远处于 active 状态，因为 kue 认为这个任务没有完成。如果这时候设置的
新的版本中，提供了 ttl 超时自动失败，以及 `watchStuckJobs` 这个方法，建议在创建 job 之前就调用这个方法。

``` js
queue.watchStuckJobs(interval=1000)
```
##### 运维

除了 kue 自带的 dashboard，还有 kue-ui，感觉比自带的好用一些。还有就是经常查看是否有失败的任务，用 kue 自带的一些方法定期去执行，然后把结果用邮件发送之类的。
##### 部署 & 重启

如果是用的 pm2，记得不要直接 restart 或者 reload，而是要用 gracefulReload，pm2 会给进程发送一个 shutdown 的 message，等它自动退出，如果超出时间未响应才会 kill，因为对于 kue 来说，可能正在跑某个人物，如果这时候直接 restart 会影响到任务。

``` js
// remember to set env PM2_GRACEFUL_LISTEN_TIMEOUT
// and process.send('online') when job app start
process.once( 'message', function ( msg ) {
  if (msg !== 'shutdown') return;
  queue.shutdown( 5000, function(err) {
    console.log( 'Kue shutdown:', err||'' );
    process.exit( 0 );
  });
});
```
#### Reference

https://github.com/Automattic/kue
http://pm2.keymetrics.io/docs/usage/pm2-doc-single-page/


***
原链接: https://github.com/xizhibei/blog/issues/15

![知识共享许可协议](https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png "署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）")

本文采用 [署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh) 进行许可。

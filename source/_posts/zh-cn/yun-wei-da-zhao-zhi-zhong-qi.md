---
title: 运维大招之重启
date: 2016-07-18 21:12:21
tags: [DevOps]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/23
---
> 没有什么运维问题是一起重启解决不了的，如果有，那就两次。   --- 🙈 

今天又栽在 mongodb 索引上了，哥们又在我不知情的情况下，加入了新建索引的代码，也怪我，没有 review。两亿多数据啊。。。。天。。。。

于是我们的平均响应时长就跟过山车似的，一波未平，一波又起，甚至一度达到了我入职以来的最高值，6kms。

没办法，先重启，回滚了刚上线的代码，怀疑是 update 操作太频繁。等先把响应时长降下去之后，才发现是索引的问题，查看建索引进度，快结束了，那就等等吧，等了 10 多分钟，建立完毕，长吁一声，以为完事了。

哎，一度把复制集索引的建立过程给忘了，于是几个从库一起复现刚才的过山车，只不过更激烈~

一个字：删！

先把主库上的刚建立的索引给删了，然后遍历每个从库，kill 掉 index builder 的 opid，这里取了个巧，因为等待的任务数已经太高，而建索引时间已经远远超过 100s，于是全部 kill：

``` bash
for m in mongo{1..10}
do
    mongo $m/dbname --eval "db.currentOp().inprog.forEach(function (p) {if (p.secs_running>100) printjson(db.killOp(p.opid))})"
done
```

好了，这下改完事了吧~

显然没，backend app 内存报警 OOM，varnish 全部挂掉 😂 

原因就是因为等待的 op 太多，把内存挤满了。

这时候，一直重启大法就行了，哪个出问题立马重启，于是等了好几个小时才完全稳定下来。
#### 总结

好了，开头只是在胡说八道，但是说出了最简单朴实的临时解决方案：重启，的确它可以解决很多问题，但是终究只是临时的，比如今天这种场景，很多请求可以直接让它超时挂掉，而不是一直等在那里：**Fail fast!**

其它的呢，需要抓紧时间解决或者完善：代码上线的 review，staging 环境建立、CI 搭建、线上流量测试以及重要接口的压测。


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/23 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
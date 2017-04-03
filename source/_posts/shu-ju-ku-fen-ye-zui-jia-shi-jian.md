---
title: 数据库分页最佳实践
date: 2016-05-22 15:02:49
tags: []
author: xizhibei
---
#### 2016-06-22 更新：

MongoID 不能保证连续增长，因此，在这种情况下，不适合此种方案，如果是为了保证速度以及效率的话，可以放缓存，比如 redis 以及 memcached 之类的。
#### 正文

说起分页，最容易想起的就是 offset+limit，在 mongodb 里面可以用 skip+limit 实现，应该说这是最容易实现的功能，与前端的交互来说非常合理，你只需告诉前端有多少页，以及每页的大小即可。

但是

这样效率太低，因为无论是哪个数据库，都会强制扫描 offset 或者 skip 的数据，即不会用到索引，所以，越到后面，skip 的数据越多，效率越低。（当然了，数据量不大的话效果不明显。）

解决方案是用条件直接筛选索引，通过索引的限定直接去取数据，这样效率最高。
#### 举个栗子：

``` js
// 已创建 createdAt 索引
Order
  .find({createdAt: {$gte: nextId}})
  .sort({createdAt: -1})
  .limit(limit)
  .exec()
```

你需要分页展示订单信息，只要前端获取 nextId 即可，尤其是 APP，目前大部分的 APP 展示大量信息的时候，会选择瀑布流加无限翻滚，就是到用户翻滚到页面尾部的时候才会去请求以及加载下一页，因此不需要给前端一共多少页这样的信息，只需要告诉还有没有数据即可。
#### 具体方案

> 前端第一次请求
> http://example.com/orders
> API 返回 order 数组，以及在返回的头部信息中有 x-next-id: 123456
> 当用户快拉到底部时，请求第二页数据
> http://example.com/orders?nextId=123456
> API 返回 order 数组，以及在返回的头部信息中有 x-next-id: 12345678
> ...
> 最后一次 API 返回的数组中只有 2 个文档，这时候头部中无 x-nexd-id 信息，即无更多数据
#### 具体实现：

``` js
// 已创建 createdAt 索引
const orders = await Order
    .find({createdAt: {$gte: nextId}})
    .sort({createdAt: -1})
    .limit(limit + 1) // 需要多取一个 doc 来获得 nextId
    .exec();
if (docs.length === limit + 1) {
    return {
        docs: docs.slice(0, -1),
        nextId: docs[docs.length - 1]._id,
    };
}
return {
    docs,
    nextId: null,
};
```
#### 一个需要注意的地方

不知道你发现没有，上面这个其实是可能有问题的，因为当有重复的 createdAt 字段存在时，就会有问题：
比如 limit10 个，恰好 createdAt 字段全部相同，于是返回的 nextId 跟前一次的 nextId 相同，那么就会造成死循环了。当然，这是最差情况，只是出现重复数据的概率挺高。

解决方案很简单，直接用 unique 字段，或者加上 unique 字段，比如 id 字段，query 的时候用两个字段一起筛选，返回的 nextId 也是包含着两个字段。
#### Reference

http://stackoverflow.com/questions/10072518/what-is-the-best-way-to-do-ajax-pagination-with-mongodb-and-nodejs


***
原链接: https://github.com/xizhibei/blog/issues/14

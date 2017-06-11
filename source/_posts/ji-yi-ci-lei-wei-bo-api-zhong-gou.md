---
title: 记一次类微博 API 重构
date: 2016-10-15 14:21:44
tags: [MongoDB, 重构]
author: xizhibei
---
最近看 APM 上面的 API 响应，发现有个 API 在挑事，平均响应时长 4s，已经到了不可忍受的地步。

仔细一看，发现是动态有关的 API，类似于微博，进一步分析发现，这个 API 设计不合理：用了 mongo 的 aggregate，占了响应时长的 90% 以上，这个不适合在 API 使用，因为非常耗数据库的计算性能。
### Mongo 数据库结构

``` js
User: {
  _id: ObjectId,
  followings: Number,
  followers: Number,
}
TweetPage: {
  user: ObjectId,
  count: Number,
  oldest: Date,
  newest: Date,
  tweets: [{
    _id: ObjectId,
    title: String,
    content: String,
  }]
}
Follower: {
  user: ObjectId,
  followers: [ObjectId]
}
Following: {
  user: ObjectId,
  followers: [ObjectId]
}
ReTweet: { // 转发的 Tweet
  _id: ObjectId,
  title: String,
  content: String,
}
```

每个用户有一个 TweetPage，于是每次请求 TimeLine，都会把所有当前用户 follow 的用户的 TweetPage 取出来，做一个 TweetPage.aggregate，由此，这个 API 才会那么耗时间。
### 主要原因
- mongo 的 aggregate 太耗时间
- 数据结构设计不合理，TweetPage 里面的 Tweet 数组太大，随着时间越来越久，数组会越来越大，类微博是一个典型的高读写比的场景，取 TimeLine 的计算时间太长

于是，重构方向就是针对这种场景下的数据高读写比，重新设计数据结构。同时，还需要顾及以后的产品改进方向，而且重构不可改变 API 的行为，所以不添加任何新行为。
### 具体步骤
- 第一步：跑通测试，由于这部分模块长久不维护，测试大部分已经失效，首先需要修改测试，并且补充必要的测试，同时这一步也是 ** 帮助你理解相关的业务逻辑 **；
- 第二步：格式化代码，应该来说，还是由于时间长久的原因，之前的团队里，代码风格不统一，因此格式化代码很有必要，也是为了之后的重构代码不被格式改变所污染，这里需要单独做一个 `git commit`；
- 第三步：重新设计数据结构，当前数据结构中的 `ReTweet` 是个妥协的存在，因为 `TweetPage` 设计失败了，`ReTweet` 是为了转发的 API 而添加的内容。因此，`Tweet` 有必要拿出来，单独作为一个 collection，`TweetPage` 也可以去掉了。同时，为了提高获取 `TimeLine` 接口的性能，单独添加 `TimeLine` collection，每一个用户一个 document，** 每当用户添加或者删除 `Tweet`，或者 follow 关系改变的时候，主动更新 follow 的用户 `TimeLine`**，获取 `TimeLine` 的时候，直接获取当前用户的 `TimeLine` 即可，然后取出对应的 `Tweet`。进一步，可将一些热门 `Tweet` 放在缓存中。由此，解决了微博的高读写比问题；
- 第四步：实现，此过程中必须不断重新跑测试，来保证重构的效果；
- 第五步：编写相关的数据迁移脚本，指定上线步骤以及回滚步骤；
### 说在最后

此次重构，其中包含了一个计算机科学中非常朴素的简单原理：** 用空间换时间 **，因为用户『写』微博的时候比『读』微博的次数少，因此可以用增加写的时间与空间，来换取读的时间减少，也不需要更多的计算。


***
原链接: https://github.com/xizhibei/blog/issues/28

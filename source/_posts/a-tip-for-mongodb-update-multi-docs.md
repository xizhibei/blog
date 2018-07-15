---
title: 一个 MongoDB 批量更新的提示
date: 2018-07-01 22:45:41
tags: [MongoDB, 数据库, 监控, 重构]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/81
---
<!-- en_title: a-tip-for-mongodb-update-multi-docs -->

不久前在我们进行的一次重构过程中，遇到了一个 MongoDB 批量更新数据的问题。

<!-- more -->

### 起因
上线之后（显然是经过了测试的），没有任何比较明显的问题，但是等到过了一段时间后，DBA 突然跑过来说，你们是不是改动了什么 DB 操作了，因为观察到主库的 update 操作在我们上线之后增加了 10 多倍不止，如果继续下去怕对主库有影响（相当于增加了 io，主库压力会增加不少）。

于是我们赶紧回顾所有的修改，以及对比其它的监控指标，马上定位到了一处与之前 DB 操作不同的地方：在更新过程中，加了一个 updatedAt 字段，考虑到这个字段只是用来标示文档的更新时间，于是马上把这个字段的更新去除了。

上线之后，观察到监控上很快恢复到了之前正常的更新频率。

### 分析复盘
那么，为什么这个字段的更新会造成那么高的更新频率，明明之前这条语句的调用频率并没有调整。以下是简单的例子，我们执行的语句一般至少匹配到 100-300 个文档。

```js
db.test.update({a: 'a'}, {$set: {b: 'b'}}, {multi: true});

// 改为以下语句

const date = new Date();
db.test.update({a: 'a'}, {$set: {b: 'b', updatedAt: date }}, {multi: true});
```

不知道你看出了什么问题，其实如果不是特别注意的话，是不会觉得下面的那个新增字段会造成影响的。

但是，如果你在 **mongo shell** 中执行下，你就会发现异常了：

首先，准备 100 条数据：

```js
for (var i = 0; i < 100; i++) {
  db.test.insert({i, createdAt: new Date(), val: 'test'})
}
```

然后依次执行以下几条语句：

```js
db.test.update({}, {$set: {val: 'test1'}}, {multi: true})
db.test.update({}, {$set: {val: 'test1'}}, {multi: true})
db.test.update({}, {$currentDate: {updatedAt: true}}, {multi: true})
```

然后，你就会发现不同的地方了：

```
WriteResult({ "nMatched" : 100, "nUpserted" : 0, "nModified" : 100 })
WriteResult({ "nMatched" : 100, "nUpserted" : 0, "nModified" : 0 })
WriteResult({ "nMatched" : 100, "nUpserted" : 0, "nModified" : 100 })
```

对了，MongoDB 的更新机制会先检查文档是不是需要修改，也就是对比数据库存着的文档跟要更新的字段的差异，假如不需要修改，就会跳过。


于是，我们就造成了我们修改前后的差异：updatedAt 这个字段每次都不一样，也就造成了每次都需要全部更新。

### 启示

也算是学到了新的知识，或者说经验。

之前在数据量比较小的时候，更新不会造成这样的影响，updatedAt 这样的字段可以随便加，包括 mongoose 也提供了 [timestamps](http://mongoosejs.com/docs/guide.html#timestamps) 这样的选项，让你能够方便地加创建时间与更新时间。

而一旦业务量上涨了之后，你会发现之前这些想法很多都会『失效』了，因为遇到的场景变化了，正所谓 ** 量变产生质变 **，这时候任何批量更新的操作都需要多一分考虑。

另外，这样的问题，一方面依赖于人的知识储备与经验，但是另一方面，我觉得便是监控的作用所在了：** 我们能预防已知的问题，但对于未知的问题（也往往是创新所要面对的），强大的监控报警系统才是你们团队真正需要的东西。**

***
原链接: https://github.com/xizhibei/blog/issues/81

![知识共享许可协议](https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png "署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）")

本文采用 [署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh) 进行许可。

---
title: MongoDB 的复制集
date: 2019-05-05 20:56:13
tags: [Golang,MongoDB,Prometheus, 数据库, 架构]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/105
---
<!-- en_title: mongodb-replica-set -->

MongoDB 如今还是很受欢迎的，毕竟它简单易用，方便拓展等等，然后它的一些高级功能不知道你有没有了解过，比如它的复制集。

### 为何需要复制集
假如经历过业务量的慢慢增长，就能感受到数据库拓展过程中的一些痛苦，以及，复制集的重要性了。毕竟单台机器的性能总是有限的，等业务量到达一定程度，就需要考虑使用多台来分散读写压力，常见的业务场景中，我们面对的都是读多写少的场景，因此，可以在相当的一段时间里，只考虑 ** 分散读的压力 **。

另外，还需要考虑容错能力，即数据库万一挂了一台，需要能够 ** 自动恢复 **。

最后一种场景是在一个比较大的区域内服务用户的，甚至是全球的，但是所有的数据都是放在一起的，于是数据与应用放在离用户更近的地方，显然可以 ** 减少延迟 **<sup>[1]</sup>。

目前市面上大部分数据都会使用以下几种方式来提供复制集 < sup>[1]</sup>：

1. ** 单主复制 **：今天要说的 MongoDB 使用的就是单主；
2. ** 多主复制 **：如 MySQL 的双主复制方案；
3. ** 无主复制 **：如 ElasticSearch；

MongoDB 的主就是 Primary，而其它的节点，有数据并有选举权的叫做 Secondary，无数据但有选举票的叫做 Arbiter。

### 预备知识
在继续之前，先了解下 [Read Preference][read-preference] 以及脏数据的概念。

#### Read Preference
它有五种模式，看字面也应该能够理解：

1. **primary**：全部读取 Primary 节点，读取量非常大的情况下，但是会造成 `Primary` 的压力，** 不宜过多使用 **；
2. **primaryPreferred**：优先读取 Primary 节点，挂掉的情况下再读取 Secondary；
3. **secondary**：全部读取 Secondary 节点；
4. **secondaryPreferred**：优先读取 Secondary 节点，全部挂掉的情况下再读取 Primary 节点，推荐配置；
5. **nearest**：读取最近的 Secondary 节点，远近通过网络延迟来决定；

#### 脏数据
其实说的就是 MongoDB 的数据持久化，在一个数据写到 journal 并 flush 到磁盘上之前，数据都是脏的，而在复制集内，数据会通过 Oplog 传播到其它节点上，然后重复写入的步骤 < sup>[2]</sup>。

假如这个过程中，主节点挂掉了，之前的某一个 Secondary 提升成为了 Primary，由于数据没有写到大部分节点上，于是新的 Primary 看不到之前的应该写入的新数据，即使这时候旧的 Primary 回来了，它也只能是 Secondary，它之前的那些新数据就会丢失，从而导致数据的回滚。<sup>[2]</sup>

### 复制集的缺点
说了优点之后，再说说它的缺点，毕竟 CAP 原理还是统治着分布式领域。在 CAP 原理中，C 表示一致性，A 表示一致性，P 表示分区容忍性。

MongoDB 的默认复制集配置是显然的 CP，因为 ReadPreference 默认为 `Primary`；如果换成 `Secondary` 或者 `SecondaryPreferred`，就相当于 AP 了，C 用了业界默认的最终一致性，因为它的复制是基于 Oplog 的 ** 异步 ** 方案。

但是，AP 方案容易导致的问题有复制延迟导致的：

* 注意：这些的例子只是随便举例，不一定会是真实情况。*

1. ** 写后读，或者说是读己写问题 **：即从 Primary 写入数据后，然后马上从 Secondary 读，这时候由于延迟问题而有可能在 Secondary 读不到最新数据，于是我刚发了个微博，刷新了下反而消失了，过一会儿又出现了；
2. ** 单调读问题，或者说是时光倒流问题 **：这时候由于多次从不同的 Secondary 读取数据，比如微博的评论下面，如果两次读到的数据不一致后，容易导致先看到了回复，刷新后却消失了，再过一会儿又出现了；
3. ** 因果读写不一致问题 **：与上面的微博例子相似，即出现在一个微博下面，评论的回复比评论先到达的现象；

解决的办法显然是有的，MongoDB 分别从读与写提供了解决方案，让你能够调整配置来取舍复制集中的 C 与 A。<sup>[3], [4]</sup>

### 读隔离 [Read Concern][read-concern]
目前一共有五种读隔离的设置：

1. **local**：不保证数据都被写入了大部分节点，我们在使用的时候基本默认的选项；
2. **available**：3.6 版本引入，与 [因果一致性会话][causally-consistent-session] 有关，也是不保证数据都被写入了大部分节点，暂时还没用过；
3. **majority**：保证数据都被写入了大部分节点，但是必须使用 WiredTiger 存储引擎；
4. **linearizable**：这个也没有用过，意思也不是很清楚，文档大致意思理解为对文档所有的读写都是顺序，或者说线性执行的，会导致花费时间超过 majority，建议与 maxTimeMS 一起食用；
5. **snapshot**：4.0 版本引入，与多文档的事务有关，也是没用过；

所以除了 local 与 majority，我都不能保证叙述的准确性，毕竟与实际用还是有区别的。但是基本上可以了解到：读隔离的效果是需要用时间去交换的，或者说降低可用性去交换的。

另外特别提一下这句文档中的话：

> Regardless of the read concern level, the most recent data on a node may not reflect the most recent version of the data in the system.
> 不管 Read concern 的具体配置，节点上最新的数据，不一定意味着它也是系统中最新的数据。

因为不管 Read concern 如何配置，它始终是从单个节点读的，这个设计的初衷只能保证不读到脏数据。

### 写确认 [Write Concern][write-concern]
```js
{ w: <value>, j: <boolean>, wtimeout: <number> }
```
这三个参数，在进行写操作的时候非常有用，常见的设置便是将 `j` 设置为 `true`，表示等数据已经写入了磁盘上的 journal 后再返回，这时候即便数据库挂掉，也是能从 journal 中恢复的，注意这不是 oplog 它是高层次的日志，而 journal 是低层次的日志，是可以用来故障恢复后重建当前节点数据的日志 < sup>[5]</sup>。

对于 w 参数，则有三种，表示写入后得到多少个 Secondary 的确认后再返回：
1. 数字：那就是确切的个数了；
2. majority：自动帮你计算 n/2 + 1；
3. tag set，标签组：即制定哪几个 tag 的 Secondary；

最后一个 `wtimeout`，则是在制定 `w` 参数的时候，推荐一并设置，防止超时，毕竟这种确认是牺牲性能的，很可能导致超时。

看到这里，大致可以得出结论，MongoDB 将读隔离与写确认交给客户端去取舍，一定程度上解决了复制延迟导致的业务问题，而本质上，这种解决方案的原理就在于用 ** 事务 **<sup>[6]</sup>。

### 总结
MongoDB 本来以易用而著称，但当我们会看到它的种种的高级配置与越来越多的概念，也就明白了它其实是把大部分我们用到的功能易用化了；而对于类似于复制延迟的这些后期会遇到的问题，它的解决方案不见得会比其它数据库更简单：** 因为它把控制权交给了应用，也就加大了应用的复杂度与难用程度，所以也就很容易见到大家对它的容易丢数据的评价了，我们可以说这些人不会用 MongoDB，但是为什么这些人不会用，是不是 MongoDB 本身的设计问题呢？**

当然，这些都是取舍，我们在小业务量的时候，可以完全不去管这些复杂的内容，毕竟当业务量起来了之后，融资容易了，或者也赚钱了，就可以招专门的人才去管理这些数据库。

### P.S.
最后补充下它的 Golang Driver：[mongo-go-driver] 以及 mgo，即使到写这篇文章的时候，这个官方的 driver 还是没有完善功能（not feature complete），不过倒是支持最新的事务功能，我们大部分还是在使用 mgo 这个库。想尝鲜的倒是可以试试，官方有 [迁移指导][go-migration-guide]。

而 mgo 这是个命途多舛的 Golang 库，历经了多次『换主』：

1. https://github.com/go-mgo/mgo
2. https://github.com/10gen/mgo
3. https://github.com/domodwyer/mgo
4. https://github.com/globalsign/mgo

从 1 到 4，目前最新的仍在维护的是最后一个，因为是目前唯一正在维护的社区版本。

说到今天的复制集，它的 `Safe` 配置需要特别注意下，今天的知识点都可以用在这里了：

```go
type Safe struct {
    W        int    // Min # of servers to ack before success
    WMode    string // Write mode for MongoDB 2.0+ (e.g. "majority")
    RMode    string // Read mode for MonogDB 3.2+ ("majority", "local", "linearizable")
    WTimeout int    // Milliseconds to wait for W before timing out
    FSync    bool   // Sync via the journal if present, or via data files sync otherwise
    J        bool   // Sync via the journal if present
}
```

单台 MongoDB 的时候，开发的时候可能并不需要注意复制相关的问题，只是，当多台 MongoDB 组成复制集的时候，这些选项就变得格外重要。

还有就是连接数据库的时候，记得设置最大连接数 `maxPoolSize`，不然连接池很可能会爆掉的。

最后建议对它开启统计，与 Promtheus 很容易结合，写一个 Collector 就能暴露监控数据了，可以参考 [我写的][collector]。

然后在程序启动的时候，注册下 collector 即可。

```go
prometheus.MustRegister(mongo.NewMgoCollector())
```

### Ref

1. [设计数据密集型应用 - 复制][1]
2. [No more dirty reads with MongoDB][2]
3. [Where does mongodb stand in the CAP theorem?][3]
4. [CAP 理论与 MongoDB 一致性、可用性的一些思考][4]
5. [How do the MongoDB journal file and oplog differ?][5]
6. [MongoDB · 引擎特性 · 事务实现解析][6]


[1]: https://github.com/Vonng/ddia/blob/master/ch5.md
[2]: https://xdg.me/blog/no-more-dirty-reads-with-mongodb/
[3]: https://stackoverflow.com/questions/11292215/where-does-mongodb-stand-in-the-cap-theorem
[4]: https://www.cnblogs.com/xybaby/p/6871764.html
[5]: https://stackoverflow.com/questions/8970739/how-do-the-mongodb-journal-file-and-oplog-differ
[6]: http://mysql.taobao.org/monthly/2018/07/03/
[read-preference]: https://docs.mongodb.com/manual/reference/read-preference/index.html
[read-concern]: https://docs.mongodb.com/manual/reference/read-concern/
[write-concern]: https://docs.mongodb.com/manual/reference/write-concern/
[causally-consistent-session]: https://docs.mongodb.com/manual/core/read-isolation-consistency-recency/#sessions
[mongo-go-driver]: https://github.com/mongodb/mongo-go-driver
[collector]: https://gist.github.com/xizhibei/bbad6e4ebe84f119511ecdabbc2b9fa5
[go-migration-guide]: https://www.mongodb.com/blog/post/go-migration-guide

***
首发于 Github issues: https://github.com/xizhibei/blog/issues/105 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
---
title: ELK5 升级小记
date: 2016-12-03 15:03:08
tags: [ELK]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/31
---
早就听说 ES5 的版本了，一直没有在意，但是直到最近正式版出来之后，才有了要升级现在的 ES 集群的想法，首先便是日志集群（2.3 版本），之前一直有问题：丢日志现象很严重，尤其是 GC 导致的静止现象，然后所用占用的空间非常大。

看 ES5 的介绍，以及网上其他人的经验，ES5 集成了 Lucene 6，性能提高不少，简单来说：** 磁盘空间少一半 => 索引时间少一半 => 查询性能提升 25%**。当然了，其它还包括：** 索引 merge 次数更少，用的内存更少了，GC 静止出现的次数也会更少 **。

我看了下文档，需要注意的地方很多，也暗自感叹，幸好选择的是日志集群，目前出点事挂掉也不会有很大的影响。看到了 ES 的好多新功能，其中就有 reindex 这个功能，于是我就想到，不要直接升级原来的集群，而是把新集群搭建好，测试完毕之后，用 reindex 的方式把旧数据迁移过来，这样对旧日志系统的影响最小，几乎不会影响到旧有的系统，中间过渡起来也方便。事实上，官方推荐由 1.x 升级到 5.x 的方案就是 reindex。同时呢，还需要注意如果原来的索引很大，持续时间会很长，所以可以用 ES5 的 task 方式去做：
```
POST _reindex?wait_for_completion=false
```

好了，现在直接罗列一些升级过程的中的坑，希望对大家有帮助，不过建议还是先通读一遍官方的注意事项：

#### ES 升级：
1. 去除了 ES_HEAP_SIZE，改用 vm.options 里面的配置，如果不改的话，集群不会启动；
2. reindex，需要在 elasticsearch.yml 中指定 reindex.remote.whitelist；
3. 很好用的 marvel 插件现在集中在 x-pack 全家桶中了，我暂时没装，似乎还有些坑，需要单独测试下；
4. kopf 插件没了，head 也没了，都改成了单独的 app；

所以，kopf 还想用的话，用这个：
```bash
docker run -d -p 9000:9000 --restart=always --name cerebro yannart/cerebro
```

#### Logstash 升级：
1. 变得非常慢，启动时间少则 20 秒，多则一分钟，比之前慢太多；
2. 配置改为 logstash.yml 中的一些参数，当然了，命令行参数也还在；
3. workers 的配置去除，改为 logstash.yml 中的 pipleline.output.workers 参数，由此带来的兼容问题比较蛋疼；
4. elasticsearch output 改动很大，建议多测试后再上；

#### Kibana
1. Marvel 插件没了，marvel 改成了 x-pack，需要单独安装;
2. Sense 变成了 dev-tools 集成在 kibana 中；
3. Timelion 插件也没了，直接集成在 kibana 中；

### 其它
reindex 的接口，似乎没有批量的功能，也就是索引名不变，直接迁移过来的功能，网上工具也几乎没有。不过还好，ES 的 npm 包也更新了，直接自己实现调用即可，下面直接贴出我的迁移代码

```js
'use strict';

const Promise = require('bluebird');
const elasticsearch = require('elasticsearch');

const oldClient = new elasticsearch.Client({
  hosts: ['old-es-host:9200'],
  apiVersion: '2.3',
  log: 'warning',
});

const client = new elasticsearch.Client({
  hosts: ['new-es-host:9200'],
  apiVersion: '5.x',
  log: 'warning',
});


oldClient.cat.indices({format: 'json'})
.then((indices) => {
  Promise.map(indices, i => {
    if (i.index.indexOf('logstash') === 0) {
      console.log(i.index, i['store.size']);
      return client.reindex({
        // 如果原来的索引很大，还是用 task 的方式比较好
        waitForCompletion: false,
        body: {
          source: {remote:{host:'http://new-es-host:9200'}, index: i.index},
          dest: {index: i.index},
        },
      });
    }
  }, {concurrency: 1});
})
.catch(e => console.log(e))
.then(() => process.exit(0))
```

### Reference
1. http://www.infoq.com/cn/news/2016/08/Elasticsearch-5-0-Elastic

***
原链接: https://github.com/xizhibei/blog/issues/31

![知识共享许可协议](https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png "署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）")

本文采用 [署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh) 进行许可。

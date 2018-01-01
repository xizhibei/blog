---
title: ELK 搭建两三事之数据需求
date: 2016-04-13 21:05:37
tags: [ELK]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/1
---
不知道大家如何应对运营以及营销同事的『临时』数据需求，在公司早期的时候，没有专门的 BI 工程师，其他工程师不够，开发任务紧。于是一次两次还好，多了之后，工程师会很烦，美女妹子的话，写个脚本导出个 excel，其他随便给导出个 CSV 文件，然后没准同事用的是 Windows，用 Excel 打开直接是乱码 :joy: 

当然了，笑归笑，作为一个负责任的工程师 :new_moon_with_face: ，你必须得帮他们解决问题，也得意识到数据对于各个部门的决策的反馈是多么重要，有助于公司的加速成长。退一步说，之后几乎是不用帮着导数据了。（什么？不明白？那。。。解决问题之后就可以约营销妹子了，懂不？

由于这几天在搭日志系统，很自然想到 ELK 强大的功能，于是进一步想到，能不能把数据库的数据直接同步到 elasticsearch，这样的话，他们可以直接到 kibana 导出数据，或者直接在上门配置好图表，这样就根本不用导出数据了。

由于在公司里面做的是 node.js 项目，为了同步 mongo 的数据到 elaticssearch，做了几个尝试：
#### River elasticsearch

[mongo-river-elaticsearch](https://github.com/richardwilly98/elasticsearch-river-mongodb)
作为 elasticsearch 的插件，看到很多文章都推荐它，细看了下，通过 ES 的 API 配置，还支持 filter，但是它不支持最新的 elasticsearch/2.3.1，所以直接跳过，如果你的项目中有的话，可以尝试
#### Mongoosastic

[mongoosastic](https://github.com/mongoosastic/mongoosastic)
作为一个 mongoose 的 plugin，需要耦合到系统中去，也需要一些开发，但是可以精确到字段级别，配置更灵活，可以考虑；
#### Mongo connector

[mongo-connector](https://github.com/mongodb-labs/mongo-connector)
试了下，配置什么的都挺灵活，关键不用耦合到项目中去，只是我们的 mongo 数据库中，类型不严格，同步时导致经常报错，主要是类型错误，如果能更灵活一点，到字段级别，就更好了 :sunglasses: ；

其实也可以考虑参考 mongo connector 自己造个轮子

之后再细说
##### PS.

Mongo connector 配置文件可以参考如下：

``` json
{
    "mainAddress": "mongodb://localhost:27017/gleeman",
    "continueOnError": false,
    "oplogFile": "/var/log/mongo-connector/oplog.timestamp",
    "noDump": false,
    "batchSize": -1,
    "verbosity": 0,

    "logging": {
        "type": "file",
        "filename": "/var/log/mongo-connector/mongo-connector.log",
        "__format": "%(asctime)s [%(levelname)s] %(name)s:%(lineno)d - %(message)s",
        "__rotationWhen": "D",
        "__rotationInterval": 1,
        "__rotationBackups": 10,

        "__type": "syslog",
        "__host": "localhost:514"
    },

    "namespaces": {
        "include": [
            "db.source1",
            "db.source2"
        ],
        "__mapping": {
            "db.source1": "db.dest1",
            "db.source2": "db.dest2"
        }
    },

    "docManagers": [{
        "docManager": "elastic2_doc_manager",
        "targetURL": "localhost:9200",
        "__bulkSize": 1000,
        "__uniqueKey": "_id",
        "__autoCommitInterval": null
    }]
}
```


***
原链接: https://github.com/xizhibei/blog/issues/1

![知识共享许可协议](https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png "署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）")

本文采用 [署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh) 进行许可。

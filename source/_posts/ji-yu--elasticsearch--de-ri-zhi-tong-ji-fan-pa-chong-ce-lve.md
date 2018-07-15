---
title: 基于 ElasticSearch 的日志统计反爬虫策略
date: 2017-04-22 15:14:59
tags: [ELK, 反爬虫]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/46
---
之前在 [接口限流](https://github.com/xizhibei/blog/issues/29) 中提到过，用 rate limit 的方式可以起到反爬虫的效果，但是一旦遇到利用代理 IP 来爬你网站的时候，就会遇到问题了

这时候，你可以付钱买服务解决，只是，如果有时间与精力，也可以考虑自己去试试，就当是一次锻炼。

用日志去解决爬虫，也是一种简单而有效的做法，可以使用 ElasticSearch 提供的 aggregate 功能，去筛选出可疑的 IP 以及 UA，接下来怎么做，可以参考之前的说法。

### 具体方案
对于这类的爬虫，它仍会有显著的特征：在短时间内，只请求几个接口，而长时间里，它的请求量会非常高。

于是，我们的思路就很简单：

统计过去一段时间 t 里所有的请求次数，首先以 ip 分组，然后以请求的地址 transcation 分组，最后，挑选出这一段时间里面，请求次数超过 n 的，并且请求的唯一 transcation 少于 k 的。

所以，利用 Terms Aggregation，我们的 ES 请求可以这么实现（注意：我使用的 ES 版本是 5.x）：

```json
{
    "size": 0,
    "query": {
        "bool": {
            "must": [{
                    "range": {
                        "@timestamp": {
                            "gte": <start>,
                            "lte": <end>,
                            "format": "epoch_millis",
                        }
                    }
                }
            ]
        }
    },
    "aggs": {
        "ips": {
            "terms": {
                "field": "ip.keyword",
                "size": 200,
                "order": {
                    "_count": "desc"
                }
            },
            "aggs": {
                "transactions": {
                    "terms": {
                        "field": "transaction.keyword",
                        "size": 10,
                        "order": {
                            "_count": "desc"
                        }
                    }
                }
            }
        }
    }
}
```

如果不清楚 ES 的 aggs 语法，我就简单说明下：这个查询首先以 ip.keyword 做 terms 聚集，以结果的 count 数量降序排列，并只取前 200 个，然后以同样的 transaction.keyword 作为子 aggs，『分割』ip 的聚集结果，同样的，每个 ip 下的 transaction.keyword 只取前 10 个。

获得结果后，按照一定的条件过滤即可，比如在这个例子中，我们可以选取单个 ip 请求数大于 2000 并且请求的唯一 transaction 数量少于 10 的。

### 还可以怎么做
还可以考虑使用 Significant Terms Aggregation，它可以帮助我们查找不寻常的 terms，不过用这个之前，需要一些理解，从官方的例子中，还是可见一斑的：

```json
{
    "query" : {
        "terms" : {"force" : [ "British Transport Police" ]}
    },
    "aggregations" : {
        "significantCrimeTypes" : {
            "significant_terms" : { "field" : "crime_type" }
        }
    }
}
```

这个查询能得到 British Transport Police 这个部门所处理的不寻常的犯罪案件：

```json
{
    ...

    "aggregations" : {
        "significantCrimeTypes" : {
            "doc_count": 47347,
            "buckets" : [
                {
                    "key": "Bicycle theft",
                    "doc_count": 3640,
                    "score": 0.371235374214817,
                    "bg_count": 66799
                }
                ...
            ]
        }
    }
}
```

从结果中可以看到，Bicycle theft 这类案件，在总体案件中，只占 1% (66799/5064554)，但是在它这个部门中，却占到了 7% (3640/47347)，这显然是不寻常的。

那么，应用到我们的场景中，可以改成这样：

```json
{
    "size": 0,
    "query": {
        "bool": {
            "must": [{
                    "range": {
                        "@timestamp": {
                            "gte": <start>,
                            "lte": <end>,
                            "format": "epoch_millis",
                        }
                    }
                }
            ]
        }
    },
    "aggs": {
        "ips": {
            "terms": {
                "field": "ip.keyword",
                "size": 200,
                "order": {
                    "_count": "desc"
                }
            },
            "aggs": {
                "transactions": {
                    "significant_terms": {
                        "field": "transaction.keyword",
                        "size": 10
                    }
                }
            }
        }
    }
}
```

于是就能得到，Top 200 的 ip 中，我们到底能找到它们多少不寻常的 transaction。

在这个例子中，我们的筛选根据 score 即可。

好了，接下来，得到过滤后的结果怎么做呢？

### 之后怎么做

配合 Nginx 或者 HAProxy，做 IP 的黑名单，将流量导入蜜罐或者直接屏蔽。

哎。。。知道你懒，简单介绍下具体方案：

选一个配置管理工具 etcd/redis/consul/zookeeper 其中任意一个，然后将结果写到里面，然后通过 confd 动态生成 blacklist，之后 reload Nginx 或者 HAProxy 即可，这个有机会也可以再说说。

### 缺点
这种策略的缺点也是很明显：反应慢，毕竟需要采集日志之后才能采取措施。而且，这个过程需要人工不断去调整参数。

因此，这个可以用来与 rate limit 配合使用，用来查找一些 rate limit 防范不了的隐蔽的爬虫。

### 其它的想法
可以用机器学习，因为机器人总会表现得跟正常用户有区别：访问的轨迹，访问频率等等，都可以作为机器学习的输入。

不过这个需要投入更多的时间与精力，不是万不得已，不用考虑，倒是作为自己锻炼提高的过程可以尝试下。爬虫、反爬虫，是会在互联网中永远存在的东西，相互斗法，其乐无穷 😄 。

### Reference
1. https://www.elastic.co/guide/en/elasticsearch/reference/current/search-aggregations-bucket-terms-aggregation.html
2. https://www.elastic.co/guide/en/elasticsearch/reference/current/search-aggregations-bucket-significantterms-aggregation.html


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/46 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
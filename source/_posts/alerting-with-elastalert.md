---
title: ElastAlert：『Hi，咱服务挂了』
date: 2017-11-19 14:37:52
tags: [DevOps,Elasticsearch,ELK, 监控]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/62
---
<!-- en_title: alerting-with-elastalert -->
今天给大家来介绍一个报警工具，具体来说，是基于 Elasticsearch 的报警工具，假如你的日志是放在 ES 里面的，这个工具是你不错的选择。

- 项目地址：https://github.com/Yelp/elastalert
- 文档地址：https://elastalert.readthedocs.io/en/latest
- 样例：https://github.com/Yelp/elastalert/tree/master/example_rules

报警系统对于线上服务稳定性的保障作用不用多说，很多情况下，作为监控中最重要的输出环节，假如监控探测到了问题，却无法通知到我们，或者干脆通知错了，通知太过频繁，都容易导致故障的出现。

因此，好的报警系统功能，至少需要达到以下几点：

1. 及时
2. 准确
3. 少

但是现实中，这三点很难全部达到，往往我们做到的也就只是及时：** 不管什么报警，统统通知给运维与开发人员，导致他们习惯性忽略报警通知。**

下面开始正式介绍：

### 如何配置 ElastAlert
目前，它提供内置的 11 种报警规则，可以直接配置使用，下面以一个常见的类型来做说明：
##### Frequency
```yml
# 规则名称
name: Example frequency rule

# 规则类型
# the frequency rule type alerts when num_events events occur with timeframe time
type: frequency

# Index to search, wildcard supported
index: logstash-*

# Alert when this many documents matching the query occur within a timeframe
num_events: 10

# num_events must occur within this amount of time to trigger an alert
timeframe:
  minutes: 10

# ES 查询，用以过滤
filter:
- query:
    query_string:
      query: level.keyword:"error" AND name.keyword:"api-access"

```

以上就是个最简单的报警类型，其中这个例子中，当 level 为 error 且 name 为 api-access，然后 10 分钟内发生 10 次的时候，就会报警。

接下来在说几个其它你可能需要的配置：

##### 报警抑制：减少重复报警
```yml
# 用来区分报警，跟 realert 配合使用，在这里意味着，
# 5 分钟内如果有重复报警，那么当 name 不同时，会当做不同的报警处理，可以是数组
query_key:
  - name

# 5 分钟内相同的报警不会重复发送
realert:
  minutes: 5

# 指数级扩大 realert 时间，中间如果有报警，
# 则按照 5 -> 10 -> 20 -> 40 -> 60 不断增大报警时间到制定的最大时间，
# 如果之后报警减少，则会慢慢恢复原始 realert 时间
exponential_realert:
  hours: 1
```

##### 报警聚合：相同报警，聚合为一条
```yaml
# 根据报警的内，将相同的报警安装 name 来聚合
aggregation_key: name

# 聚合报警的内容，只展示 name 与 message
summary_table_fields:
  - name
  - message
```

##### 报警格式化：突出重要信息
在这里，你可以自定义 alert 的内容，它的内部使用 Python 的 format 来实现的。

```yml
alert_subject: "Error {} @{}"
alert_subject_args:
  - name
  - "@timestamp"

alert_text_type: alert_text_only
alert_text: |
  ### Error frequency exceeds
  > Name: {}
  > Message: {}
  > Host: {} ({})
alert_text_args:
  - name
  - message
  - hostname
  - host
```

### 其它报警规则
除了上面的 frequency， 这里再举几个常见的报警场景，以及在这个工具中对应的报警类型。

- `any`：这个是查到了什么便直接报警，属于自定义选项；
- `spike`：API 流量陡然上升并马上恢复的时候；
- `flatline`：内存或者 CPU 使用率下降的时候；
- `new_term`：某个枚举类型字段，突然出现了未定义的类型；
- `change`：应用的状态突然从 UP 转为 DOWN；
- `blacklist` or `whitelist`：昨天的那个疑似爬虫的 IP 地址又出现了；
- `cardinality`：线上的 API 服务器突然挂了一台，它是根据唯一值的数量来判定的；

### 报警通知配置
目前它提供了 10 多种通知的类型，但是目前国内常用的可以是 Email、Slack 或者 JIRA 了，没有微信之类的还是挺可惜的。

不过，不用担心，有第三方的：

- 微信报警：https://github.com/anjia0532/elastalert-wechat-plugin
- 钉钉报警：https://github.com/xuyaoqiang/elastalert-dingtalk-plugin

你也可以自己根据文档去实现，文档在 [这里](https://elastalert.readthedocs.io/en/latest/recipes/adding_alerts.html)。

### 在工具之外
总之，基于 ElasticSearch 的监控报警的需求，基本上都能满足你，并且也支持你自定义大部分内容。

接下来，可能你会觉得，报警工具有了，就可以安枕无忧了，显然，并不是。

你可曾想过，报警通知了之后，谁来处理，怎么处理？工具是为你所在的团队服务的，仅仅使用了这个工具，并不能很明显地提升你们的运维水平。

毕竟，这个过程还是需要人来处理（有些流程形成了后，可以自动化处理，那是你们以后需要做的），与之配套的流程与制度才是关键：

1. 谁负责报警规则的制定与维护？
2. 报警了之后，处理流程应该是怎样的？规范吗？有效吗？
3. 流程中有报警升级？升级成为线上故障之后的流程，又该如何处理？
4. 值班制度如何？是不是应该有人 24 On-Call ？

在这里，可以参考下有赞的 [线上故障管理](https://tech.youzan.com/you-zan-xian-shang-gu-zhang-guan-li-shi-jian-chu-tan/)。

相信，** 在工具之外的东西才是真正最重要的 **，不然报警系统做得再好也只是浪费时间精力而已，起不了应有的作用。而当你们团队内部行成了这种规范且有效的流程，线上服务的稳定也就有了保障，这个工具的真正价值就会显现出来。

### P.S.
这个工具是用来基于 ElasticSearch 日志来报警的，另外，这个名字没错，确实是 Elast 而不是 Elastic。



***
原链接: https://github.com/xizhibei/blog/issues/62

![知识共享许可协议](https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png "署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）")

本文采用 [署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh) 进行许可。

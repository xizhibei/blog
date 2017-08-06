---
title: 监控利器之 Prometheus
date: 2017-08-06 17:22:21
tags: [DevOps,Prometheus]
author: xizhibei
---
<!-- en_title:monitoring-with-prometheus -->

一直以来，我们会在项目中，使用 APM 去监控应用的状况，分析性能等，这些工具很有效，而且不侵入业务，不需要埋点。

然而，有些需求，是 APM 的监控满足不了的，比如 ** 应用业务指标 **。

### 监控模式
目前，采集指标有两种方式，一种是『推』，另一种就是『拉』：

推的代表有 ElasticSearch，InfluxDB，OpenTSDB 等，需要你从程序中将指标使用 TCP，UDP 等方式推送至相关监控应用，只是使用 TCP 的话，一旦监控应用挂掉或存在瓶颈，容易对应用本身产生影响，而使用 UDP 的话，虽然不用担心监控应用，但是容易丢数据。

拉的代表，主要代表就是 Prometheus，让我们不用担心监控应用本身的状态。而且，可以利用 DNS-SRV 或者 Consul 等服务发现功能就可以自动添加监控。

当然，InfluxDB 加上 collector，或者 ES 加上 metricbeat 也可以变为 『拉』，而 Prometheus 加上 Push Gateway 也可以变为 『推』。

接下来，我们主要介绍下 Prometheus。

### Prometheus
『普罗米修斯』，也是希腊之神，取义『先见之明』，应该就是监控的意义所在吧。

它跟 k8s 一样，也是依据 Google 内部的应用原理设计来的，可以看作是 Google 内部监控系统 Borgmon 的一个实现。

架构图如下（来自 Prometheus [官方文档](https://prometheus.io/docs/introduction/overview/)）：

![](https://prometheus.io/assets/architecture.svg)

Prometheus 可以从配置或者用服务发现，去调用各个应用的 metrics 接口，来采集数据，然后存储在硬盘中，而如果是基础应用比如数据库，负载均衡器等，可以在相关的服务中安装 Exporters 来提供 metrics 接口供 Prometheus 拉取。

采集到的数据有两个去向，一个是报警，另一个是可视化。

下面将一一介绍。

### Metrics 格式
```
<metric name>{<label name>=<label value>, ...}
```

各个部分需符合相关的正则表达式
- metric name: [a-zA-Z_:][a-zA-Z0-9_:]*
- label name: [a-zA-Z0-9_]*
- label value: .* (即不限制)

需要注意的是，label value 最好使用枚举值，而不要使用无限制的值，比如用户 ID，Email 等，不然会消耗大量内存，也不符合指标采集的意义。

### Metrics 接口的实现

大部分语言都有提供客户端，比如 Node.js 的客户端 [prom-client](https://github.com/siimon/prom-client)：

``` bash
npm install prom-client --save
```

目前，这个客户端提供了完整功能，可以在应用中埋点采集数据，比如

- 今天注册了多少用户，收入了多少钱，可以使用 `Counter`;
- Node 内存以及 CPU 的变化，可以使用 `Gause`；
- API 接口响应时间的统计，可以使用 `Histogram` 或者 `Summary`，前者可以按照具体数值，而后者可以按照百分比去统计响应时长；

对了，这个包内部提供了采集默认数据的功能，比如 Node 相关的指标：

```js
const promClient = require('prom-client');

promClient.collectDefaultMetrics({
    timeout: 5000,
});
```

### 报警
你可以根据业务需求，来定制相关的规则去报警，然后关键就来了，你是否在传统的短信或者邮件报警中感到厌烦呢？

一方面，当线上问题出现的时候，我们会收到大量的报警消息，而其中很大一部分是重复的；另一方面，收到没用的报警，或者报警级别不高，导致这时候如果有重要的报警，会被我们忽略。

Prometheus 的 AlertManager 提供了解决这些问题的各种高级报警功能。

- ** 报警分组 **：将报警分组，当报警大量出现的时候，只会发一条消息告诉你数据库挂了的情况出现了 100 次，而不是用 100 条推送轰炸你；
- ** 报警抑制 **：显然，当数据库出问题的时候，其它的应用可肯定会出问题，这时候你可能不会需要其它的不相干的报警短信，这个功能将真正有用的信息及时通知你；
- ** 报警静默 **：一些不重要的报警，可以完全忽略，因此也就没有必要通知；

报警通知的方式，目前可以通过 webhook, email 等方式，估计微信或者钉钉也可以，我目前使用的是 slack。

### 可视化
首选当然是 Grafana，Prometheus 自己放弃了 PromDash 的可视化工具，而专注于监控数据采集与分析。在 Grafana 中配置 Prometheus 也很简单，在配置好数据源之后，可以直接创建图表。

需要注意的是，你会需要用到 Prometheus 专用的 [查询语言](https://prometheus.io/docs/querying/basics/) 去配置数据，其中如果涉及到的图表内容太多，你可能会需要用到 Grafana 的模板：

- label_values(label)：全局中 label 值的集合；
- label_values(metric, label)：某个 metric 的 label 值的集合；
- metrics(metric)：metric 的正则表达集合，返回全部匹配的 metric；
- query_result(query)：返回查询集合；


### Ref

- https://prometheus.io/docs/operating/configuration/
- https://prometheus.io/blog/2015/06/01/advanced-service-discovery/
- http://docs.grafana.org/features/datasources/prometheus/



***
原链接: https://github.com/xizhibei/blog/issues/54

![知识共享许可协议](https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png "署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）")

本文采用 [署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh) 进行许可。

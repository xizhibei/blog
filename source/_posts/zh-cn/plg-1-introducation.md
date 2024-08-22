---
title: 【PLG 系列】（一）Loki 生态系统入门指南
date: 2024-07-08 21:09:15
categories: [可观测性工程]
tags: [PLG Stack,可观测性,Loki,Promtail,Grafana,日志工具]
author: xizhibei
---

### 前言

关于简写的解释：我们一般把之前基于 ElasticSearch、Logstash、Kibana 的日志聚合系统简称为 ELK，那么如今我们也可以把 Promtail、Loki、Grafana 的日志聚合系统简称为 PLG。

<!-- more -->

在正式开始之前，我们可以简单回顾一些之前的相关文章：

- [监控利器之 Prometheus](/zh-cn/2017/08/06/monitoring-with-prometheus/)
- [ElastAlert：『Hi，咱服务挂了』](/zh-cn/2017/11/19/alerting-with-elastalert/)
- [ELK 最近的一些总结](/zh-cn/2017/04/08/elk--zui-jin-de-yi-xie-zong-jie/)

其实，我在 2019 年 Loki 刚出来不久就开始接触并使用了。当时，我正在评估用最低的成本给我们初创的小公司搭建一个日志收集系统，Loki 刚好符合需求。它所需资源比 ELK 小得多，并且即使我们未来成长为几万人的大公司，它依然能支持。

这里不妨与 ELK 的仔细比较一下：

1. **资源消耗低**：Loki 的标签查询机制比 ElasticSearch 的全文索引更高效，减少了资源(CPU 内存以及磁盘)的消耗。Loki 不对日志内容进行全文索引，而是使用标签来组织和查询日志数据，这种设计显著降低了资源需求。同时，这也意味着对初创公司来说，Loki 更加经济实惠。
2. **易于部署和维护**：**PLG** 系统整体设计更简洁，组件之间的集成更加紧密，减少了配置和维护的复杂性。相比之下，**ELK** 系统需要配置和维护多个复杂的组件（ElasticSearch、Logstash、Kibana），对系统管理员的技术要求较高，这点相信配置过 Logstash 的一定有体会。
3. **扩展性强**：Loki 是水平可扩展的，能够轻松处理日志数据的增长。随着日志数据量的增加，可以通过增加节点来扩展 Loki 的处理能力。而 ElasticSearch 的扩展通常需要更多的规划和配置。
4. **轻量级设计**：Promtail 作为日志收集代理，比 Logstash 更轻量级，占用的系统资源更少。Promtail 专为与 Loki 集成而设计，简化了日志收集和传输的流程。
5. **灵活的查询语言**：Loki 采用与 Prometheus 类似的标签查询语言（PromQL），这种统一的查询语言使得用户在监控指标和日志时，能够使用相同的语法，简化了学习和使用成本（实际上，Loki 刚出来的时候，它的主要宣传点就是强调与 Prometheus 的相似性）。


现在再来写这篇文章也有好处，不会停留在表面，我可以更全面地介绍这个工具，并分享一些实践经验。我在写这篇文章时，Loki 的最新版本已经是 v3.1 [3.1.0 (2024-07-02)](https://grafana.com/docs/loki/latest/release-notes/v3-1/)。

### 日志管理的重要性

在复杂的分布式系统中，日志是排查问题和优化性能的关键工具。良好的日志管理能够帮助我们：

* **监控系统健康**：实时了解系统运行状态，及时发现异常。
* **故障排除**：快速定位问题源头，减少故障排除时间。
* **性能优化**：分析日志数据，发现潜在的性能瓶颈和优化机会。

### PLG 生态系统剖析

#### Loki：高效轻量的日志聚合引擎

Loki 是一个水平可扩展的日志聚合系统，旨在与 Prometheus 结合使用，以提供完整的监控解决方案。Loki 采用了 Prometheus 的标签查询语言（PromQL）和 Grafana 的查询构建器，可以轻松地查询和可视化日志数据。

![Loki Overview](media/17131020855900/loki-overview.png)

与传统的日志管理系统相比，Loki 具有更低的资源消耗和更高的性能，适用于大规模的日志数据收集和分析。它支持日志数据的分片存储和压缩，以优化存储空间和查询性能。

#### Promtail：智能日志采集代理

[Promtail](https://grafana.com/docs/loki/latest/send-data/promtail/) 是日志采集终端，与之搭配的还有 [Docker driver client](https://grafana.com/docs/loki/latest/send-data/docker-driver/)。它们的作用是在每台需要采集日志的机器中，收集、处理并发送本地日志到 Loki。

#### Grafana：强大而灵活的可视化平台

Grafana 不用多作介绍，它是一个强大的可视化工具，被绝大多数 IT 公司使用。通过 Grafana，用户可以创建丰富的可视化仪表板，实现对日志、指标等数据的全面监控和分析。Grafana 强大的插件系统和灵活的查询语言，使其成为日志管理、性能监控和故障排除的理想工具。

有趣的是，Grafana 最早其实是 Kibana 3 的分支，也就是说 Kibana 是它的祖先。具体可以查看 [v1.0](https://github.com/grafana/grafana/tree/v1.0) 的代码，Readme 中介绍了它的由来：

> This software is based on the great log dashboard Kibana.

另外还可以看作者 Torkel Ödegaard 关于它的历史介绍 [The (Mostly) Complete History of Grafana UX](https://grafana.com/blog/2019/09/03/the-mostly-complete-history-of-grafana-ux/):

> Before Grafana, there was Kibana 3.

介绍完这三个组件后，我们来实际测试体验一下：

### PLG 栈快速部署指南

这里我直接照搬了官网的例子，安装方法已经提供在 Loki 代码库中，有一个可供测试的例子：[Getting Started](https://github.com/grafana/loki/tree/0ee2a6126ae40a1d666f500c19efd639763f1bae/examples/getting-started)。这个简单的例子甚至使用了读写分离，展示了 Loki 的拓展性。

安装之前，需要确保机器上有 Docker 运行环境。如果 Docker 版本较旧，Docker Compose 可能需要手动安装。另外，由于近期国内镜像政策的调整，Docker Hub 的镜像可能无法访问，所以可能需要你有一些科学上网的手段。

这里由于篇幅，接下来实际的体验就由你自己来体验了，我相信你会喜欢这个工具的。同时，我也会另外再写一篇文章来详细介绍 Loki 的使用。

### 总结

本文介绍了 Grafana 这一强大的可视化工具，它广泛应用于 IT 行业，帮助用户通过创建丰富的可视化仪表板来全面监控和分析日志、指标等数据。通过本文的介绍，读者应该能够对 Grafana 的功能、起源以及如何开始使用它有一个基本的了解。未来的文章将进一步深入探讨 Loki 的使用，为读者提供更详细的指导。总的来说，Grafana 作为一个监控和分析工具，其强大的功能和灵活性使其成为 IT 行业内不可或缺的一部分。(此处由 GPT 生成)

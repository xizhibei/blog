---
title: ELK 最近的一些总结
date: 2017-04-08 23:09:34
tags: [ELK]
author: xizhibei
---
### 不要执迷于登录服务器敲命令，而是用自动化脚本完成所有的事情
各种博客，包括我自己，一眼望过去，全是教你一步步怎么搭建某个服务，其实这是一个 **『反模式 anti-pattern』**。

为什么？

- 首先，不可重复，他人在他们的服务器上搭建的时候，环境有可能不一致，相同的命令，可能会有完全不同的效果；
- 其次，浪费时间，当你登录服务器一步一步操作，意味着你只能一步步操作，也就是说你不能并行部署服务；

因此，你得充分利用工具的力量，ansible，puppet，chef 等之类的部署工具可以将整个过程变为可重复执行的代码，每次只要执行代码，就可以保证得到相同的结果，节省你还有他人的时间，如果这个过程是大家经常用的，不妨开源出去。

### 不要过分浪费时间在挖掘服务器的性能上
能用 SSD 硬盘就用上，花不了多少钱，服务器调优的时间，完全可以去开发更多的业务功能或者更有价值的事情上去。

而当你的老板觉得这个 ELK 日志集群服务器很花钱的时候，告诉他能得到什么：

- 快速定位问题的能力，日志里面记录着所有问题的蛛丝马迹；
- 更多维度的监控能力，也就是快速发现问题的能力。不妨计算下，宕机一小时，你们会损失多少钱；
- 可用来分析用户行为，作为个性推荐的基础数据；
- 可用来反爬虫，平台大了之后，总会有爬虫来爬你数据的，遇到恶意爬虫，甚至会造成服务器的不稳定，也是造成损失的因素；

### ELK 之外的一些工具
#### [Curator](https://www.elastic.co/guide/en/elasticsearch/client/curator/current/index.html)

这个工具是用来运维的，包括删除老的数据，备份数据等等，可能是因为配置太复杂了，命令行确实太复杂，所以 Curator 提供了基于 yml 格式的配置文件来执行相关操作。

举个最常用的例子，删除旧的 indices，释放空间：

```yml
# config.yml
---
client:
  hosts:
    - localhost
  port: 9200
  url_prefix:
  use_ssl: False
  certificate:
  client_cert:
  client_key:
  ssl_no_validate: False
  http_auth:
  timeout: 30
  master_only: False

logging:
  loglevel: INFO
  logfile: /var/log/elasticsearch-curator.log
  logformat: default
  blacklist: ['elasticsearch', 'urllib3']
```

```yml
# action.yml
---
actions:
  1:
    action: delete_indices
    description: >-
      Delete indices older than 4 days
    options:
      ignore_empty_list: True
      timeout_override:
      continue_if_exception: False
    filters:
    - filtertype: pattern
      kind: regex
      value: ^logstash-
      exclude:
    - filtertype: age
      source: name
      direction: older
      timestring: '%Y.%m.%d'
      unit: days
      unit_count: 4
      exclude:
```



然后每天凌晨定时执行：

```conf
0 0 * * * /usr/bin/curator --config <config-dir>/config.yml <config-dir>/action.yml >> /dev/null 2>&1
```

#### [grafana](https://grafana.com/)
这个不属于 elastic 公司，它提供的是图像监控功能，因此这一部分它比 kibana 的 visualize 强大一些，不过，各有长处。

另外，用 docker 部署很方便的 :P

```bash
docker run \
  -d \
  --restart=always \
  -p 3000:3000 \
  --name=grafana \
  -v /data/grafana:/var/lib/grafana \
  -e "GF_SECURITY_ADMIN_PASSWORD=test" \
  grafana/grafana
```

#### [filebeat](https://www.elastic.co/guide/en/beats/filebeat/current/index.html)
这个是最近才出来的，从文件中收集日志数据，然后发送到 logstash 或者 elasticsearch，它的一个很有意思的功能就是，可以根据 ELK 集群的负载情况，自动调整发送的速度，于是 logstash 这里就可以拿掉 broker 作为缓冲了。

#### [metricbeat](https://www.elastic.co/guide/en/beats/metricbeat/current/index.html)
这个就是用来收集应用的 metric 的，相当于 zabbix-agent，刚出来不久，但是挺有发展前景。我给它加了个 pm2 的 module ：https://github.com/xizhibei/beats/tree/master/metricbeat/module/pm2 ，用来收集 pm2 跑 node 的一些监控信息。




***
原链接: https://github.com/xizhibei/blog/issues/45

![知识共享许可协议](https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png "署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）")

本文采用 [署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh) 进行许可。

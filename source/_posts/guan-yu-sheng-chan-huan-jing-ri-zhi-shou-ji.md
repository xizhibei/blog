---
title: 关于生产环境日志收集
date: 2016-07-26 22:55:02
tags: [ELK,Node.js]
author: xizhibei
---
日志收集的重要性不言而喻，总结下在日志方面做的一些尝试：
#### 日志收集的选型

目前 nodejs 比较流行的工具有 winston，log4js，还有 bunyan，也是我用过比较多的，总体看来的话，winston 功能丰富，log4js 老牌有保障，bunyan 比较轻量级，我最后选择了 bunyan 是因为看中它的轻量级，怎么说呢，winston 太复杂了以至于影响到了我们系统的性能，具体可以看看这个：[A Benchmark of Five Node.js Logging Libraries](https://www.loggly.com/blog/a-benchmark-of-five-node-js-logging-libraries/)。
#### 收集工具

当然是 ELK，有条件的话最好搭一个集群，还有 SSD 的机器。这个成本呢，可以这么来跟你老板说：『养兵千日用兵一时』，有些致命的线上错误，只能用这个日志来发现与调试，同时呢，方便我们开发与运维，对提高系统性能，提早发现问题有很大的帮助。
#### 日志传输方式

首选 UDP，传输快，不占用应用机器的磁盘，缺点么，丢数据，UDP 么；
TCP 的话，如果日志集群足够稳定可以考虑，几乎不会丢数据；
然后还有 elastic 公司的 filebeat，这个就需要把日志输入到应用机器的文件里面了，只要日志写入到文件，几乎不会丢数据，只是部署比较麻烦，在一定程度上，限制了应用机器的快速横向拓展；
#### 日志规范

最好是每个请求都只有一条日志，这样 ELK 的压力会小一点，如果请求一条数据，返回一条数据，那就是 x2 了，如果重要的接口，需要多条日志，那就是更多了。

可以考虑在每条日志中加入 reqId，即请求 ID，每次请求若有多条日志，reqId 是把它们串起来的唯一线索，（用 bunyan 另一点就是它的 child logger，可以将 reqId 放在生成的 child logger 上，然后附在 res 或者 req 上面，后续的 middleware 直接打日志即可，不用管 reqId）然后也需要写在 response header 里面返回给客户端，这样的话，可以方便调试，APP 开发的同事直接给这个 reqId，就可以查询了，日后如果客户端也需要上传日志，也需要将 reqId 上报。

其它呢，能记上的都记上，可以方便日后的日志分析。
#### 日志安全

日志里面可能会有一些敏感信息，反正端口不能暴露在外网，然后如果真的需要的话，最简单的方式是用 nginx 做个反向代理，做个 basic auth，但是！！！不建议这么干！

其他的方案么，sheild，哎。。。要收费，[Search Guard](https://github.com/floragunncom/search-guard) 挺不错的，功能丰富，细粒度的权限控制，只是配置起来真的挺麻烦，人员多了之后可以考虑配置一下。
#### 其它作用

日志除了查询与分析之外，还有个作用就是报警，这个目前还没做，不过做起来也挺简单，定时去 ES 查询相关的结果，直接根据结果决定是否报警即可。


***
原链接: https://github.com/xizhibei/blog/issues/24

![知识共享许可协议](https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png "署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）")

本文采用 [署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh) 进行许可。

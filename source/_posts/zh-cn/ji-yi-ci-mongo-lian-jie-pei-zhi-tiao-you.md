---
title: 记一次 Mongo 连接配置调优
date: 2016-04-14 17:56:52
tags: [MongoDB,Node.js, 数据库]
categories: [数据库,MongoDB]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/2
---
话说在我接手公司的项目后花时间去优化 API 性能的时候，在 newrelic 上面看到，大部分都是 mongo 的时间，因此很有必要花大时间去优化。

我们用的是 mongoose@3.8.23，然后修正了其中的复制集排序选择问题（3.8.39 已经修正了，目前我正在比较测试，包括目前最新的 4.4.x），先把项目的连接配置贴出来：

``` javascript
var options = {
    replset: {
        strategy: 'statistical',
        readPreference: 'secondaryPreferred',
        socketOptions: {
            connectTimeoutMS: 5000,
            keepAlive: 1,
        }
    },
    server: {
        poolSize: 10,
        slaveOk: true,
        auto_reconnect: true
    }
}
```

来，给你一分钟，找找其中的问题

---

好，不知道你想的是否跟我一样：
1. replset 里面没有配置 poolSize，默认的是 5，有点小，这个数字需要根据实际项目调整，但 5 的话，对于高并发项目太小；
2. socketOptions 里面的 keepAlive 设置的是 1，这个参数可不是 Boolean，它是 Number，表示时间间隔，属于 TCP 连接的参数，单位是毫秒，如果是 1 的话，就表示每隔一毫秒就给 mongo 数据库发一个空的 TCP keepAlive 包【[可以参见这里](http://tldp.org/HOWTO/TCP-Keepalive-HOWTO/overview.html)，以及 [Node.js net 模块文档](https://nodejs.org/api/net.html#net_socket_setkeepalive_enable_initialdelay)】，所以数据库被『DDOS』了，所以可以设置为 1000ms；
3. 由于项目生产环境用的是复制集，server 参数在这里是没用的；
4. connectTimeoutMS 设置有点小，可以是 30 秒，或者更大点；


***
原链接: https://github.com/xizhibei/blog/issues/2

![知识共享许可协议](https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png "署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）")

本文采用 [署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh) 进行许可。

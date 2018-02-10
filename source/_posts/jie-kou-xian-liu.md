---
title: 接口限流
date: 2016-10-29 18:30:42
tags: [Node.js,redis, 反爬虫]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/29
---
在业务安全性方面，我们常常会用到接口限流，主要是为了防止系统压力过大、保证每个用户请求的资源保持均匀以及屏蔽恶意请求。

几个常见的场景如下：
- 恶意注册
- 爬虫的过度抓取
- 秒杀场景

目前实现 API 接口限流的方式有几种常见的，简单来说原理很简单，无非是在一个固定的时间段内，限制 API 的请求速率，一般来说是根据 IP，如果是登录用户的话，还可以用用户的 ID。
### Token Bucket 与 Leaky Bucket
- Token Bucket：定时的往每个 bucket 内放入 token，然后每个请求都会减去 token，假如没有 token 的话就采取限流措施，能够限制平均请求频率；
- Leaky Bucket：做个缓冲队列，所有请求进入 bucket 排队，超过 bucket size 则丢弃，能够应付流量暴涨，请求集中；

两个算法，都有优缺点，都有适合的场景，比如 Leaky Bucket 很适合秒杀，因为需要应对所有用户的请求，用在正常业务中，容易卡着正常业务；而 Token Bucket 的话，更适合用在我们正常业务中的场景，限制接口的请求频率。

拿 TJ 的一个项目来说：[RateLimiter](https://github.com/tj/node-ratelimiter)

算是一个 Token Bucket 的实现，每过一个 duration，就让 bucket 重新填满，优点是处理简单，快速，缺点还是是无法避免请求的集中效应，比如你限制每个小时 1000 次，那就是说，每个小时的开始的一秒内，爬虫可以用 1000 个并发（实际上，如果上个小时，爬虫没有任何请求，则可以在上个小时结束的一秒以及这个小时开始的时候的 2 秒内请求 2000 次）来搞垮你的服务器。当然了，你可以再加入更小的 duration，比如 10 分钟内 100 次，1 分钟内 10 次，这样的确可以避免这种情况，但是效率比较低下，毕竟要经过三层，而且，每层都要计数，一旦一层超过了，其它两层可能无法计数了，如果反过来，先检查最大的 1 小时，则还是会遇到每小时开始时候重置的问题。

所以，我们需要这个固定 duration 滑动起来，不会有 reset，就可以一定程度上避免了集中效应。
### Token Bucket 滑动窗口限流

目前查到的 Node.js 实现的项目中，只有两个实现了滑动窗口限流：
- [redback/RateLimit](https://github.com/chriso/redback/blob/master/lib/advanced_structures/RateLimit.js)
- [ratelimit.js](https://github.com/dudleycarr/ratelimit.js)

只是实现略复杂，效率可能比不上上面的，简单来说是把 duration 切分成多个 block，然后单独计数，时间每经过一个 block 的长度，就向前滑动一个 block，然后每次请求都会计算那个 duration 直接的 block 内的请求数量。只是，如果还是单个 duration 的话，并不能解决集中效应。

简单比较下这两个滑动窗口的方案：
##### redback/RateLimit:
- 优点：实现简单优雅，代码容易看懂，由于没用 lua 脚本（需要支持 script 相关命令），很多云服务商提供的 redis 可以用了；
- 缺点：功能不够丰富，代码很久没更新了，只支持 node_redis；
##### ratelimit.js：
- 优点：使用 lua 脚本实现了具体逻辑，减少通讯时间，效率高，支持多个 duration，并且还有白黑名单功能，支持 ioredis 以及 node_redis；
- 缺点：可能还是因为 lua 脚本，如果不熟悉的话，看起来比较吃力；
### 限制了后怎么做

对于恶意请求，假如对方的反反爬虫做的一般的话，完全可以直接将对方的 IP 加入黑名单，但如果对方用的 IP 代理，那就不是限流这个方案能解决的了，需要更高级的反爬虫方案。

但是我想提一点，对方既然爬了你的数据，肯定有对方的用处，假如对方没有恶意，请求频率也没有让你的机器有太多压力，那也就算了，毕竟你可能也在爬其它人的数据，大家都是搞技术的，没准对方背着万恶的 KPI 呢。

但是，如果对方恶意爬取，那么你完全可以在探测到对方的请求之后，返回空数据，甚至以假乱真的数据欺骗对方，让对方无利可图，对方也可能就会主动放弃了。
### 如何设置限制参数

查日志，统计下用户的正常请求就行。
### PS1:

express 以及 koa 框架下，如果是在反向代理服务器 nginx 或者 haproxy 之类的后面，这时候获取用户的 IP 的话，则需要设置 trust proxy，具体可以看这里：https://github.com/xizhibei/blog/issues/3
### PS2:

可能你注意到了，我介绍的三个项目都是基于 redis 做的，原因无非是快，效率高，多进程多机器状态共享，对于其它的我觉得 mencached 勉强可以考虑，如果基于内存的话，无法处理多进程，多机器的情况。

什么？MongoDB？MySQL？别逗了。。。
### Reference
- https://en.wikipedia.org/wiki/Leaky_bucket
- https://en.wikipedia.org/wiki/Token_bucket
- http://www.dr-josiah.com/2014/11/introduction-to-rate-limiting-with.html
- http://www.dr-josiah.com/2014/11/introduction-to-rate-limiting-with_26.html


***
原链接: https://github.com/xizhibei/blog/issues/29

![知识共享许可协议](https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png "署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）")

本文采用 [署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh) 进行许可。

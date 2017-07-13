---
title: 关于 Redis 缓存
date: 2016-06-22 22:09:09
tags: [redis]
author: xizhibei
---
今天尝试了用 redis 的 set 作为缓存用途，恩，好疼。。。

是这样的，看到项目中用到应用缓存的地方很少，为了减轻 MySQL 数据库的压力，特地引入 redis 作为已购买物品的缓存，但是物品不能重复购买，因此这个缓存还得支持重复性检查。

于是很自然想到 redis 里面的 hash 或者 set，然后，有个问题就是，当 hash 或者 set 没有 member 的时候，他们是不会存在于 redis 之内的，也就是 `hgetall` 或者 `smembers` 返回为空，于是为了缓存没有购买物品的用户，比如存一个自定义的特殊值，来确保这个值是存在的，即制造一个自定义空值，那么，为了区分这个 key 有没有存在，必须得使用 `exists` 或者 `type` 命令，`exists` 会返回 0 或者 1，`type` 会返回 none 或者其他类型。

来，直接说结论：** 不要用 exists 或者 type!!!!!**

首先这俩命令会很慢，其次程序中会先使用 exists，存在才会继续使用 smembers 或者 hgetall，进一步增加时间开销。

还是老老实实用 get 跟 setex 吧，效率高多了。另外，在这种场景下，还有个数据一致性问题，因为重复性检查可能需要锁，不然会有数据不一致现象。

不过我的解决方案是允许重复，然后如果有重复的，在异步业务流程中手动回滚，并及时 reload 缓存。
#### PS

推荐一个缓存模块，用起来挺顺手：
https://github.com/BryanDonovan/node-cache-manager


***
原链接: https://github.com/xizhibei/blog/issues/21

![知识共享许可协议](https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png "署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）")

本文采用 [署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh) 进行许可。

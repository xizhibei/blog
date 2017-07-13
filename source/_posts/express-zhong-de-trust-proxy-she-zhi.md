---
title: express 中的 trust proxy 设置
date: 2016-04-15 11:12:38
tags: [Node.js]
author: xizhibei
---
一般来说，我们的项目都是放在反向代理后面的，比如 nginx，haproxy 之类的，这时候就会有个问题，你获取的 IP 地址可能一直是前面代理的 IP，而不是用户端的 IP，于是这时候 express 就需要设置下 trust proxy 了

默认是 false，也就是不信任任何代理，比如你所在的私有网络是 **10.0.0.0/8**，那么直接设置：

``` javascript
app.set('trust proxy', '10.0.0.0/8');
```

即可，然后在代码中获取 **req.ip** 就可获得客户端的地址，**req.ips** 里面放是从 **x-forwarded-for**
 取出的地址，当然了，地址会经过过滤处理，只会根据你设置的规则，只会把根据设置的规制，把受信任的 IP 地址留下。

然后，如果你觉得某个代理 IP 是值得信任的，也可以单独设置：

``` javascript
app.set('trust proxy', '10.0.0.0/8', '123.123.123.123');
```

当然，特殊的规制还可以用函数：

``` javascript
app.set('trust proxy', ip =>  /^123/.test(ip));
```

具体请参考 [官方文档](http://expressjs.com/en/guide/behind-proxies.html)


***
原链接: https://github.com/xizhibei/blog/issues/3

![知识共享许可协议](https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png "署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）")

本文采用 [署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh) 进行许可。

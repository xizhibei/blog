---
title: HTTPS 两三事
date: 2016-11-13 16:54:22
tags: []
author: xizhibei
---
### 为什么我们需要
近来 HTTPS 越来越被大家重视，尤其是在 http2 出来之后。

#### 流量劫持
国内的网络环境很恶劣，运营商各种流量劫持，DNS 劫持，只是为了在你页面上加上几个小广告，或者更严重的，是否还记得 12306 抢票软件拖垮了 github？对于流量劫持，很简单的方案就是用 HTTPS，流量加密之后就可以解决。（说句题外话，DNS 劫持的话，httpDNS 不错）

#### Http Session 劫持
正常来说，你肯定在公共场合用到过 WiFi，那你是否知道，假如我跟你在一个子网内，你用的是 HTTP 的话，我可以很轻易的嗅探到你的 Cookie，或者你的用户名密码，然后登陆你的账号。。。

具体怎么做就不说了，想象以下，你正在转账，或者付款。所以目前大部分付款有关的地址都是 HTTPS 的，为了防止你的交易甚至账户信息被劫持。

另外，就算同网络下没有人劫持，你别忘了，还有更大的公网呢，这些公网都是由人去管理的，恩，不多说了。

同理，没有加密的 SMTP，POP3 之类的协议，也会非常不安全。

### 为什么现在没有完全普及开来
很简单：成本，使用 HTTPS 是有成本的，证书本身还好，但是，一旦请求量上去之后，就得堆上更多的机器。另外，国内大部分公司的安全跟隐私意识不够强，也没有法律说必须要用。只是目前 CPU 成本越来越低，已经低到可以用这点成本来换取流量的安全以及用户的信任了。

另外，这是未来的趋势，来看几个消息吧：
1. [Deprecating Powerful Features on Insecure Origins](https://sites.google.com/a/chromium.org/dev/Home/chromium-security/deprecating-powerful-features-on-insecure-origins)，Google Chrome 表示它的 API 必须在 HTTPS 下调用；
2. [Deprecating Non-Secure HTTP](https://blog.mozilla.org/security/2015/04/30/deprecating-non-secure-http/)，Mozilla 公司明确表态，逐步淘汰 http；
3. [Apple will require HTTPS connections for iOS apps by the end of 2016](http://techcrunch.com/2016/06/14/apple-will-require-https-connections-for-ios-apps-by-the-end-of-2016/)，这个估计知道的人多些，简单来说就是 App Store 上面的 APP 必须使用 HTTPS；

很简单，以前你可以说我们传输的内容不重要，为了省几个小钱，所以不管了。但是以后不行了，几个科技巨头都宣布你必须要用 HTTPS，否则你就会被强制淘汰。科技巨头的力量还是很强大的，这也是正是巨头应该做的：Make the world a better place。

另外，用了 HTTPS 后意味着可以用 HTTP2，而 HTTP2 能抵消掉性能的损失，或者，进一步提高性能。

### 怎么用
一般来说，放在 web app 里面是不合适的，相当于每个 web app 都得部署了，而且拓展起来不方便。好一点的做法是直接部署在 load balance 上面，比如 nginx 或者 haproxy。

下面简单说说 Nginx 上如何配置：
首先肯定不能像 12306 那样用 self signed 证书，申请个正规的证书吧，免费的也有，但是，最好还是付钱的，免费的最贵啊。

申请之后，会有 example.crt，还有 example.key，这两个放在对应的目录下，调整下配置即可。

``` 
    listen                   443 ssl;
    server_name       example.com;
    add_header         Strict-Transport-Security "max-age=63072000; includeSubdomains; preload";

    ssl_certificate        /etc/nginx/certs/example.crt;
    ssl_certificate_key /etc/nginx/certs/example.key;
    ssl_protocols         TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers             HIGH:!aNULL:!MD5;
```

### 怎样会更好

- 禁用 SSLv3，不安全
- 使用 HSTS，加入一个 http 头，强制浏览器在 max-age 之前只用 https 连接。 


### Reference
- https://raymii.org/s/tutorials/Strong_SSL_Security_On_nginx.html
- https://imququ.com/post/moving-to-https-asap.html
- https://wiki.mozilla.org/Security/Server_Side_TLS
- http://www.barretlee.com/blog/2015/10/22/hsts-intro/
- https://www.oschina.net/translate/why-http-is-sometimes-better-than-https?print





***
原链接: https://github.com/xizhibei/blog/issues/30

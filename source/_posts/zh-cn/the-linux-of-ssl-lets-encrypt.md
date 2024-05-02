---
title: SSL 界中 Linux：Let's Encrypt
date: 2019-09-09 19:56:34
tags: [DevOps,Linux]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/120
---
<!-- en_title: the-linux-of-ssl-lets-encrypt -->

今天我们来说说造福人类的 [Let's Encrypt](https://letsencrypt.org)（以下简称 LE）。为什么说它造福人类？因为免费。

我之前在[划一划 HTTPS 以及 SSL/TLS 的重要知识点](https://github.com/xizhibei/blog/issues/83)说过，各路权威 CA 机构通过颁发证书来获利，然后保证服务质量，不去作弊，获得长久的可持续发展。只是，这同时也在一定程度上阻碍了 HTTPS 证书的大范围推广。而现在，LE 通过免费，大大普及了 HTTPS 的应用。（妥妥的互联网思维）

### 几个统计数据

先来看看官网上的[数据统计](https://letsencrypt.org/stats/)，结果还是挺令人惊讶的：

从 2015 年 8 月 8 日开始，截止今天 2019 年 9 月 9 日：

1.  1.8 亿活跃完全合格的域名 ([FQDN](https://en.wikipedia.org/wiki/Fully_qualified_domain_name))，1.08 亿活跃证书，0.54 亿活跃的注册域名；
2.  2019 年 2 月 2 日，单日颁发证书量达到历史最高值 155 万；

官网上还提供了 Firefox 的 HTTPS 加载页面的数据，从 30% 一直提升到 80% 左右，虽然没有直接说明，但还是可以看出来，这个功劳至少有它的一份（我认为是大部分，毕竟免费 HTTPS 证书还是很有吸引力的），它果真是推动着互联网的进步。

既然有免费又好用的证书，为何不好好用好它？

### 初级用法

就是使用符合[ACME](https://github.com/ietf-wg-acme/acme) 标注的客户端，ACME 是 Automated Certificate Management Environment（也就是自动化证书管理环境）缩写。

由于这个标准，我们有[一堆的工具](https://letsencrypt.org/docs/client-options/)可以使用，下面举两个常用的：

#### [Certbot](https://certbot.eff.org/)

这个工具是大多数人早期接触的时候会用到的，简单易用，并且网站的教程也是通俗易懂。

注意，这是 Python 写的工具，建议在 Python3 下安装使用，毕竟 Python2 马上要停止支持了（2020-01-01 停止，只有三月不到了）。

#### [acme.sh](https://github.com/Neilpang/acme.sh)

这个工具比上面的好用一些，毕竟不需要考虑 Python 的兼容性了，一键安装，然后就可以直接使用了，大部分工作只是在于获取以及部署证书到服务中，后续它也会自动帮你获取证书然后自动部署。

生成证书：

```bash
acme.sh --issue -d example.com -w /home/wwwroot/example.com
```

安装证书：

```bash
acme.sh --install-cert -d example.com \
    --key-file       /path/to/keyfile/in/nginx/key.pem  \
    --fullchain-file /path/to/fullchain/nginx/cert.pem \
    --reloadcmd     "service nginx force-reload"
```

### 进阶用法

高级点的用法，便是对于你作为运维自己造轮子，或者开发 SaaS/PaaS 平台的相关功能了，比如用户可以配置自定义域名并且配置 DNS 指向你的服务平台。而如果用户自己上传证书则会让这个功能的体检不够，因为：

1.  一个是要校验证书格式、是否有效（域名、有效期）、在国内的话还需要检查域名是否已经 ICP 备案等；
2.  客户需要自己定期去更新证书，如果通知不及时，或者客户没有来得及更新就会会影响客户的服务；
3.  有证书泄露的风险，毕竟证书存于你的服务中，到时候容易扯皮了；

那么，该如何集成 ACME 功能到我们的服务中去？如果你的应用用的是 Golang，推荐一个库 [lego](https://go-acme.github.io/lego/usage/library/) 它就是用 Golang 实现的，并且目前仍在积极维护，我们就可以用它来实现我们的服务。（下次没写作灵感的时候，我就来写个实践 🙈 ）

不过在使用它之前，需要明白 Challenge 的概念，简单来说，LE 会通过 DNS 解析域名后访问来确认你在控制某个域名，也就是它提出一个挑战 (Challenge)，你需要去解决 (Solve) 这个挑战，那如何来实现呢？

大致步骤包括：
1\. 使用邮箱注册账号（他们会通过邮件来通知你证书快过期了）；
2\. 请求校验 Challenge，它会在你的请求中，给你返回相关的认证信息，其中就包括 token 与 keyauth；
3\. 目前有三种方式可以 "Solve Challenge"，你可以将 token 与 keyauth 根据不同的方式存入：
    1\. **HTTP-01**：可以将内容写入文件系统，缓存，数据库等地方，等待 LE 的 HTTP 请求，一般是 `/.well-known/acme-challenge/:token` 这样的接口，返回相应的 keyauth 即可；
    2\. **DNS-01**：LE 通过 DNS `_acme-challenge.yousite.example.com.`的 TXT 记录之来获取 keyauth；
    3\. **TLS-ALPN-01**：LE 将 keyauth 写入一个临时证书，用作临时 HTTPS 服务器，通过 HTTPS 访问你的服务后确认通过；
4\. LE 会在 Challenge 通过后，颁发 HTTPS 证书给你，然后你就能直接使用了，如若不通过则会报错，可通过返回的错误信息调试；

这里建议都通过 LE 的 Staging 服务器来调试，不然会触发[频率限制](https://letsencrypt.org/docs/rate-limits/)。另外，如果你在实现 SaaS/PaaS 平台，涉及到比较多的自定义域名需要获取证书，那就需要向 LE 申请更多的配额了。

### 最后

LE 到底通过什么来实现可持续发展？目前官方的说法是[靠赞助商以及捐赠](https://letsencrypt.org/docs/faq/)，而我的看法是，目前 LE 做的事情是在创造价值，它就是 SSL 界的 Linux，并且目前他们已经越来越成为这个互联网不可或缺的基础，而一旦成为了基础，自然有人买单（目前赞助商看到不少大厂的身影），因此不用担心他们的可持续发展。


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/120 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
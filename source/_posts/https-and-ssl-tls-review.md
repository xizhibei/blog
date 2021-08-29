---
title: 划一划 HTTPS 以及 SSL/TLS 的重要知识点
date: 2018-07-29 14:06:46
tags: [反爬虫,基础知识,HTTPS]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/83
---
<!-- en_title: https-and-ssl-tls-review -->

首先，从我们最常见的『安全』网站来说。

我们在 Chrome 浏览器中（其它浏览器类似），假如浏览的是 **https** 开头的网站，会发现开头会是绿色的：**『🔒安全』** 字样，点击之后，会有个小悬浮窗口就会告诉你『连接是安全的』，浮窗下面会有三个选项：『证书、Cookies、站点设置』，继续点击证书，就会弹出一个窗口，里面大概会提到这个证书所对应的网址、有效期等。

以 GitHub 的为例：

> www.github.com
> Issued by: DigiCert SHA2 High Assurance Server CA
> Expires: Saturday, June 20, 2020 at 20:00:00 China Standard Time

你看到的正是 HTTPS 协议所需要的 SSL 证书。

好了，作为好学的你，现在应该有几个问题了吧，不急，慢慢看。

<!-- more -->

### HTTPS

其实一年多之前，我写过一篇比较粗糙的文章 [HTTPS 两三事](https://github.com/xizhibei/blog/issues/30)，而今天我们来继续理一理 HTTPS 的知识点。

#### 为什么 HTTPS 开头的网址会被标记为安全的？

这是 Chrome 等浏览器提示我们当前浏览的网页是建立在 HTTPS 协议之上的，在我们与服务器的传输过程中，明文信息不会被第三方窃取。事实上，Chrome 56 正式将 HTTP 页面标记『不安全』。

#### 为什么 HTTPS 能够保护我们的信息不会被第三方窃取？

因为这个过程中，信息都是经过加密的，而所用到加密算法在目前可以被认为是难以破解的。

#### 加密的算法再厉害，假如有个人在你与服务器之间进行窃听的话也是可以做到的吧？

这个问题很有意思，这也是 HTTPS 协议中最重要的一环：防止『中间人』攻击。

中间人攻击说的是窃听者分别于你以及服务端建立独立的加密连接，但由于你与服务器都只能确认连接是加密的，而不能确认对方的实际身份，从而造成了中间人攻击。

就比如你在银行网站进行转账的时候，你以为是给正常的对方转账，而实际上有可能在假的网站上给黑客转账而已。

解决的方式就是引入 CA (Certificate authority) 即证书权威机构，由它们来认证这个证书的持有者（服务端）确实是真的。

#### SSL 证书是什么？

可以理解为钥匙，可用来加解密信息。CA 会给各个网站发行 SSL 证书，

#### 那如何确保 CA 的身份？

这位同学很棒，问题很刁钻。

一般来说，CA 的证书是预先放到操作系统里面的，而这些证书都是比较权威的机构，比如 VeriSign、Symantec、GoDaddy 等。

可能你会以为这样的话他们就可以随意发证书，甚至发证书给黑客来进行窃密了。不是的，因为这些机构可以通过发行证书来获利，而一旦被发现违规了，就会被加入黑名单[3]，它们不会拿自己的财路开玩笑，所以可以放心。

但同时，由于 CA 证书可以自行生成，然后安装到操作系统里面以后，所有经过 CA 签名的证书都会被标记为安全的，甚至可以给知名网站签发假证书，造成信息泄露，所以千万注意不要安装来路不明的证书。

### SSL/TLS

然后，再说说 SSL/TLS，不过得复习一个基础知识：**网络模型**。

我们知道，OSI 网络模型有七层[1]：

> 第 7 层 应用层（Application Layer）提供为应用软件而设的接口，以设置与另一应用软件之间的通信；
> 第 6 层 表达层（Presentation Layer）把数据转换为能与接收者的系统格式兼容并适合传输的格式；
> 第 5 层 会话层（Session Layer）负责在数据传输中设置和维护电脑网络中两台电脑之间的通信连接
> 第 4 层 传输层（Transport Layer）把传输表头（TH）加至数据以形成数据包。
> 第 3 层 网络层（Network Layer）决定数据的路径选择和转寄，将网络表头（NH）加至数据包，以形成分组。网络表头包含了网络数据。
> 第 2 层 数据数据链路层（Data Link Layer）负责网络寻址、错误侦测和改错；
> 第 1 层 物理层（Physical Layer）在局部局域网上传送数据帧（data frame），它负责管理电脑通信设备和网络媒体之间的互通。

而工业界实现的 TCP/IP 模型只有四层：也就是对应上面的应用层、传输层、网络层以及链路层。

那么，接着的问题就来了：SSL/TLS 协议在哪个层呢？

显然，是与 HTTP 协议一起在应用层，组成了 HTTPS 协议，但是也可以说是介于 HTTP 与 TCP 之间的一个层，因为 HTTP 既可以直接工作在 TCP 之上，也可以工作在 SSL/TLS 之上，两个 HTTP 协议本身没有根本区别（SSL/TLS 也可以为作为其它应用层协议的安全层，比如邮件的 POP3，SMTP 等）。

再说个临时凑数的例子：假如把 HTTP 比喻成你自己以及 TCP 是天空的话，SSL/TLS 协议就是保护你免受在雨天行走时淋雨的伞。

![](https://xizhibei.github.io/media/15318057777104/15327668012129.png)

现在可以来简单说说 SSL/TLS 协议的区别了。

-   SSL 全称为 Secure Socket Layer，即安全套接字层，它是由网景公司（Netscape）在 1994 年推出首版网页浏览器 Netscape Navigator 时提出的（但从未公开发布）[2]；
-   TLS 全称为 Transport Layer Security，即传输层安全性协议，由 IETF 在 1999 年将 SSL 进行标准化，发布了第一个版本[2]；

是的，两者关系很紧密，只是目前 SSL 协议都被认为是不安全的[2]，推荐还是使用 TLS 协议，比如注意你在 Nginx 的配置中，用到的那几项协议是否安全，下面的是推荐的：

    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;

详细的协议区别就不赘述了（显然我暂时也说不好 :P ），想了解的可以参考 [4][5]。

### 一些实践

#### 用 OpenSSL 生成自签名证书

OpenSSL 一般都是系统自带的：

```bash
# 生成 CA 证书的 key
openssl genrsa -out ca.key 4096

# 根据 key 生成 CA 证书
openssl req -new -x509 -days 365 -key ca.key -out ca.crt

# 服务器 key
openssl genrsa -out server.key 4096

# 服务器证书请求
openssl req -new -key server.key -out server.csr

# 用 ca 签名服务器证书请求，生成一个有效期为 365 天的证书
openssl x509 -req -days 365 -in server.csr -CA ca.crt -CAkey ca.key -set_serial 01 -out server.crt
```

#### 用 CFSSL 生成自签名证书

用 [CFSSL: Cloudflare’s PKI and TLS toolkit](https://github.com/cloudflare/cfssl) 其实更简单一些。

首先安装下：

```bash
go get -u github.com/cloudflare/cfssl/cmd/...
```

然后具体请参照安装 kubernetes 的时候的实际例子：
[kelseyhightower/kubernetes-the-hard-way · GitHub](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md)

#### 帮助 HTTPS 开发的小工具

[mkcert](https://github.com/FiloSottile/mkcert) 是比 CFSSL 还要方便的工具，可以用来本地开发测试时候使用。

#### 关于 API 接口加密

有时候为了防止接口被破解之后的爬虫爬取数据，会将 API 接口加密，可能我们会选择对接口进行加密，但是我想在你继续之前说几句：

1.  防爬虫，你们只有加密接口这个解决方案了吗？验证码，[日志反爬](https://github.com/xizhibei/blog/issues/46)，[频率限制](https://github.com/xizhibei/blog/issues/29)了解下？
2.  加密接口后续维护考虑清楚了吗？包括出错了如何调试，是否有相关工具帮助调试？相信我，用 Postman 之类的 HTTP 工具得到一堆密文之后，头疼的不只是破解者，实际上更大概率是你们自己头疼。
3.  假如加密的接口还是被破解了（你要相信有足够的利益驱使的话，破解不是问题，而且一个破解之后，就可以扩散出去了），你们有解决方案吗？
4.  还要继续的话，考虑下客户端 HTTPS 证书，是的，既然有服务端证书，那客户端证书也肯定能有的，而且由于服务端是 C/S 系统架构的中心，CA 证书可以用自己生成的。

### Ref

1.  [OSI 模型](https://zh.wikipedia.org/zh-cn/OSI%E6%A8%A1%E5%9E%8B)
2.  [传输层安全协议](http://zh.wikipedia.org/wiki/%E4%BC%A0%E8%BE%93%E5%B1%82%E5%AE%89%E5%85%A8%E5%8D%8F%E8%AE%AE)
3.  [违规被浏览器列入黑名单的 CA、SSL 证书](https://blog.myssl.com/ca-blacklist/)
4.  [SSL/TLS 协议运行机制的概述 - 阮一峰](http://www.ruanyifeng.com/blog/2014/02/ssl_tls.html)
5.  [SSL/TLS 原理详解](http://seanlook.com/2015/01/07/tls-ssl/)


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/83 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
---
title: HTTPS 双向证书认证
date: 2021-02-03 17:51:26
tags: [HTTPS,反爬虫,安全,工具]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/159
---
<!-- en_title: https-two-way-authentication-with-certificates -->

在很久之前，我在 [划一划 HTTPS 以及 SSL/TLS 的重要知识点](https://github.com/xizhibei/blog/issues/83) 提到过客户端 HTTPS 证书，之后就没后续了，不过目前还是遇到了接口问题，不得不用上了。

### 简介

接下来会给大家说清几个概念：HTTPS 单向认证、HTTPS 双向认证、中间人攻击。

#### HTTPS 单向认证与双向认证

在这两种认证场景中，主要的区别在于服务器是不是需要客户端提供证书验证，我们，在进行 TCP 三次握手成功后，就开始进行 SSL 阶段的握手了了。

SSL 握手阶段可以参考如下，此图盗自 [Ssl handshake with two way authentication with certificates](https://commons.wikimedia.org/wiki/File:Ssl_handshake_with_two_way_authentication_with_certificates.png) 。这张图里面的大致阶段是对的，只是并不是很详细，更详细的请参考 [Transport Layer Security][1] 。

![Ssl handshake with two way authentication with certificates](https://blog.xizhibei.me/media/16120752577354/16121774495273.jpg)

正如如上图所示，这个过程中，主要区别就在于第三阶段<sup>[1]</sup>：

-   第一阶段：协商，客户端发送 hello 消息，会包含自己能支持的最大支持的 TLS 版本，**一个随机数**，以及一系列建议的加密套件以及压缩方法；然后服务器在接收之后，也会发送 hello 消息，包含着根据客户端挑选过的 TLS 版本，加密套件以及压缩方法；
-   第二阶段：服务器证书处理，服务器会将证书发送至客户端，并且紧接着就会发送一个要求发送客户端证书的请求，客户端会在这个时间根据 CA 来验证服务器的证书；
-   第三阶段：客户端证书处理，客户端会将证书发送至服务器，服务器会根据 CA 来验证（这个 CA 可以完全是自己生成的），客户端同时会发送一个用服务器证书加密过的随机数 **PreMasterSecret**，然后客户端会发送一个前一个握手阶段的消息的签名来告诉服务器，客户端是的确是拥有当前证书的（有私钥），然后客户端以及服务器会根据 PreMasterSecret 以及随机数，来生成一个公共的 secret，叫做 **Master secret**；
-   第四阶段：加密通信，两边开始都用 **Master secret** 来进行对称的加解密；

如果把第三阶段省略掉，那就变成单向认证了，所以担心加密过程开销的同学们可以稍稍省点心了，因为整个过程中，就是 SSL 握手阶段的开销会略微加大，而实际通信过程中的开销还是与单向认证一样。

#### 中间人攻击

所谓中间人攻击，就是在双方握手阶段，由于没有用 CA 对证书进行验证造成的问题：比如你如果不在意浏览器的警告，或者被骗安装了攻击者提供的 CA 证书。攻击者可以在你与服务器建立 SSL 通信的时候，先用假的证书与你建立 SSL 通信，然后再与服务器建立 SSL 通信，这个过程中，攻击者就能拿到这个过程中所有的明文消息。

用一个非常简单的例子来说明，就是 HTTPS 抓包，比如现在你需要抓手机上的 HTTPS 请求，那么你就需要在手机上安装抓包工具提供的 CA 证书，然后配置好代理后，就可以抓到 HTTPS 的明文请求了。

### 我们的问题

到目前，我们知道了 HTTPS 双向认证是怎么一回事，那么它能解决我们的什么问题呢？防止有人冒充我们的客户端来请求服务器的私有资源，那么我们可以直接去验证客户端的身份，就能在很大程度上解决问题。

下面自问自答，来帮大家理清楚思路：

#### 为什么不用自己的方式来加密呢？

相信这样的场景很常见，为了保护接口，直接跟客户端约定一个密钥，然后大家根据这个密钥来进行加密通信，这种方案在我看来很容易破解，而且一旦破解拿到密钥，你很难短时间里面通过更新客户端来更换密钥。

这种方式，做的好的能够使用公开经得起验证的加密算法，而做的差的会用私有加密算法（多个公开算法叠加套用不算私有）。这在一定程度上能够阻挡破解者，只是私有加密算法出问题的概率在遇到**高价值资源**的时候，就会变得非常大，简而言之，就如闭源与开源一般。

另外，还有个很尴尬的地方在于，在开发人员进行接口调试的时候，一大段密文信息将会让调试非常困难。于是，所谓的的防止破解，更多的时候都在恶心开发者自己了。

用 HTTPS 证书就不会有这个问题了，在自己电脑安装完成证书后，就能在浏览器中明文调试了。

#### 会给服务器造成很大压力吗？

理论上，跟 HTTPS 单向的认证区别就在于多了一步验证客户端证书的过程，因此会多出 SSL 握手时的开销，具体我还没有压力测试过，但是我相信玩过 kubernetes 的应该会对此有个概念。

如果你预计会有比较大的流量，不放心，那就建议先找几台机器进行测试再决定也不迟。

#### 客户端证书不是也有泄露的风险吗？

确实如此，如果客户端会流落在他人手里，那么在不加一层保护的前提下，确实有可能会泄露，只是你有两种方案可以一起使用来保护证书：

1.  混淆客户端证书，让破解者无法通过简单的 `strings` 命令, 或者解压你的安装包就能获取到明文证书。另外，你也可以直接用 pkcs12 格式的证书，记得更换一个更强的密码；
2.  即使证书泄露，你还可以在服务器配置一个撤销证书列表，这样，被泄露的证书就没有权限来访问了；

#### 为何我对于客户端证书如此推崇？

我的理由主要有两点：

1.  有着广泛的支持，操作系统本身以及各种反向代理 Nginx、Apache，网络工具 curl、wget 以及各种语言等；
2.  加密通信是应该由通信协议本身来解决的问题，它应该与具体传输的内容解耦，所以它还能支持其它协议，比如 MQTT、AMQP 等等；

大多数没有选择客户端证书的，我认为是因为对它不够了解，或者说它的强大显得过于简单，导致很多人都没有什么安全感，尤其是领导没有什么安全感，但是请大家不妨想想现在有谁能够简单破解 HTTPS 请求内容呢？基于 RSA 加密的通信，是我们现代互联网的安全基础，没有谁能够轻易破解。

### 如何实现<sup>[2]、[3]</sup>

目前大部分方案都是拿 OpenSSL + Nginx 来举例的（随便搜索都是一大堆），那我就把 OpenSSL 换成更简单好用的 [CFSSL](https://github.com/cloudflare/cfssl) 。

#### 安装

多种方式可选，比如最简单的就是直接去下载已经编译好的工具：[cfssl/releases](https://github.com/cloudflare/cfssl/releases) 。

我目前使用的是 v1.5.0 版本的，大版本前提下，命令应该不会相差太多。

#### CA 证书

生成 CA 默认配置：

```bash
cfssl print-defaults config > ca-config.json
```

这里面的内容需要略加修改，下面给出一个我修改的例子，因为今天只需要客户端证书，因此 profiles 里面只留下了 client，`signing.default.expiry` 表示签发证书的默认过期时间，时间比较短，而另一个 `signing.profiles.client.expiry` 则比较长，8760h 就表示一年了。

```json
{
    "signing": {
        "default": {
            "expiry": "168h"
        },
        "profiles": {
            "client": {
                "expiry": "8760h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "client auth"
                ]
            }
        }
    }
}
```

然后是生成 CA 证书申请：

```bash
cfssl print-defaults csr > ca-csr.json
```

也需要根据自己的情况修改，这里需要注意下 key，v1.5.0 下面默认是 ecdsa-256 ，而我改成了 rsa-2048，只是为了说明方便，以及兼容性。

```json
{
    "CN": "Awesome Inc",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "ST": "Guangdong",
            "L": "Shenzhen",
            "O": "Awesome Inc",
            "OU": "Tech Dept"
        }
    ]
}
```

然后就可以生成 CA 证书了：

```bash
cfssl gencert -initca ca-csr.json | cfssljson -bare ca -
```

在当前目录下，会生成三个文件：

-   ca-key.pem CA 密钥
-   ca.csr CA 证书请求
-   ca.pem CA 证书

#### 客户端证书

接下来就开始生产客户端证书，与上面是类似的：

```bash
cfssl print-defaults csr > client.json
```

照例给出 client.json 的修改样例：

```json
{
    "CN": "xizhibei",
    "hosts": [""],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "ST": "Guangdong",
            "L": "Shenzhen",
            "O": "Awesome Inc",
            "OU": "Tech Dept"
        }
    ]
}
```

```bash
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=client client.json | cfssljson -bare client
```

命令行中会出现如下的日志：

    2021/02/03 15:21:09 [INFO] generate received request
    2021/02/03 15:21:09 [INFO] received CSR
    2021/02/03 15:21:09 [INFO] generating key: rsa-2048
    2021/02/03 15:21:10 [INFO] encoded CSR
    2021/02/03 15:21:10 [INFO] signed certificate with serial number 657128885698804019594922156238712961504332210277

然后生成了三个文件：

-   xizhibei-key.pem
-   xizhibei.csr
-   xizhibei.pem

#### 撤销证书

当证书发布出去后，在有效期之前，它是一直有效的，但是如果我们想让它提前失效（比如泄露的情况下），那么就需要用到撤销证书。

比如，我们要撤销上面刚刚生成的证书，需要先将序列号写入撤销证书序列号列表，然后来生成撤销证书：

```bash
echo 657128885698804019594922156238712961504332210277 >> crl-serials.txt
cfssl gencrl crl-serials.txt ca.pem ca-key.pem| base64 -D | openssl crl -inform DER -out ca-crl.pem
```

然后替换已有的撤销证书即可。

好了，到目前为止，证书部分基本上就搞定了，相对 OpenSSL 来说是不是很简单？

### 配置 Nginx

将上面生成的 `ca.pem` 以及 `ca-crl.pem` 放在 `/etc/nginx/certs/client_ca` 中，然后在 server 中如下配置（这里假设你已经开启了 HTTPS，并且配置好了服务端的证书）：

```conf
ssl_client_certificate /etc/nginx/certs/client_ca/ca.pem;
ssl_crl /etc/nginx/certs/client_ca/ca-crl.pem;
ssl_verify_client on;
```

更新 Nginx：

```bash
nginx -s reload
```

这里留给你一个思考题，为什么这里只需要配置一个 CA 证书就可以了？

#### 客户端证书的安装

如果你在配置好 nginx 后，直接用浏览器请求网站，那么你就会看到一个 HTTP 400 错误，告诉你需要提供证书。

![nginx 400 bad request](https://blog.xizhibei.me/media/16120752577354/16123454428511.jpg)

本地安装证书很简单，直接鼠标双击证书就能够安装，如果是 Mac，记得在 Keychain 中配置始终信任。

另外，为了方便发送证书给他人使用，建议打包成 `pkcs12` 格式的证书，还能设置密码。

```bash
openssl pkcs12 -export -clcerts \
    -CApath . -inkey xizhibei-key.pem -in xizhibei.pem \
    -certfile ca.pem -passout pass:strong-password -out xizhibei.p12
```

### Ref

1.  [Transport Layer Security][1]
2.  [Generate self-signed certificates][2]
3.  [kubernetes-the-hard-way][3]

[1]: https://en.wikipedia.org/wiki/Transport_Layer_Security#Client-authenticated_TLS_handshake

[2]: https://coreos.com/os/docs/latest/generate-self-signed-certificates.html

[3]: https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/159 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
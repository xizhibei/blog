---
title: 如何实现一个安全的 SaaS/PaaS 服务
date: 2019-09-23 21:45:38
tags: [Golang,业务,安全,总结,系统设计]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/121
---
<!-- en_title: how-to-impl-a-secure-saas-paas-service -->

这篇文章是接着上篇 [SSL 界中 Linux：Let's Encrypt](https://github.com/xizhibei/blog/issues/120) 写的。（是的，这周灵感不够 🙈 ）

### 功能

上次说到，如果我们实现的 SaaS/SaaS 服务中的客户需要自定义域名，我们需要给客户提供相应的功能。这个功能大致如何运作？

1.  客户在 DNS 解析中，设置 CNAME 到我们给他提供的唯一子域名上 **（注意，之后客户可以直接通过这个域名来访问我们的服务）**；
2.  等待一定时间，让 DNS 记录生效，客户配置自定义域名，提交到我们的服务中；
3.  服务开始验证域名是否解析成功，返回是否成功设置；
4.  则告知客户结果，若成功我们需要等待几个小时甚至一两天来配置 HTTPS 证书，期间可以改成 HTTP 访问，或者还是使用我们提供的子域名访问，不成功则告知需要重新设置；
5.  后端任务服务器开始排队生成 HTTPS 证书；
6.  生成成功后，部署到相应的负载均衡器或者 Web 服务器中，取决于你们如何部署 HTTPS 证书；
7.  通知客户证书部署成功，并且每过 60 天就需要更新证书；

因此，我们需要的功能，最关键的地方在于证书的获取以及部署，部署不用多说，我们一般部署在负载均衡器中，性能会比部署在 Web 服务中要好很多，而如果是云服务的负载均衡器的话，也可以通过相应的 API 去部署。

### 获取实现

接下来以 Golang 的 Web 服务来说明，我们用 [lego](https://github.com/go-acme/lego) 来实现。

首先让我们把 lego 文档上的代码抄过来，限于篇幅，删掉一些注释，以及修改一些代码：

```go
package main

import (
	"crypto"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"fmt"
	"log"

	"github.com/go-acme/lego/v3/certcrypto"
	"github.com/go-acme/lego/v3/certificate"
	"github.com/go-acme/lego/v3/challenge/http01"
	"github.com/go-acme/lego/v3/challenge/tlsalpn01"
	"github.com/go-acme/lego/v3/lego"
	"github.com/go-acme/lego/v3/registration"
)

// MyUser 实现 acme.User
type MyUser struct {
	Email        string
	Registration *registration.Resource
	key          crypto.PrivateKey
}

func (u *MyUser) GetEmail() string {
	return u.Email
}
func (u MyUser) GetRegistration() *registration.Resource {
	return u.Registration
}
func (u *MyUser) GetPrivateKey() crypto.PrivateKey {
	return u.key
}

func main() {
	privateKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		log.Fatal(err)
	}

	myUser := MyUser{
		Email: "you@yours.com",
		key:   privateKey,
	}

	config := lego.NewConfig(&myUser)
    // 用 Staging 服务器，在正式环境中再修改成正式服务器的
	config.CADirURL = lego.LEDirectoryStaging
	config.Certificate.KeyType = certcrypto.RSA2048

	client, err := lego.NewClient(config)
	if err != nil {
		log.Fatal(err)
	}

  // HTTP-01 验证
	err = client.Challenge.SetHTTP01Provider(http01.NewProviderServer("", "5002"))
	if err != nil {
		log.Fatal(err)
	}
	
  // TLSALPN-01 验证
	err = client.Challenge.SetTLSALPN01Provider(tlsalpn01.NewProviderServer("", "5001"))
	if err != nil {
		log.Fatal(err)
	}

	// New users will need to register
	reg, err := client.Registration.Register(registration.RegisterOptions{TermsOfServiceAgreed: true})
	if err != nil {
		log.Fatal(err)
	}
	myUser.Registration = reg

	request := certificate.ObtainRequest{
		Domains: []string{"mydomain.com"},
		Bundle:  true,
	}
	certificates, err := client.Certificate.Obtain(request)
	if err != nil {
		log.Fatal(err)
	}

	// 存入文件系统，或者数据库
	fmt.Printf("%#v\n", certificates)
}
```

这个例子足够我们进行下一步工作了。

### 如何与 SaaS/PaaS 服务结合

我们看到这个例子中：

1.  使用 `HTTP-01` 以及 `TLSALPN-01` 来实现的，考虑到 SaaS/PaaS 服务中，我们无法控制客户的 DNS，因此只能用这两者来实现；
2.  我们的 Web 服务实例放在负载均衡后面，并且不止一个，因此不能用例子中默认的内置服务器来实现这个功能；
3.  `TLSALPN-01` 在云服务中，需要跟负载均衡器打交道，会比较麻烦，为了方便有效地实现，我们选用 `HTTP-01`；

那么，我们的问题就简化为：如何在我们的 Web 服务中，实现 `HTTP-01`。

我在[前面](https://github.com/xizhibei/blog/issues/120)说过，Let's Encrypt 在 `HTTP-01` 中会返回 `token` 与 `KeyAuth` 给你，然后通过 HTTP 请求来验证你是否在控制这个域名，那么，在我们房子负载均衡后面的 Web 服务中，我们如何去响应 LE 的请求？

**很简单，放在数据库中**，更具体点，那就是放在缓存（比如 Redis、Memcache）中，因为可以不用管过期删除的问题。

相对应的，我们可以通过 lego 的 Challenge Solver interface 来实现我们的 Solver：

```go
type Provider interface {
	Present(domain, token, keyAuth string) error // 存储
	CleanUp(domain, token, keyAuth string) error // 清理
}
```

我们用缓存实现 Preset，比如就把 `keyAuth` 存入 `'lego' + domain + token` 对应的 key 中，然后等待 LE 访问 `/.well-known/acme-challenge/:token` 这个接口，返回 keyAuth 即可。

获取证书后，记得先把存入数据库，再部署至负载均衡器，并且还要周期性地更新证书。

最后，如果你的客户量比较多，记得要向 LE 申请配额，不然会超过频率限制，这点很容易忘，而且你需要考虑申请通过的时间，不会太快。

### P.S.

其实 Lego 内置了 [Memcache 的 Solver](https://github.com/go-acme/lego/blob/master/providers/http/memcached/memcached.go)。


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/121 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
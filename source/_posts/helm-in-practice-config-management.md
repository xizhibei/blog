---
title: Helm 实践之配置管理
date: 2018-10-27 19:49:55
tags: [DevOps,Helm,kubernetes, 配置]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/90
---
<!-- en_title: helm-in-practice-config-management -->

这是 Helm 系列的第二篇，今天来说说与它相关的应用配置管理的实践。

<!-- more -->

### 说在前面
在我们开发项目的管理中，应用配置的管理一直是个问题，我曾经也讨论过挺多次（[谈谈项目的配置管理](https://github.com/xizhibei/blog/issues/27) [应用配置管理实践](https://github.com/xizhibei/blog/issues/41) 以及 [应用配置的几个原则](https://github.com/xizhibei/blog/issues/56)），而在 Helm 中，也面临着这样的问题。

在实践中，我们的应用配置一般是放在文件中的，也有配置可能是放在数据库中的，在团队比较小的时候可以用文件存储，而团队大了之后可以放在专门的配置数据库，甚至配置中心去。

显然，对于现在的我们，将配置放在文件中，然后放在 Git 中管理是比较方便的方式。假如你也采用了这种方式的，为了安全，一般推荐采用与代码分开存放或者加密配置的方式，但即使是分开存放，也最好进行加密，只有与项目相关的重要人员才拥有密钥。

这里插一句，还记得前阵子华住数据库泄露的事件？就是因为没有分开存放代码与配置，更没有进行加密存储，类似的案例还是不少的，都逼得 Github 开发密钥检测功能了。

因此，假如你是一个项目的负责人，最好一开始就做好准备，不要等到项目的配置被泄露才想到要加密配置：** 避免出问题的最好的方式就是一开始就做好（破窗理论）**。这点对于项目的单元测试代码以及 lint 规则也是适用的。

### helm-secrets & sops
回到正题，对于 Helm 来说，有个插件是比较好用 [helm-secrets](https://github.com/futuresimple/helm-secrets)，对于使用文件管理应用配置的可以考虑，因为它提供的加密功能挺好用，而且安全性也有的保证，在 Helm 中，我们可以将 secrets values 加密后放在 Git 项目中，至于是不是分开存放，由你自由选择了。

另外，需要了解下，这个插件依赖的是 [sops](https://github.com/mozilla/sops) 这个工具，helm-secrets 只是帮我们做了封装（是的，也就是说它可以支持 Helm 之外的应用配置加密管理）。

实际上，它只是一个编辑器，或者说配置文件加密管理工具也行，只是目前它只支持 AWS KMS, GCP KMS, Azure Key Vault 等外国云服务商的服务，于是我们只能选的用它支持的 PGP 加密。

### 例子
下面，我们来简单做一个例子，来体会下它的便捷：

#### 安装
下面以 Mac 环境为例，其它环境对不住了，靠你们自己了 :P。
```bash
# 安装依赖
brew install sops gpg
```

```bash
# 安装插件
helm plugin install https://github.com/futuresimple/helm-secrets
```

#### GPG key
然后需要生成一个可用的 GPG key，已有的话可以跳过，建议不要用私人的，毕竟之后你部署的时候也需要用到。具体生成 key 的步骤可以看 Github 的教程 [Generating a new GPG key](https://help.github.com/articles/generating-a-new-gpg-key/)。

然后提取下 Finger print，以我的 GPG key 为例：

```bash
$ gpg --list-keys xuzhipei@gmail.com
pub   rsa4096 2015-11-19 [SC] [expires: 2019-11-19]
      21ADFF583EF7B147FD54FD9D84DF33FBB8950468
uid           [ultimate] Zhipei Xu <xuzhipei@gmail.com>
sub   rsa4096 2015-11-19 [E] [expires: 2019-11-19]
```

`21ADFF583EF7B147FD54FD9D84DF33FBB8950468` 便是 Finger print。

#### 准备 .sops.yaml
在 Git repo 的根目录下，创建 .sops.yaml 这个文件：

```yaml
---
creation_rules:
  - pgp: 21ADFF583EF7B147FD54FD9D84DF33FBB8950468
```

其中的 Finger print 替换为你自己的。

#### 加密文件
创建一个 secrets.yaml 文件，在其中添加一些需要加密的配置，然后

```bash
helm secects enc secrets.yaml 
```

然后，你就会发现这个文件的内容被加密过了。

假如需要编辑的话：

```bash
helm secects edit secrets.yaml 
```

#### 与 Git diff 结合使用
在我们修改了密钥文件之后，每次提交实际的 comiit diff 是一堆密文，显然不方便查看变动，更不适合代码审阅，于是可以这么做：

```
$ git config diff.sopsdiffer.textconv "sops -d"
```

然后在项目的根目录创建一个 .gitattributes 文件，内容为：
```
*.yaml diff=sopsdiffer
```

之后用 `git diff` 查看的时候，就能看到明文对比了。

#### 部署时自动解密
helm-secrets 为了能让你在部署到 k8s 的时候，能够读自动读到明文，对 Helm 进行了简单的封装：把 helm 替换为 helm-wrapper 即可。

于是，这样的部署代码：

```bash
helm secrets dec secrets.yaml
helm install -n test -f secrets.yaml
```

就可以改为简单的：

```bash
helm-wrapper install -n test -f secrets.yaml
```

好了，例子就到这，其它更多功能需要你自己去摸索了，比如 sops 还有更多高级功能，又比如你用的正好是那几个云服务商之一，你就可以探索下如何用他们的工具来用了。

### P.S.
最近辞职了，也换了城市，开始学一些全新的知识，体会到了跳出舒适区的感觉，毕竟这种机会不是经常有。

我们经常说做事或创业应该从 MVP 做起，其实学习也类似，从一个非常简单的例子开始学，当第一次尝到甜头之后就会给之后你的进一步学习带来不少的信心，这也是今天这篇文章的思路，我尝试用简单的例子来告诉你这个工具是多么好用，而之后的内容就需要你自己去摸索了，毕竟不能抢走你学习与探索的乐趣。

***
首发于 Github issues: https://github.com/xizhibei/blog/issues/90 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
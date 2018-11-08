---
title: Helm 实践之持续交付
date: 2018-11-03 20:42:57
tags: [DevOps,Docker,Gitlab,Helm,kubernetes, 总结]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/91
---
<!-- en_title: helm-in-practice-continue-delivery -->

这是 Helm 系列的第三篇，在前两篇中，我介绍了 Helm 的 [入门](https://github.com/xizhibei/blog/issues/89) 以及 [配置实践](https://github.com/xizhibei/blog/issues/90)，而今天我们来说说 Helm 持续发布的实践。

<!-- more -->

其实继续之前可以稍稍复习下，参看我之前关于持续交付的文章 [持续交付的实践与思考](https://github.com/xizhibei/blog/issues/42)。

好了，接下来我主要以 Gitlab CI 为例来说明，需要你有一定的 Gitlab CI 基础，或者先看看这几篇文章也行：

- [Gitlab 的部署与维护](https://github.com/xizhibei/blog/issues/61)
- [CI 系统搭建](https://github.com/xizhibei/blog/issues/26)
- [GitLab CI/CD Variables](https://docs.gitlab.com/ee/ci/variables/)

### 准备工作

#### Git 项目
你需要按照我在入门篇中描述的，把你所需要的这个 Chart 用 Git 管理，同时按照配置管理的做法，将 secrets values 使用 PGP 管理（用云服务提供的密钥管理其实也是类似的）。

#### 部署镜像
这个镜像中安装好 kubectl，helm，helm-secrets，sops 等，这样，你就不用每次都需要重新安装了。

当然，你也可以直接用我的，修改下涉及到的版本号即可，而在国内可能需要翻墙，设置下 http_proxy 以及 https_proxy 即可。

```Dockerfile
FROM alpine:3.7

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories \
  && apk update --no-cache \
  && apk add --no-cache bash curl wget gnupg openssh-client bash gettext git

ARG KUBECTL_VERSION=1.9.3
RUN wget --no-check-certificate -O /usr/local/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl \
  && chmod +x /usr/local/bin/kubectl

ARG HELM_VERSION=2.9.1
RUN wget --no-check-certificate https://storage.googleapis.com/kubernetes-helm/helm-v$HELM_VERSION-linux-amd64.tar.gz \
  && tar -xf helm-v$HELM_VERSION-linux-amd64.tar.gz \
  && mv linux-amd64/helm /usr/local/bin \
  && rm helm-v$HELM_VERSION-linux-amd64.tar.gz \
  && rm -r linux-amd64 \
  && helm init --client-only

ARG SOPS_VERSION=3.0.5
RUN wget --no-check-certificate -O /usr/local/bin/sops https://github.com/mozilla/sops/releases/download/$SOPS_VERSION/sops-$SOPS_VERSION.linux \
  && chmod +x /usr/local/bin/sops \
  && helm plugin install https://github.com/futuresimple/helm-secrets
```

然后编译镜像后推到镜像服务中心即可：

```bash
$ docker build . -t registry.example.com/your-custom-helm-image
$ docker push registry.example.com/your-custom-helm-image
```

### 完整流程

现在我们开始用一个比较完整的例子来说明，会介绍得比较快，请系好安全带 🙈。

0、我们的需要部署项目的结构大致如下：

```
app/
    ...
deploy/
    chart/
        ...
    vars/production/values.yaml
    vars/production/secrets.yaml
    ...
    deploy-k8s.sh
Dockerfile
.sops.yaml
.gitlab-ci.yaml
```

1、 导出 PGP 密钥的私钥，先确认需要导出的 key 的 ID：

```bash
$ gpg --list-secret-keys
```

然后导出：

```bash
$ gpg --export-secret-keys your-gpg-id > private.asc
```

2、将私钥（private.asc 的内容）添加到 CI&CD pipeline Variables，名称可以定为 `PGP_KEYS`。

3、同时，你需要一个类似如下的部署脚本，在部署阶段运行：

```bash
# Usage: ./deploy-k8s.sh tag-name
helm-wrapper upgrade --install your-app-release-name \
    --namespace your-space \
    -f ./deploy/vars/production/values.yaml \
    -f ./deploy/vars/production/secrets.yaml \
    --set image.tag=$1 \
    --wait \
    ./deploy/chart
```

4、准备 Gitlab CI 的配置，以下是部分可参考内容：

```yaml
deploy:
  stage: deploy
  image: registry.example.com/your-custom-helm-image:latest
  before_script:
    # 在 Pipeline Variables 中配置 PGP_KEYS 为导出的 PGP 私钥
    # 理想情况下，每个 git 项目应该用不同的密钥
    - echo "$PGP_KEYS" | gpg --import
  script:
    - ./deploy/deploy-k8s.sh $CI_COMMIT_REF_SLUG
  environment:
    name: production
  when: manual # 手动发布
  only:
    - tags # 只发布打了 tag 的 commit
```

5、提交，测试没问题后创建一个 tag 就可以手工点击发布了。

### P.S.
最后介绍一个项目：[weaveworks/flux](https://github.com/weaveworks/flux)，既所谓的 GitOps，其实就是帮你自动化部署在 Git 中管理的 helm chart，在上面说的的实践中，我们都是需要手工去 CI&CD 中配置这个部署系统的，而这个工具可以进一步节约你的工作量（不过也需要折腾），有兴趣可以了解下。

### P.P.S
Helm 系列的三篇文章写完了，算是写博客以来第一个系列，比较粗糙，也没有完整规划过，就算是个简单的总结了，总之，希望能对你有用。

***
首发于 Github issues: https://github.com/xizhibei/blog/issues/91 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
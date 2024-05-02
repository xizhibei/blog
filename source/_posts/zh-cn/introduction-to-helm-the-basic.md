---
title: Helm 入门之基础
date: 2018-10-20 19:30:08
tags: [DevOps,Golang,Helm,kubernetes]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/89
---
<!-- en_title: introduction-to-helm-the-basic -->

Helm 最近是越来越得到大家的认可了，其实一年之前我们团队就开始用了，而今天我是想把这个工具的使用经验总结下。

<!-- more -->

Kubernetes 上手一段时候，就会发现他的资源描述文件的管理是个问题，很容易有过多相似的文件，这时候可能就会有做成同一份模板加不同环境的输入参数的想法，可惜 kubectl 不支持。

而在这之前，我们也试过其它的模板系统，比如 [ktmpl](https://github.com/jimmycuadra/ktmpl)，这些小工具的特点就是上手挺快，只是如果要其它比较高级的功能的话（如模板渲染的流程控制，依赖管理等），只能自己去开发了。

在上手 Helm 之前，有一段时间觉得这个工具不怎么好用，因为需要学挺多东西，还得以 **Chart** 的方式管理各个项目，不过一旦上手后，就会发现用它管理 k8s 上的部署还是非常方便的，功能挺强大，而且放在 Git 中管理起来也非常方便。

好，下面开始讲重点，需要你有点基础，最好先去看一遍[官方文档](https://docs.helm.sh)，因为我不会说的很仔细，会挑选点比较重要的说说，毕竟再仔细也不能比得过官方的文档。

### 基础概念

-   Helm：客户端，主要负责管理本地的 Charts、repositories 以及与服务端通信，；
-   Tiller：安装在 k8s 集群中的服务端，是实际用来管理安装在 k8s 中应用的，就是将模板与 values 合并，当然实际开发过程中，[也可以安装在 k8s 集群之外](https://docs.helm.sh/using_helm/#installing-tiller)；
-   Chart：是用来管理模板与默认 values 的项目，也可以认为是一个 package，可以发布到专门的 repository；

### 安装 & 初始化

```bash
helm init
```

这个命令会在本地初始化配置，同时在远程 k8s 上的 kube-system 中安装服务端应用，也就是 Tiller 。

这里有三个参数需要注意下：

-   \--client-only：也就是不安装服务端应用，这在 CI&CD 中可能需要，因为通常你已经在 k8s 集群中安装好应用了，这时只需初始化 helm 客户端即可；
-   \--history-max：最大历史，当你用 helm 安装应用的时候，helm 会在所在的 namespace 中创建一份安装记录，随着更新次数增加，这份记录会越来越多；
-   \--tiller-namespace：默认是 kube-system，你也可以设置为其它 namespace；

### Charts

可以将它简单与 npm 对比下

    npm          <====> helm
    node modules  <====> charts
    registry     <====> repository
    package.json <====> requirements.yaml

这样，是不是能快一点理解？那么，接下来就是如何开发 Chart 了，最重要的肯定是模板了。

### 模板

由于是用 Golang 开发的，使用的也是 Go 的模板语法，举个简单的例子：

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
data:
  myvalue: {{ .Values.config }}
```

这个模板，用到了 Release 以及 Values 这两个内置变量，因此当用 Helm 安装到 k8s 中的时候，Tiller 会将模板中的变量渲染成 k8s 可用的 yaml 文本。

其它内置变量看[这里](https://docs.helm.sh/chart_template_guide#built-in-objects)。

另外，就是 values 文件了，它最大的特点就在于可以**覆盖**，举例来说，假如你运行的命令是：

```bash
helm install -n test ./mychart -f values1.yaml -f values2.yaml
```

那么，values2 中的值就会覆盖 value1 中同名 key 的值，利用这一点，就可以用不同的 values 文件区分出不同的环境。

假如你分别在云服务商的两个可用区内，有两个类似的 k8s 集群（比如双活架构），那么，同一个应用在两边部署的时候，就可以采取如下类似的文件目录了：

    common.yaml # zone-a 与 zone-b 共享
    zone-a/
        front-app.yaml
        backend-api.yaml
        worker.yaml
    zone-b/
        front-app.yaml
        backend-api.yaml
        worker.yaml

然后，在不同的环境中，用不同的 values 文件即可，而其中 common.yaml 便可以在不同环境中共享一些 values。

```bash
helm install -n test ./mychart -f common.yaml -f zone-a/font-app.yaml
```

另外，如果需要将文件配置放到 k8s 的 Secrets 中，可以这么做：

```yaml
{{- $fullName := include "chart.fullname" . -}}
apiVersion: v1
kind: Secret
metadata:
  name: {{ $fullName }}
  labels:
    app: {{ template "chart.name" . }}
    chart: {{ template "chart.chart" . }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
data:
{{ (.Files.Glob "bar/*").AsSecrets | indent 2 }}
```

### [几个小技巧](https://docs.helm.sh/developing_charts/#chart-development-tips-and-tricks)

#### Image pull credentials

有些时候，Docker 镜像可能需要用户名与密码去 registry 拉取，那么，你就需要专门为此创建一个模板了。

比如 value 是：

```yaml
imageCredentials:
  registry: quay.io
  username: someone
  password: sillyness
```

而模板就是：

    {{- define "imagePullSecret" }}
    {{- printf "{\"auths\": {\"%s\": {\"auth\": \"%s\"}}}" .Values.imageCredentials.registry (printf "%s:%s" .Values.imageCredentials.username .Values.imageCredentials.password | b64enc) | b64enc }}
    {{- end }}

当然，需要注意多个 Deployment 共享一个 Chart 的情况，这时候可能会出现 secrets 冲突的情况，可考虑单为此单独创建一个 Config Chart，然后作为 App Chart 的依赖。

#### 配置更新后 Pod 自动重启

利用 k8s 的 Deployment 更改后的自动更新[1]，我们可以用来更新应用配置，简单说就是更新 Secrets 或 ConfigMaps 后，计算它的最新 hash 值，然后将这个 hash 值 patch 到相应的 Deployment 中。

```yaml
kind: Deployment
spec:
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
[...]
```

这样，假如这个配置有问题，比如造成应用崩溃了，k8s 也会认为新的 ReplicaSet 失败了，不会将流量导过去，从而不继续滚动更新，避免了了由配置更新导致的应用崩溃问题。

### P.S.

这篇文章可以看看：[draft-vs-gitkube-vs-helm-vs-ksonnet-vs-metaparticle-vs-skaffold](https://blog.hasura.io/draft-vs-gitkube-vs-helm-vs-ksonnet-vs-metaparticle-vs-skaffold-f5aa9561f948)

主要讲的是 helm 与其它工具的对比，比如 draft 可以帮你快速初始化一个对应开发语言的 helm Chart，而 ksonnet 与 Helm 非常类似，可重点看看；

另外，我接下来还尝试把 Helm 写成一个系列，会细讲我们是如何实践这个工具的，比如应用配置管理，与 CI&CD 集成等，敬请期待。

### Ref

1.  <https://stackoverflow.com/questions/37317003/restart-pods-when-configmap-updates-in-kubernetes>


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/89 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
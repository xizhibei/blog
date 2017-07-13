---
title: k8s Ingress 实践
date: 2017-06-10 16:06:41
tags: [kubernetes]
author: xizhibei
---
一般来说，我们从外部访问 k8s 里面的应用，有以下种方式：

1. Ingress：有些云服务商有提供，自己也能安装自己的 ingress controller；
2. Service NodePort：在 Node 上暴露一个 30000-32767 的端口，可以通过 NodeIp:NodePort 的方式访问；
3. Service LoadBalancer：取决于云服务商，目前似乎只有 AWS、GCE 以及国内的阿里云有提供；
4. Kubectl Proxy：通过本地执行 `kubectl proxy`，然后访问 http://localhost:8001/api/v1/proxy/namespaces/namespace/services/service-name 即可；
5. Kubectl Port-forward，与 Proxy 类似，测试可以，正式环境就不用考虑了；

显然，在一个云服务商不支持的环境下，ingress 是我们最佳的选择。

### 概念
> Ingress 是允许外部可以从集群内部的相关服务的一系列规则。

用 Ingress，你可以定义一些列的转发规则，具体的实现是由 Ingress controller 完成，一般是 Nginx 或者 HAProxy。

其它的细节，不妨看看官方文档。

另外，对于 Ingress controller，这个项目里面的介绍也可以参考：https://github.com/kubernetes/ingress 。

### 部署 Ingress controller
由于 Ingress controller 属于集群的基础服务，我们想要它随着 Node 的启动之后，首先启动，因此 DaemonSet 最合适。

接下来搬运下代码：

```yml
# https://github.com/kubernetes/ingress/blob/master/examples/daemonset/nginx/nginx-ingress-daemonset.yaml
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: nginx-ingress-lb
  labels:
    name: nginx-ingress-lb
  namespace: kube-system
spec:
  template:
    metadata:
      labels:
        name: nginx-ingress-lb
      annotations:
        prometheus.io/port: '10254'
        prometheus.io/scrape: 'true'
    spec:
      terminationGracePeriodSeconds: 60
      containers:
      - image: gcr.io/google_containers/nginx-ingress-controller:0.9.0-beta.7
        name: nginx-ingress-lb
        readinessProbe:
          httpGet:
            path: /healthz
            port: 10254
            scheme: HTTP
        livenessProbe:
          httpGet:
            path: /healthz
            port: 10254
            scheme: HTTP
          initialDelaySeconds: 10
          timeoutSeconds: 1
        ports:
        - containerPort: 80
          hostPort: 80
        - containerPort: 443
          hostPort: 443
        env:
          - name: POD_NAME
            valueFrom:
              fieldRef:
                fieldPath: metadata.name
          - name: POD_NAMESPACE
            valueFrom:
              fieldRef:
                fieldPath: metadata.namespace
        args:
        - /nginx-ingress-controller
        - --default-backend-service=$(POD_NAMESPACE)/default-http-backend
```

### P.S.
1. 由于声明了 `hostPort`，各个 Node 的相关端口不能被占用；
2. 默认情况下，如果提供了默认 https 证书，则会将 80 端口转发至 443 端口，可以通过在创建 Ingress 时，设置 metadata 的配置：`ngress.kubernetes.io/ssl-redirect: "false"`，或者 为 Ingress 提供全局 ConfigMap 配置：`ssl-redirect: false`;
3. 由于 Ingress 目前还是处于测试阶段，生产环境的测试还不一定能完全放心地上，因此可以先在 staging 环境使用，这时候可以考虑 [goreplay](https://github.com/buger/goreplay) 之类的工具去复制线上的流量去测试。

### Ref
1. https://kubernetes.io/docs/concepts/services-networking/ingress/
2. https://kubernetes.io/docs/concepts/services-networking/service/


***
原链接: https://github.com/xizhibei/blog/issues/50

![知识共享许可协议](https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png "署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）")

本文采用 [署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh) 进行许可。

---
title: 在 k8s 中部署 Prometheus
date: 2017-08-19 21:21:59
tags: [DevOps,Prometheus,kubernetes, 沟通]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/55
---
<!-- en_title: deploy-prometheus-in-k8s -->

自从 [上次](https://github.com/xizhibei/blog/issues/54) 介绍了 Prometheus 之后，就想到要在 k8s 中使用了，不过，在这之前，先介绍下 k8s 的监控。

### k8s 的监控
k8s 默认以及推荐的监控体系是它自己的一套东西：Heapster + cAdvisor + Influxdb + Grafana，具体可以看 [这里](https://kubernetes.io/docs/tasks/debug-application-cluster/resource-usage-monitoring/) 。

包括 k8s 自身的 HPA (Horizontal Pod Autoscaler)，默认从 Heapster 中获取数据进行自动伸缩。（顺便提一句，当你部署完 k8s 集群之后，如果从 Dashboard 中看不到监控数据，往往就是因为你没有部署 Heapster，或者网络层有问题， Dashboard 无法访问 Heapster。）

那，这跟我们介绍的 Prometheus 有什么关系？

首先，它们都是一套监控解决方案，而 k8s 没有把 Prometheus 作为默认监控，因此，如果你想直接使用 HPA，你还是需要部署 Heapster。

其次，kubelet 中的 cAdvisor 其实是支持 Prometheus 作为存储的后端的，只是相对于 Prometheus 自己的 SD 解决方案来说，太弱了点。

最后，k8s 1.6 之后，在 annotations  中配置 custom metrics 的方式已经被移除了，而根据
 Prometheus 的监控数据来进行自动伸缩还是很有可操作性的。

### 部署

其实部署很简单，关键是配置，因此这里着重介绍下，如何配置。

#### Relabel
首先，先来了解下，什么是 [relabel_config](https://prometheus.io/docs/operating/configuration/#relabel_config)。

就如字面意思而言，它的作用是 Prometheus 抓取 metrics 之前，就将对象相关的 labels 重写。下面是它几个重要的 label：

- \_\_address\_\_：默认为 host:port，也是之后抓取之后 instance 的值；
- \_\_scheme\_\_：http or https ？；
- \_\_metrics\_path\_\_：就是 metrics path，默认为 **/metrics**；
- \_\_param\_${name}：用来作为 URL parameter，比如 **http://.../metrics?name=value**；
- \_\_meta\_：这个开头的配置都是 SD 相关的配置；

#### Kubernetes SD
其次，上次提到，我们可以用到 Service Discovery 这个功能，其中就包含 [Kubernetes SD](https://prometheus.io/docs/operating/configuration/#<kubernetes_sd_config>)。

它包含四种角色：

- node
- service
- pod
- endpoints

由于篇幅所限，这里只是简单介绍下其中的 node 还有 pod 角色：

```yml
- job_name: 'kubernetes-nodes'
  scheme: https
  tls_config:
    ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
  bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
  
  kubernetes_sd_configs:
  - role: node
  
  relabel_configs:
    # 即从 __meta_kubernetes_node_label_<labelname> 这个配置中取出 labelname 以及 value
  - action: labelmap
    regex: __meta_kubernetes_node_label_(.+)
    
    # 配置 address 为 k8s api 的地址，相关的 ca 证书以及 token 在上面配置
  - target_label: __address__
    replacement: kubernetes.default.svc:443
    
    # 取出所有的 node，然后设置 /api/v1/nodes/<node_name>/proxy/metrics 为 metrics path
  - source_labels: 
    - __meta_kubernetes_node_name
    regex: (.+)
    target_label: __metrics_path__
    replacement: /api/v1/nodes/${1}/proxy/metrics
```
接下来的这个 pod 角色挺重要：

```yml
- job_name: 'kubernetes-pods'

  kubernetes_sd_configs:
  - role: pod

  relabel_configs:
  - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
    action: keep
    regex: true
  - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
    action: replace
    target_label: __metrics_path__
    regex: (.+)
  - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
    action: replace
    regex: ([^:]+)(?::\d+)?;(\d+)
    replacement: $1:$2
    target_label: __address__
  - action: labelmap
    regex: __meta_kubernetes_pod_label_(.+)
  - source_labels: [__meta_kubernetes_namespace]
    action: replace
    target_label: kubernetes_namespace
  - source_labels: [__meta_kubernetes_pod_name]
    action: replace
    target_label: kubernetes_pod_name
```
在定义了这个角色之后，你只要在你部署的应用 Pod 描述中，加入以下 annotations 就能让 Prometheus 自动发现此 Pod 并采集监控数据了：

```yml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "<your app port>"
```

其它详细配置请看 [这里](https://github.com/prometheus/prometheus/blob/master/documentation/examples/prometheus-kubernetes.yml)。

### Kubernetes Deployment
最后，部署 Prometheus，需要注意的是，我们已经在 k8s 之外单独部署了一套，为了统一处理，在这里是打算作为中转的。

```yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus
  namespace: kube-system
  labels:
    app: prometheus
data:
  prometheus.yml: |-
  # 省略，在这里定义你需要的配置
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: prometheus
  namespace: kube-system
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        args:
          - '-config.file=/prometheus-data/prometheus.yml'
          # 显然，这里没有用 `Stateful Sets`，存储时间不用太长
          - '-storage.local.retention=48h0m0s'
        ports:
        - name: prometheus
          containerPort: 9090
        volumeMounts:
        - name: data-volume
          mountPath: /prometheus-data
      volumes:
      - name: data-volume
        configMap:
          name: prometheus
---
# 简单处理，直接使用 NodePort 暴露服务，你也可以使用 Ingress
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: kube-system
spec:
  selector:
    app: prometheus
  ports:
  - name: prometheus
    protocol: TCP
    port: 9090
    nodePort: 30090
  type: NodePort
```

#### Prometheus Federate
而在我们外部单独的 Prometheus 中，需要配置 [Federate](https://prometheus.io/docs/operating/federation/)，将 k8s 中 Prometheus 采集的 metrics 全部同步出来。

```yml
  - job_name: 'federate'
    scrape_interval: 15s

    honor_labels: true
    metrics_path: '/federate'

    params:
      'match[]':
        - '{job=~".+"}' # 取 k8s 里面部署的  Prometheus 中所有的 job 数据

    static_configs:
      - targets:
        - '<k8s-node1>:30090'
        - '<k8s-node2>:30090'
        - '<k8s-node3>:30090'
```



***
首发于 Github issues: https://github.com/xizhibei/blog/issues/55 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
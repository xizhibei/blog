---
title: 【PLG 系列】（二）部署实战：从配置到日志查询
date: 2024-08-22 10:00:15
categories: [可观测性工程]
tags: [PLG Stack, 日志监控, Loki, Grafana, Docker, 可观测性, LogQL]
author: xizhibei
---

上次在[Loki 生态系统入门指南](/zh-cn/2024/07/08/plg-1-introducation/)中提到有实际的例子可以用来体验，这次就继续详细讲解下这个例子：[Getting Started](https://github.com/grafana/loki/tree/0ee2a6126ae40a1d666f500c19efd639763f1bae/examples/getting-started)

<!-- more -->

## Docker 环境配置

如果你使用的是 Linux 环境并且在国内，建议按照这篇文章[如何解决 Docker 镜像无法拉取的问题](/zh-cn/2024/07/10/how-to-fix-docker-pull-in-cn/)的内容进行「科学处理」。

## 快速部署与配置

你需要将目录中的三个 `yaml` 文件（docker-compose.yml, loki-config.yaml, alloy-local-config.yaml）直接下载到本地，然后放到一个专门的文件夹，比如 `loki-test`。接下来，直接启动即可：

```bash
docker compose up -d
```

成功启动后，你会看到类似下面的输出：

```bash
 ✔ Network loki-test_loki         Created     0.1s
 ✔ Container loki-test-flog-1     Started     0.4s
 ✔ Container loki-test-minio-1    Started     0.5s
 ✔ Container loki-test-write-1    Started     0.7s
 ✔ Container loki-test-read-1     Started     0.8s
 ✔ Container loki-test-gateway-1  Started     1.0s
 ✔ Container loki-test-alloy-1    Started     1.4s
 ✔ Container loki-test-backend-1  Started     1.4s
 ✔ Container loki-test-grafana-1  Started     1.3s
```

然后打开 `http://localhost:3000`，使用默认的用户名和密码 `admin` 登录。新版本可能会要求你修改密码，如果你只是本地测试，可以选择跳过。登录后，你就可以看到 Grafana 的界面了。选择左边侧栏的 Explore，然后选择 Loki 数据源，就可以开始使用了。

注意：Loki 的默认数据源是 `http://loki:3100`。如果你的 Loki 在另外的机器上，或者 Loki 的端口不是 3100，那么需要修改数据源的配置。

![Grafana界面](media/17205193921030/17205194433405.jpg)

接下来，你需要学习一些基础知识，比如 LogQL。让我们用一个例子来简单说明：

```
{container="query-frontend",namespace="loki-dev"} |= "metrics.go" | logfmt | duration > 10s and throughput_mb < 500
```

这句查询可以分为 4 个部分：

1. `{}`: 用来过滤标签。Loki 将 Label 与日志本身分开存储，所以我们需要先用 Label 快速筛选出想要的日志。
2. `|= "metrics.go"`: 使用关键词进行过滤。
3. `| logfmt`: 对日志进行进一步解析。
4. `duration > 10s and throughput_mb < 500`: 最后的筛选条件。

你可能会疑惑为什么需要 `logfmt`。这是因为这条日志没有预先处理，即没有预先对日志进行解析。这在你的日志含有不同格式的情况下比较有用，你可以在查询的时候进行解析。当然，如果你需要频繁使用类似的查询时解析，可以考虑把这个步骤放到日志发送的时候，用 Promtail 之类的工具就可以。

回到我们的例子，当你在 Explore 中的查询框输入 `{}` 时，就会有补全提示出现。我们可以用 `container` 来进行第一步筛选：

```
{container="loki-test-flog-1"}
```

![查询结果](media/17205193921030/17242966076298.jpg)

从这里，我们可以看到查询之后的日志，它会有简单的日志量统计，以及下方的最新日志（默认是倒序）。

接下来，我们再加上关键词筛选：

```
{container="loki-test-flog-1"} |= "GET"
```

![关键词筛选结果](media/17205193921030/17242966419959.jpg)

这样就可以看到关键词高亮了。你可以按照自己的需求来不断尝试。

## 组件分析与配置详解

如果你按照流程走到了这里，相信你已经有了初步的概念。接下来我们就来搞清楚这个例子的内部是怎么回事。

我们采取的方式是查看我们一开始下载的三个文件里面的内容。首先，我们来看 `docker-compose.yml` 里面的几个角色。

![Loki架构图](media/17205193921030/17218773392822.jpg)

- minio: 开源版本的阿里云 OSS 或者 AWS S3，主要用来存取日志数据。
- flog: 日志生成器，用来生成用于测试的日志。
- write: Loki 写角色，包括 Queryer 和 Query Frontend。
- read: Loki 读角色，包括 Distributor 和 Ingester。
- backend: Loki 除了读与写之外的后端角色。
- gateway: Nginx，用来提供统一的接入点，并根据请求路径来区分读写，分发到不同的角色中去。
- grafana: 可视化界面，可以用来查看与搜索日志。
- alloy: 用来采集日志，在这里实际上也可以用 Promtail 来替代。

从上面官网借鉴的图中，大家也能看明白怎么回事了。这是稍复杂一些的部署方案，因为如果是非常小体量的部署情况下，Loki 的角色并不需要分离。

我们看下例子中的 Nginx 配置，从中可以看到它在这里做了读写分离，即根据请求的路径来区分读写后，分发到不同的读写实例中去，即 `http://read:3100` 以及 `http://write:3100`。

```nginx
location = /api/prom/push {
  proxy_pass       http://write:3100$request_uri;
}

location = /api/prom/tail {
  proxy_pass       http://read:3100$request_uri;
  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection "upgrade";
}

location ~ /api/prom/.* {
  proxy_pass       http://read:3100$request_uri;
}

location = /loki/api/v1/push {
  proxy_pass       http://write:3100$request_uri;
}

location = /loki/api/v1/tail {
  proxy_pass       http://read:3100$request_uri;
  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection "upgrade";
}

location ~ /loki/api/.* {
  proxy_pass       http://read:3100$request_uri;
}
```

也许你会奇怪，`backend` 实例哪里去了，并没有看到配置。确实如此，因为在 Loki 的架构中，`backend` 并不是对外开放接口的，也就是说，它是给 `read` 以及 `write` 提供服务的。我们可以在 Loki 的配置文件 `loki-config.yaml` 中看到它。

下面是我截取的部分配置，从中可以看到三个角色的配置以及 `backend` 的身影。

```yaml
# ...
memberlist:
  join_members: ["read", "write", "backend"]
  # ...

schema_config:
  configs:
    - from: 2023-01-01
      store: tsdb
      object_store: s3
      # ...
common:
  path_prefix: /loki
  replication_factor: 1
  compactor_address: http://backend:3100
  storage:
    s3:
      endpoint: minio:9000
  ring:
    kvstore:
      store: memberlist
```

我们来看看配置中特意留下来的 `minio`。因为 Loki 存储的日志内容都在 minio 当中，它是 AWS S3 的私有化替代，所以我们可以看到 Loki 的配置中直接把 `minio` 的访问地址配置上去了。

接下来，我们来看看日志是怎么被采集的，也就是 `alloy` 这部分。它的容器配置部分把 `/var/run/docker.sock` 挂载了，这就意味着它可以直接读取主机中 docker 正在运行的实例以及它们的日志。

我们来看下 `alloy-local-config.yaml`，这个配置最好配合 [Grafana Alloy/Reference/Components/loki/loki.source.docker](https://grafana.com/docs/alloy/latest/reference/components/loki/loki.source.docker/) 一起看，会更加清楚。

```hcl
# 配置 Docker 容器发现
discovery.docker "flog_scrape" {
    host             = "unix:///var/run/docker.sock"
    refresh_interval = "5s"
}

# 配置针对发现的 Docker 容器的标签重写规则
discovery.relabel "flog_scrape" {
    # 当前没有直接指定要处理的 targets，因为 targets 将在 Docker 发现中自动填充
    targets = []

    rule {
        # 源标签，从 Docker 容器元数据中获取容器名称
        source_labels = ["__meta_docker_container_name"]
        # 正则表达式，用于从容器名称中提取有用的部分
        regex         = "/(.*)"
        # 目标标签名，将提取的结果设置到此标签中
        target_label  = "container"
    }
}

# 配置 Loki 的 Docker 日志源
loki.source.docker "flog_scrape" {
    host             = "unix:///var/run/docker.sock"
    targets          = discovery.docker.flog_scrape.targets
    # 定义将日志转发到的 Loki 写入配置的接收器
    forward_to       = [loki.write.default.receiver]
    # 应用前面定义的标签重写规则
    relabel_rules    = discovery.relabel.flog_scrape.rules
    refresh_interval = "5s"
}

# 配置 Loki 的写入端点
loki.write "default" {
    endpoint {
        # Loki API 的 URL
        url       = "http://gateway:3100/loki/api/v1/push"
        # 租户 ID，如果 Loki 配置了多租户支持
        tenant_id = "tenant1"
    }
    # 外部标签，这些标签将应用于发送到 Loki 的所有日志条目
    external_labels = {}
}
```

其中可以注意下 `target_label  = "container"`，这个配置就对应我们在上面用的 LogQL 中使用的标签筛选的 Key。如果这里改成 `target_label  = "x_container"`，那么对应的 LogQL 就需要改成 `{x_container="loki-test-flog-1"}`。

## 总结

以上就是 Loki 部署的例子，相信大家已经看明白了 Loki 的部署架构以及配置。在接下来的文章中，我会继续深入分析 Loki 的架构，探讨其设计理念和实现细节，以帮助大家更好地理解和使用这个强大的日志管理工具。

### Ref

- https://grafana.com/docs/loki/latest/get-started/quick-start/
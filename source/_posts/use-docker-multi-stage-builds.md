---
title: Docker multi-stage builds
date: 2019-11-04 18:57:04
tags: [DevOps,Docker]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/124
---
<!-- en_title: use-docker-multi-stage-builds -->

今天来介绍一个 Docker build 很有用的特性：**Multi-stage builds**，即多阶段打包。

### 前言

这个特性很早之前，在 2017 年初的时候就可以使用了。如果你没有用到，很有可能你不需要编译语言，就比如 C/C++/Golang/Java 之类的语言。

现在网上有非常多的教程告诉我们，打包 Docker 镜像的时候，我们需要把镜像缩减到最小，因此我们可以看到最佳实践是类似于这样的：

```Dockerfile
RUN apt-get update && apt-get install -y \
    aufs-tools \
    automake \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*
```

又或者这样的：

```Dockerfile
RUN npm install --production \
    && rm -rf $HOME/.npm
```

还有这样的：

```Dockerfile
RUN pip install -r requirements --no-cache-dir
```

这些技巧的目的都在于把改动的内容缩减到最小，因为没必要把缓存之类的内容也放到镜像中去，这样就可以把镜像尽可能缩小。

而今天介绍的 Multi-Stage builds 就是达到这个目的的另一个重要手段。

### 很早之前

对于编译型的语言，我们可能需要编译完成后，将依赖与编译好的二进制文件（artifacts，即制品）拷贝到一个新的小镜像中来进行打包了，比如我们会把镜像的打包过程放到 CI 中去，大概的内容包括：

1.  测试
    1.  安装测试依赖
    2.  静态检查
    3.  单元测试
2.  编译
    1.  安装编译依赖
    2.  编译
3.  打包镜像
    1.  安装依赖
    2.  将编译制品拷贝到空镜像
    3.  将镜像推送到镜像库中

我们可以看到，编译与打包的步骤需要分开，因为我们需要：

1.  解耦，简化整体的过程；
2.  两者如果是基于不同 CI 运行镜像的话，我们还需要用到不同的镜像；
3.  需要用到 CI 提供的并行执行能力；

于是我们的问题出现了：如何将编译制品传送至打包步骤？用缓存是比较简单的，但是需要保证缓存只能被当前的编译步骤使用，不然会导致编译的版本错误。

Gitlab 提供的 `dependencies` 也能做到这一点，自动将你制定步骤的 artifacts 下载下来，只不过这样的步骤会显得多余：有时候你只是想用来打包镜像而已，而如果 artifacts 上传至 Gitlab 服务器，还有那缓慢速度的限制，拖慢整体打包步骤。

所以，我们的救星来了，**Multi-stage builds**。

### 现在

现在这个步骤就很简单了，它允许你把所有的步骤放到一个 Dockerfile 中去完成，拿官网<sup>[1], [2]</sup>上的例子来说：

```Dockerfile
FROM golang:1.7.3 AS builder
WORKDIR /go/src/github.com/alexellis/href-counter/
RUN go get -d -v golang.org/x/net/html  
COPY app.go    .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o app .

FROM alpine:latest  
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /go/src/github.com/alexellis/href-counter/app .
CMD ["./app"] 
```

它将我之前说的 CI **编译与打包步骤**合并了，可以注意到的是它有两个 `FROM` 关键字，这就是这个多阶段的关键所在了，它允许多个 `FROM` 来达到多阶段的目的，并且，最后一个 `FROM` 才是你真正的打包步骤，利用这个特性，你可以将最后打包完成的镜像做到最小。

这样还有一个好处，你可以更方便地迁移到其它 CI 平台了，毕竟两个步骤合并成一个了。

另外，这样的改变，在不注意的情况下，会让你的编译过程变慢，因为没有缓存。

解决方案也是有的，就是官网上说的是 **Stop at a specific build stage**，我们在编译的时候，需要多加一行镜像编译命令，就拿上面的例子来说：

```bash
docker build -t . example-registry.com/app:latest
docker push example-registry.com/app:latest
```

我们可以利用 `--target` 以及 `--cache-from` 来实现：

```bash
# 将最新已有的 builder 镜像拉下来
docker pull example-registry.com/app:builder || true

# --cache-from 就是关键了，它就可以复用缓存了
# 另外还有个 --target 即告诉 docker 
# 只要编译到 builder 这个就停止，这样可以把缓存保留下来
docker build \
    --cache-from=example-registry.com/app:builder \
    --target builder \
    -t example-registry.com/app:builder \
    .

# 将最新已有的镜像拉下来
docker pull example-registry.com/app:latest || true
docker build \
    --cache-from=example-registry.com/app:builder \
    --cache-from=example-registry.com/app:latest \
    -t example-registry.com/app:latest \
    .

# 将最新的镜像以及 builder 镜像推送至远程
docker push example-registry.com/app:latest
docker push example-registry.com/app:builder
```

### Ref

1.  [Builder pattern vs. Multi-stage builds in Docker][1]
2.  [Use multi-stage builds][2] 
3.  [Caching Docker layers on serverless build hosts with multi-stage builds, —target, and —cache-from][3]

[1]: https://blog.alexellis.io/mutli-stage-docker-builds/

[2]: https://docs.docker.com/develop/develop-images/multistage-build/

[3]: https://andrewlock.net/caching-docker-layers-on-serverless-build-hosts-with-multi-stage-builds---target,-and---cache-from/


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/124 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
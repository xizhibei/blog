---
title: 如何解决 Docker 镜像无法拉取的问题
date: 2024-07-10 23:13:09
tags: [Docker, 科学上网]
categories: [技术教程]
author: xizhibei
---

> **注意**：本文涉及的外部网址和信息具有时效性，但解决方案部分是通用的。

由于众所周知的原因，GFW 需要保护我们免受「有害」Docker 镜像的损害，因此国内大部分主流镜像加速服务已经停止或只提供白名单服务。当然，你可以继续使用一些非主流的镜像，可以在这里查看：[Docker Hub 镜像加速器](https://gist.github.com/y0ngb1n/7e8f16af3242c7815e7ca2f0833d3ea6)。随着政策的落实，我认为国内的镜像加速服务可能只有两种结局：要么关闭，要么采用白名单模式。

<!-- more -->

![SJTUG（上海交通大学 Linux 用户组）发布公告称已下架 Docker Hub 镜像](media/17206003151822/17206114852710.jpg)
这种情况下，如果你的正常开发服务需要用到「无害」的镜像服务的话，白名单内的镜像可以继续使用，但是如果刚好你认为的「无害」被 GFW 认为「有害」的情况下，原则上你还是需要遵纪守法的，但是如果你出于个人学习的目的仍然想使用的，可以用以下几种方式来解决：

1. 申请加入白名单
2. 科学上网
3. 自建镜像站

下面分别介绍这几种方案。

### 申请加入白名单


我在这里直接推荐 DaoCloud，他们的镜像服务之前一直很稳定，这次也很为国内的开发者考虑，没有直接关闭镜像站，非常值得称赞：[DaoCloud - 白名单 & 限流 & 降级 的公开信息](https://github.com/DaoCloud/public-image-mirror/issues/2328)。

这是最推荐的方式，相信大家大部分时候只是工作上使用而已。如果你需要的镜像不在白名单内，可以尝试申请。虽然流程可能有点慢，但它是免费的。

### 科学上网

首先，接下来要操作系统是 Linux，如果是其他系统，用 Docker Desktop 设置起来更简单。其次，需要你已经有科学上网的手段，接下来假设你的代理地址是 `http://127.0.0.1:7890`，可以根据你的需求修改。最后，这里主要涉及 Docker 本身的一些基础知识，比如 Docker 有两个地方需要使用到 Proxy：

- Docker client
- Docker server

#### Docker client

这里的代理主要是容器和镜像使用，需要修改 `~/.docker/config.json`：

```json
{
 "proxies": {
    "default": {
      "httpProxy": "http://127.0.0.1:7890",
      "httpsProxy": "http://127.0.0.1:7890",
      "noProxy": "localhost,::1,127.0.0.1,10.0.0.0/8,127.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
    }
 }
}
```

这个配置主要是在两个地方生效，一个是在运行 `docker run` 时生效，实际原理是将对应的变量设置为 Container 的环境变量，因此修改之前正在运行的 Container 无法生效。另一个是在 `docker build` 时也会生效，因为有些资源需要科学上网才能获取。

配置会一直生效，如果不想放在配置文件里，也可以使用命令行传入的方式：

```bash
docker build \
     --build-arg HTTP_PROXY="http://127.0.0.1:7890" \
     --build-arg HTTPS_PROXY="http://127.0.0.1:7890" \
     --build-arg NO_PROXY="localhost,::1,127.0.0.1,10.0.0.0/8,127.0.0.0/8,172.16.0.0/12,192.168.0.0/16" \
     .
```

```bash
docker run \
     --env HTTP_PROXY="http://127.0.0.1:7890" \
     --env HTTPS_PROXY="http://127.0.0.1:7890" \
     --env NO_PROXY="localhost,::1,127.0.0.1,10.0.0.0/8,127.0.0.0/8,172.16.0.0/12,192.168.0.0/16" \
     nginx
```

#### Docker server

这里有两种修改方式，任选其一即可，但都需要重启 Docker 服务。

修改 `daemon.json`，路径是 `/etc/docker/daemon.json`：

```json
{
  "proxies": {
     "http-proxy": "http://127.0.0.1:7890",
     "https-proxy": "http://127.0.0.1:7890",
     "no-proxy": "localhost,::1,127.0.0.1,10.0.0.0/8,127.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
  }
}
```

修改完后，执行 `systemctl restart docker`。

如果使用的是 Ubuntu 新版本等使用 Systemd 的系统，也可以通过新增配置文件的方式：

```bash
sudo mkdir -p /etc/systemd/system/docker.service.d
```

在该目录下，新建一个 `proxy.conf` 文件，内容如下：

```conf
[Service]
Environment="HTTP_PROXY=http://127.0.0.1:7890"
Environment="HTTPS_PROXY=http://127.0.0.1:7890"
Environment="NO_PROXY=localhost,::1,127.0.0.1,10.0.0.0/8,127.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
```

最后，执行以下命令来应用更新：

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl show --property=Environment docker  # 确认生效
```

#### 其他

如果使用的是 Docker Desktop，在 `Preferences > Resource > Proxies` 中设置即可，最简单。

![Docker Desktop 设置](media/17206003151822/17206115939639.jpg)

对于 Mac，推荐使用 OrbStack，需要设置两个地方：

![OrbStack 设置](media/17206003151822/17206101651927.jpg)

这里需要像 Linux 设置 Docker 服务器一样设置：

![OrbStack Docker 服务器设置](media/17206003151822/17206101466093.jpg)

### 自建镜像站

推荐两个自建镜像站的方案，自建时注意不要共享给太多人，毕竟还是自己或公司内部使用。而且由于不是国内 IP，可能需要与科学上网结合使用。

- [CF-Workers-docker.io](https://github.com/cmliu/CF-Workers-docker.io)：使用 Cloudflare Workers，不用自建机器，省成本。
- [Docker-Proxy](https://github.com/dqzboy/Docker-Proxy)：需要有国外机器，流量算自己的，成本相对高一些。

其他类似的方案也有很多，大家可以自行搜索。

另外，我也见过用 GitHub Actions 拉取镜像，然后用 `docker save` 打包镜像后，手动下载到本地进行 `docker load` 的方式，偶尔使用还是可以考虑的。

### Refs

- [Docker Network Proxy](https://docs.docker.com/network/proxy/)
- [Docker Daemon Proxy Configuration](https://docs.docker.com/config/daemon/proxy/)

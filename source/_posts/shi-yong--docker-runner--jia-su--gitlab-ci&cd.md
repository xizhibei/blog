---
title: 使用 docker runner 加速 gitlab CI&CD
date: 2017-05-29 16:47:48
tags: [DevOps,Docker,Gitlab]
author: xizhibei
---
在之前的 CI&CD 实践中，我们一直使用的是 Shell runner，简单来说，就是在一台机器上配置好所有的环境，然后序列地去执行任务。

很明显，好处是配置非常简单，也很容易 Debug，出了问题，登录到机器上去查找即可；然而坏处就是配置迁移麻烦，也非常容易被破坏环境，而且单台机器上并发比较麻烦，好些的方法是需要配置多个机器，只是这就有些有点浪费资源了。

因此为了更快，我们需要并行地去执行 CI&CD 任务，这就需要换种更好些的方式了。

### 选择其他 Runner
因此在剩下的几个方式中：

* Docker：最简单，从 Shell 迁移来说，工作量不大；
* Docker Machine & Docker Machine SSH：需要多台机器，配置复杂；
* Parallels OR VirtualBox：虚拟机，太重量级了；
* SSH：与 Shell 一个意思，换成远程执行 Shell 命令；
* Kubernetes：有点复杂，目前团队 k8s 仍处于引入阶段，暂时不考虑；

考虑到目前团队规模小，CI & CD 任务量也不是很高，因此在单台机器上部署 Docker Runner 即可。

### Docker runner 介绍
首先，使用 docker runner 需要有两个前提：

1. 有自己的 private docker registry，推荐使用 gitlab 自带的 registry 功能；
2. 编译好自己的 docker image：
 * build image：用来跑任务，里面必须要有 git，用来拉代码，还得有其它工具用来跑任务；
 * service image：用来配合跑任务，比如数据库 mongo, redis 等，编译 docker 镜像： docker:dind，其中通过 docker 的 link 功能，通过配置域名来连接至相关的服务；

另外，使用 docker runner 的话，有两种方式去编译镜像：

1. 挂载 /var/run/docker.sock，使用比较简单，直接使用 share docker daemon 的方式，共享缓存也简单，能够加快编译速度；缺点是有权限问题，因为在 ci 里面完全可以执行 `docker rm -f $(docker ps -a -q)` 这样危险的命令；
2. Docker in docker & Privileged mode，也就是在 docker container 里面编译镜像，没有了权限问题的担忧，编译镜像互相隔离；缺点么，就是无法共享缓存，从而导致编译速度会变慢，因此在 docker:dind 中建议使用 overlay fs driver 以及本地的一些镜像缓存来加快速度；

考虑到线上环境是隔离的，而且管理人员局限于开发以及运维，可以牺牲一些安全性，我们采用了第一个选项。

### 具体配置文件

```toml
concurrent = 2
check_interval = 0

[[runners]]
  name = "docker-runner"
  url = "https://git.example.com/ci"
  token = "<you token here>"
  executor = "docker"
  [runners.docker]
    tls_verify = false
    image = "docker:git"
    privileged = false
    disable_cache = false
    volumes = [
      "/data/gitlab-runner-cache:/cache",
      "/data/gitlab-runner-npm-cache:/root/.npm",
      "/var/run/docker.sock:/var/run/docker.sock"
    ]
    shm_size = 0
    pull_policy = "if-not-present"
  [runners.cache]
```

注意 `/data/gitlab-runner-npm-cache:/root/.npm` 这个配置，这是为了 Node.js 项目的 npm 缓存共享，这样安装的时候能够更快些。

### 优化建议

1. 打开 gitlab 的 registry 功能，它以 docker 官方的 registry:2 为基础，用 gitlab 自己的账号系统加入了权限管理功能，在 ci 中也可以直接使用私有镜像；
2. 如果是 centos，docker 的 devicemapper fs driver 请优化下：https://docs.docker.com/engine/userguide/storagedriver/device-mapper-driver/ ，或者使用 overlay； 
3. 使用 alpine 为基础镜像，体积最小，国内的镜像也挺快的，比如：mirrors.tuna.tsinghua.edu.cn；
4. 由于每个 pipeline 相互独立，并发数可以调高些，比如就是团队的开发人数；
5. 搭建 npm private registry: https://github.com/verdaccio/verdaccio ，来加快 npm install 速度；

### Reference
1. http://docs.gitlab.com/runner/executors/docker.html
2. http://docs.gitlab.com/runner/configuration/advanced-configuration.html
3. https://docs.gitlab.com/ce/ci/docker/using_docker_build.html



***
原链接: https://github.com/xizhibei/blog/issues/49

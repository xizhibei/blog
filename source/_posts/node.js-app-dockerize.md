---
title: Node.js APP dockerize
date: 2016-05-17 22:42:24
tags: [docker,Node.js]
author: xizhibei
---
今天把做的项目直接做了 docker 化，一个是前端纯静态化的，另一个是后端 Node.js App，对于这两个项目，想用最简单的方式来使用 docker

静态项目最容易，直接用 nginx，将编译好的静态文件直接丢到 volums 里面即可:

``` yml
version: '2'
services:
  nginx:
    image: nginx:latest
    volumes:
      - ./build:/user/share/nginx/html:ro
    ports:
      - "8080:80"

```

后端项目有点麻烦，需要写 Dockerfile，我觉得 dockerfile 的编写原则就是：** 越是不怎么会改动的内容，越往上放，然后把经常变动的东西放到最后 **，这样每次 build 的话会用到 cache，下次不用重新 build 了。

这里还用到了 gosh，比 sudo 更棒，还有 tini，解决僵尸进程问题

``` Dockerfile
# For your nodejs app

# Change your node.js version here
FROM node:latest

MAINTAINER Xu Zhipei "xuzhipei@gmail.com"

RUN groupadd -r app && useradd -r -m -g app app

ENV UBUNTU_MIRROR http://ftp.sjtu.edu.cn
RUN echo "deb ${UBUNTU_MIRROR}/ubuntu/ trusty main restricted universe multiverse" > /etc/apt/sources.list \
    && echo "deb ${UBUNTU_MIRROR}/ubuntu/ trusty-security main restricted universe multiverse" >> /etc/apt/sources.list \
    && echo "deb ${UBUNTU_MIRROR}/ubuntu/ trusty-updates main restricted universe multiverse" >> /etc/apt/sources.list \
    && echo "deb ${UBUNTU_MIRROR}/ubuntu/ trusty-proposed main restricted universe multiverse" >> /etc/apt/sources.list \
    && echo "deb ${UBUNTU_MIRROR}/ubuntu/ trusty-backports main restricted universe multiverse" >> /etc/apt/sources.list \
    && echo "deb-src ${UBUNTU_MIRROR}/ubuntu/ trusty main restricted universe multiverse" >> /etc/apt/sources.list \
    && echo "deb-src ${UBUNTU_MIRROR}/ubuntu/ trusty-security main restricted universe multiverse" >> /etc/apt/sources.list \
    && echo "deb-src ${UBUNTU_MIRROR}/ubuntu/ trusty-updates main restricted universe multiverse" >> /etc/apt/sources.list \
    && echo "deb-src ${UBUNTU_MIRROR}/ubuntu/ trusty-proposed main restricted universe multiverse" >> /etc/apt/sources.list \
    && echo "deb-src ${UBUNTU_MIRROR}/ubuntu/ trusty-backports main restricted universe multiverse" >> /etc/apt/sources.list

RUN apt-get update \
    && apt-get install -y --force-yes ca-certificates wget --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# grab gosu for easy step-down from root
ENV GOSU_VERSION 1.7
RUN set -x \
    && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
    && wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
    && rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu \
    && gosu nobody true

# grab tini for signal processing and zombie killing
ENV TINI_VERSION v0.9.0
RUN set -x \
    && wget -O /usr/local/bin/tini "https://github.com/krallin/tini/releases/download/$TINI_VERSION/tini" \
    && wget -O /usr/local/bin/tini.asc "https://github.com/krallin/tini/releases/download/$TINI_VERSION/tini.asc" \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys 6380DC428747F6C393FEACA59A84159D7001A4E5 \
    && gpg --batch --verify /usr/local/bin/tini.asc /usr/local/bin/tini \
    && rm -r "$GNUPGHOME" /usr/local/bin/tini.asc \
    && chmod +x /usr/local/bin/tini \
    && tini -h

STOPSIGNAL SIGTERM

RUN mkdir -p /usr/src/app
RUN chown -R app /usr/src/app
WORKDIR /usr/src/app

ENV NPM_CONFIG_LOGLEVEL http
ENV NPM_CONFIG_REGISTRY https://registry.npm.taobao.org
ENV PHANTOMJS_CDNURL https://npm.taobao.org/mirrors/phantomjs

# for app port
ENV PORT 3000

CMD ["gosu", "app", "tini", "node", "app.js"]

EXPOSE 3000

# frequently change begins here
COPY . /usr/src/app

RUN npm install --production

RUN npm build
```
#### Reference

https://github.com/tianon/gosu
https://github.com/krallin/tini
https://github.com/docker-library/kibana/


***
原链接: https://github.com/xizhibei/blog/issues/13

---
title: 应用配置管理实践
date: 2017-03-04 00:09:23
tags: [DevOps,Node.js, 配置]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/41
---
自从 [上次](https://github.com/xizhibei/blog/issues/27) 简单提到应用配置管理的几种方式以来，我都在尝试不同的方式，到目前为止，仍觉得 ** 剥离单独管理 ** 加上 ** 动态配置服务器 ** 的方式最好用，接下来谈谈原因以及具体实践。

### 原因
#### 记录变更与审计
其实这个涉及到 CD，即持续交付的范畴，为了保证线上应用环境的稳定性，如果配置无法追踪的话，即意味着你不能在出问题的时候，快速定位原因，处理问题。

因此，放到 CVS 系统中就可以非常方便审计，在更新提交历史中查找即可。

#### 自动化
与 CD 配合，即你可以提交到 CVS 系统后，采用 CD 方式直接将各个不同环境中的配置更新。

#### 简单，直观，简洁
在 CVS 中，可以直接看到修改的内容，同事也能知道你修改过什么。

#### 环境统一
这意味着，你可以快速重建自动化生产环境，或者很方便地搭建预发布环境，而由于两个环境相似，一旦在预发布环境上验证过相关的脚本之后，就可以在生产环境中出问题时候，排除脚本问题。

### 实践
#### git submodule
主项目中，可以直接 git submodule 结合起来：

```bash
cd project-root/
git submodule add https://github.com/your-group/project-config config
```

#### npm private module
即相当于拆出一个单独的配置管理模块。
发布时：

```bash
npm set registry http://private-registry-url/
npm adduser --registry http://private-registry-url/

npm publish
```

安装时：

```bash
npm install @your-group/config --registry 
```

具体的 npm private registry，你可以付费使用 npmjs 的服务，也可以自己搭建一个。

搭建的话可以看这里：https://github.com/verdaccio/verdaccio，用 docker 部署非常方便：

```bash
docker run -d --name verdaccio -d -p 4873:4873 verdaccio/verdaccio
```

#### 动态配置
可以使用 etcd，Node.js 应用中使用 nconf 以及 nconf-etcd2

```bash
npm i nconf nconf-etcd2 --save
```

在配置文件中：

```js
nconf.env();

nconf.defaults({
    NODE_ENV: 'development',
    ETCD_HOSTS: 'localhost:2379',
});

nconf.add('etcd', {
    namespace: nconf.get('NODE_ENV'),
    hosts: nconf.get('ETCD_HOSTS').split(',')
});
```

然后，在项目直接使用 `nconf.get` 即可，当然了，为了达到动态更新的目的，可以使用 node-etcd 提供的 watch 方法，实时监听配置变化。

### P.S.
不知道你注意到没有，我在这篇文章中，特意在配置管理之前加了『应用』两个字，这是有原因的：

配置管理不仅包括应用的配置，而且还包括线上环境所有相关的配置，如基础设施的配置：服务器的配置，网络的配置等。

在 《持续交付》 这本书中，给配置管理的定义是：

> 配置管理是指一个过程，通过该过程，所有与项目相关的产物，以及他们之间的关系，都被唯一的定义、存储、检索和修改。

显然，应用配置管理只是配置管理的一小部分而已，而配置管理是所有自动化的基础与前提，做好配置管理至关重要。

多余的不在这里赘述，下次需要专门讲讲持续交付。



***
原链接: https://github.com/xizhibei/blog/issues/41

![知识共享许可协议](https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png "署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）")

本文采用 [署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh) 进行许可。

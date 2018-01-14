---
title: Node Version Manager
date: 2017-01-30 22:34:23
tags: [Node.js,ansible]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/38
---
### 关于
NVM，简单来说，就是管理 node 版本的，自从 Node.js 跟 io.js 合并之后，node 版本迭代就非常快了。然而这时候，我们可能会需要用到多个 node 版本：旧的用来兼容以前的老项目，新的用来应用到新项目；另外线上升级 node 版本的话，也需要很方便去操作。

### 三个选择

#### [creationix/nvm](https://github.com/creationix/nvm)
老牌的 NVM，一般来说 Node.js 入门都是用的这个，相信也一直很熟悉这个工具。它提供的 sandbox 功能可以让你很方便得切换 node 环境，甚至在不同的窗口中使用不同的 node 版本且互不影响，只是带来的麻烦就是每次安装新版本，你都得重新安装全局的包。

还有个很方便的点在于，你可以在项目根目录下，添加一个 `.nvmrc` 文件，直接填入 node 版本号，这样你就可以很方便地使用 `nvm use` 这个命令来切换项目所需的 node 版本了。

如果使用国内镜像，在环境变量中添加：

```bash
export NODEJS_ORG_MIRROR=http://npm.taobao.org/mirrors/node
```

#### [tj/n](https://github.com/tj/n)
TJ 大神写的，简单一个脚本，很适合用于线上单一环境，但是本地的话，似乎没有其它两个好用，功能还不是很强大。

对于安装在服务器上的情景，可以直接使用默认的 N_PREFIX，即 `/usr/local/`，它提供的 Makefile 也只是把 n 这个 bash 脚本拷贝至 `/usr/local/bin` ，然后它就会把可执行文件放到 `/usr/local/bin` 下面，使用 ansible 的时候，会很方便。

不足之处在于，它不能提供 nvm 一样的 sandbox 功能，即各个版本之前，安装的全局包会有冲突，所以切换之后可能需要 ` npm rebuild`。

如果要用国内镜像来安装 node，可以这样：

```bash
NODE_MIRROR=http://npm.taobao.org/mirrors/node/ n latest
```

另外，提供下我的 ansible 安装配置：

```yml
---

- name: install N
  get_url:
    url: https://raw.githubusercontent.com/tj/n/master/bin/n
    dest: /usr/local/bin/n
    mode: u=rwx,g=rx,o=x

- name: install node
  shell: n {{node_version}}
  environment:
    NODE_MIRROR: http://npm.taobao.org/mirrors/node/
  
- name: install global npm packages
  npm:
    name: "{{item}}"
    global: yes
    registry: https://registry.npm.taobao.org
  with_items:
    - pm2
    - yarn
```

#### [jasongin/nvs](https://github.com/jasongin/nvs)
这个比较新，属于新造的轮子，我在试用了之后，直接把 nvm 卸载了，恩，好用太多。

可以说是集成了 nvm 与 n 的功能：可以跟 n 一样在命令行中直接选择 node 版本（但是可以直接下载安装），又有 nvm 的 sandbox 以及那些管理功能。再加上本身是用 Node.js 写的，所以有问题也可以自己查看，很方便地定制。

它的自动切换 node 版本比 nvm 更强大，不同之处在于它使用的是 `.node-version` 文件，而当你 cd 进项目时，它会自动切换，而不用你手工切换。当然了，需要事先打开这个功能：`nvs auto on`。其实这个功能很有意思，算是对 shell hack，有兴趣的不妨查看下源码。

对了，它直接集成了镜像源管理功能，深得我心：

```bash
nvs remote cn-node http://npm.taobao.org/mirrors/node/
nvs add cn-node/4.7.2
```

### 迁移至不同的 NVM

#### pm2
这是非常需要注意的一点，当你使用 pm2 来管理的情况下，因为当你之前已经有旧的 NVM 来管理的时候，很容易出问题，环境变量之类的都会变掉，尤其是 global 的 node modules，路径会改变。

因此，需要重新部署项目，注意：是更新内存中的 pm2，而不是仅仅安装新的 pm2 版本那么简单。

#### ansible
上面已经提到过，ansible 不会主动加载你 .bashrc 或者 .zshrc 之类的，因此当使用 nvm 或者 nvs 管理线上服务器版本的话，可能需要手动 source 一下，或者自己更改 PATH 这个环境变量，具体可以看 [这里](http://docs.ansible.com/ansible/playbooks_environment.html)。




***
原链接: https://github.com/xizhibei/blog/issues/38

![知识共享许可协议](https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png "署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）")

本文采用 [署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh) 进行许可。

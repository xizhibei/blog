---
title: 设置 Github Pages https 个人域名
date: 2018-05-20 23:55:24
tags: []
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/77
---
<!-- en_title: setting-up-github-pages-https-custom-domain -->

用了 GitHub Pages 作为博客已经几年了，而 HTML 博客的域名一直用的是默认的 xizhibei.github.io，之所以没有用自定义域名，也就是考虑到 GitHub 自定义域名不支持 HTTPS。而如果一定要使用，则必须在其它进行一些设置，比如配置 CDN，来将 GitHub Pages 当成源站。

直到最近，看到 [终于支持了](https://blog.github.com/2018-05-01-github-pages-custom-domains-https/)。

马上很激动地分配了个域名，那时候不能马上开启，所以等了 9 个小时后才终于能用上。

对于没置过的朋友，可以看看。

### 设置个人域名
个人域名有四种方式：

- 顶级域名，如 `xizhibei.me`
- www 域名，如 `www.xizhibei.me`
- 顶级域名与 www 域名，如 `xizhibei.me` 与 `www.xizhibei.me`
- 个人二级域名，如 `blog.xizhibei.me`

一般来说，国内比如 DNSPod 都能设置 CNAME 记录，因此直接设置二级域名 CNAME 记录即可。

比如我的博客域名 blog.xizhibei.me 就设置 CNAME 到 xizhibei.github.io。不推荐使用 A 记录直接到 IP，因为不知道什么时候 IP 地址就变了。

然后用 `dig blog.xizhibei.me` 命令检查下：

```
;; QUESTION SECTION:
;blog.xizhibei.me.              IN      A

;; ANSWER SECTION:
blog.xizhibei.me.       600     IN      CNAME   xizhibei.github.io.
xizhibei.github.io.     3600    IN      CNAME   sni.github.map.fastly.net.
sni.github.map.fastly.net. 1381 IN      A       185.199.108.153
sni.github.map.fastly.net. 1381 IN      A       185.199.111.153
sni.github.map.fastly.net. 1381 IN      A       185.199.109.153
sni.github.map.fastly.net. 1381 IN      A       185.199.110.153
```

以上就是生效后起作用的输出。


### 设置项目个人域名
这个简单，在 `Settings -> GitHub Pages -> Custom domain` 设置即可。

不过，这里还需要补充下，这里设置完成后，GitHub 会提交一个 CNAME 文件到项目中去，然后如果你修改这个文件，设置中的 Custom domain 也会跟着改变，而假如这个文件被删除了，个人域名就会消失，回归到 Github Pages 默认域名上去。

### 开启 HTTPS
在 `Settings -> GitHub Pages -> Enforce HTTPS` 选中即可，但是假如是刚刚设置个人域名的话，需要等待证书生成。





***
原链接: https://github.com/xizhibei/blog/issues/77

![知识共享许可协议](https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png "署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）")

本文采用 [署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh) 进行许可。

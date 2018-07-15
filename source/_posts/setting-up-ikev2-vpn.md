---
title: IKEv2 VPN 搭建
date: 2018-06-19 15:55:59
tags: [DevOps,Linux]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/80
---
<!-- en_title: setting-up-ikev2-vpn -->

之所以想写这个，也是时机到了，因为上周看了一眼自己团队管理的服务器数量，不知不觉已经达到一屏幕都放不下的程度了，好还自己当初强制规范团队统一内网域名格式，不然现在真不知道怎么管理。

其实回想起来，管理内部网络还是不够规范的，因为现在还是允许团队直接连接生产环境内网登录机器的，也就是开发与生产环境没有隔离。这么做显然有点不安全，这当然会在之后有足够精力后会去改正（是的，当初如果一开始做好就不会有这事了），现在团队的日常开发真是到了分分钟都离不开内网的程度，贸然实行严格安全制度必然会引起太多不必要的麻烦。

于是，当前为了能够提升开发运维效率，还是得提供稳定且高效的 VPN 网络的，于是，就讲到了我们当前的主题：搭建 VPN 网络。

### 基础知识
在开始之前先复习一下相关的几个基础知识：

#### VPN 网络
VPN 能在公网上建立一个安全稳定的隧道或者说局域网，用处既可以是公司内部人员使用避免外人能直接侵入，也可以是连接自由的网络躲避封锁 [1]。

另外，常用的协议有 `L2TP`，`PPTP` 以及 `IPSec`，由于收到 GFW 升级的影响，会受到或多或少的影响常用的这几种，而如果是比较新的 Mac 系统，你会发现 VPN 选项就剩下 `L2TP over IPSec`, `Cisco IPSec` 以及 `IKEv2`，其实只是因为 `PPTP` 被认为是不安全的 [2]。

目前来看，`L2TP over IPSec` 以及 `IKEv2` 是其中比较合理以及免费的方案 [3]。

#### DNS 协议
这个应该是最简单的了，其实就是个 IP 跟域名相互映射的分布式数据库，我们使用的系统里面，可以使用不同的方法来解析域名，上面我说的内网域名，就是用最简单的：修改 hosts 文件。

P.S. 然后不知道你想到了什么最新技术，是的，其实 DNS 协议使用区块链的技术是最适合的，能真正避免 DNS 被污染（其实很多不能访问的网站被封锁的方式只是因为在国内 DNS 被污染了）[4]。

### 搭建 IKEv2 网络
搭建很简单，使用一键搭建脚本就能直接在 CentOS 或者 Ubuntu 上面搭建：https://github.com/quericy/one-key-ikev2-vpn ，这里也就略过了。

不过，了解下它做了什么还是有必要的，实际上还是围绕着 strongswan 这个工具来实现的，帮你做了繁杂的配置过程，包括生成证书、配置 iptables、IPSec 等。

但是需要提醒一点，假如你只是用来连接内网，其它本地流量不走 VPN 的话，你就需要更改配置了，这个脚本其实是专门为越过障碍的场景而开发的，修改的方式也很简单：修改 `/usr/local/etc/ipsec.conf` 里面的 `leftsubnet` 参数即可，默认是 `0.0.0.0/0`，也就是全部走这个流量，你可以按照你们的内网地址来定这个 `CIDR`，可以是多个，用逗号分隔就行。

其它参数可以参考 [5]。

```
conn ios_ikev2
    keyexchange=ikev2
    ike=aes256-sha256-modp2048,3des-sha1-modp2048,aes256-sha1-modp2048!
    esp=aes256-sha256,3des-sha1,aes256-sha1!
    rekey=no
    left=%defaultroute
    leftid = 马赛克
    leftsendcert=always
    leftsubnet=10.0.0.0/8, 192.168.0.0/16
    leftcert=server.cert.pem
    right=%any
    rightauth=eap-mschapv2
    rightsourceip=10.31.2.0/24
    rightsendcert=never
    eap_identity=%any
    dpdaction=clear
    fragmentation=yes
    auto=add
```

这个例子显示的就是线上有两个内网，连接后你就可以在你的电脑商用 `ip route | grep ipsec0` 命令查看验证了：

```
default via link#17 dev ipsec0
10.0.0.0/8 via 10.31.2.1 dev ipsec0
192.168.0.0/16 via 10.31.2.1 dev ipsec0
224.0.0.0/4 dev ipsec0  scope link
255.255.255.255/32 dev ipsec0  scope link
```

看见中间两个 `via 10.31.2.1 dev ipsec0` 也就意味着你本地如果访问这两个 CIDR 之内的任何 IP 地址都会走 VPN。

### 与 Dnsmasq 配合使用
VPN 搭好了，这时候大家都维护自己的 hosts 文件就有点麻烦了。当然了，可以用 `SwitchHosts!` 软件来实时更新线上的一份统一 hosts 文件。这里提供另一种做法：用 DNS 代理软件 Dnsmasq（其它比如 bind 之类的也可以），它可以将你的内部域名解析为内部地址，这样大家只要配置下 DNS 就能使用了，而 VPN 也能提供 DNS 地址下发的功能，这样直接连上 VPN 就能解析内网地址，很方便。（其实还有另一个好处，在手机上也能访问内部基础设施了，因为在 iOS 手机上你是不能修改 hosts 文件的，只能使用 DNS 代理软件。）

搭建 dnsmasq 这里就简单带过了，用 docker 很简单，如果有人感兴趣再展开。

```bash
docker run -d -p 53:53/tcp -p 53:53/udp \
  --cap-add=NET_ADMIN \
  --name dns-server \
  -v `pwd`/domain.conf:/etc/dnsmasq.d/domain.conf \
  -v `pwd`/resolv.dnsmasq:/etc/resolv.dnsmasq \
  -v `pwd`/private-hosts:/etc/private-hosts \
   andyshinn/dnsmasq
```

domain.conf
```
resolv-file=/etc/resolv.dnsmasq
addn-hosts=/etc/private-hosts
```

resolv.dnsmasq
```
nameserver 114.114.114.114
nameserver 8.8.8.8
```

然后修改 `/usr/local/etc/strongswan.conf` 里面 dns1，dns2 以及 nbns1，nbns2 （给 Windows 用的）即可。

然而现实却很残酷，由于 Mac 在只有部分流量走 VPN 的情况下，是不会使用 VPN 提供的 DNS 的。你可以在 Mac 机器上用 `scutil --dns` 来确认，你设置的 DNS 地址确实是加进去了，但是没有被使用。而如果使用搜索域的话 [6]，Mac 系统似乎没有实现这个协议 [7]，因此只能是自己看情况取舍了。

### Ref
1. [虚拟专用网](https://zh.wikipedia.org/zh-cn/%E8%99%9B%E6%93%AC%E7%A7%81%E4%BA%BA%E7%B6%B2%E8%B7%AF)
2. https://forums.developer.apple.com/thread/48569
3. https://thebestvpn.com/pptp-l2tp-openvpn-sstp-ikev2-protocols/
4. [域名服务器缓存污染](https://zh.wikipedia.org/wiki/%E5%9F%9F%E5%90%8D%E6%9C%8D%E5%8A%A1%E5%99%A8%E7%BC%93%E5%AD%98%E6%B1%A1%E6%9F%93)
5. https://segmentfault.com/a/1190000000646294
6. https://serverfault.com/questions/521536/strongswan-cant-push-dns-resolver-to-osx-mountain-lion-split-tunnel?answertab=active#tab-top
7. http://users.strongswan.narkive.com/u9x7xj8b/setting-domain-search-via-attr-plugin-ikev2


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/80 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
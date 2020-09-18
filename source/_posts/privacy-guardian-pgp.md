---
title: 隐私守卫者 PGP
date: 2020-08-12 15:16:01
tags: [PGP,安全,工具]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/147
---
<!-- en_title: privacy-guardian-pgp -->

我第一次提到过 PGP，是在 [Helm 实践之配置管理](https://github.com/xizhibei/blog/issues/90) 以及 [Helm 实践之持续交付](https://github.com/xizhibei/blog/issues/91)  里面，但当时只是提到它可以用来加密我们的配置，但没有拓展它，今天我们来简单拓展下。

### 简单介绍

菲利普 · 齐默曼（Philip R. Zimmermann）在 1991 年创造了第一个版本的 PGP，其名称 “Pretty Good Privacy”<sup>[1]</sup>。

显而易见，他发明这东西就是为了对抗政府的监视，一经发出，受到了广泛的欢迎。

由于这个软件是商业应用，无法大面积推广，后来就出现了 OpenPGP，是一个互联网标准，其中，最著名的莫过于 GunPG，也就是我们的主角 gpg（我在刚使用的时候，经常打错成 pgp）。

目前 PGP 的作用挺多，主要在于加解密（邮件内容加密）、数字签名（Ubuntu 的软件分发）等。

### 安装

```bash
sudo apt-get install gnupg # ubuntu
brew install gpg # mac
```

或者你可以去[官网](https://gnupg.org/)下载。

### 使用

#### 管理<sup>[2]</sup>

```bash
# 按照步骤，一步一步设置即可，最后的密码不要设置太简单
gpg --generate-key

# 注意最后生成的 Key ID，在很多命令中需要用到
# 如果不知道，看看已经生成的密钥
gpg --list-keys

# 其中那一长串 fingerprint 就是 key ID 了，可以只取最后 8 位

# 可以导出公钥，armor 表示用 ASCII 编码
gpg --export --armor --output your-name.pub.asc <your-key-id>

# 私钥也可以导出，但是不建议，很容易不小心泄露了
gpg --export-secret-keys --output your-name.pri.asc

# 也可以发送至远程公钥服务器
# 你的朋友们就可以从服务器获取了
# 之后你可能会收到一份验证邮件，来验证你是这个公钥的持有者
# 其它公钥服务器就不一定会验证了
gpg --keyserver hkps://keys.openpgp.org --send-keys <your-key-id>

# 假如你的密钥泄露了，可以撤消它
# 不要以为撤销就是删除，证书只能追加，
# 因此，你需要生成一个撤销证书来追加到之前的证书中去，
# 合并起来的证书就相当于证书被「撤销」了
gpg --gen-revoke <your-key-id> > revoke.asc
gpg --import revoke.asc
gpg --keyserver hkps://keys.openpgp.org --send-keys <your-key-id>
```

这里需要注意的是，从公钥服务器获取的证书不一定代表本人，我在上面提到的 keys.openpgp.org 也不一定完全值得信任。

但是，PGP 区别于 SSL 证书体系的不同就在于此了：它可以由使用者自行决定是否信任中央证书机构，比如你可以由朋友来当这个背书者，即由你的朋友来对新的公钥进行签名认证，从而信任新添加的证书。

### 加解密

首先你需要明白，加密是必须指定接收者的，你必须用朋友的公钥来进行加密，同时，你可以对加密内容进行签名，表示这个加密过的信息，是由你写的。

```bash
# 加密，会生成一个 mail.txt.asc 的文件，你就可以直接发送给朋友了
gpg --armor --sign --recipient <your-friend-id> --encrypt mail.txt

# 解密，会看到解密后的内容，以及签名是否正确
gpg --decrypt mail.txt.asc
```

### 签名

这是对内容的完整性进行保护了：

```bash
# 签名有 clearsign 以及 detach-sign，
# 区别在于前者会在签名文件中带有原文件信息，而后者没有
# 生成的文件依然是以 asc 结尾
gpg --armor --detach-sign app.tgz

# 验证
gpg --verify app.tgz.asc
```

### 实践

实际使用中，会有其它问题，比如，你如何在脚本中使用呢？

在上面的加密以及签名命令中，你需要用到私钥，因此在 Ubuntu 中你得在弹出的密码框中输入密码，而在脚本中，你是不能这么干的，有其它参数干这个事情。

```bash
gpg --batch --yes --passphrase <passphrase> --detach-sign --armor app.tgz
```

其中，`--passphrase` 可以换成 `--passphrase-fd` 或者 `--passphrase-file`，来指定密码输入的方式。

另外，如果你需要直接使用 armor 公钥，一个方式是导入后使用，`gpg --import pub.asc`，然后对签名进行验证，另一个是需要对公钥的格式进行转换，不然会出错：

```bash
gpg --yes -o pub.gpg --dearmor pub.asc
gpg --trust-model always --no-default-keyring --keyring pub.gpg --verify app.tgz.asc
```

### Ref

1.  [PGP][1]
2.  [GnuPrivacyGuardHowto][2]

[1]: https://zh.wikipedia.org/wiki/PGP

[2]: https://help.ubuntu.com/community/GnuPrivacyGuardHowto


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/147 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
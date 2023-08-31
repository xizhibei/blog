---
title: 【MQTT系列】（二）Broker 搭建
date: 2021-10-31 20:17:30
tags: [DevOps,MQTT]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/180
---
<!-- en_title: mqtt-mosquitto-broker-setup -->

又停更了，两个月。 🙈 

我在上次的 [简介](https://github.com/xizhibei/blog/issues/179) 里简单提到过，如何用公共的 Broker 来做测试，显然，你不能用测试服务器当做生产环境的服务器，我们还是需要一个属于自己的服务器。

### Mosquitto

Mosquitto 可谓是开源届最有名气的 MQTT Broker 了，只是功能上勉强够用，有些如权限管理之类的高级功能需要自己安装插件，或者干脆自己的实现插件来拓展。

它还提供了一个公共的 Broker 可以用来测试： <https://test.mosquitto.org/>

它的安装非常简单，直接安装相应的程序即可，比如在 Mac 中 `brew install mosquitto`，而在 Linux 中 `sudo api install mosquitto`。如果想用 docker 也是类似，目前官方的镜像是 `eclipse-mosquitto`，运行细节，这里掠过，主要说说它的配置<sup>[1]</sup>：

听默认的 1883 非加密端口：

    listener 1883 0.0.0.0

如果不想配置用户密码登录，这里就可以配置允许匿名连接，也就是没有用户密码：

    allow_anonymous true

但如果配置了不允许匿名，那么需要配置用户名密码。这个文件里面的用户密码可以用 mosquitto 提供的工具来配置：`mosquitto_passwd mosquitto/config/pwfile username`，然后按照提示输入密码即可。

然后，我们还需要在配置文件中加入这么一行：

    password_file /mosquitto/config/pwfile

另外，如果需要对每个用户进行权限限制，则需要配置 acl：

    acl_file /mosquitto/config/aclfile

这个配置也很简单，它支持三种语法：

1.  `topic [read|write|readwrite|deny] <topic>`，这个可以针对匿名客户的 topic 权限；
2.  `user <username>`，这个是与 topic 权限联合使用；
3.  `pattern [read|write|readwrite] <topic>`，这个可以针对单个用户来做权限划分了，其中的 `<topic>` 可以包含 `%c` 代表登录的 Client ID 以及 `%u` 代表登录的用户名；

如下便是例子：<sup>[2]</sup>

允许匿名用户读取所有用户级别的 topic：

    topic read #
    topic read $SYS/broker/messages/#

允许用户 web 读取所有 topic

    user web
    topic read #
    topic read $SYS/#

显然，这种权限只能满足最低级别的要求，如果需要跟你们的平台整合起来，实现动态登录认证，则需要用到 auth_plugin，目前看到官方推荐的一个插件是 [mosquitto-go-auth](https://github.com/iegomez/mosquitto-go-auth) 。

##### 集群

mosquitto 本身并不支持集群部署，但是可以通过后端来实现，详情请见 [MQTT server support](https://github.com/mqtt/mqtt.org/wiki/server-support)。

另外，由于我目前也没有搭建过集群，这里就不多说了。

##### TLS 证书

随着国家对隐私权的保护等级要求越来越高，加密传输是其中越来越重要的一个环节，也就是所有的个人信息传输必须加密。

其实对于 MQTT 来说，我们可以用 HTTPS 证书，因为本质上他们是一样的，都是 TLS 证书，因此也可以用在 MQTT 协议上。

如果你用经过权威 CA 签名颁发的证书，那就简单配置如下即可：

    listener 8883 0.0.0.0
    certfile /path/to/certs/example.com.cer
    keyfile /path/to/certs/example.com.key

但如果要用自己签发的证书，客户端连接的时候就会稍稍复杂些，需要配置好 ca 才能连接。

另外，跟 [HTTPS 双向认证](https://github.com/xizhibei/blog/issues/159) 一样，MQTT 也可以采用双向认证，这种情况下，当客户端连接的时候，服务器便会要求客户端提供证书，并且用你配置的 ca 证书来验证客户端证书的签名。

    cafile /path/to/certs/ca.pem
    require_certificate true

##### 测试

好了，当我们搭建完毕，就可以使用客户端进行简单的测试了。不过，可能大多数人简单测试后，都会认为已经可以正常投入使用了，不过，其实你可以做的更完善一些。

比如，你可以先预估下你需要连接的客户端数量，然后是消息的数量、并发数以及消息大小，得出个大概范围，再进行基准测试。

这里我用的是 [MQTT benchmarking tool](https://github.com/krylovsk/mqtt-benchmark)，它可以很方便测试出，你现在搭建完毕的 Broker 能承受多大的压力。

它本身还是比较容易使用的，如果你使用过 HTTP 接口的 Apache bench 之类的压测工具，就能很快上手。比如，它的主页上的一个例子便是，以 10 个客户的，每个客户端连续发送 100 条消息：

```bash
mqtt-benchmark --broker tcp://broker.local:1883 --count 100 --clients 10 --qos 1 --topic house/bedroom/temperature --payload {\"temperature\":20,\"timestamp\":1597314150}
```

最后，在输出中，你能看到测试后的统计结果，也能提前发现一些搭建过程中隐藏的问题。虽然这多出来的一两个小时可能在你看来比较浪费，但是这些问题如果在使用了一段时间后才被发现的话，你付出的成本就会远远高于你多花的一两个小时了。而且我相信，工程师之间的差距，不仅仅在于做事快慢，更会在这些专业素养上体现出来。

### P.S.

其实你也可以考虑使用付费的服务，免去自己出维护的人力以及服务器成本。比如可以选择一些商业性质的 Broker，比如国内的 EMQX 以及 国外的 HiveMQ，它们既支持商业版本，也有开源版本，既可以自己在服务器上搭建，也可以直接用他们提供的服务器。毕竟是商业支持，功能更完善，体验也会比较好。

### Ref

1.  [mosquitto-conf][1]
2.  [mosquitto-mqtt][2]

[1]: https://mosquitto.org/man/mosquitto-conf-5.html

[2]: https://troy.dack.com.au/mosquitto-mqtt/


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/180 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
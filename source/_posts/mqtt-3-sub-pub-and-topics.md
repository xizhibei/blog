---
title: 【MQTT系列】（三）发布、订阅与主题
date: 2021-12-12 00:09:19
tags: [MQTT]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/181
---
<!-- en_title: mqtt-3-sub-pub-and-topics --->

接着上次的简介（这个博主真会拖更 :P），我们来说说 MQTT 的一些基本概念。

### 基本概念

在上次非常简单的 MQTT Hello World 中，我们其实就已经涉及到了一个非常重要的概念：发布与订阅。

想象大家很容易想起的，便是设计模式里面的发布订阅模式，确实，本质上 MQTT 实现的，就是架构上的发布订阅模式。

让我们回想下， 发布订阅模式的好处在哪里？解耦。如果说观察者模式是发送方与接收方的低耦合，那发布订阅模式是两方的完全解耦了。

### 与消息队列的区别

而随后想起的便是各种分布式应用里面的各种消息队列中间件了（比如 ActiveMQ、RabbitMQ、RocketMQ、Kafka 等），我们很容易理解错误的地方在于，认为他们两个是一类，但是它们应用的场景与范围完全不一样。

首先，需要明白的是 MQTT 只是一个应用层的协议，与之可以对比的是消息队列中的 AMQP 协议，MQTT Broker 则对应各种消息队列。

1.  云端的消息队列中间件通信协议更复杂，并且不需要考虑复杂的网络条件，但是 MQTT 则简单很多，对内存、网络的资源要求更低；
2.  云端的消息队列中间件通信协议需要储存消息，没有客户端订阅的话，会一直储存，用来达到暂存消息、削峰填谷的目的，但是 MQTT 则不需要存储，遇到客户端没有订阅的情况，就会直接丢弃；
3.  MQTT 客户端只要订阅了有数据的主题，都会收到，但是消息队列则不一定，不仅队列需要先创建，而且在多个客户端订阅同一个队列的情况下，每个消息只会由一个客户端收到；

说到这里，其实他们可以配合起来使用，比如设备通过 MQTT 协议将数据传送至服务器后，放到消息队列进行缓存，防止服务器无法及时处理而丢失数据。

话说回来，其实 ActiveMQ [支持 MQTT](https://activemq.apache.org/mqtt)， RabbitMQ 也支持 MQTT，详细情况请看 [MQTT Adapter](https://blog.rabbitmq.com/posts/2012/09/mqtt-adapter)。

### Topic

MQTT 里面的 Topic 很容易理解，可以把它与 HTTP 协议或者 Linux 中的路径来对待，但是需要把第一个 “根目录” 给去掉，因为这在 MQTT 中代表一个空的根目录。

你可以在有权限的情况下，发送任意数据到任何 topic，也可以订阅但是需要注意三个符号：

1.  '+' 表示匹配配单级目录，它只能放在相邻目录，即不能与其它字符组成一个目录；
    1.  合法的例子：
        1.  a/b/c/+
        2.  a/+/c
        3.  a/+/c/+/e
    2.  不合法的例子
        1.  a/b/c+
        2.  a+
        3.  a/+b
2.  '#' 表示匹配多级目录，它只能是订阅主题的最后部分，前面如果有内容，则必须有一个 '/'，你也可以理解为订阅含有它前面内容作为前缀的所有主题；
    1.  合法的例子
        1.  # 
        2.  a/#
        3.  a/b/c/#
    2.  不合法的例子
        1.  a#
        2.  \#a
        3.  \#/a/b
3.  '$' 这是保留的内部主题前缀，即使你用单独一个 '#' 去订阅，Broker 也不会给你发送，必须要明确订阅后才会收到，比如常见的 [`$SYS 主题`](https://github.com/mqtt/mqtt.org/wiki/SYS-Topics)；

另外需要提一句，除了测试，尽量不要订阅 '#' 的主题，当客户端发送数据量太大时，大概率会出问题。

### 例子

在继续之前，你最好是搭建一个自己的本地测试 Broker，这样的话，可以尽量避免被公共服务器上面，其他人的消息干扰。

下面我们以 Go 为例来说明消息发布与接收。

目前最常用的库是 [paho.mqtt.golang](github.com/eclipse/paho.mqtt.golang)，我们可以直接使用 `go get github.com/eclipse/paho.mqtt.golang` 来获取。

作为 MQTT 客户端，第一件要做的时间，便是建立连接。

```go
opts := mqtt.NewClientOptions().
  AddBroker("tcp://localhost:1883").
  SetClientID("test-client-id")

c := mqtt.NewClient(opts)
if token := c.Connect(); token.Wait() && token.Error() != nil {
  panic(token.Error())
}

defer c.Disconnect(250)

time.Sleep(time.Second)
```

在上面的例子中，我们用最简单的选项建立了连接，并且在一秒后断开了连接。如果对这里的选项感兴趣，可以看下代码 [MQTT Client options](https://github.com/eclipse/paho.mqtt.golang/blob/04f56444eae54291f9194f479bb4185b4d7f17ed/options.go?_pjax=%23js-repo-pjax-container%2C%20div%5Bitemtype%3D%22http%3A%2F%2Fschema.org%2FSoftwareSourceCode%22%5D%20main%2C%20%5Bdata-pjax-container%5D#L101)，里面的默认选项也能一目了然。

然后，便是发布与订阅，下面便是一个非常简单的例子：

```go
{
    token := c.Subscribe("testtopic/#", 0, func(c mqtt.Client, m mqtt.Message) {
		fmt.Println(string(m.Payload()))
	})
    token.Wait()
    if token.Error() != nil {
	   fmt.Println(token.Error())
	   os.Exit(1)
    }
}

{
    token := c.Publish("testtopic/123", 0, false, "Hello world")
    token.Wait()
}

time.Sleep(10 * time.Second)
```

或者，你也可以按照第一篇文章里面的内容，尝试联动下发布与订阅，比如程序上发送数据，在桌面客户端中接收，反之亦然。

### 最后

在这次的入门篇里面，我们忽略了连接时的参数，也忽略了发布订阅时的 `QoS` 以及 `Retained` 两个参数，这些都是非常重要的细节，它们将会在之后的文章中出现（放心，会让你们的孙辈们通知你们更新的 🙈 ）。


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/181 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
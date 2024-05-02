---
title: 【MQTT 系列】（四）v3.1.1 特性
tags: [MQTT, Golang]
date: 2024-05-02 20:44:51
---


在[上次的文章](/2021/12/11/mqtt-3-sub-pub-and-topics/)中（似乎有那么亿点久了 :P），我们说了 MQTT 的发布订阅相关的功能，这次我们直接来说它的特性。

<!-- more -->

### 服务质量

QoS 有三个级别，分别用 0、1、2 来表示，代表的意义如下：

- **QoS 0**: 最多一次，类似于 UDP 数据包，只管发送，不保证到达。这是最简单的服务级别，有可能丢失消息。由于其高性能，此级别适合用于周期性的传感器数据上报。；
- **QoS 1**: 至少一次，这意味着消息至少会被发送一次，即使在网络不稳定的情况下也能保证消息的到达，性能稍差，比较适用于不在意重复（接收端做了重复数据的处理），但却在意数据需要确保送达的场景；
- **QoS 2**：刚好一次，这是最高的级别，保证消息既不会丢失，也不会重复（不过事情没有绝对，还是有概率会丢失数据），显然这种方式的性能是最差的，比较适用于对消息的重复性有严格要求的场景，比如航空航天等；

在常见的家庭、办公室以及工业物联网场景中，我们常用的只有 QoS 0 跟 1 级别，QoS 2 这个级别由于性能差，用的比较少，而且对于数据比较重要的场景，我们也完全可以在接收端进行重复数据的处理即可，性能高了很多。并且，我们也完全用 QoS 0 在应用层实现自己的消息重发机制来实现消息的不丢失。

另外，除了 QoS 0，其它两个级别都需要用到客户端的存储来进行消息的重发机制，因此如果本地有多个客户端实例的情况下，需要注意给它们分配不同的存储区域，不然会导致冲突以及错误。

比如在 [paho.mqtt.golang](https://github.com/eclipse/paho.mqtt.golang) 中，默认使用 [MemoryStore](https://github.com/eclipse/paho.mqtt.golang/blob/fe38f8024a1a2edb07fec9906f5a4389cd1262b6/memstore.go) 来作为 `Store` 使用，但是如果你用了它的 [FileStore](https://github.com/eclipse/paho.mqtt.golang/blob/fe38f8024a1a2edb07fec9906f5a4389cd1262b6/filestore.go)，我们需要制定不同的文件夹路径来解决这个问题。

### 保持会话

保持会话是指客户端在断开连接之后，可以恢复到之前的会话状态，而不是丢失所有未处理的消息。显然，这对于需要长期连接到网络的物联网设备而言非常重要，它们所处的环境可能非常糟糕，需要在网络中断后恢复。保持会话就允许设备可以在重新连接时从上次断开的位置重新开始，防止处理重复的数据以及丢失数据。

跟这个特性相关的配置就是 `CleanSession`，具体的原理也很容易理解， Broker 会在客户端连接的时候就确认客户端是不是需要保持会话，即是不是设置了 `CleanSession=false`，需要保持会话的时候， Broker 会存储以下信息：

1. 会话本身的信息，包含一些连接时候的参数；
2. 客户端的订阅信息；
3. 消息：
    1. QoS 1&2 未被客户端确认的消息；
    2. QoS 1&2 离线时候的新消息；
    3. QoS 2 的未完成确认的消息；

同时，客户端也会存储 QoS 0 之外的消息：
1. QoS 1&2 未被 Broker 确认的消息；
2. QoS 2 的未完成确认的消息；

显然，由于 [paho.mqtt.golang](https://github.com/eclipse/paho.mqtt.golang) 默认使用 `MemoryStore`，这里你需要特别注意下，改成 `FileStore`。

这里需要注意的地方：

- 离线期间的数据可能会比较多（根据你的业务来计算），那么在客户端恢复连接的时候，可能会有大量的数据需要处理，需要考虑设备的性能进行接收的限制。或者，如果你不想处理离线期间的消息，即能接受它们的丢失，那么设置 `CleanSession=true` 会更适合你；
- 出了发送的 QoS，还有接收的 QoS，而这时候如果两者不一样，就会出现降级，即按低的 QoS 来处理；

### 保留消息

这一功能常被误解且被滥用。许多人误以为它用于存储消息，而实际上，保留消息确保每个主题（Topic）仅保存最新的一条消息。

保留消息是在发送的时候设置，用来告诉 Broker 当前这个消息是否需要保留，我们可以从代码中看到，`retained` 是发送的第三个参数，往往我们会设置它为 `false`，在需要的时候会设置它为 `true` 。

```go
type Client interface {
   // ...
   
	Publish(topic string, qos byte, retained bool, payload interface{}) Token

	// ...
}
```

保留消息最常见的使用场景包括：

- **设备状态更新**：例如，一个智能家居系统中的灯光控制器发布一个状态更新消息，所有订阅了这个主题的客户端（如手机应用或其他控制器）都能立即知道灯光的当前状态，当然还有个最重要的状态也可以使用：设备的上下线状态；
- **通知系统**：在一个通知系统中，当有新通知发布时，保留消息可以确保所有在线的用户都能立即看到最新的通知，而无需等待下一次心跳检查或订阅更新；
 
需要注意的地方：

- 跟使用 QoS 1&2 需要注意离线期间的消息一样，订阅 Retained 相关的主题时，也需要注意，如果你订阅了一大堆的主题都有 Retained 消息，那么在订阅成功的那一刻，就会有大量的消息从 Broker 发送过来（这点也跟 Broker 相关，它们往往也会限制已订阅主题的 Retained 消息数量）；
- 如果想要删除 Retained 消息，给相同主题发送一个空的消息即可，一般来说除非你发送错了，比如把一个消息误标记成 Reatained 消息了，大多数情况下你并不需要删除，因为后一个消息总是会覆盖前一个消息；


### 遗嘱消息

遗嘱消息，顾名思义就是客户端下线之后留下的消息。简单来说就是客户端设置的，能够让 Broker 在检测到客户端断连时，向指定的 Topic 发送指定消息的一种功能。它最适合的应用场景就是客户端断连时，给相关的 Topic 发送一个下线消息，而其它客户只要订阅这个 Topic 便能及时获取其它客户端的下线通知。

在 [paho.mqtt.golang](https://github.com/eclipse/paho.mqtt.golang) 中涉及到的几个连接配置参数如下，就如同人留下遗嘱的时候是生前，MQTT 协议中，留遗嘱是在连接的时候设置：

```go
WillEnabled             bool
WillTopic               string
WillPayload             []byte
WillQos                 byte
WillRetained            bool
```

可以看到，它需要的参数跟正常的消息一样，如果配合 Retained，就能简单实现设备的上下线通知消息了，不过需要注意的是，配置好的消息其实是由 Broker 代替客户端完成的，毕竟发送这条消息的时候，客户端处于离线状态。

### 保活协议以及客户端接管

这其实是为了解决 TCP 的「半开」问题，所谓的半开就是理论上 TCP 本身虽然有断开的通知机制，但是实际情况下，还是会出现一方断开，却不通知另一方的情况出现，在 MQTT 协议中，从前往往是手机或者卫星连接时出现，而如今更多的情况是物联网设备断电的情况下出现。

因此 MQTT 协议就有 `KeepAlive` 选项，于是客户端需要跟 Broker 协商一个心跳周期，来检测对方是否在线，在这个周期内，如果客户端跟 Broker 之间有消息交换，那么心跳包没必要发送，但是一旦在这个周期内，客户端没有其它消息交换，客户端就必须发送一个心跳包来告诉 Broker 自己仍然在线。对应的，如果 Broker 在一个半的心痛周期内没有收到心跳包，那么就可以认为客户端已经离线，需要主动断开。同样的，如果客户端没有在一个合理的时间范围内（即 `PingTimeout`）收到 Broker 的心跳回复包，那么也需要主动断开连接。

不知道你有没有意识到一个问题，那就是如果 Broker 在没有断开客户端连接的情况下，比如心跳周期很长，但是 TCP 连接已经处于半开了，但是客户端却已经在重连了，如果这时候客户端重连成功，是不是意味着会出现客户端跟 Broker 产生多个 TCP 连接？但现实却不会出现这个问题，因为 MQTT 协议中，需要设置 ClientId，同一个 ClientId 跟 Broker 最多只能保持一个连接，后一个连接会接管前一个连接，即把前一个连接踢下线，这就是所谓的客户端接管。

在 [paho.mqtt.golang](https://github.com/eclipse/paho.mqtt.golang) 涉及到的几个参数如下：

```go
ClientID                string
KeepAlive               int64
PingTimeout             time.Duration
```

从它的[源码](https://github.com/eclipse/paho.mqtt.golang/blob/fe38f8024a1a2edb07fec9906f5a4389cd1262b6/options.go#L134)可以看到，默认的心跳周期是 30 秒，而心跳的超时时间为 10 秒。

### 总结

总的来说，MQTT 协议的这些特性使其能够高效地支持各种物联网应用场景，包括资源受限的远程设备、不可靠网络环境、实时数据分发等。了解和正确使用这些特性，有助于构建更加可靠和高效的物联网系统。

同时，我也相信，了解了协议细节的你，能够在使用到这个协议时，更加专业，少犯一些低级错误：

- 实现客户端，对接服务端的时候：
    * 把 Retained 认为是服务端需要保留的数据；
    * 忽略场景，将所有发送的消息的 QoS 设置为 2；
- 实现服务端，对接客户端的时候：
    * 要求对方实现应用层的心跳协议；
    * 责怪对方发送消息频率太高了，客户端解释它最多一分钟上报一次消息（这里给你留个课后作业，为什么？）；

我们这次只说明了 MQTT v3.1.1 的特性，事实上 MQTT 还有 v5 特性，我会在下次再继续讲解。

### Refs

- [What is MQTT Quality of Service (QoS) 0,1, & 2? – MQTT Essentials: Part 6](https://www.hivemq.com/blog/mqtt-essentials-part-6-mqtt-quality-of-service-levels/)
- [Understanding Persistent Sessions and Clean Sessions – MQTT Essentials: Part 7](https://www.hivemq.com/blog/mqtt-essentials-part-7-persistent-session-queuing-messages/)
- [What are Retained Messages in MQTT? – MQTT Essentials: Part 8](https://www.hivemq.com/blog/mqtt-essentials-part-8-retained-messages/)
- [What is MQTT Last Will and Testament (LWT)? – MQTT Essentials: Part 9](https://www.hivemq.com/blog/mqtt-essentials-part-9-last-will-and-testament/)
- [What Is MQTT Keep Alive and Client Take-Over? – MQTT Essentials Part 10](https://www.hivemq.com/blog/mqtt-essentials-part-10-alive-client-take-over/)
---
title: (MQTT Series) Part 4 - v3.1.1 Features
tags: [MQTT, Golang]
date: 2024-05-02 20:44:51
lang: en
---

In [our last article](/2021/12/11/mqtt-3-sub-pub-and-topics/) (which feels like ages ago :P), we discussed MQTT's publish-subscribe functionality. This time, let's go straight into its features.

<!-- more -->

### Quality of Service

QoS has three levels, represented by 0, 1, and 2, with the following meanings:

- **QoS 0**: At most once, similar to UDP packets, send it and don't guarantee delivery. This is the simplest service level and may lose messages. Due to its high performance, this level is suitable for periodic sensor data reporting.
- **QoS 1**: At least once, this means the message will be sent at least once, even in unstable network conditions, ensuring the message arrives. It has slightly poorer performance and is suitable for scenarios where duplicates are handled (redundant data processed at the receiver's end) but reliable delivery is needed.
- **QoS 2**: Exactly once, this is the highest level, ensuring the message neither gets lost nor duplicates (although nothing is absolute, there is still a chance of data loss). Obviously, this method's performance is the worst and is suitable for scenarios where strict requirements on message duplication are necessary, such as in aerospace.

In common home, office, and industrial IoT scenarios, we mostly use QoS levels 0 and 1. QoS 2 is less used due to poor performance, and for important data scenarios, we can simply handle duplicate data on the receiver's end, which greatly improves performance. Additionally, we can use QoS 0 and implement our own message retransmission mechanism at the application layer to ensure no message loss.

Furthermore, besides QoS 0, the other two levels require client storage for message retransmission mechanisms. Therefore, if there are multiple client instances locally, it is necessary to allocate different storage areas for them to avoid conflicts and errors.

For example, in [paho.mqtt.golang](https://github.com/eclipse/paho.mqtt.golang), [MemoryStore](https://github.com/eclipse/paho.mqtt.golang/blob/fe38f8024a1a2edb07fec9906f5a4389cd1262b6/memstore.go) is used by default as the `Store`. However, if you use its [FileStore](https://github.com/eclipse/paho.mqtt.golang/blob/fe38f8024a1a2edb07fec9906f5a4389cd1262b6/filestore.go), you need to specify different folder paths to solve this problem.

### Session Persistence

Session persistence means that after a client disconnects, it can resume the previous session state instead of losing all unprocessed messages. Obviously, this is very important for IoT devices that need to be connected to the network for a long time and may be in very poor environments. Session persistence allows the device to resume from where it was disconnected upon reconnection, preventing duplicate data processing and data loss.

This feature is related to the `CleanSession` configuration, and its principle is easy to understand. The Broker confirms whether the client needs to maintain a session, i.e., whether `CleanSession=false` is set, during client connection. When a session is maintained, the Broker stores the following information:

1. Session information itself, including some connection parameters;
2. Client subscription information;
3. Messages:
   1. QoS 1&2 messages not confirmed by the client;
   2. QoS 1&2 new messages when offline;
   3. QoS 2 messages not completed confirmation;

Meanwhile, the client also stores messages outside QoS 0:
1. QoS 1&2 messages not confirmed by the Broker;
2. QoS 2 messages not completed confirmation;

Obviously, since [paho.mqtt.golang](https://github.com/eclipse/paho.mqtt.golang) uses `MemoryStore` by default, you need to pay special attention to changing it to `FileStore`.

### Retained Messages

This feature is often misunderstood and misused. Many people mistakenly believe it is used for storing messages, but in fact, retained messages ensure that each topic only keeps the latest message.

Retained messages are set during sending to tell the Broker whether the current message needs to be retained. We can see from the code that `retained` is the third parameter sent, which we usually set to `false`, setting it to `true` when needed.

```go
type Client interface {
   // ...
   
	Publish(topic string, qos byte, retained bool, payload interface{}) Token

	// ...
}
```

Common uses of retained messages include:

- **Device status updates**: For example, a light controller in a smart home system publishes a status update message, and all clients subscribing to this topic (like mobile apps or other controllers) can immediately know the current status of the lights, and importantly, the device's online/offline status;
- **Notification systems**: In a notification system, when a new notification is published, retained messages ensure that all online users can see the latest notification immediately, without waiting for the next heartbeat check or subscription update.

Considerations:

- As with offline messages with QoS 1&2, be careful when subscribing to topics with retained messages. If you subscribe to a bunch of topics that have retained messages, at the moment of successful subscription, a large amount of messages will be sent from the Broker (this also depends on the Broker, as they often limit the number of retained messages for subscribed topics);
- If you want to delete retained messages, send an empty message to the same topic. Generally, unless you sent a message incorrectly marked as retained, you do not need to delete it, as the later message always overrides the previous one.

### Last Will Message

Last will messages, as the name suggests, are messages left by the client after it goes offline. Simply put, it is a feature set by the client that allows the Broker to send a specified message to a specified Topic when it detects the client's disconnection. Its most suitable application scenario is sending an offline message to a relevant Topic when the client disconnects, and other clients just need to subscribe to this Topic to get timely notifications of other clients going offline.

In [paho.mqtt.golang](https://github.com/eclipse/paho.mqtt.golang), the connection configuration parameters involved are as follows, just as one sets a will before passing away, in MQTT protocol, the last will is set at the time of connection.

```go
WillEnabled             bool
WillTopic               string
WillPayload             []byte
WillQos                 byte
WillRetained            bool
```

You can see that the required parameters are the same as for a normal message. If combined with Retained, you can easily implement device online/offline notification messages. However, keep in mind that the configured message is actually completed by the Broker on behalf of the client, since the client is offline when this message is sent.

### Keep Alive Protocol and Client Takeover

This is actually to address the 'half-open' problem of TCP, where 'half-open' means that theoretically, TCP itself has a disconnection notification mechanism, but in practice, it often happens that one side disconnects without notifying the other. In the MQTT protocol, this used to occur frequently with mobile or satellite connections, but nowadays, it is more common with IoT devices disconnecting due to power outages.

Therefore, the MQTT protocol includes a `KeepAlive` option, so the client needs to negotiate a heartbeat cycle with the Broker to check if the other party is online. During this cycle, if there are message exchanges between the client and the Broker, there is no need to send a heartbeat packet. However, if there are no other message exchanges within this cycle, the client must send a heartbeat packet to tell the Broker that it is still online. Correspondingly, if the Broker does not receive a heartbeat packet within one and a half heartbeat cycles, it can consider the client offline and actively disconnect. Similarly, if the client does not receive a heartbeat reply packet from the Broker within a reasonable time frame (i.e., `PingTimeout`), it also needs to actively disconnect.

Have you noticed a problem? If the Broker does not disconnect the client connection, for example, the heartbeat cycle is very long, but the TCP connection is already half-open, and the client is already reconnecting, does it mean that multiple TCP connections between the client and the Broker might occur? But in reality, this will not happen because in the MQTT protocol, a ClientId is required, and the same ClientId can only maintain one connection with the Broker at most. The later connection will take over the previous one, i.e., kick the previous connection offline.

In [paho.mqtt.golang](https://github.com/eclipse/paho.mqtt.golang), the parameters involved are as follows:

```go
ClientID                string
KeepAlive               int64
PingTimeout             time.Duration
```

You can see from its [source code](https://github.com/eclipse/paho.mqtt.golang/blob/fe38f8024a1a2edb07fec9906f5a4389cd1262b6/options.go#L134) that the default heartbeat cycle is 30 seconds, and the heartbeat timeout is 10 seconds.

### Conclusion

Overall, these features of the MQTT protocol enable it to efficiently support various IoT application scenarios, including resource-constrained remote devices, unreliable network environments, and real-time data distribution. Understanding and using these features correctly helps to build more reliable and efficient IoT systems.

At the same time, I believe that with a better understanding of the protocol details, you can be more professional when using this protocol and avoid some common mistakes:

- When implementing a client, interfacing with the server:
    * Considering Retained as data that the server needs to retain;
    * Ignoring the scenario and setting the QoS of all sent messages to 2;
- When implementing a server, interfacing with a client:
    * Requiring the other party to implement an application-layer heartbeat protocol;
    * Blaming the other party for sending messages too frequently, with the client explaining that it reports messages at most once a minute (here's a homework assignment for you, why?);

We've only discussed the features of MQTT v3.1.1 this time. In fact, MQTT also has v5 features, which I will continue to explain next time.

### Refs

- [What is MQTT Quality of Service (QoS) 0,1, & 2? – MQTT Essentials: Part 6](https://www.hivemq.com/blog/mqtt-essentials-part-6-mqtt-quality-of-service-levels/)
- [Understanding Persistent Sessions and Clean Sessions – MQTT Essentials: Part 7](https://www.hivemq.com/blog/mqtt-essentials-part-7-persistent-session-queuing-messages/)
- [What are Retained Messages in MQTT? – MQTT Essentials: Part 8](https://www.hivemq.com/blog/mqtt-essentials-part-8-retained-messages/)
- [What is MQTT Last Will and Testament (LWT)? – MQTT Essentials: Part 9](https://www.hivemq.com/blog/mqtt-essentials-part-9-last-will-and-testament/)
- [What Is MQTT Keep Alive and Client Take-Over? – MQTT Essentials Part 10](https://www.hivemq.com/blog/mqtt-essentials-part-10-alive-client-take-over/)

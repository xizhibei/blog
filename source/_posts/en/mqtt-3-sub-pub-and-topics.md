---
title: (MQTT Series) Part 3 - Publishing Subscribing and Topics
date: 2021-12-12 00:09:19
tags: [MQTT]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/181
---
<!-- en_title: mqtt-3-sub-pub-and-topics --->

Following up on the last introduction (this blogger really drags out the updates :P), let's discuss some basic concepts of MQTT.

### Basic Concepts

In the very simple MQTT Hello World last time, we actually touched on a very important concept: publishing and subscribing.

It's easy to recall from design patterns, indeed, MQTT fundamentally implements an architectural publish-subscribe pattern.

Let's recall, where's the benefit of the publish-subscribe pattern? Decoupling. If the observer pattern is a low coupling between sender and receiver, then the publish-subscribe pattern completely decouples them.

### Difference from Message Queues

Then what comes to mind are the various message queues in distributed applications (such as ActiveMQ, RabbitMQ, RocketMQ, Kafka, etc.), and it's easy to mistakenly think that they are similar, but their application scenarios and ranges are completely different.

First, it's important to understand that MQTT is just an application layer protocol, comparable to the AMQP protocol in message queues, with MQTT Broker corresponding to various message queues.

1.  Cloud message queue middleware communication protocols are more complex and do not need to consider complex network conditions, but MQTT is much simpler and requires less memory and network resources;
2.  Cloud message queue middleware communication protocols need to store messages, which will be stored indefinitely without client subscriptions, serving purposes like message buffering and smoothing peaks and valleys, whereas MQTT does not store messages, directly discarding them if there are no subscribers;
3.  MQTT clients will receive messages as long as they subscribe to a topic with data, but this is not necessarily the case with message queues, not only do the queues need to be created first, but in the case of multiple clients subscribing to the same queue, each message will be received by only one client;

At this point, they can actually be used in combination, such as devices transmitting data to servers via the MQTT protocol, then placing it into message queues for caching to prevent data loss if the server cannot process timely.

Speaking of which, actually, ActiveMQ [supports MQTT](https://activemq.apache.org/mqtt), and RabbitMQ also supports MQTT, see more details in [MQTT Adapter](https://blog.rabbitmq.com/posts/2012/09/mqtt-adapter).

### Topic

Topics in MQTT are easy to understand, you can think of them like paths in HTTP protocol or Linux, but you need to remove the first "root directory" because it represents an empty root directory in MQTT.

You can send any data to any topic if you have the permission, and you can also subscribe, but note three symbols:

1.  '+' represents a single-level directory match, it can only be placed between directories, not combined with other characters;
    1.  Valid examples:
        1.  a/b/c/+
        2.  a/+/c
        3.  a/+/c/+/e
    2.  Invalid examples:
        1.  a/b/c+
        2.  a+
        3.  a/+b
2.  '#' represents a multi-level directory match, it can only be the last part of a subscription topic, if there is content before it, it must have a '/', you can also think of it as subscribing to all topics with its preceding content as a prefix;
    1.  Valid examples:
        1.  # 
        2.  a/#
        3.  a/b/c/#
    2.  Invalid examples:
        1.  a#
        2.  \#a
        3.  \#/a/b
3.  '$' is a reserved prefix for internal topics, even if you subscribe with a single '#', the Broker will not send them to you unless you explicitly subscribe, like the common [`$SYS topics`](https://github.com/mqtt/mqtt.org/wiki/SYS-Topics);

Additionally, aside from testing, try not to subscribe to the '#' topic, as it's likely to cause problems when the client sends too much data.

### Example

Before continuing, it's best to set up your own local test Broker to avoid interference from other people's messages on public servers.

Below, we'll use Go as an example to demonstrate message publishing and receiving.

The most commonly used library currently is [paho.mqtt.golang](https://github.com/eclipse/paho.mqtt.golang), which can be obtained directly by using:

```bash
go get github.com/eclipse/paho.mqtt.golang
```

As an MQTT client, the first thing to do is establish a connection.

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

In the example above, we established a connection with the simplest options and disconnected after a second. If you're interested in the options here, you can see [MQTT Client options](https://github.com/eclipse/paho.mqtt.golang/blob/04f56444eae54291f9194f479bb4185b4d7f17ed/options.go?_pjax=%23js-repo-pjax-container%2C%20div%5Bitemtype%3D%22http%3A%2F%2Fschema.org%2FSoftwareSourceCode%22%5D%20main%2C%20%5Bdata-pjax-container%5D#L101), where the default options are clear at a glance.

Next is publishing and subscribing, below is a very simple example:

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
```

```go
{
    token := c.Publish("testtopic/123", 0, false, "Hello world")
    token.Wait()
}
```

time.Sleep(10 * time.Second)


Alternatively, you can also try linking publishing and subscribing as mentioned in the first article, such as sending data on the program and receiving on the desktop client, and vice versa.

### Finally

In this introductory article, we omitted connection parameters, as well as `QoS` and `Retained` two parameters during publishing and subscribing, which are very important details. They will appear in future articles (rest assured, we will let your descendants notify you of updates 🙈).


***
Originally posted on Github issues: https://github.com/xizhibei/blog/issues/181, feel free to Star and Watch

{% post_link footer_en %}
***

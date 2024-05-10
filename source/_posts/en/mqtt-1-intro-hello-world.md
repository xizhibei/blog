---
title: (MQTT Series) Part 1 - Introduction Hello World
date: 2021-08-29 23:43:27
categories: [MQTT]
tags: [MQTT]
author: xizhibei
lang: en
issue_link: https://github.com/xizhibei/blog/issues/179
---
<!-- en_title: mqtt-1-intro-hello-world -->

### Preface

Over the past two months, I've practically stopped updating, although I've mentioned before that updates would not be timely, but it's the first time it's been delayed this long. I could excuse it by saying I'm busy, especially since my weekends spent on browsing Bilibili have also decreased significantly. This has led to another predicament: I now have material to write about, but these materials are only available when I'm busy, leaving me no time or energy to sort them out.

Nevertheless, the blog must go on, otherwise the accumulated experience and knowledge will remain unorganized.

Yes, I'm starting another series. On one hand, articles in a series appear more systematic and can be more helpful to beginners. On the other hand, it saves me from having to ponder too much on what to write next (which seems to be the real purpose).

### Introduction to MQTT

MQTT is a very simple protocol, originally designed in 1999 by two IBM engineers, Andy Stanford-Clark and Arlen Nipper, for monitoring oil pipelines. It was designed for scenarios with limited bandwidth, lightweight, and very low power consumption. At that time, satellite bandwidth was just so small and painfully expensive.<sup>[1]</sup>

In modern society, although the cost of bandwidth has greatly decreased, there are still many scenarios where this protocol is needed, such as in smart homes (still part of IoT). Many small IoT devices rely on a button cell battery to function for years, making MQTT very suitable as an application layer transmission protocol.

In summary, MQTT is a client-server architecture publish-subscribe messaging transmission protocol. It is very lightweight, open, and simple, making it very easy to implement. These characteristics make it highly suitable for fields like machine-to-machine (M2M) and Internet of Things (IoT), which are limited by small memory and narrow bandwidth.<sup>[2]</sup>

IBM submitted version 3.1 to OASIS in 2013, and in 2014, OASIS made minor changes and released version 3.1.1.

In 2019, OASIS added many features to MQTT, such as better error handling, shared subscriptions, message content types, etc., and upgraded to version 5. These features will be discussed in dedicated chapters later on.

### Hello World

First, you need an MQTT Broker. Install mosquitto … oh? You don't know what that is? Okay, let's try a simpler approach.

First, we can use some public ones, like China's EMQ (Hangzhou Yingyun Technology Co., Ltd.) provides broker.emqx.io (I must advertise for domestic software here, their MQTTX client is the most user-friendly I've used so far, and the Broker's features are also very powerful, I plan to specifically introduce server setup in a separate article).

Then, their [MQTTX client](https://mqttx.app/), implemented in Electron, supports all platforms, just download and use.

Open the MQTTX client, let's start a simple test.

1.  Click the + on the left sidebar to create a connection (this +, I think does not conform to interaction logic, as a creation button it should be a different level from other buttons, better placed together with new group creation);
2.  A creation page will then pop up, fill in a name randomly, and click connect. If there are no network issues, you should be able to connect successfully (see, they know you're lazy, all the details like Broker address and port are filled in for you, which is also very valuable for us making tech products, on how to let users start using the product with the lowest cost);
3.  Now, let's create a subscription, click add subscription on the page, in the popup dialog, fill in a somewhat random topic like `test/907839342134` to avoid conflicts with others, as this is a public Broker, then click confirm.
4.  Finally, let's publish a message. In the bottom left corner, there's an input box prompting you to enter a Topic, we enter `test/907839342134`, and in the content box below it, enter `{"hello": "world"}`, click the paper airplane below, and after sending, you will see that you have received the message you sent to yourself.

![mqttx](/media/16253875626915/16302244840845.jpg)

That's it for now, a very simple introduction. In the next installments, I will introduce MQTT concepts, principles, and practical applications in more detail.

### Ref

1.  [MQTT][1]
2.  [MQTT Version 3.1.1 Plus Errata 01][2]

[1]: https://en.wikipedia.org/wiki/MQTT

[2]: http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/mqtt-v3.1.1.html


***
Originally posted on Github issues: https://github.com/xizhibei/blog/issues/179, feel free to Star and Watch

{% post_link footer_en %}
***

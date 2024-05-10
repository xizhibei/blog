---
title: (MQTT Series) Part 2 - Setting Up a Broker
date: 2021-10-31 20:17:30
categories: [MQTT]
tags: [DevOps, MQTT]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/180
---
<!-- en_title: mqtt-2-mosquitto-broker-setup -->

Another hiatus, two months. 🙈

In my last [introduction](https://github.com/xizhibei/blog/issues/179), I briefly mentioned how to use a public Broker for testing. Obviously, you can't use a test server as a production environment server; you need one of your own.

### Mosquitto

Mosquitto is arguably the most famous open-source MQTT Broker, with just enough functionality. Some advanced features like permission management require the installation of plugins, or even custom plugin development to extend its capabilities.

It also offers a public Broker for testing: <https://test.mosquitto.org/>

Installing it is very straightforward, just install the appropriate package, for example, on Mac `brew install mosquitto`, and on Linux `sudo api install mosquitto`. If you prefer Docker, the official image is `eclipse-mosquitto`. I'll skip the running details and focus mainly on its configuration<sup>[1]</sup>:

Listening on the default unencrypted port 1883:

```
    listener 1883 0.0.0.0
```

If you don't want to configure user password login, here you can configure to allow anonymous connections, meaning no user password:

```
    allow_anonymous true
```

But if you configured to disallow anonymous access, then you need to set up username and password. The user password in this file can be configured using the tool provided by mosquitto: `mosquitto_passwd mosquitto/config/pwfile username`, and then follow the prompt to enter the password.

Additionally, you need to add this line in the configuration file:

```
    password_file /mosquitto/config/pwfile
```

Furthermore, if you need to restrict permissions for each user, you need to configure an ACL:

```
    acl_file /mosquitto/config/aclfile
```

This configuration is simple, it supports three syntaxes:

1.  `topic [read|write|readwrite|deny] <topic>`, this can set permissions for anonymous client topics;
2.  `user <username>`, this is used in conjunction with topic permissions;
3.  `pattern [read|write|readwrite] <topic>`, this can be used for individual user permissions, where `<topic>` can contain `%c` representing the logged-in Client ID and `%u` representing the username;

Here's an example:<sup>[2]</sup>

Allow anonymous users to read all user-level topics:

```
    topic read #
    topic read $SYS/broker/messages/#
```

Allow user 'web' to read all topics:

```
    user web
    topic read #
    topic read $SYS/#
```

Clearly, this level of permissions only satisfies the most basic requirements. If you need to integrate with your platform to implement dynamic login authentication, you would need to use an auth_plugin. One officially recommended plugin is [mosquitto-go-auth](https://github.com/iegomez/mosquitto-go-auth).

##### Clustering

Mosquitto itself does not support cluster deployment, but it can be implemented through the backend, see [MQTT server support](https://github.com/mqtt/mqtt.org/wiki/server-support) for details.

##### TLS Certificates

With increasing national requirements for privacy protection, encrypted transmission is becoming an increasingly important component, meaning all personal information transmission must be encrypted.

For MQTT, HTTPS certificates can be used because fundamentally, they are both TLS certificates and thus can be applied to MQTT as well.

If you use a certificate issued and signed by an authoritative CA, simple configuration would be:

```
    listener 8883 0.0.0.0
    certfile /path/to/certs/example.com.cer
    keyfile /path/to/certs/example.com.key
```

But if using a self-signed certificate, the client connection process is a bit more complex, requiring proper CA configuration.

Like [HTTPS mutual authentication](https://github.com/xizhibei/blog/issues/159), MQTT can also use mutual authentication. In this case, when a client connects, the server will require the client to provide a certificate and use your configured CA certificate to verify the client certificate's signature.

```
    cafile /path/to/certs/ca.pem
    require_certificate true
```

##### Testing

Once setup is complete, you can perform simple tests using a client. However, after a basic test, most people might think it's ready for full use, but you can do more to ensure reliability.

For instance, you might estimate the number of client connections you need, the number of messages, concurrency, and message sizes to get a general range, and then perform benchmark testing.

I used the [MQTT benchmarking tool](https://github.com/krylovsk/mqtt-benchmark), which easily tests the stress your newly setup Broker can handle.

It's fairly user-friendly; if you've used HTTP benchmarking tools like Apache Bench, you'll quickly get the hang of it. For example, from its homepage, a typical scenario is 10 clients, each sending 100 consecutive messages:

```bash
mqtt-benchmark --broker tcp://broker.local:1883 --count 100 --clients 10 --qos 1 --topic house/bedroom/temperature --payload {\"temperature\":20,\"timestamp\":1597314150}
```

In the output, you'll see the results of the test and can identify potential issues that were not apparent during setup. Although spending an extra hour or two might seem wasteful, discovering these issues after some usage would cost much more than these additional hours. Plus, I believe the difference between engineers isn't just in speed but in such professional diligence.

### P.S.
You could also consider using a paid service to avoid maintenance labor and server costs. For instance, you could choose commercial Brokers like China's EMQX and international HiveMQ. They support both commercial and open-source versions, and you can either set up on your own servers or use their provided servers. Being commercially supported, they offer more robust features and generally a better experience.

### Ref

1.  [mosquitto-conf][1]
2.  [mosquitto-mqtt][2]

[1]: https://mosquitto.org/man/mosquitto-conf-5.html

[2]: https://troy.dack.com.au/mosquitto-mqtt/


***
Originally posted on Github issues: https://github.com/xizhibei/blog/issues/179, feel free to Star and Watch

{% post_link footer_en %}
***

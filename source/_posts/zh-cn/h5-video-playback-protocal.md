---
title: 网页视频播放：协议篇
date: 2019-12-02 17:38:23
tags: [总结,业务,视频直播]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/126
---
<!-- en_title: h5-video-playback-protocal -->

最近一两周折腾了监控视频的方案，现在把过程中涉及到的知识总结一下，希望对后来的你有帮助。

### 前言

起初是为了客户端可以跨平台使用，但是我们又不想折腾不同平台的 UI 库，Qt 之类的跨平台库虽然不错，只是它的设计太丑，无法入我法眼。这时候 Electron 方案走进了我们的视线：可以用 Web UI，而 Web UI 的设计又有非常多可供挑选，于是，我们就选了它，然后，问题来了：如何在网页上播放视频。

其实可供选择挺多，只是其中很多的方案已经或将会不可用，比如 vlc 插件不被支持以及 flash 播放器将会不可用。于是我们需要优先选择原生的方案，即不需要插件，并且基于 HTTP 的方案。

于是，为了在网页上看到摄像头的视频，我们首先需要从摄像头获取数据源，然后经过处理（一般无法直接播放，我们需要转码、转协议等），最后提供一个链接给网页上的播放器使用。

在这个过程里面，我们大致需要知道如下几个协议：

1.  RTSP/RTMP
2.  HLS/DASH
3.  HTTP-FLV
4.  WebRTC

限于篇幅，今天只是介绍几个协议，之后再介绍具体的方案以及实现。

### 几个协议的科普

下面来简单说说这几个协议。之后的文章还会补上实战的一些内容。

#### RTSP/RTMP

RTSP 协议：这是目前主流摄像头都支持的视频流协议，能够支持获取实时的视频，尤其是安防监控领域。

RTMP 协议：Macromedia 发明，后被 Adobe 收购，主要用在 flash 播放器上的私有协议，得益于 flash 的普及，因此在浏览器视频播放领域有先发优势，支持范围广，进而成为了目前大多数直播服务、CDN 服务都支持的一种视频流协议。

他们两者都无法直接被浏览器使用，RTMP 需要 flash 播放器，而 RTSP 需要把底层协议转成 WebSocket。（另外，再提醒下：[Adobe 早就宣布在 2020 年底停止支持 flash 了](https://language.chinadaily.com.cn/2017-07/31/content_30266780.htm)。）

这里放几个拓展阅读链接：

1.  [Real Time Messaging Protocol](https://en.wikipedia.org/wiki/Real-Time_Messaging_Protocol)
2.  [Real Time Streaming Protocol](https://en.wikipedia.org/wiki/Real_Time_Streaming_Protocol)

#### HLS/DASH

HLS 全称是 Http Live Streaming，是苹果发明的协议，用来取代 flash，但是它一点也不 Live，延迟通常高达 10s 以上，DASH 也是一路货色，因此这俩几乎只能用来点播视频。

它们的大致原理是把视频流切成合适的大小，比如 10s 一个片段 (ts 文件)，然后将路径写入一个专门的索引文件中，客户端首先请求这个索引文件 (.m3u8)，来获取里面视频的路径，拼凑成地址，再请求片段地址，下载后在本地播放。更新就很简单了，服务器一直不停写索引文件，而客户端一直不停请求索引文件即可。

相信你了解了之后，就会明白延迟来自于何处了：

1.  至少两次请求才能开始播放；
2.  一直不停请求索引文件以及 ts 文件所造成的服务器资源消耗；
3.  以及最关键的：ts 文件写完之后才能下发给客户端，比如上面提到的 10s 一个片段，那么至少是 10s 之后才能下发；

聪明的同学在这个时候应该已经想到可以通过 WebSocket 和 HTTP/2 来减少 HLS 的延迟，苹果当然也想到了：

苹果在 WWDC 2019 宣布了新的 Low-Latency HLS 协议，能够大大降低延迟：
[Protocol Extension for Low-Latency HLS](https://developer.apple.com/documentation/http_live_streaming/protocol_extension_for_low-latency_hls_preliminary_specification)，实际上，它就是利用 HTTP/2 的新特性来达到这个目的。

只是，小分片带来的大量小文件碎片是存储的灾难，目前仍然不适合使用。

什么，你说 DASH？哦，差点忘了，其实它是 MPEG 的同志们牵头发起的国际标准，除了苹果公司之外，各大公司支持的一种与 HLS 类似的协议。目前大部分线上视频点播的服务器，都会用它来提供服务，比如 B 站<sup>[1]</sup>。

这里再放几个拓展阅读链接：

1.  [Dynamic Adaptive Streaming over HTTP](https://en.wikipedia.org/wiki/Dynamic_Adaptive_Streaming_over_HTTP)
2.  [HTTP Live Streaming](https://en.wikipedia.org/wiki/HTTP_Live_Streaming)
3.  [MPEG-DASH - An Overview](https://www.encoding.com/mpeg-dash/)

#### HTTP-FLV

得益于 [flv.js](https://github.com/bilibili/flv.js) 的横空出世，有着充分利用了浏览器的硬件加速以及 FLV 格式视频的特点，目前大部分网页直播都是选择这个协议了。

它实际上与 RTMP 传输的内容几乎一致，都属于 [flv 文件的 Tag](https://en.wikipedia.org/wiki/Flash_Video)。但是它的好处在于 80 端口直接穿透防火墙，以及更少的状态交互，造成的延迟也就更低。<sup>[2]</sup>

这个也是目前我们选择的协议，毕竟它也是目前最成熟的方案。

#### WebRTC

目前是所有协议里面，延迟最低的，可以做到实时，它原本就是用来实现视频聊天功能的，并且因为它使用了 P2P 技术，可以使客户端可以直接互相连接，而不需要通过服务端转发音视频。

我们将服务端作为一个 Peer 即可实现服务器转发直播的功能，毕竟我们可能需要在服务器处理视频，以及直播情况下，是一个一对多的场景，一个浏览器发送端带不起那么多的接收端。不过，由于它仍处于发展阶段，仍然不成熟，目前市场的接受度不高。

WOWZA 在它的 [Low Latency Streaming](https://www.wowza.com/low-latency) 中对现有的各种视频播放协议进行了一些比较。

### Ref

1.  [Bilibili - 我们为什么使用 DASH][2]
2.  [H5 直播系列四 RTMP HTTP-FLV HLS MPEG-DASH][1]

[1]: https://www.bilibili.com/read/cv855111/

[2]: https://www.jianshu.com/p/a9c2db7b1fb9


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/126 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
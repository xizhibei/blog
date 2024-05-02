---
title: RTSP 协议详解
date: 2020-10-26 18:40:03
tags: [视频直播]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/152
---
<!-- en_title: rtsp-explain -->

当我们谈到 RTSP 的时候，其实不仅仅是 RTSP 协议本身，我们其实不可避免会谈到以下几个协议：

-   RTP (Real-time Transport Protocol)：真正用来传输音频视频的协议，一般是建立在 UDP 协议的基础上，特别需要注意的是，它使用偶数端口<sup>[1][Real-time Transport Protocol]</sup>；
-   RTCP (Real-time Control Protocol)：RTP 的姊妹协议，通过周期性发送统计信息，提供服务质量（QoS）的反馈，它使用的端口是奇数，而且就是 RTP 端口 +1<sup>[2][RTP Control Protocol]</sup>；
-   SDP (Session Description Protocol)：是应用层的一个协议，也可以说事一个格式，跟 HTML、JSON 之类的算是同一类（在今天的文章里就简单带过了）<sup>[3][Session Description Protocol]</sup>；

<!-- more -->

这里相信你也能看出一些内容了，比如其实 RTSP 协议本身不负责播放，只负责交互控制，RTP 以及 RTCP 才是真正的视频传输。

下面我们将其中的详细内容展开来说说，并且会用实际的例子来说明。

### 几个协议的详细介绍

在 Web 开发的时候，我们经常会使用到各种 HTTP 抓包工具，但是，作为一个有追求的工程师，你应该学会使用 WireShark，这是一款强大免费的网络抓包分析工具，它可以让我们看清楚，我们每天在使用的协议究竟是什么样的。

打开 WireShark （安装的过程就略过了，相信你可以自己搞定的），选择你电脑正在使用的网络端口，比如 Linux 可能是 eth0，Mac 是 en0 ，双击就能进入抓包。

接着在 WireShark 的筛选栏里，填入 `rtsp || rtcp || rtp` 这样，我们就能够把一些无关的协议过滤掉。

在继续之前，你还需要准备的是，一个 RTSP 服务器，我这里准备的是一个网络摄像头，另外就是本地的 RTSP 播放器，比如我就是用 VLC 来播放的。如果你身边暂时没有可用的，也可以临时造一个，可以看看 [rtsp-simple-server](https://github.com/aler9/rtsp-simple-server) 里面介绍的。

当然，还有客户端，我们可以直接用各种播放器（如 VLC）来播放 RTSP 视频源，或者你可以使用命令行， 比如 FFMpeg 的 ffplay：

```bash
ffplay rtsp://192.168.1.100/live
```

如果你跟我一样使用 VLC：点击打开媒体 -> 网络，然后在 URL 中填入视频源，点击打开就开始播放了，过几秒钟后点击停止播放。

#### 整体通信过程总览

下面两张图就是我用 VLC 播放以及停止之间发生的网络通信抓包，其中 192.168.2.31 是网络摄像头，而 192.168.2.115 则是我的电脑，即播放器所在的电脑。

![通信抓包 1](https://blog.xizhibei.me/media/16031752728797/16036923034941.jpg)

![通信抓包 2](https://blog.xizhibei.me/media/16031752728797/16036924099950.jpg)

需要注意到的部分：

1.  这次忽略了暂停（PAUSE），以及其它比如 GET_PARAMETER，SET_PARAMETER；
2.  在 PLAY 请求的回复之前，我们看到了一个 RTCP 以及 RTP 请求，这说明，在回复之前，播放源已经开始传输播放数据；
3.  在后续不断的 RTP 中，有些数据包带有 Mark 字样，这是由于视频数据过大造成了分包；

#### RTSP 协议

接下来，让我们通过实际抓包的内容来作具体说明。

##### OPTIONS 请求

首先，客户端会发送一个与 HTTP 协议很类似的 RTSP 协议到 192.168.1.100 的 554 端口，是一个 OPTIONS 请求，即列出这个播放源可用的请求，注意 CSeq，每个 RTSP 请求都会带上，这样，服务端的回应就会跟客户端一一对应起来（这不就是 HTTP）。

![OPTIONS 请求](https://blog.xizhibei.me/media/16031752728797/16036926311878.jpg)

然后服务器就会回应：

![OPTIONS 回复](https://blog.xizhibei.me/media/16031752728797/16036926489106.jpg)

如上，服务器告诉客户端，可以使用 DESCRIBE, SETUP, TEARDOWN, PLAY, PAUSE 等几个请求。

##### DESCRIBE 请求

现在，客户端发送 DESCRIBE 请求：

![DESCRIBE 请求](https://blog.xizhibei.me/media/16031752728797/16036926623169.jpg)

服务器会用 SDP 格式的内容回应：

![DESCRIBE 回复](https://blog.xizhibei.me/media/16031752728797/16036926933772.jpg)

WireShark 的一个非常友好的部分在于，它会把协议的说明描述显示出来，SDP 看不懂？它会很清楚地告诉你，另外，SDP 详细的协议解释清看 [维基上的说明][Session Description Protocol] 。

这里注意下 `rtpmap:96 H264/90000` 这一行，这里表示这个视频源是用 H264 编码，采样频率是 90000 。

如上，服务器会展示出，这个视频源的实际视频内容是 MP4 格式的，视频在 0 通道，音频在 1 通道。

##### SETUP 请求

现在，我们到了 SETUP 步骤，相当于初始化（如果播放源既有音频又有视频，那么需要 SETUP 两次）：

![SETUP 请求](https://blog.xizhibei.me/media/16031752728797/16036927615614.jpg)
这里解释下 Transport 的内容：

-   RTP/AVP：表示 RTP A/V Profile，其实后面省略了 UDP，如果是 RTP/AVP/TCP 则表示 RTP 使用 TCP 进行传输；
-   unicast：表示单播，与组播（multicast）进行区别，即一对一进行传输，而不是一对多；
-   client_port=57246-57247：表示客户端打开了 57246 以及 57247 端口，分别进行 RTP 以及 RTSP 进行数据传输；

记下来就是服务端回应：

![SETUP 回复](https://blog.xizhibei.me/media/16031752728797/16036928151218.jpg)

这里需要注意下 Session，这是接下来的播放控制请求都会带上的，用来区别不同的播放请求。

##### PLAY 请求

接下来就是正式的请求了：

![PLAY 请求](https://blog.xizhibei.me/media/16031752728797/16036928328995.jpg)

其中的 Range 表示播放时间的范围，而上图的 `npt=0.000-` 表示这是一个实时的视频源。

服务端会回应一个带有 RTP-Info 的头，其中的 seq 以及 rtptime 的信息都用来指示 RTP 包的信息。

![PLAY 回复](https://blog.xizhibei.me/media/16031752728797/16036928562414.jpg)

如果你注意下上面的总览，你会发现服务端在接收到 PLAY 请求的同时，就开啊是发送 RTP 以及 RTCP 数据进行真正的播放了。

##### TEARDOWN 请求

即停止播放请求，这里很简单，就不详述了。

![TEARDOWN 请求](https://blog.xizhibei.me/media/16031752728797/16037043429830.jpg)

![TEARDOWN 回复](https://blog.xizhibei.me/media/16031752728797/16037043599550.jpg)

#### RTCP 协议

相比于 RTSP 的 文本协议，RTCP 属于二进制协议，它的协议头如下<sup>[2][RTP Control Protocol]</sup>：

![RTCP](https://blog.xizhibei.me/media/16031752728797/16036940344086.jpg)

1.  Version: 版本号，与 RTP 中的版本号一致，目前为 2；
2.  P (Padding): 用来表示 RTP 包是否包含填充字节（比如加密的 RTP 包会用到）；
3.  RC (Reception report count): 统计信息，接收
4.  PT (Packet type) : 包的类型，目前有发送者报告（SR）、接收者报告（RR）、SDES（源描述）、BYE（结束）、APP（应用自定义）；
5.  Length: 当前包的长度；
6.  SSRC: 同步源标识；

拿出实际例子，我们会发现服务端接受到 PLAY 请求后，紧接着就发送了一个 RTCP Sender Report：

![RTCP](https://blog.xizhibei.me/media/16031752728797/16036935371953.jpg)

从中需要注意的一点在于，它有两个时间戳，一个是 NTP (Network Time Protocol) 时间戳，用 8 个字节来表示的绝对时间，另一个则是 RTP 时间戳，这是相对时间，可以用来计算 RTP 包的时间，具体的计算规则是用两个 RTP 时间戳的差值除以视频采样频率，再加上这里的绝对时间，就是当前 RTP 包的绝对时间了。（不知道采样频率？回头去看看上面 RTSP 的 DESCRIBE 请求的回复。）

### RTP 协议

RTP 也属于二进制协议，它的协议头如下<sup>[1][Real-time Transport Protocol]</sup>：

![RTP](https://blog.xizhibei.me/media/16031752728797/16037029014375.jpg)

1.  Version: 版本号，同 RTCP；
2.  P (Padding): 同 RTCP；
3.  X (Extension): 表示是否有拓展包头；
4.  CC (CSRC count): CSRC 个数；
5.  M (Marker): 标志位，比如可以用来标志视频帧的边界；
6.  PT (Payload type): 包内容类型，具体类型非常多，想了解的可以看 [rfc3551][rfc3551 RTP Profile for Audio and Video Conferences with Minimal Control]；
7.  Sequence number: 序号，防止丢包以及包乱序；
8.  Timestamp: 时间戳，与上面 RTCP 时间戳相关；
9.  SSRC: 同步源标识；
10. CSRC: 贡献源标识；
11. Header extension: 可拓展的包头；

我们选取第一个 RTP 包来看，我们可以看到，内容类型是 96，也就是 H264。

![RTP](https://blog.xizhibei.me/media/16031752728797/16037061301231.jpg)

### 总结

RTSP 协议本身不复杂，下一篇我们来说说关于 RTSP 的实践。

### Ref

1.  [Real-time Transport Protocol]
2.  [RTP Control Protocol]
3.  [Session Description Protocol]
4.  [Real Time Streaming Protocol]
5.  [rfc2326 Real Time Streaming Protocol (RTSP)]
6.  [rfc3550 RTP: A Transport Protocol for Real-Time Applications]
7.  [rfc3551 RTP Profile for Audio and Video Conferences with Minimal Control]

[Real Time Streaming Protocol]: https://en.wikipedia.org/wiki/Real_Time_Streaming_Protocol

[RTP Control Protocol]: https://en.wikipedia.org/wiki/RTP_Control_Protocol

[Real-time Transport Protocol]: https://en.wikipedia.org/wiki/Real-time_Transport_Protocol

[Session Description Protocol]: https://en.wikipedia.org/wiki/Session_Description_Protocol

[rfc2326 Real Time Streaming Protocol (RTSP)]: https://tools.ietf.org/html/rfc2326

[rfc3550 RTP: A Transport Protocol for Real-Time Applications]: https://tools.ietf.org/html/rfc3550

[rfc3551 RTP Profile for Audio and Video Conferences with Minimal Control]: https://tools.ietf.org/html/rfc3551


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/152 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
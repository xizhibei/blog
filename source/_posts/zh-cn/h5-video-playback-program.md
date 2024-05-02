---
title: 网页视频播放：方案篇
date: 2019-12-17 10:49:55
tags: [业务,视频直播]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/127
---
<!-- en_title: h5-video-playback-program -->

在[上篇](https://github.com/xizhibei/blog/issues/126)我们说到，直播协议的介绍，简单回顾下几个技术点：

1.  客户端 / 摄像头：RTSP/RTMP
2.  视频传输：RTSP 转成 RTMP/HTTP-FLV/DASH/HLS/WebRTC
3.  浏览器播放：video.js / flv.js

这篇我们接着来说说具体的实现方案。

### 方案

现成的方案其实挺多，不仅有各个厂家提供的集成 SDK 与服务一条龙，也有开源的项目。

今天以开源方案为主，主要介绍几个方案。由于摄像头以及浏览器播放的限制，我们目前主要需要实现的是视频传输这块，尤其是视频传输协议的转换。

好，那么现在的问题就是，如何实现服务端。

### 方案一：重量级

这是大规模播放的方案，一般核心都是 nginx + ffmpeg。

这是一种相对成熟的方案：[arut/nginx-rtmp-module](https://github.com/arut/nginx-rtmp-module)。

如下，便是一个最简单的配置，它实现了从 RTSP 源拉流，然后推送到本地的 RTMP 源，之后浏览器便可以用 flash 播放器播放 RTMP 源了。

其实这里需要提一句，它需要借助 flash 播放器，比如如果你使用 video.js，那么就需要使用 [videojs-flash](https://github.com/videojs/videojs-flash) 这个插件。

```conf
rtmp {
    server {
        listen 1935;
        chunk_size 4000;
        application live {
            exec ffmpeg -re -i rtsp://localhost/1/h264major
            -vcodec flv -acodec copy
            -f flv rtmp://localhost:1935/live/${name};
        }
    }
}
```

在这个配置中，你可以将 RTSP 源直接改为 RTMP 源，实现拉 RTMP 的流，当然你也可以直接将 RTMP 的源推送到服务器的 1935 端口，实现转发功能。

下面两个项目是类似的，不过它们还提供了 HTTP-FLV 源，意味着你不需要 flash 也可以播放了。

-   [winshining/nginx-http-flv-module](https://github.com/winshining/nginx-http-flv-module)：基于 nginx-rtmp-module 做的，目前还在积极维护；
-   [ossrs/srs](https://github.com/ossrs/srs)：这是大佬 winlin 实现的『运营级的互联网直播服务器集群』，适合大规模的视频直播；

### 方案二：轻量级

这里用我用过的两个项目来说明。

用 Golang 实现的 [gwuhaolin/livego](https://github.com/gwuhaolin/livego) 它很简单，直接下载安装运行即可，配置基本不需要改。

还有 Node.js 实现的 [illuspas/Node-Media-Server](https://github.com/illuspas/Node-Media-Server)。它比较适合集成在你的 Node.js 项目中去，当然单独作为服务器也是可以的。

```js
const NodeMediaServer = require('node-media-server');

const config = {
  rtmp: {
    port: 1935,
    chunk_size: 60000,
    gop_cache: true,
    ping: 30,
    ping_timeout: 60
  },
  http: {
    port: 8000,
    allow_origin: '*'
  }
};

var nms = new NodeMediaServer(config)
nms.run();
```

这两个轻量级的协议转换基本上能满足我们的需求了。


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/127 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
---
title: RTSP 服务器的简单实现
date: 2020-12-20 21:50:42
tags: [C/C++,视频直播]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/156
---
<!-- en_title: a-simple-implementation-of-rtsp-server -->

在上次的 [RTSP 协议详解](https://github.com/xizhibei/blog/issues/152) 中，把 RTSP 协议本身简单介绍了，这次就来说说如何实现一个简单的 RTSP 服务器。

### Live555

Live555 是我们经常用的 C++ 媒体库，它支持非常多的媒体服务协议，实现了对多种音视频编码格式的音视频数据的数据流化、接收和处理等支持。

它也是现在为数不多的可用库之一，它的代码比较繁琐，但是胜在简单，多数人拿到之后就能简单上手了，因此也非常适合拿来练手，以及改写。

### 一个简单的 RTSP/H264 实现

我们拿 `testProgs/testOnDemandRTSPServer.cpp` 作为例子。

首先创建 RTSP 服务本身：

```c++
TaskScheduler* scheduler = BasicTaskScheduler::createNew();
env = BasicUsageEnvironment::createNew(*scheduler);

UserAuthenticationDatabase* authDB = NULL;

# 这里如果不需要认证的话，可以去掉
authDB = new UserAuthenticationDatabase;
authDB->addUserRecord("username1", "password1");

# 监听 554 端口，标准的 RTSP 端口
RTSPServer* rtspServer = RTSPServer::createNew(*env, 554, authDB);
```

然后添加 H264 文件作为视频源，如果不太理解，可以联想上面创建了 HTTP 服务器，而下面则在服务里面添加了 HTTP 路由资源的实现。

```c++
char const* streamName = "h264ESVideoTest";
char const* inputFileName = "test.264";
ServerMediaSession* sms
  = ServerMediaSession::createNew(*env, streamName, streamName,
			      descriptionString);
sms->addSubsession(H264VideoFileServerMediaSubsession
	       ::createNew(*env, inputFileName, reuseFirstSource));
rtspServer->addServerMediaSession(sms);
```

### 基于摄像头的视频流

在这里，你需要注意到，Live555 的 RSTP 服务器是基于文件去做的，如果你的视频源不是一个静态的文件，那你就需要自己去实现 `ServerMediaSubsession` 了。

目前，我搜索到的方案主要有两种，一种方案是利用 Linux 的命名管道 `fifo` 来进行数据的传输，这样就可以在不实现 `ServerMediaSubsession` 的情况下直接使用。

具体就是用 Linux 的 `mkfifo` 命令，或者系统 API 调用创建一个管道，然后就可以使用文件的的 API 来进行读写（不得不赞叹 Linux 的精巧之处，一切皆文件）。

```bash
mkfifo [OPTION]... NAME...
```

然而，我没有进行测试，不过看各种论坛上的提问以及经验总结来看，这种方案虽然简洁，但是性能堪忧，并且会造成很大的延迟。

那么，另一种方案就呼之欲出了，其实新版本中，Live555 已经给出了解决方案的例子，就在 `liveMedia/DeviceSource.cpp` 中。

```cpp
DeviceSource*
DeviceSource::createNew(UsageEnvironment& env,
			DeviceParameters params) {
  return new DeviceSource(env, params);
}

EventTriggerId DeviceSource::eventTriggerId = 0;

unsigned DeviceSource::referenceCount = 0;

DeviceSource::DeviceSource(UsageEnvironment& env,
			   DeviceParameters params)
  : FramedSource(env), fParams(params) {
  if (referenceCount == 0) {
    // 任何的全局初始化，比如设备的初始化
    //%%% TO BE WRITTEN %%%
  }
  ++referenceCount;

  // 实例级别的初始化
  //%%% TO BE WRITTEN %%%

  // 接下来就是设置如何从设备上读取视频帧，有两种方式，一种是可以直接读取的，具体例子可以搜索 turnOnBackgroundReadHandling
  envir().taskScheduler().turnOnBackgroundReadHandling(...);
  
  // 另一种则是需要异步读取的，这样的话，就需要用到事件触发的方式读取
  if (eventTriggerId == 0) {
    eventTriggerId = envir().taskScheduler().createEventTrigger(deliverFrame0);
  }
}

DeviceSource::~DeviceSource() {
  // 释放实例资源
  //%%% TO BE WRITTEN %%%

  --referenceCount;
  if (referenceCount == 0) {
    // 释放全局资源
    //%%% TO BE WRITTEN %%%

    // Reclaim our 'event trigger'
    envir().taskScheduler().deleteEventTrigger(eventTriggerId);
    eventTriggerId = 0;
  }
}

void DeviceSource::doGetNextFrame() {
  // 当下游，如 RTSP 客户端请求数据时，此方法会被调用

  // 当设备不可读了之后，比如关闭，在这里需要处理下
  if (0 /*%%% TO BE WRITTEN %%%*/) {
    handleClosure();
    return;
  }

  // 如果视频帧数据可用了
  if (0 /*%%% TO BE WRITTEN %%%*/) {
    deliverFrame();
  }

  // 无视频帧数据时，不用做任何事了，但是当数据可用时，需要调用触发事件
  // Instead, our event trigger must be called (e.g., from a separate thread) when new data becomes available.
}

void DeviceSource::deliverFrame0(void* clientData) {
  ((DeviceSource*)clientData)->deliverFrame();
}

void DeviceSource::deliverFrame() {
  // 此方法会在视频数据帧可用时调用
  // 下面的参数将会用于将数据拷贝至下游（客户端等）
  //     fTo: 拷贝至地址，只能拷贝数据，不可修改
  //     fMaxSize: 最大可拷贝数据，不可修改，如果实际数据大于此数值，则需要截取，并且相应地修改 "fNumTruncatedBytes"
  //     fFrameSize: 实际数据大小 (<= fMaxSize).
  //     fNumTruncatedBytes: 在上面提到了
  //     fPresentationTime: 视频帧的展示时间，可调用 "gettimeofday()" 设置为系统时间，如果能获取解码器的时间的话更好
  //     fDurationInMicroseconds: 视频帧的持续时间，如果是实时视频源，不需要设置，因为这会导致数据永远不会早到达客户端

  if (!isCurrentlyAwaitingData()) return; 

  u_int8_t* newFrameDataStart = (u_int8_t*)0xDEADBEEF; //%%% TO BE WRITTEN %%%
  unsigned newFrameSize = 0; //%%% TO BE WRITTEN %%%

  if (newFrameSize > fMaxSize) {
    fFrameSize = fMaxSize;
    fNumTruncatedBytes = newFrameSize - fMaxSize;
  } else {
    fFrameSize = newFrameSize;
  }
  gettimeofday(&fPresentationTime, NULL); // 如果没有实时视频源的时间戳，就获取当前系统时间
  // 如果设备不是实时视频源，比如文件，那就在这里设置 "fDurationInMicroseconds"
  memmove(fTo, newFrameDataStart, fFrameSize);

  // 传送完数据，通知读取方数据可用
  FramedSource::afterGetting(this);
}


// 下面的代码就是用来通知 DeviceSource 视频源可用的代码（异步方式），可以在不同线程中调用，但是不能在多个线程中用同样的 'event trigger id' 调用（这样的话，会导致只会触发一次）。另外，如果有多个视频源，则需要修改 eventTriggerId 为非静态成员。
void signalNewFrameData() {
  TaskScheduler* ourScheduler = NULL; //%%% TO BE WRITTEN %%%
  DeviceSource* ourDevice  = NULL; //%%% TO BE WRITTEN %%%

  if (ourScheduler != NULL) {
    ourScheduler->triggerEvent(DeviceSource::eventTriggerId, ourDevice);
  }
}
```

目前我用这种方式，采用芯片硬编码，能获取在内网 1080P 30fps h.264 1000ms 以下的延迟。当然了，实验代码写得比较粗糙，需要进一步优化了，这里就不放出来了，相信总体思路还是对的。

### Ref

<https://blog.csdn.net/xwu122930/article/details/78962234>
<https://blog.csdn.net/u012459903/article/details/103099705>
<https://blog.csdn.net/weixin_33700350/article/details/86010562>


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/156 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
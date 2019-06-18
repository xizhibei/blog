---
title: Golang 中的跨语言调用
date: 2019-01-27 16:20:51
tags: [C&#x2F;C++,Golang]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/98
---
今天，我们来说说 cgo。

<!-- en_title: golang-cgo -->

### 前言

在有些特殊的场景下，我们会有这样的困扰：

1.  当前开发语言的性能仍不够，比如视频处理（直播领域）、机器学习以及游戏；
2.  有些优秀的 C/C++ 库一时无法使用当前开发语言来重新实现（FFmpeg、OpenCV、Protobuf、ZeroMQ 等等一大堆）；

一般情况下，我们会倾向于使用这样几种方式去解决：

1.  封装原始 C/C++ 库，将其中的接口变为当前语言的接口；
2.  封装成 C/C++ Web 服务，其实也相当于封装原始库，只不过封装成了 Web API 接口；

这里面的思路，无非是通过添加一层『胶水层』，将调用方与被调用方『粘合』在一起。

在取舍的时候，就看你们目前能承担的成本是多高了，比如人员不够的情况下，封装成 Web 服务耗费的精力可能比直接调用高，更遑论后期的运维成本了。

### Node.js

于是，我们可以看到在 Node.js 中，有非常方便的 addons 集成方式，封装完成后，直接通过 require 的方式引入后调用即可。但由于需要针对平台进行编译，每次 Node.js 升级的时候，很容易导致模块被破坏，Node.js 直到 8.0 的时候，提供了 N-API 来保证 Node 本身大版本升级的时候，拓展的 C/C++ 模块依然能够使用。（对了，又是 DIP，通过依赖于抽象而不是具体实现，就能避免掉这种问题。）

另外，可以顺便提几个我们常用的 C/C++ 模块：

1.  gRPC：通信
2.  iconv：字符集转换
3.  canvas： 服务端的 canvas 元素 

Node.js 的 addons 研究不多，以后有机会再说，有兴趣的也可以参考死月的《Node.js：来一打 C++ 扩展》。

### Golang

Golang 中，就不得不提 cgo 了，相比 Node.js 的 addon 来说，似乎里面的黑魔法更多。

首先，在 Go 中调用 C 代码的方式是这样的：

```go
// #include <stdio.h>
// #include <errno.h>
import "C"
```

然后所有的 C 代码 ，都可以通过 `C.XXX` 这样的方式来调用了，比如 `C.putchar, C.malloc, C.free` 等等。

这里，你应该能看出来 import 的 C 包是一个 "pseudo-package" 即『伪包』，是种黑魔法没错了，因为这里针对 cgo 进行了特殊对待，可以看作是一个命名空间。

而最关键的，莫过于参数的传递，C 与 Go 中的大部分基础类型都是可以互相转换的，不像 Node.js 或者 Python 中，需要包装一层成为专门的动态语言对象。CGO 中，它会将各种数据类型进行映射，比如 C 的 int 对应 go 的 int 或者 int32，C 的 float 对应 Go 的 float32 等等。

下面提两个比较特别，又是我们可能经常用到的例子：

#### CGO struct

而在 C 中的 struct，你可以使用 `C.struct_example` 的方式去定义[4]，但同时也要注意，如果使用了 C 的 packed struct，则需要特殊处理[5]。

#### CGO struct array

在 C 中返回 struct array 是个很常见的需求，我们可以有两种方式来处理：

在知道长度的情况下[6]：

```go
exampleSize := 10
examples := C.get_structs()
defer C.free(unsafe.Pointer(examples))
exampleSlice := (*[1 << 30]C.struct_Example)(unsafe.Pointer(examples))[:exampleSize:exampleSize]
```

不知道长度，动态 struct 长度，与上面相似：

```go
var examples *C.struct_Example
var size C.size_t
C.get_structs((**C.struct_Example)(unsafe.Pointer(&examples)), (*C.size_t)(unsafe.Pointer(&size)))
defer C.free(unsafe.Pointer(examples))
exampleSlice := (*[1 << 30]C.struct_Example)(unsafe.Pointer(examples))[:size:size]
```

### CGO 编译

CGO 的编译，也是个黑魔法，需要将相关的编译选项写在注释里面：

```go
// #cgo CFLAGS: -I${SRCDIR}/include
// #cgo LDFLAGS: -L${SRCDIR}/lib -lfoo
```

如果引入其他的库，也可以使用 `pkg-config`：

```go
// #cgo pkg-config: opencv
```

另外，由于不同平台的编译选择可能不一样，那么还可以加上编译限制：

```go
// #cgo darwin,amd64 LDFLAGS: -lomp
// #cgo linux,amd64  LDFLAGS: -lgomp
```

其中的逗号可以看作 and，而空格则表示 or，细节看[这里](https://golang.org/pkg/go/build/#hdr-Build_Constraints)。

#### 样例

假如你想从具体的例子中，学到更多的内容，可以参考以下几个项目：

1.  <https://github.com/hybridgroup/gocv>
2.  <https://github.com/keroserene/go-webrtc>
3.  <https://github.com/tensorflow/tensorflow/tree/master/tensorflow/go>

### 总结

CGO 虽然方便，但是在我看来有着很大的的不确定性，假如在有足够人员的情况下，还是尽量封装为 Web API 服务更靠谱，因为：

1.  破坏了整体编译的特点以及方便部署的特性，因为编译完成后的可执行文件可能会依赖于动态链接库，导致不能直接拷贝至其它机器使用，如果使用 Docker，则会导致 image 变大，而且可能是量级的增大，原本 ~10M，现在可能需要 ~100M；
2.  调用过程黑魔法太多，大部分情况下需要引入 unsafe 包，从字面意义上也容易理解：它就是引入了不安全特性；
3.  生态不成熟，在开发过程中，资料非常缺失，社区也不怎么活跃，很多问题需要查找调试很久；
4.  提高了开发成本，分工之后的合作效率高，人员容易配备，毕竟找个同时精通 C/C++ 与 GO 的开发人员比单独找要难不少，而在合作的过程中，调用都是依赖于网络通信，而不是 C 语言接口，符合微服务的设计；

### Ref

1.  <https://nodejs.org/api/addons.html>
2.  <https://golang.org/cmd/cgo/>
3.  <https://blog.golang.org/c-go-cgo>
4.  <https://utcc.utoronto.ca/~cks/space/blog/programming/GoCGoCompatibleStructs>
5.  <https://medium.com/@liamkelly17/working-with-packed-c-structs-in-cgo-224a0a3b708b>
6.  <https://stackoverflow.com/questions/28925179/cgo-how-to-pass-struct-array-from-c-to-go>
7.  <http://www.ntu.edu.sg/home/ehchua/programming/cpp/gcc_make.html>
8.  <http://yangxikun.com/golang/2018/03/09/golang-cgo.html>
9.  <http://bastengao.com/blog/2017/12/go-cgo-c.html>
10. <http://bastengao.com/blog/2017/12/go-cgo-cpp.html>
11. <https://documentation.help/Golang/cgo.html>
12. <https://github.com/swig/swig/blob/master/Examples/go/reference/Makefile>
13. <https://stackoverflow.com/questions/13417789/cgo-c-function-has-int-pointer-argument-how-to-pass-correct-type>
14. <https://dave.cheney.net/tag/cgo>


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/98 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
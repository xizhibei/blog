---
title: Golang Heap 分析
date: 2021-06-27 17:24:27
tags: [Golang,工具]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/175
---
<!-- en_title: golang-heap-profiling -->

通常，我们只会在两种情况下，会去分析一个程序的表现：

1.  你遇到了问题；
2.  你闲的没事干；

好了，开个玩笑，其实研究程序的性能对于每一个工程师来说，都很重要，我甚至可以这么说：**这是一个工程师的必备技能**。

下面来说说，我们如何去研究 Golang 程序的性能问题。

### 介绍

之前我也在 [穷人的程序性能分析器](https://github.com/xizhibei/blog/issues/158) 介绍过 C++ 的性能分析，以及很久之前也介绍过 [Node.js 性能分析之火焰图](https://github.com/xizhibei/blog/issues/57) ，那么今天就轮到 Golang 了。

相比之下，Golang 的性能分析工具 `pprof` 可谓是豪华了，它内建支持以下几种分析：

-   heap：当前内存中所有存活对象的采样（几乎是带 GC 语言的必备了），可以用来分析内存问题；
-   profile：与 `heap` 相对的，是 CPU 的采样，可以用来分析程序的耗时瓶颈；
-   goroutine： 所有当前 `goroutine` 的栈追踪；
-   allocs： 所有过去的内存申请采样；
-   threadcreate： 系统层面的线程栈追踪；
-   block：同步原语上的堵塞的栈追踪；
-   mutex：所有竞争关系的 `mutex` 栈追踪；
-   trace：当前程序执行情况的追踪；

凭借良好的工具带来的调试体验也是非常棒的，整个过程只需几个简单的命令，你就能进行分析个大概了。不过受限于篇幅，以及之前也多次提到过 CPU 的分析，因此今天只说说如何分析内存，也就是 Heap。 

Heap 的使用一般是内存泄露，或者是你想优化内存的使用。

### 内存泄露与内存优化

对于内存泄露，这类问题往往难以发现与分析，因为需要监控 Go 程序本身，或者看 Linux 的 dmesg 里面的 OOM 记录才能发现。

```bash
dmesg | grep oom-killer
```

当你发现一次 OOM 记录时，你就要考虑给本身忽略的监控加上了，因为这种问题会复现的（但是往往难以在自己的机器以及预发布环境中复现）。如果不知道是是什么监控参数，你可以看监控数据，简单定一个比例，比如当你的程序初始化的时候占用 10% 的内存，那么一旦 Go 程序的内存使用达到一定比例比如机器内存 50% 时，就要马上进行告警了，你也可以进场分析了。

不过，也不用大费周章，因为你只需用几行简单的代码，就能给你的 Go 程序增加 pprof 支持，不会影响程序的运行，并且是支持 Web 访问的：

```go
import (
  "net/http"
  _ "net/http/pprof"
)

func main() {
  go func() {
    http.ListenAndServe("localhost:8080", nil)
  }()
}
```

然后，使用 go 提供的 `pprof` 工具就能进行分析了，比如对于内存泄露问题：

```bash
go tool pprof http://localhost:8080/debug/pprof/heap
```

就会进入 pprof 的 REPL，在这里用一些简单的命令你就能定位问题所在。不过为了更好的分析体验，有两个地方需要注意：

1.  如果你的编译参数重加了 `-trimpath` 以及 `-ldflag "-s -w"`，最好去掉，不然会影响到你定位问题；
2.  在编译机器上执行这条命令，这样可以直接分析到每一行代码的级别；

接下来的我用的实际例子是属于内存使用分析优化，由于还没遇到 OOM，先用我遇到的一个小例子来代替，因为两个问题的分析方法是一致的。

### 如何使用 pprof

**第一步**，先看 `top10`：

    (pprof) top10
    Showing nodes accounting for 3759.91kB, 100% of 3759.91kB total
    Showing top 5 nodes out of 24
          flat  flat%   sum%        cum   cum%
     2345.25kB 62.38% 62.38%  2345.25kB 62.38%  io.ReadAll
      902.59kB 24.01% 86.38%   902.59kB 24.01%  compress/flate.NewWriter
             0     0%   100%   902.59kB 24.01%  bufio.(*Writer).Flush
             0     0%   100%   902.59kB 24.01%  compress/gzip.(*Writer).Write
    (以下省略)...

这里需要提示下，`flat` 表示目前最右边的调用仍旧没有被释放的空间，而 `cum` 表示累计 (cumulative) 申请的空间。top 的默认排序是按照 flat 排序，你可以通过参数来切换排序方式：`top10 -cum` 。

如果在这里看不到什么异常的地方，那么还有别的地方可以看，因为 Golang heap 的采样统计会区分成四个部分：

-   alloc_objects：申请过的对象
-   alloc_space ：申请过的空间
-   inuse_objects：正在使用的对象
-   inuse_space：正在使用的空间（默认）

你可以通过类似于 `sample_index=inuse_objects` 的命令来切换。

在我的这个例子中，由于我这里确定第一项 `io.ReadAll` 为什么会在我的程序中，但是第二项的 `compress/flate.NewWriter` 让我觉得有异常，但是不知到是哪里调用的。因此，在确定异常项后，**第二步**可以通过 `tree` 来进一步确认调用链条：

    (pprof) tree 10 compress
    Active filters:
       focus=compress
    Showing nodes accounting for 2354.01kB, 29.36% of 8018.09kB total
    Showing top 10 nodes out of 11
    ----------------------------------------------------------+-------------
          flat  flat%   sum%        cum   cum%   calls calls% + context              
    ----------------------------------------------------------+-------------
                                             2354.01kB   100% |   compress/gzip.(*Writer).Write
     1805.17kB 22.51% 22.51%  2354.01kB 29.36%                | compress/flate.NewWriter
                                              548.84kB 23.32% |   compress/flate.(*compressor).init
    ----------------------------------------------------------+-------------
                                              548.84kB   100% |   compress/flate.(*compressor).init (inline)
      548.84kB  6.85% 29.36%   548.84kB  6.85%                | compress/flate.(*compressor).initDeflate
    ----------------------------------------------------------+-------------
                                             2354.01kB   100% |   github.com/prometheus/common/expfmt.MetricFamilyToText.func1
             0     0% 29.36%  2354.01kB 29.36%                | bufio.(*Writer).Flush
                                             2354.01kB   100% |   compress/gzip.(*Writer).Write
    ----------------------------------------------------------+-------------
                                              548.84kB   100% |   compress/flate.NewWriter
             0     0% 29.36%   548.84kB  6.85%                | compress/flate.(*compressor).init
                                              548.84kB   100% |   compress/flate.(*compressor).initDeflate (inline)
    ----------------------------------------------------------+-------------
                                             2354.01kB   100% |   bufio.(*Writer).Flush
             0     0% 29.36%  2354.01kB 29.36%                | compress/gzip.(*Writer).Write
                                             2354.01kB   100% |   compress/flate.NewWriter
    ----------------------------------------------------------+-------------
                                             2354.01kB   100% |   github.com/prometheus/common/expfmt.NewEncoder.func7
             0     0% 29.36%  2354.01kB 29.36%                | github.com/prometheus/common/expfmt.MetricFamilyToText
                                             2354.01kB   100% |   github.com/prometheus/common/expfmt.MetricFamilyToText.func1
    ----------------------------------------------------------+-------------
                                             2354.01kB   100% |   github.com/prometheus/common/expfmt.MetricFamilyToText
             0     0% 29.36%  2354.01kB 29.36%                | github.com/prometheus/common/expfmt.MetricFamilyToText.func1
                                             2354.01kB   100% |   bufio.(*Writer).Flush
    ----------------------------------------------------------+-------------
                                             2354.01kB   100% |   github.com/prometheus/common/expfmt.encoderCloser.Encode
             0     0% 29.36%  2354.01kB 29.36%                | github.com/prometheus/common/expfmt.NewEncoder.func7
                                             2354.01kB   100% |   github.com/prometheus/common/expfmt.MetricFamilyToText
    ----------------------------------------------------------+-------------
                                             2354.01kB   100% |   xizhibei-app/controllers/internal_rpc.(*SystemCtrl).GetMetrics
             0     0% 29.36%  2354.01kB 29.36%                | github.com/prometheus/common/expfmt.encoderCloser.Encode
                                             2354.01kB   100% |   github.com/prometheus/common/expfmt.NewEncoder.func7
    ----------------------------------------------------------+-------------
             0     0% 29.36%  2354.01kB 29.36%                | xizhibei-app/controllers/internal_rpc.(*SystemCtrl).GetMetrics
                                             2354.01kB   100% |   github.com/prometheus/common/expfmt.encoderCloser.Encode
    ----------------------------------------------------------+-------------

现在，我们基本可以确认是在我实现的 `GetMetrics` 中，处理 prometheus 客户端的序列化压缩时候出了点小问题（但是还没有到内存泄露的地步）。另外，这里你也可以加个**第三步**：用 `list` 加上关键词的命令来查看精确到每一行代码级别的分析。

定位到问题后，就是**最后一步**解决，我的解决方案是用 `sync.Pool`。在之前，我是直接使用 `gzip.NewWriter` 来压缩每次从 prometheus 中取出的指标文本，但是这样会造成 `gzip` 多次重复的内存申请以及初始化，所以当改用 `sync.Pool` 后，我的代码从：

```go
buf := new(bytes.Buffer)
gzipWritter := gzip.NewWriter(buf)
```

变为：

```go
var (
	gzipPool = sync.Pool{
		New: func() interface{} {
			return gzip.NewWriter(nil)
		},
	}
	bufferPool = sync.Pool{
		New: func() interface{} {
			return new(bytes.Buffer)
		},
	}
)

...

gzipWritter := gzipPool.Get().(*gzip.Writer)
defer gzipPool.Put(gzipWritter)

buf := bufferPool.Get().(*bytes.Buffer)
defer bufferPool.Put(buf)

buf.Reset()
gzipWritter.Reset(buf)
```

我们可以写个 benchmark 来测试下：

    goos: linux
    goarch: amd64
    cpu: Intel(R) Core(TM) i9-9820X CPU @ 3.30GHz
    BenchmarkEncode-20                          2422            504022 ns/op          851822 B/op        129 allocs/op
    BenchmarkEncodeWithSyncPool-20              7654            150188 ns/op           48799 B/op        108 allocs/op

可以看到，内存的 `allocs` 从 129 降到了 108。

好了，分析就暂时到这。

### P.S.

对于大多数人来说，在网页上用鼠标点击分析问题更简单，因为目前 Go pprof 这个工具做到了一条龙服务，你可以直接在网页上看到调用图表以及火焰图（这里需要着重艾特下 C/C++，咱还能不能把调试体验做好点了）。

```bash
go tool pprof -http=:6000 http://localhost:8080/debug/pprof/heap
```

Go 会打开一个本地 6000 端口的网页，但如果你在云服务器上，你有两种选择：

1.  用 wget 下载 heap 文件 `wget http://localhost:8080/debug/pprof/heap`，然后拷贝到本地进行分析；
2.  用 ssh 代理 `ssh -L 8080:127.0.0.1:8080 user@server`；

### Ref

1.  [Diagnostics](https://golang.org/doc/diagnostics)
2.  [Profiling Go Programs](https://blog.golang.org/pprof)


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/175 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
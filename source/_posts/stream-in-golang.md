---
title: Golang 中的 stream
date: 2018-12-01 19:51:14
tags: [Golang]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/93
---
<!-- en_title: stream-in-golang -->

数据流的概念其实非常基础，最早是在通讯领域使用的概念，这个概念最初在 1998 年由 Henzinger 在文献 87 中提出，他将数据流定义为 “只能以事先规定好的顺序被读取一次的数据的一个序列”。[1] 

<!-- more -->

### 简介
正如字面上所说的，数据流就是由数据形成的流，就像由水形成的水流，非常形象，现代语言中，基本上都会有流的支持，比如 C++ 的 iostream，Node.js 的 stream 模块，以及 golang 的 io 包。

随着大数据技术的发展，数据流在我们的业务中可谓是重中之重，这也不难理解，毕竟程序肯定有输入输出，而当我们目前的设备无法在短时间内处理输入的数据，或者需要实时处理输入数据的时候，基于数据流的处理就显得格外重要。

举几个实际的例子 [2]：

1. 物联网行业中，车辆实时上传状态数据，从而为车辆的制造商提供实时数据反馈，检测用户的车是否有隐患，有问题便可以通知用户进行维修，甚至可以直接将新零件寄给用户；
2. 手机 APP 不断上传各种用户操作数据，我们需要不断收集以及处理，从而可以实时给用户推荐他真正想要的商品；
3. 现代手游中，每时每刻都需要跟服务端交互，我们就需要提供玩家间的交互，或者是与虚拟 AI 玩家的交互；

好了，闲扯就到这，只是为了说明，流在我们现代的技术场景中，变得越来越重要，下面来说说流在 Golang 的实践。

### Stream in Golang
与流密切相关的就是 `bufio` `io` `io/ioutil` 这几个包了，这也不难理解，流就是 io 的一部分了。

现在假设一个这样的场景，我们需要实时处理用户上传的视频数据，这个视频数据非常大，大概有 10M~50M 大小，现在，我们需要这样处理视频：

1. 处理视频，转成可以方便处理的视频格式
2. 提取关键的帧做成预览视频
3. 储存到指定位置
4. 下发至其它客户端

那么，为了达到高效处理视频，以及利用有限资源的前提下，我们就需要使用流去处理了，那么，我们就需要开始准备管道了，显然除了 1 以外，我们可以并行处理：

```
=== get http Body ==>
    === process video ===>
       === extract key frames ===>
       === store video ===>
       === dispatch video ===>
```

然而流的概念就是只可以读取一次，于是我们就需要复制流，从而可以并行处理。

有两种方案可以参考，一种是用 `io.TeeReader`，另一种便是 `io.MultiWriter`

#### `io.TeeReader`
这个非常简单，很像是 linux 中的 tee 命令，可以用来复制出一条数据流。

而它的实现很简单，看源码就会发现，它就是几行代码而已：

```go
func TeeReader(r Reader, w Writer) Reader {
	return &teeReader{r, w}
}

type teeReader struct {
	r Reader
	w Writer
}

func (t *teeReader) Read(p []byte) (n int, err error) {
	n, err = t.r.Read(p)
	if n > 0 {
		if n, err := t.w.Write(p[:n]); err != nil {
			return n, err
		}
	}
	return
}

```
做的事情，也很简单，就是将 r 中的数据读出后同时写入 w 中，然后 teeReader 本身也是可以读取数据的，这样，就相当于复制出了一条数据流。

它的用法也很简单，拿官方的例子：

```go
r := strings.NewReader("some io.Reader stream to be read\n")
var buf bytes.Buffer
tee := io.TeeReader(r, &buf)

printall := func(r io.Reader) {
	b, err := ioutil.ReadAll(r)
	if err != nil {
		log.Fatal(err)
	}

	fmt.Printf("%s", b)
}

printall(tee)
printall(&buf)
```

那，我如果修改下 `TeeReader`，往其中再加入几个 writer，不是就可以达到目的了么？没错，其实 io 包里面的 `MultiWriter` 已经帮你这么做了。

#### `io.MultiWriter`
于是，我们大致可以这么实现这个功能了，以下代码没有经过验证，仅仅作为参考：

```go
func handler(req *http.Request) error {
  r := req.Body
  defer r.Close()

  v := processVideo(r)

  extractR, extractW := io.Pipe()
  storeR, storeW := io.Pipe()
  dispatchR, dispatchW := io.Pipe()

  mw := io.MultiWriter(extractW, storeW, dispatchW)

  done := make(chan bool)
  errs := make(chan error)
  defer close(done)
  defer close(errs)

  go func() {
    err := extractKeyFrames(extractR)
    if err != nil {
      errs <- err
      return
    }
    done <- true
  }()
  go func() {
    err := storeVideo(storeR)
    if err != nil {
      errs <- err
      return
    }
    done <- true
  }()
  go func() {
    err := dispatchVideo(dispatchR)
    if err != nil {
      errs <- err
      return
    }
    done <- true
  }()

  go func() {
    defer extractW.Close()
    defer storeW.Close()
    defer dispatchW.Close()
    
    _, err = io.Copy(mw, v)
    if err != nil {
      errs <- err
      return
    }
  }()

  for i := 0; i < 3; i++ {
    select {
    case err := <-errs:
      return err
    case <-done:
    }
  }
  return nil
}
```

### 总结
流本身是数据处理的基础，其实本身也挺简单。

我之前在面试的时候，会经常考察候选人对于流的理解，因为我们服务端平时开发中最常见的流便是数据库的数据流，尤其是当我们的业务上在积累一段时间的数据后，便会有对数据进行批量处理的需求，这时候，如果候选人对于流不够理解，或者根本不知道这个内容，那么，这将会是一个扣分点。

好吧，答案也很简单，就是利用数据库的游标，不断取数据到服务器进行处理，可以在低内存的情况下处理大量数据。当然了，肯定会有更好的处理方式，包括利用数据库本身的聚合计算能力，这种方式比较适合特定时期的处理需求，更大的数据量更适合交给专业的大数据团队去处理了。

另外，大数据处理中的实时流计算，是一个非常火热的领域，而它的本质也就跟今天说的这点内容是一样的。

### Ref
1. [Computing on Data Streams - Semantic Scholar](https://pdfs.semanticscholar.org/95c8/44d261ffae25c69d819d8776a18b381f2108.pdf)
1. [What is Streaming Data?](https://aws.amazon.com/streaming-data/)


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/93 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
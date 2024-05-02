---
title: Golang 中饱受争议的 context
date: 2019-08-26 20:03:42
tags: [Golang]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/118
---
<!-- en_title: golang-the-highly-controversial-context -->

今天来说说 Go 中，一个存在争议的包：context。官方在博客中给了一个例子，说的是在 Go 实现的服务中，对于每一个请求，都会有一个 goroutine 去处理，然后这些处理的地方，又会启动一些额外的 goroutine，去请求数据库，或者其他 RPC 服务，这些请求的过程中，它们会携带一些与单个请求相关的数据，如截止时间、认证信息，而当超时或者被客户端取消的时候，goroutine 应该快速释放它所占用的资源，好让其它请求去使用。<sup>[1]</sup>

做过微服务的同学们，听起来有点熟悉对不？这说的不就是微服务的那套东西么：比较明显就是分布式追踪（忘了的同学可以看看[我之前写的](https://github.com/xizhibei/blog/issues/74)）以及熔断，几乎每个微服务都会用到，而 Golang 实现这些东西的基础，便是 context。

<!-- more -->

它在官方的文档中，是这么定义的：

> A Context carries a deadline, a cancelation signal, and other values across API boundaries.
> 一个上下文携带着一个到期时间，一个取消信号以及其它的值跨越 API 的界线。

于是我们就知道了，所谓的值，便是请求 ID（用来分布式追踪）、用户认证信息等，而超时以及取消功能便对应着熔断机制的实现。

实际上，Google 在内部要求 Go 开发者必须将 Context 作为 API 的第一个参数，无论是提供给别人还是自己调用<sup>[1]</sup>。

而 Google 的分布式追踪系统 Dapper，基本上也是依据于 context 传递相关的信息来实现。<sup>[2],[3]</sup>

### Context 简介

首先来看看它的定义：

```go
type Context interface {
	Deadline() (deadline time.Time, ok bool)
	Done() <-chan struct{}
	Err() error
	Value(key interface{}) interface{}
}
```

-   `Deadline()`：可以用来获取超时时间，以及是否已设置超时时间；
-   `Done()`：返回一个可以判断是否已经被取消的 `chan struct{}`，如果可被取消，当它可读取的时候，意味着 parent context 已经调用了 cancel 函数，需要你在这个时候释放所有的资源然后退出，而如果没有设置可取消，则返回 `nil`；
-   `Err()`：当取消时（或者说 Done() 被 closed 时），返回错误，如果没有取消，返回 `nil`；
-   `Value()`：通过 key 来 获取 context 携带的值；

下面这个官方文档的例子中，展示了我们该如何使用 `Done()` 与 `Err()`：

```go
func Stream(ctx context.Context, out chan<- Value) error {
 	for {
 		v, err := DoSomething(ctx)
 		if err != nil {
 			return err
 		}
 		select {
 		case <-ctx.Done():
 			return ctx.Err()
 		case out <- v:
 		}
 	}
 }
```

目前这个包提供了几种常用的用法，其中包括了：

-   `context.TODO()`：空的 context，算是个 placeholder，如果打算重构 web 服务的实现，可以用上这个来暂时实现；
-   `context.Background()`：一般用在最开始的地方，用来派生出子 context；
-   `context.WithCancel()`：可用来手动取消 goroutine；
-   `context.WithDeadline()`：可设置一个固定的时间点，用来超时自动取消；
-   `context.WithTimeout()`：可设置一个固定的时间间隔，用来超时自动取消；
-   `context.WithValue()`：用来存储数据，如上文提到的认证信息、用户；

另外一个值得注意的点在于：**Context 默认不可变**，这点从它的几个函数就可以看出来：它们接收一个 parent，然后返回一个新的子 Context。

```go
func WithCancel(parent Context) (ctx Context, cancel CancelFunc)
```

```go
func WithDeadline(parent Context, d time.Time) (Context, CancelFunc)
```

```go
func WithTimeout(parent Context, timeout time.Duration) (Context, CancelFunc)
```

```go
func WithValue(parent Context, key, val interface{}) Context
```

具体的使用例子就不赘述了，可以看看官方文档以及 [Go 语言实战笔记（二十）| Go Context](https://www.flysnow.org/2017/05/12/go-in-action-go-context.html) ，我自觉暂时还写不出更好的教程 :P。

下面来说说它面临的争议。

### Context 的争议

在 Golang 的 Github Wiki 上，有这样一篇专门的 [ExperienceReports](https://github.com/golang/go/wiki/ExperienceReports) 页面，里面有一堆的文章列表，被各个作者用来表达他们的使用体验，里面就有专门讨论 context 的几篇文章，有褒有贬。

Michal Štrba 与 Jon Calhoun，分别在他们的文章 [Context should go away for Go 2](https://faiface.github.io/post/context-should-go-away-go2/) 以及 [Pitfalls of context values and how to avoid or mitigate them in Go](https://www.calhoun.io/pitfalls-of-context-values-and-how-to-avoid-or-mitigate-them/)，他们两个的反对主要集中在 `Value(interface{}) interface{}` 上，认为这个方法让我们损失了类型安全，即不能将错误在编译时检测出来。另外，它目前的实现只是一个效率低下的链表，事实上看下源码就不难发现确实如此，一旦 `WithValue()` 调用次数过多，则链表的查找效率就会降低，它的查找实现是 `O(n)` 的。

```go
func (c *valueCtx) Value(key interface{}) interface{} {
	if c.key == key {
		return c.val
	}
	return c.Context.Value(key)
}
```

另外就是 Michal Štrba 吐槽 [proposal: io: add Context parameter to Reader, etc](https://github.com/golang/go/issues/20280)，认为这太过分了：『你还不如爆我头』，他认为 Go 是一门普适的语言，不仅仅是用来实现 Web 服务的。

```go
type Reader interface {
  Read(context.Context, []byte) (int, error)
}
```

看着这个提议，确实很过分，我也同意作者的观点，毕竟这样既不优雅、又不简洁。

Dave Cheney 则在文章 [Context isn't for cancellation](https://dave.cheney.net/2017/08/20/context-isnt-for-cancellation) 中提到 Context 应该回归它本意，即只为 Value 的读写服务，Cancellation 这样的生命周期管理不应该放在 Context 里面。

Sam Vilain 则在[Using Go's context library for making your logs make sense](https://blog.gopheracademy.com/advent-2016/context-logging/) 歌颂 context 为打印日志带来的好处，毕竟这样可以将多个不同的日志串联起来了，方便调试。

Ross Light 在[Canceling I/O in Go Cap’n Proto](https://medium.com/@zombiezen/canceling-i-o-in-go-capn-proto-5ae8c09c5b29) 歌颂 Cancellation 为他的项目带去的便利，所以他觉得这是把好锤子，进而提出了上面那个被喷的 Read context 方案。

Iman Tumorang 在 [Avoiding Memory Leak in Golang API](https://hackernoon.com/avoiding-memory-leak-in-golang-api-1843ef45fca8) 讲述了 Context 如何帮他避免掉 goroutine 所带来的内存泄露。

最后，我想特别提下 Axel Wagner 在 [Why context.Value matters and how to improve it](https://blog.merovius.de/2017/08/14/why-context-value-matters-and-how-to-improve-it.html) 提到的观点：简单来说，作者让我们在提议去除 context 这个包之前，好好思考下：『我们是否需要一个规范的解决方案来管理单个请求范围内的传值，以及愿意为之付出多大的成本』。

确实，仅仅因为它的不足之处而提议删除有点因咽废食了。

### 使用 Context 的规范

目前看来，大部分人还是接受 context 的，而目前我们也可以用设计规范来尽量避免 `Value(interface{}) interface{}` 的问题，事实上官方在文档中也给了我们一个良好的示范：

```go
// Package user defines a User type that's stored in Contexts.
package user

import "context"

// User is the type of value stored in the Contexts.
type User struct {...}

// key is an unexported type for keys defined in this package.
// This prevents collisions with keys defined in other packages.
type key int

// userKey is the key for user.User values in Contexts. It is
// unexported; clients use user.NewContext and user.FromContext
// instead of using this key directly.
var userKey key

// NewContext returns a new Context that carries value u.
func NewContext(ctx context.Context, u *User) context.Context {
	return context.WithValue(ctx, userKey, u)
}

// FromContext returns the User value stored in ctx, if any.
func FromContext(ctx context.Context) (*User, bool) {
	u, ok := ctx.Value(userKey).(*User)
	return u, ok
}
```

这样，我们就可以以一种**类型安全**的方式在 Context 中传值了。

目前 (2019-08-26)，争议到还在继续，在 [proposal: Go 2: update context package for Go 2](https://github.com/golang/go/issues/28342) 中，他们想改进这个包，让我们能够更好的使用它，如果你也有想法，不妨也去参与讨论。

### P.S. 与 Thread Local Storage 关系

其实 context 出来之后，有开发者建议用 Thread Local Storage 来替换 context<sup>[3]</sup>，但是官方认为 TLS 的设计不明确，里面用 map 实现的 storage 会不可避免地增大，因此潜在的代价会很大。

### Ref

1.  [Go Concurrency Patterns: Context][1]
2.  [proposal: Replace Context with goroutine-local storage][2]
3.  [Dapper, a Large-Scale Distributed Systems Tracing Infrastructure][3]

[1]: https://blog.golang.org/context

[2]: https://github.com/golang/go/issues/21355

[3]: https://ai.google/research/pubs/pub36356


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/118 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
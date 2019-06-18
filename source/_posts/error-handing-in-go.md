---
title: Golang 中的错误处理
date: 2018-12-16 22:20:23
tags: [Golang]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/94
---
<!-- en_title: error-handing-in-go -->

错误处理在编程处理中，可谓是最重要也是最伤脑筋的一块内容，因为在绝大多数情况下，正确的途径只有几条，而剩下的几十上百种的情况便都是错误了，不同意？编译原理中提到的编译器了解下 :P 。

<!-- more -->

### 高级语言中的错误处理

高级语言中，在调用一个函数发生错误的时候，通常会用抛出错误的方式来退出处理逻辑，如 Java，JavaScript, Python 等等。

```js
try {
  doSomething()
} catch (e) {
  console.error(e)
}
```

这种处理是比较简便的，只是，**『意外』** 总是出现在你意想不到的地方，你以为调用这个函数没问题，于是不加 `try catch`，但某一天它可能会冷不丁给你一个 **『意外』**。

同时还有另外的一种处理方式，便是将错误作为函数的返回值，比如在写 C/C++ 的时候，很多 API 遍会用程序返回值 0 表示正常，其它数字都表示错误，用 Linux 的 文件操作 POSIX 部分 API 举例[1][2]：

```c
int open(const char *path, int oflag, .../*,mode_t mode */);
int openat(int fd, const char *path, int oflag, ...);
int creat(const char *path, mode_t mode);
FILE *fopen(const char *restrict filename, const char *restrict mode);
```

基本上，它们的返回值都是用 -1 表示错误，而用 0 表示正常。

还有一个最常见的例子：最基本的 main 函数返回值也是用 0 表示正常，其它数字表示错误。

### Golang 中的错误处理

Golang 就不一样了，它采用了一种 **error last** 的返回值方式来返回错误（其实目前似乎没有 **error last** 这种说法，我是根据 Node.js 中历史悠久的 callback API 风格中的 **error first** 联想来说的），也就是除了 `nil` 之外的都是错误，这造成一种问题便是，你的代码中，很可能大部分都是这种代码：

```go
if err != nil {
  return err
}
```

于是我们的一个业务逻辑的处理函数中，就可能有十多处这样的代码，显得非常不美观，尤其是对有代码洁癖的人来说。

所以，有些人也会用 `panic` 跟 `recover` 来处理，完全仿照其它语言的 `try catch` 方式，这样的好处是代码中判断返回错误的代码会少很多，显得紧凑美观，坏处是不符合 Go 的设计以及推荐的实践，以及，总会有你意想不到的 **『意外』**。

应该说，Go 的错误处理是在设计上还是比较符合实践的，它最大的好处便是：将所有的错误都**非常明确地**集中在那最后的那个返回参数中，让你能够轻松地处理少一点的错误，对的，**不用考虑会有意外，你不会也不能忘记这个非常明显的最后一个返回值参数**。

所以，可以认为这种设计是一种妥协，用不那么优雅紧凑的代码，换取你能节约精力以便少处理错误情况。[3]

### Golang 错误类型判断

在常见的错误判断中，我们可能会用类似于以下的代码来判断：

```go
if err.Error() == "NotFound" {
  // ...
}
```

但实际上这种方式不被推荐，因为有可能 `err.Error()` 的返回值会改变，即使你用上了正则表达式去判断。

#### 提供判断方法

因此，如果你是提供 API 的一方，建议做法是加入一个方法来判断是否是某个错误，拿 `os` 包中判断是不是文件不存在的错误的例子来说明：

```go
if _, err := os.Stat(cacheDir); os.IsNotExist(err) {
   // ...
}
```

这就是个很好的例子，即使以后 `os.Stat` 返回的错误返回值变化了，我们还是能够根据 `os.IsNotExist` 这个方法来判断这个错误是不是文件不存在的错误。

#### Type assertion

另外我们还可以通过类型判断的方式，比如你写的 `custom` 包中，有个错误类型叫做 `CustomError`，那我们就可以用这样的方式来判断错误种类了：

```go
if nerr, ok := err.(custom.CustomError); ok {
  // ...
}
```

也可以这样：

```go
switch err := err.(type) {
case nil:
   // ...
case custom.CustomError:
   // ...
case custom.OtherCustomError:
   // ...
default:
   // ...
}
```

### 什么时候适合使用 panic

一般推荐是：**在程序使用简单的返回错误很难处理的时候**，就比如递归函数中，最简单的例子便是 `json` 包，它使用了一系列的递归函数来解码 json 数据，但是一旦遇到错误，那整个解析便会 `panic`，造成停止其它部分的解析，返回最顶层的调用，但是在返回给调用方错误的时候，就不是 panic 了，它会使用 `recover` 转换为正常的错误，这样，就不会给调用方造成意外情况。[8][9]

这也就给了你一个很好的指导原则：**即使你写的包中使用了 panic ，你也需要在对外的 API 中提供 recover 之后的 err**。

### 为何不用公共错误类型

我们在提供错误类型的时候，可能会想要提供一个比较通用的错误类型[6]，但其实这不是一个好的做法，因为提供的错误信息太少。

想象下 Java 中的 `NullPointerException` 跟 `IllegalArgumentException`，这两者提供的错误信息太少。

因此，建议在实践中，在错误中加入足够的信息，及时错误本身的名字也是信息，而参数错误也要告诉用户那个参数错误，或者缺少了，甚至是调用栈也需要提供。

当这些信息打印到日志中被收集展示后，将会是你快速定位处理错误的最佳法宝。

说到这里就需要推荐一个包了：[pkg/errors](https://github.com/pkg/errors)，他提供了两个方法 `Wrap` 用来提供更多的错误上下文，而 `Cause` 则是提取 wrap 过的原始错误。

### Web 中常见的做法

假如你用 golang 来写 web 程序，那通常会建议你实现一个带有 HTTP Status Code 的错误类型，来包装程序中出现的错误：

```go
type webError struct {
    Error   error
    Code    int
} 
```

将状态码加入错误中后，你就能根据错误类型，比如参数不对，那一般是 400，而服务器内部错误则是 500。

```go
e := webError{err, 400}
http.Error(w, e.Error(), e.Code)
```

当然了，你也可以根据自己的需要，加入更多的信息来帮助定位错误，比如错误栈，只是也要注意安全问题，不要在公共接口中返回这种信息。

### P.S.

我认为 Golang 中错误处理的设计其实是在逼你认真对待程序中出现的错误，就比如我们常说要好好做单元测试、代码风格、文档等等，但是我们通常在赶时间的时候会忘记这些重要的东西，积累一堆又一堆的技术债务。

人都是懒惰的，尤其是做工程师的我们，所以我们做单元测试、写文档、规范代码风格，并且在流程上用 CI 来实施，而这个流程是强制的，因为想从一开始就逼你把事情做好。

### P.P.S.

有时间不妨多看看 golang 的官方博客，能够学到很多有意思的东西。

### Ref

1.  <https://en.wikipedia.org/wiki/Open_(system_call>)
2.  <https://en.wikipedia.org/wiki/File_descriptor>
3.  <https://www.quora.com/Do-you-feel-that-golang-is-ugly>
4.  <https://stackoverflow.com/questions/30930042/managing-errors-in-golang>
5.  <https://opencredo.com/blogs/why-i-dont-like-error-handling-in-go/>
6.  <https://stackoverflow.com/questions/30177860/does-go-have-standard-err-variables/30178766>
7.  <https://golang.org/doc/effective_go.html#errors>
8.  <https://blog.golang.org/error-handling-and-go>
9.  <https://blog.golang.org/defer-panic-and-recover>
10. <https://dave.cheney.net/2014/12/24/inspecting-errors>
11. <https://dave.cheney.net/2016/04/27/dont-just-check-errors-handle-them-gracefully>


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/94 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
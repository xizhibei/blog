---
title: Golang 中的测试
date: 2018-12-31 13:01:56
tags: [Golang]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/95
---
<!-- en_title: testing-in-golang -->

长期以来，有时候会不重视测试，尤其是赶项目时间的时候，而近来自己可以规划的时间多了之后，就开始想，如何才能把测试做好。

在这个实践测试的过程中，我也开始对一些设计原则有了更深一步的理解与思考。

> 杰出的开发者每编码一小时，就会花上两小时进行测试。 -- Bruce Rosenblum, Disney-ABC TV Group President Of Business Operations

<!-- more -->

### 测试种类
一般来说，我们在日常的软件开发过程中，会用到以下几种测试：

1. 单元测试：即作为开发工程师开发任务的一部分，通常我们会将实现按层级拆分成最小单元，大部分情况下，就是函数，然后通过各种测试技术来测试我们实现的函数，对于 web 来说我们还会用 HTTP API 来测试，单元测试的优点就在于简单，以及执行快，非常方便进行自动化，所以我们会鼓励多进行测试：开发中随时测试，提交时 git hook 触发测试，以及提交后 CI 进行测试，另外更进一步还可以使用 TDD；[1]
2. 集成测试：即将所有的部分集成后进行测试，测试的目的在于验证各个模块之间的数据通信，这种测试成本比较高，如果还涉及到状态的话，就会更难测试，所以会在单元测试没问题后，才进行集成测试，一般来说会交给测试人员进行测试，一定程度上也可以进行自动化。而作为开发人员也可以进行测试，比如服务端工程师的可以用工具单独测试 API（比如 Postman）客户端工程师可以 Mock API 测试；[2]
3. 系统测试：这种测试包含的内容就多了，比如对于后端来说我们的部分 API 需要进行压力测试，性能测试，以保证在一定的流量下面不会让系统垮掉，而对于客户端来说需要进行用户体验测试；[3]
4. 验收测试：即提交给需求方进行测试了，在互联网产品中，就意味着直接发版本进行 beta 测试或者灰度测试了；

这几种测试的成本会依次升高，即意味着对于开发者来说，需要你多做成本低的单元测试，而不是等着 QA 找到你或者客服反馈用户问题，这样的成本对于所有企业来说成本都是很高的。** 越早发现，修复成本越低。**

接下来会以 Golang 为例，说说单元测试。

### 单元测试
Golang 自带测试框架，它会推荐你将测试代码与源代码放在一起，而测试代码的文件名需要源码文件的名字带上 **_test** 后缀。

另外，我们写单元测试的时候，需要保证的事情就是必须保证每一个测试是互相隔离的，而 go 会将每一个测试用单独的 goroutine 来执行，也就是并发的，在设计上强制你必须隔离。（在 Node.js 中，推荐使用 ava 这样的测试框架，也是并发执行。）

#### 框架
go 自带的测试框架没有实现 BDD 的那套东西，比如 Setup 以及 TearDown，而 [testify](github.com/stretchr/testify) 提供的 suite 包可以达到这一点，一定程度上让你写起来更顺手些，而它提供的 assert 相对自带的 assert 包功能更丰富些。

#### Mock
Mock 模块的时候，你可以使用官方提供的 [mock](https://github.com/golang/mock) 来生成 mock 代码：

```bash
go get github.com/golang/mock/mockgen
mockgen -source=pkg/storage/interface.go -destination=mock/storage.go -package=mock
```

另外，如果使用了 SQL，可以使用 [go-sqlmock](https://github.com/DATA-DOG/go-sqlmock)。另外，这个模块对于 gorm 依然是可以用的：

```go
mockDB, sqlMock, err := sqlmock.New()
database, err := gorm.Open("mysql", mockDB)
```

#### HTTP 测试
[gofight](https://github.com/appleboy/gofight) 提供了基于 go httptest 的测试工具，很方便。

```go
r := gofight.New()

r.GET("/").
// turn on the debug mode.
SetDebug(true).
Run(BasicEngine(), func(r gofight.HTTPResponse, rq gofight.HTTPRequest) {

  assert.Equal(t, "Hello World", r.Body.String())
  assert.Equal(t, http.StatusOK, r.Code)
})
```

### 测试之外
介绍了 Go 中的单元测试，而在这个测试的过程中，才对软件架构有了更深的理解，明白了在 golang 中，什么是可测试的代码实现。

比如在设计模式中常常提到的 SOLID 原则，我们拿最后一个 DIP （依赖倒置原则）来说，我们实现的 ** 设计需要多依赖于抽象，而不是具体实现 **。这样的一个好处便是可以利用这个原则来 mock 某个模块依赖的各个模块，当依赖的模块是一个抽象后，我们便可以采用依赖注入的方式，将 mock 的模块传入要测试的模块中，进行测试。对了，其实我之前在 [Go-kit](https://github.com/xizhibei/blog/issues/78) 中也提到过。

另外，我还是那句话，** 把事情做好的方式就是一开始把事情做好 **：早点做单元测试，集成进 CI，在日常开发过程中，谁把单元测试覆盖率搞低了，谁就要请客喝下午茶。

最近发现 LinkedIn 的 CEO 也有类似的说法：

> 你在项目开始的头一个星期所要求的代码质量，将会成为之后每周代码质量的缩影。 -- Joe Kleinschmidt, CEO and Co-Founder LinkedIn

### Ref
1. https://www.guru99.com/unit-testing-guide.html
2. https://www.guru99.com/integration-testing.html
3. https://www.guru99.com/system-testing.html
4. https://segment.com/blog/5-advanced-testing-techniques-in-go/
5. https://medium.com/@romanyx90/testing-database-interactions-using-go-d9512b6bb449


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/95 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
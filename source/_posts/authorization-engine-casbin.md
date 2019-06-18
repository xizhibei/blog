---
title: 权限引擎之 casbin
date: 2019-03-24 22:39:28
tags: [Golang,系统设计]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/102
---
<!-- en_title: authorization-engine-casbin -->

在[上次介绍了权限系统的设计](https://github.com/xizhibei/blog/issues/101)后，这次我们来说说如何实现系统的实现。

复习一遍上次提到的内容，我们知道：

> 权限就是规定谁可以对什么资源进行什么样的操作。

那么，权限引擎就是根据这个原则来进行设计，于是，就引出了我们今天想介绍的工具：[casbin](https://github.com/casbin/casbin)。

不过，今天想换种方式，如果我们自己要做个权限引擎，改如何实现呢？

### 假如我们自己实现

#### 我们的需求

1.  与具体业务场景无关，即所有的角色、资源以及操作都是抽象的；
2.  适应任何权限模型，如 ACL，RBAC、ABAC；
3.  管理相关的存储;

#### 功能

我们理想中的情况就是：可以在中间件中，统一对用户进行鉴权，如果没有权限，中止继续访问，返回 HTTP status code 403，而如果有权限，则放行。

那么，再具体细化，就是这个权限引擎应该给我们提供至少以下几个接口：

-   判断某个用户 ID 是否具有权限;
-   管理用户角色，甚至角色组;
-   管理角色的权限，即可以对那些资源进行什么样的操作;

#### 实现

在这个模型中，有三种实体：

-   角色：subject(用户可以与角色合并成为 subject，于是角色组也可以表示了)；
-   资源：object;
-   操作：action;

然后，就是它们的关系，我们可以分为模型与规则，模型即 ACL、RBAC 等，而规则会涉及到具体业务对象，可以理解为模型相当于代码，而规则代表数据，比如在 RBAC 中，规定哪个用户会有什么角色，哪个角色可以对具体的资源进行什么操作等等。

好了，大致的需求就到此，因为往深了说就没完了，而这些简单的功能，我们都可以在自己的系统中去实现，毕竟如何运行都明白了。

只是，**我们往往会做得跟业务比较耦合，因为一旦需要做个普适性的权限引擎，这点是完全不够的，你需要根据模型与规则，编写一套相应的规则引擎**。所以，还是回到我们今天的主角，我们现在来看看 casbin 是如何实现的。

### Casbin 的介绍

正如上面所说，它把模型称为 model，而规则称为 policy。

#### Model

一个具体的 RBAC model：

```conf
# Request definition
[request_definition]
r = sub, obj, act

# Policy definition
[policy_definition]
p = sub, obj, act

# Policy effect
[policy_effect]
e = some(where (p.eft == allow))

# Matchers
[matchers]
m = r.sub == p.sub && r.obj == p.obj && r.act == p.act
```

我们可以看到，`Request definition` 即为请求定义，代表了你可以传入什么样的参数来确定权限，而 `Policy definition` 代表了规则的组成，这两处也就是我上面说的，这个模型规定了，谁 (sub) 可以对什么资源 (obj) 进行什么操作(act)。

`Policy effect` 则表示什么样的规则可以被允许，`e = some(where (p.eft == allow))` 这句就表示当前请求中包含的任何一个规则被允许的话，这个权限就会被允许，而反过来，假如是 `e = !some(where (p.eft == deny))` 则表示，只要有一个规则被拒绝了，这个权限请求就会被拒绝，也就是说所有的规则都要被允许才能继续。

`Matchers` 表示请求与规则是如何起作用的，上面配置中的例子告诉我们，只有当请求与规则的 sub、obj、act 都相匹配的情况下，这条规则才会被批准。

#### Policy

与上面的模型相对应的规则，可以这样来写：

```csv
p, alice, data1, read
p, bob, data2, write
```

这两条记录就表示，alice 可以对 data1 进行读取，而 bob 可以对 data2 进行写入，那么接口的判断条件可以类似于这样的接口： `isAllow('alice', 'data1', 'read')`。

#### 在项目中使用

下面我们以 Golang 来简单说说如何在我们的项目中使用。

很简单：

```go
e := casbin.NewEnforcer("path/to/model.conf", "path/to/policy.csv")
```

这句就是初始化了，然后：

```go
if e.Enforce(sub, obj, act) {
    // 允许继续操作
} else {
    // 拒绝请求
}
```

是不是很简单呢？

在实际使用过程中，我们可以将这个步骤封装到一个中间件内统一处理，大致原理是将用户的 ID 与角色进行绑定，然后用 `Enforce` 来判断每次用户的请求是否被允许。

而当我们的系统是 Web 系统时，就更方便了，尤其是 RESTful 接口，每一个路径都是资源，而操作就是 `GET, POST, PUT, DELETE` 等。

对应例子可以利用 casbin 的内建函数来处理，将模型中的 matchers 改为：

```conf
[matchers]
m = r.sub == p.sub && keyMatch2(r.obj, p.obj) && regexMatch(r.act, p.act)
```

对应的规则改为：

```csv
p, role1, /users/:id, GET
p, role2, /users/:id, POST
p, role3, /articles, .+
```

#### 存储

我们可以看到，它默认的规则存储在 CSV 文件中，但是也可以存储在其它地方，比如各种数据库，具体可以去[policy-storage](https://casbin.org/docs/en/policy-storage)查看。

#### 其他

Casbin 目前支持多种语言，以及多种储存，更重要的上面我提到的几种权限模型它都支持，可以说是非常强大了。

假如是微服务，它也可以作为一个独立的权限微服务或者 API 网关的模块存在：<https://casbin.org/docs/en/service。>

核心代码其实是基于 github.com/Knetic/govaluate 来实现的，有兴趣的可以去[看看](https://github.com/casbin/casbin/blob/master/enforcer.go)。


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/102 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
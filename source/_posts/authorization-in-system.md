---
title: 系统权限的设计 
date: 2019-03-09 15:29:28
tags: [架构, 系统设计]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/101
---
<!-- en_title: authorization-in-system -->

今天，我们来说说系统设计中的权限设计（其实是为了之后写实践做铺垫 🌝)。

### 前言
一般来说，我们在设计与人有交互的系统时，如果涉及到多用户能对同类资源进行操作的时候，就会有区分权限的需求了。

最简单的例子莫过于普通用户与管理员，两者进行操作的客户端不一致，普通用户可以用专门的 APP 或者小程序进行登陆操作，而管理员却有一个专门的管理后台，能够进行一些影响比较大操作：审核内容、发布公告、退款等等。

而即使是管理员，在管理后台中，也会有不同的权限，比如编辑管理员可以被授权审核内容，而退款却需要财务或者主管之类的管理员才能被授权进行操作。

这里需要强调下，认证（Authentication）与授权（Authorization）是两个不同的概念，虽然他们的英文单词很像。

认证的时候，只有能不能登录这种说法，在 Web 程序中对应的是 HTTP Status 401 错误，而授权认证则是登录之后才会进行的操作，对系统内的资源，你是不是有权限进行操作，没有的话对应的是 HTTP Status 403 错误。

### 权限认证的种类
下面我们来说说几种比较流行的权限模型。

ACL[1], RBAC[2], ABAC[3]，他们本质上，都是在解决 ** 谁可以对什么资源进行什么样的操作 ** 这个问题。

#### Access Control List (ACL)
这种模型非常简单，即直接将用户与权限进行一一对应，如：

```
Alice -> read:article, update:article
Bob   -> read:article, del:article
```

通过这张 ACL 表，我们在程序中可以直接对响应的用户进行权限判断，实现起来也非常简单。权限对应 ** 行为 + 资源 **，即每一种权限对应可以对什么资源进行什么样的操作。

在我们设计 Web 程序中的 RESTful 接口的时候，权限就可以设计为：

```
Alice -> GET /article, PUT /article
Bob   -> GET /article, DELETE /article
```

只是，这个模型缺点也非常明显：每次在系统中添加新用户的时候，我们必须给他全部设置一遍权限，非常麻烦，在资源类别少的时候，我们可以忍受，随着业务的发展，我们同事越来越多，资源类别也越来越多的时候，管理员的工作就会非常痛苦。

#### Role Based Access Control (RBAC)
这种模型是对 ACL 模型进行拓展后得来的，既然用户与权限一一对应很麻烦，那我们不妨在用户与权限之间进行解耦，引进 ** 角色 ** 这个概念，即我们在系统初始的时候，只需要按照角色进行权限设置，之后对于每一个新添加的角色，我们只需给他分配角色即可。这种模型大大减少了工作量，也方便与组织结构进行一一对应，是目前主流的权限模型。

而且，它还可以拓展，以便更进一步的简化，比如引入 ** 资源组以及角色组 **，让管理员可以更方便地管理权限。

```
ArticleEditor -> read:article, update:article
ArticleAdmin  -> read:article, del:article

Alice -> ArticleEditor
Bob   -> ArticleAdmin
Lily  -> ArticleEditor
...
```

这种模型，也有缺点，因为整个模型不能很细化，如果我想规定：

- 编辑不能在办公室之外的地方进行操作，以及不能在下班之后进行操作；
- 运营同事可以直接批准退款 100 元以下的订单，超过才需要主管批准；

如果一定要完成这样的权限细分需求，我们就需要换 ABAC 模型了。

#### Attribute Based Access Control (ABAC)
ABAC 可谓是非常强大的模型，它允许你完成非常细化的权限需求，它所有的权限都是依赖于用户、角色、行为、资源甚至环境的属性。

比如加上环境属性后，我们就可以对用户或者角色的登录 IP、时间以及地理位置进行授权判断。

然后再加上其它几个属性，我们可以组合成非常丰富的权限策略 [3]：

1. 一个用户可以查看它所在部门内部的文档；
2. 一个用户可以编辑一个处于草稿阶段的文档；
3. 早上 9 点之前，禁止登录用户查看任何文档；

缺点，与 ACL 有点类似：** 非常繁琐 **，而且非常依赖于规则引擎，而这种引擎无法独立于系统，即需要与系统耦合在一起。

于是我们看到，正是由于 ABAC 太复杂，难以使用，k8s 在 1.3 版本后引入 RBAC alpha，1.6 beta，并在 1.8 后转为 GA。（顺便可以回顾下我之前写的 [kubernetes 中的权限管理](https://github.com/xizhibei/blog/issues/64))

### Ref
1. https://en.wikipedia.org/wiki/Access_control_list
2. https://en.wikipedia.org/wiki/Role-based_access_control
3. https://en.wikipedia.org/wiki/Attribute-based_access_control

***
首发于 Github issues: https://github.com/xizhibei/blog/issues/101 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
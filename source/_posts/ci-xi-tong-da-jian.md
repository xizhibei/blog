---
title: CI 系统搭建
date: 2016-08-22 23:06:16
tags: [DevOps,Gitlab]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/26
---
不知道，你有没有遇到类似的情况：
- 不重视测试，开发新功能都是手工测试
- 每次开发新功能，都会懒得去做回归测试，线上经常出问题
- 新同事来，不熟悉系统，提交的代码会把系统搞坏
- 测试覆盖率一直非常低

这时候，你需要个 CI，也就是持续集成。

我理想中的团队开发流程中，CI 是最重要的一环，团队成员按照 git flow 开发，然后提交，等待 CI 测试通过，最后提交 pull request，让同事 Code Review。

在以后，还可以加入 CD，即当提交到 master 通过之后，构建并打包 docker，部署到正式环境。
#### 好处：
- 快速发现错误。每完成一点更新，就集成到主干，可以快速发现错误，定位错误也比较容易。
- 防止分支大幅偏离主干。如果不是经常集成，主干又在不断更新，会导致以后集成的难度变大，甚至难以集成。

CI 也是敏捷开发流程中最重要的一环，是否还记得这句口号？

> 自动化一切
#### 搭建

我选择的系统是 gitlab，自带 pipeline 可以当成 CI&CD，老牌的 jenkins 也可以考虑，只是插件式的不如写个 pipeline 的定义文件来得方便。当然了，第三方服务如 Travis, Codeship 也不错。
只是，我的考虑是：首先，我的项目中带有私有的 npm 包，目前我已经搭了一个 npm private registry；其次，国内的服务让人很不放心，国外又太慢；

最方便的简单搭建可以看看这个：
https://github.com/sameersbn/docker-gitlab
#### 配置 .gitlab.yml

由于是 nodejs，项目，这里就直接贴我的了，其他的，你们自己解决了 ^_^。

另外，建议 executor 选择 shell，简单，可配置性强，另外，node 的 version 可以用 nvm 解决。

``` yml
variables:
  NODE_VERSION: v4.2.2
  NODE_ENV: development
  npm_config_registry: http://<you_private_registry>/
  npm_config_loglevel: warn
  PHANTOMJS_CDNURL: https://npm.taobao.org/mirrors/phantomjs
  SELENIUM_CNDURL: https://npm.taobao.org/mirrors/selenium
  ELECTRON_MIRROR: https://npm.taobao.org/mirrors/electron/
  SASS_BINARY_SITE: https://npm.taobao.org/mirrors/node-sass
  NODEJS_ORG_MIRROR: http://npm.taobao.org/mirrors/node
  NVM_NODEJS_ORG_MIRROR: http://npm.taobao.org/mirrors/node
  NVM_IOJS_ORG_MIRROR: http://npm.taobao.org/mirrors/iojs

before_script:
  - source ~/.nvm/nvm.sh && nvm install $NODE_VERSION

# This folder is cached between builds
# http://docs.gitlab.com/ce/ci/yaml/README.html#cache
cache:
  key: "$CI_BUILD_REF_NAME"
  untracked: true
  paths:
  - node_modules/

test_all:
  stage: test
  script:
    - npm install
    - npm run lint
    - npm run coverage

```
#### 代码的覆盖率

我选的是 istanbul，npm 的 script 加一个：
`./node_modules/.bin/istanbul cover ./node_modules/.bin/_mocha -- test/`

gitlab 上对应的正则填这个：
`Lines\s*:\s*(\d+.\d+)%`
#### Reference

http://www.ruanyifeng.com/blog/2015/09/continuous-integration.html
https://www.zhihu.com/question/23444990


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/26 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
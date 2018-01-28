---
title: 使用 TypeScript 开发 NPM 模块
date: 2018-01-28 12:46:47
tags: [Node.js,TypeScript]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/68
---
<!-- en_title: developing-npm-module-with-typescript -->

最近对 TypeScript 很是着迷，或者说是在使用的过程中找回之前使用强类型语言写后端程序的感觉，在介绍 TypeScript 之前，先简单说说 JavaScript 的历史。

<!-- more -->

### JavaScript 的黑历史
话说，那是个注定要在互联网历史上留下浓重墨笔的时代，有一天，网景公司的领导把 Brendan Eich 叫到办公室

『Eich 啊，你看我们这刚发布的 Navigator 浏览器很牛叉吧？』
『那必须。』
『只是呢，用户只能看啊，不能摸，哦不，是不能交互啊。』
『对的。』
『那，你说说，我们该怎么办呢？』

Eich 立马在心理念叨：『天呐，升职加薪，赢取白富美走上人生巅峰的机会来了，得好好表现！』
 
『领导，我知道，我们可以在浏览器中加入一门脚本语言，这样用户可就可以跟浏览器交互了。』
『不错，那该加什么呢？』
『Perl、Python、Tcl、Scheme 都可以。』
『还有其它的选择吗？』
『可以发明一种新语言』
『这个怎么说？』
『您看我们与 Sun 公司关系那么铁哥们，不如发明一门跟 Java 很类似的语言，可以根据浏览器环境专门定制，之后也方便跟 Sun 公司联合推广。』
『小伙子，不错，行，就这个了！』
『好的，领导，我立马去设计！』
『对了，你预计要多少时间？』
『一个月，我保证设计出来』
『这个，你看，我们时间不够啊，能不能早一点？』

Eich 呆住了：『时间不够啊，算了，咬咬牙加班搞定吧，三周应该够了，刚想说出口，看着满脸笑意的领导，又后悔了，这是在考验我呢！』

『领导，给我 15 天时间。』
『10 天！好，就这样，去忙吧，期待你优秀的表现啊。』

Eich 满脸苦逼，早知道说三个月的，没准最后能给一个月。

就这样，应验了那句老话 **『Deadline 从来不是第一生产力，只是给了你把一堆 shit 上交上去的勇气』**，怀着这样的勇气，Brendan Eich 也不会意识到这门语言会成为未来互联网的第一大语言，就在 10 天的时间里，设计出了 JavaScript 语言。（其实，已经比大部分的我们都牛叉了

** 以上故事纯属瞎扯 **，但大致的诞生过程类似，具体可以看 [1]。

### TypeScript 应运而生
其实在 Node.js 诞生之后，JS 开始真正火爆大江南北，占据了互联网开发语言的几乎半个江山，尤其是创业公司，之后为了进一步的发展，负责制定 ECMAScript 规范草案的委员会 TC39 对 JS 进行了进一步的改善，在这两年中 EcmaScript 6  标准大行其道。

Node.js 的灵活性与便捷性给了创业公司节约了大量的开发成本，让他们能够以一种语言就能前后端通吃，快速开发，再配合着敏捷开发流程，简直是如虎添翼。

然而，这种灵活与便捷也意味着它是 ** 一种非常容易欠技术债务的语言 **，我们之所以使用各种 Lint 工具以及大量的单元测试，就是用来保证代码质量，显然，这是一种不得已的妥协。

尤其是在服务端开发过程中，灵活的类型意味着可能存在的频繁类型转换，也就意味着性能的损耗，同时，大量的模块中的类型信息几乎只能去文档中查找。

怎么解决这类问题呢？可以考虑加上类型。

TypeScript 是其中一个目前被广泛接受的方案，它是 JavaScript 的一个超集，也就是说它可以编译为 JavaScript。尤其是伴随着 VSCode 这一神级 IDE（话说，从接触的那一刻我就放弃了 WebStorm），逐渐为开源社区所广泛接受与发扬光大。这一刻，从来没觉得微软也能这么谦卑与靠谱，顿时黑转粉。

TypeScript 提供了 ES6 转为 ES5 以及在『你认为必要的地方』添加类型检查 [2]，对的，它没有大包大揽，而是彻底拥抱开源社区：『By the community, for the community. 』

于是，使用 TypeScript 的过程中，你完全可以使用 JS 语法，并在『你认为必要的地方』可以添加类型，这样，如果使用它开发基础库，你完全可以做到不丢失类型信息，以及做到 **『代码即文档』**。

### 如何使用 & 实际的例子
其实在开发属于自己 NPM 包之前，还是纠结了一会儿，因为不怎么熟悉 TypeScript，但是考虑到我写的 NPM 包需要提供详尽的类型以及完善的文档这一点后，我还是决定用 TypeScript。

具体的语法，请出门左转至 [TypeScript 官网](https://www.typescriptlang.org)。

下面提几个开发过程中需要注意的几个点：

#### 配置
tsconfig.json 这个文件是 TypeScript 必备的配置文件，使用 tsc 来编译文件的时候，默认就会读取当前目录下的 tsconfig.json 来进行编译。

比如我在 [getui-rest-sdk](https://github.com/xizhibei/getui-rest-sdk) 中使用的配置：
```json
{
  "compilerOptions": {
    "outDir": "./dist",
    "declaration": true,
    "target": "es5",
    "sourceMap": true,
    "module": "commonjs",
    "lib": [
      "es2016"
    ],
    "typeRoots" : [
      "./node_modules/@types/"
    ]
  },
  "include": [
    "./src/**/*",
    "./test/**/*"
  ],
  "exclude": [
    "node_modules"
  ]
}
```

对的，这又是个无耻的广告，关键是个推本身提供的 SDK 太烂了，而我也刚好想要写个模块练手，就把个推的 REST API 封装了下。如果你们的 Node.js 项目中使用了个推，欢迎尝试，另外，这个模块已经在我们的生产环境中平稳运行超过两个月了。

#### Lint 工具
之前一直使用 ESLint 工具来规范 JS 代码，但是对于 TypeScript 来说，可以使用 TSLint，毕竟 ESLint 是针对 JS 的，TypeScript 可以用这个专门的 TSLint。

#### 类型
一般情况下，有两种为 NPM 包提供类型的方式：

一种是在 [DefinitelyTyped](https://github.com/DefinitelyTyped/DefinitelyTyped) 上面提交 PR，现有的大部分 NPM 包如果没有类型声明文件，可以在这里查找。一般为了图方面，可以直接 `npm i @types/<package-name>` 来查看是否有对应的包。

另一种，就是 NPM 包的管理者主动将类型文件添加到包里面，这个类型文件可以是根目录下单独的一个 index.d.ts 文件，也可以是任意位置，然后将这个入口文件写到 package.json 里面的 types 或 typings 字段中。

之后呢，就可以在 VSCode 中使用的过程中直接 `^ + Space` 来直接使用相关的 API 了。

![](https://xizhibei.github.io/media/15167944332909/15170461711355.jpg)


#### 测试 & 覆盖率
我在项目中使用的是 ava + nyc，其实 ava 并不是像支持 ES6 一样支持原生的 TypeScript 编译，需要你编译为 JS 代码后才能运行 ava (其实也可以，但需要 require 一个比较蛋疼的运行时编译： ts-node ）。

而至于代码覆盖率，nyc 是与 ava 配合使用的，需要注意的是 nyc 的配置，比如我放在了 package.json 中：

```json
"nyc": {
  "extension": [
    ".ts"
  ],
  "reporter": [
    "lcov",
    "text-summary"
  ],
  "include": [
    "dist/src"
  ],
  "all": true
}
```

其中 include 非常关键，因为用 ava 的时候，运行的是 dist 里面的代码，因此，nyc 所对应的代码覆盖率也是针对 dist 里面的编译后代码的。

可能你会疑惑，那 ts 的代码覆盖率怎么查看？

其实不用担心，因为我们编译成 js 文件的时候，选择了产生 Source Map，因此最后生成报告的时候，会将报告里面的代码转换成原始的 ts 代码，你可以在 coverage/lcov-report 中查看网页版覆盖率报告。

### Ref
1. [Javascript 诞生记](http://www.ruanyifeng.com/blog/2011/06/birth_of_javascript.html)
2. [现在 TypeScript 的生态如何？](https://www.zhihu.com/question/37222407)



***
原链接: https://github.com/xizhibei/blog/issues/68

![知识共享许可协议](https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png "署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）")

本文采用 [署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh) 进行许可。

---
title: Webpack 在后端 APP 中的使用
date: 2016-04-25 23:24:03
tags: [Node.js]
author: xizhibei
---
一直都说，webpack 一般只作为前端项目的开发工具使用，非常方便，但是因为它太好用了，而且 react 后端渲染也需要用到，所以纯粹用到后端项目也是可以的。

比如我用在 koa 项目中，为了更好得使用 babel，（babel-node 太慢了。。。项目大了之后挺要命的。。。），用 webpack 的 hot reload，缓存，然后部分编译，不要太爽~

以下是我今天创建的项目中用到的文件，需要 node v4 以上版本，然后项目中用到 koa2，于是 `async-await` 很自然想用起来了。
### webpack.config.js

``` javascript
const path = require('path');
const webpack = require('webpack');
const nodeExternals = require('webpack-node-externals');

const includePaths = [
  path.join(__dirname, './src'),
];

module.exports = {
  entry: './src/server.js',
  target: 'node',
  plugins: [
    new webpack.BannerPlugin(
      'require("source-map-support").install();',
      {raw: true, entryOnly: false}
    ),
    new webpack.NoErrorsPlugin(),
    new webpack.HotModuleReplacementPlugin(),
  ],
  module: {
    loaders: [
      {
        test: /\.js$/,
        include: includePaths,
        loader: 'babel',
        query: {
          presets: ['es2015-node4'], // node v4 中很多特性已经默认打开，目前不用 es2015 这个 presets 了
          plugins: ['transform-async-to-generator'],
          cacheDirectory: '.tmp',
        },
      },
      {
        test: /\.json$/,
        include: includePaths,
        loader: 'json',
      },
    ],
  },
  output: {
    path: path.join(__dirname, 'build'),
    filename: 'backend.js',
  },
  devtool: 'sourcemap',
  externals: nodeExternals(),
};
```
#### Reference

[1] http://jlongster.com/Backend-Apps-with-Webpack--Part-I


***
原链接: https://github.com/xizhibei/blog/issues/7

![知识共享许可协议](https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png "署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）")

本文采用 [署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh) 进行许可。

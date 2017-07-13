---
title: 爬虫方案之 PhantomJS
date: 2016-05-06 12:18:43
tags: [Node.js]
author: xizhibei
---
发现 zombie.js 还是太弱了，很多地方不能满足需求，包括 request 的 HTTP 头也不合乎标准，于是硬着头去尝试下 PhantomJS。

这一试，我就后悔了，这么好的东西我居然不先尝试！怎么说呢，它比 zombie 好用太多，加载处理速度方面也是远远超过。唯一比较遗憾的是没有原生的 nodejs 接口，它只是一个环境，像 mocha 这样有自定义的变量，需要用它去执行 js 文件。所以如果要用到爬虫上面的话，需要通过第三方的包去包装一层。比如我用的 https://github.com/amir20/phantomjs-node

目前我没找到这个库一些常用的方法 utils，比如 waitFor 之类的没有实现，所以只能手动实现了，下面贴出我自己实现的：

``` js
async function waitFor(testFx, {
  timeout = 3000,
  delay = 100,
  silence = false,
}) {
  function sleep(t) {
    return new Promise((resolve) => {
      setTimeout(resolve, t);
    });
  }

  const start = new Date().getTime();

  async function _waitFor() {
    if (new Date().getTime() - start > timeout) {
      const e = new Error('Timeout');
      if (silence) return e;
      throw e;
    }
    const result = await testFx();
    if (!result) {
      await sleep(delay);
      return await _waitFor();
    }
  }

  return await _waitFor();
}
```

当然了，其他成熟的框架也有，比如
#### [SlimerJS](http://slimerjs.org/)

跟 PhantomJS 几乎一样，API 接口一致，但是没有 PhantomJS 不能获取 response body 的问题，是个替代品，但是它是基于 Gecko 的
#### [CasperJS](https://github.com/casperjs/casperjs)

包装了 PhantomJS 以及 SlimerJS，提供了一些语法糖，高层实现，挺适合做 e2e 测试的
#### [SpookyJS](https://github.com/SpookyJS/SpookyJS)

基于 CasperJS，提供了 nodes 的 API，就相当于上面 phantomjs-node 对 PhantomJS 封装，如果下次再做的话，我会考虑这个包。


***
原链接: https://github.com/xizhibei/blog/issues/10

![知识共享许可协议](https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png "署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）")

本文采用 [署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh) 进行许可。

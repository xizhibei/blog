---
title: 爬虫方案之 zombie.js
date: 2016-05-05 14:17:38
tags: [Node.js]
author: xizhibei
---
这几天在做爬虫的东西，腾讯的登录真能把人搞死。。。
首先是对 http 头做了校验，一旦顺序或者大小写不对，立马报 403 错误，然后最后密码加密那块 md5 + salt + RSA + 还有自创的 TEA 加密，我完全被搞晕了。

只能说它们的安全措施是做得非常好的，我搞了几天，完全用它的 JS 代码，本来还有希望的，今天再一看，登录相关的逻辑又改了。。。

所以，为了以后不蛋疼，想到用简单粗暴点的方案，直接模拟浏览器登录，搜了下，zombie 还有 phantomjs 都可以，但 phantomjs 似乎重了点，先拿 zombie 试试：https://github.com/assaf/zombie

``` bash
npm install zombie --save
```

这个项目看起来是做了很久了，但是最新的文档很差，我看了以前的文档是有的。

如下是个登录后取得 cookie 的例子：

``` js
function async getCookies(username, password) {
    // browser.debug();
    // browser.userAgent = ua;
    await browser.visit('http //example.com/login');

    await browser.wait({
        duration: '10s',
        element: '#submit',
    });

    await browser
        .fill('username', account.username)
        .fill('password', account.password)
        .click('#submit');

    return browser.cookies
}
```
#### 缺点

太慢；
耗内存；
#### 优点

能模拟真实用户登录；
可以在一定程度上绕过对方系统的反爬虫机制；
对于像腾讯登录那样复杂的前端加密验证可以简单绕过解决；


***
原链接: https://github.com/xizhibei/blog/issues/9

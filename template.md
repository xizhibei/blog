---
title: {{ &post.title }}
date: {{ date }}
tags: [{{ tags }}]
author: {{ post.user.login }}
issue_link: {{ &post.html_url }}
---
{{ &post.body }}

***
原链接: {{ &post.html_url }}

![知识共享许可协议](https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png "署名-非商业性使用-相同方式共享（BY-NC-SA）")

本文采用 [署名-非商业性使用-相同方式共享（BY-NC-SA）](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh) 进行许可。

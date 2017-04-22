---
title: {{ post.title }}
date: {{ date }}
tags: [{{ tags }}]
author: {{ post.user.login }}
---
{{ &post.body }}

***
原链接: {{ &post.html_url }}

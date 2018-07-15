---
title: {{ &post.title }}
date: {{ date }}
tags: [{{ tags }}]
author: {{ post.user.login }}
issue_link: {{ &post.html_url }}
---
{{ &post.body }}

***
首发于 Github issues: {{ &post.html_url }} ，欢迎 Star 以及 Watch

{% post_link footer %}
***
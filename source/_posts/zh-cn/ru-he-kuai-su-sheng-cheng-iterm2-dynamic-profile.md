---
title: 如何快速生成 iTerm2 Dynamic Profile
date: 2017-01-05 19:31:10
tags: [ansible]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/35
---
日常服务器运维中，很多情况下，我们得登录到远程，当服务器一旦多了之后，管理还是挺麻烦的。之前一直用的 **SSH Shell** 这个小工具，一直用的挺顺畅，直到看到它在不断接收文本太多之后一次又一次奔溃，终于打算放弃。

后来仔细回想，似乎 iTerm 2 的 Profile 的就能达到类似的效果：
1. 新建 Profile，在 "Send text at start" 中输入 "ssh host"，保存；
2. `CMD + O`，选择 host，确定，就可以直接连到服务器上面；

只是，那么多的 profile 要我手工录入无异于侮辱我是个工程师的身份。

赶紧问谷老哥，恩，『自从 iTerm2 版本 2.9.20140923 之后，增加了个 Dynamic Profile 的功能』，简单来说，你需要根据特定的格式，xml 或者 json，提供一个配置文件，然后 iTerm2 会直接自动加载。只是！！！** 需要你来生成这个配置文件 **，恩，二话不说，毕竟在装逼的路上，咱得 ** 不点鼠标，少敲键盘 **。

本来想着，干脆开脚本做个工具，但是！！！我是懒人好不，写个脚本费事不，有现成工具不用作甚！

⚠️ 接下来继续的话需要以下几个基础知识：
- ansible （常用运维工具）
- js-beautify (Node.js 格式化代码工具）

首先，根据提示，为了制作这个 profile.json（输出），我们需要根据先用的 host 列表来生成（输入）。很自然的想到，目前是根据 inventory 来管理 hosts 列表的，那么，我们是不是可以根据这个来直接生成呢？

对的，用 ansible 的 template module：
```js
# profile.j2
{
  "Profiles": [
{% for group in groups %}
  {% if group != 'all' %}
  {% for host in groups[group] %}
    {
      "Name" : "{{host}}",
      "Guid" : "{{group}}-{{host}}",
      "Initial Text" : "ssh {{host}} tmux a",
      "Tags": ["{{group}}"]
    },
  {% endfor %}
  {% endif %}
{% endfor %}
  ]
}
```

然后一条命令搞定：
```bash
ansible localhost -m template -a "src=./profile.j2 dest=./profile.json" --connection=local
```

接下来作为强迫症的我，必须要 format 一下：
```bash
js-beautify -r -s 2 ./profile.json
```
会有个小问题，因为上面的模板中，最后个元素后面还有逗号，严格来说是不允许的，但是 iTerm2 不介意，所以不用管。

然后移到目录即可：
```bash
mv ./profile.json /Users/x/Library/Application\ Support/iTerm2/DynamicProfiles/
```

现在，`CMD + O`，直接输入 host 名称，按确定，立马连上，那叫一个爽~
另外，不妨看看 iTerm2 上面的 Profiles 选项，你会看到，上面的组织方式，完全是按照你在 inventory 上面的分组一致，恩，不谢~

### Reference
- https://www.iterm2.com/documentation-dynamic-profiles.html

***
首发于 Github issues: https://github.com/xizhibei/blog/issues/35 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
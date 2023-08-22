---
title: 巧用群晖，让你的耳朵在每一次游泳时都能充满新意
date: 2023-08-21 19:00:04
tags: [Synology,SonyWalkman,效率,游泳]
author: xizhibei
issue_link: 
---
### 写在前面
首先来介绍下我用的 Sony Walkman NW-WS623 (以下统称 Walkman)。

![Sony Walkman NW-WS623](media/16921668954200/walkman.jpg)

<!--more-->

当时搜了挺多的资料，看了各种推荐才下单的，如今已经用了差不多 4 年了（刚刚去瞟了一眼电商平台，价格依然坚挺）。其实当时也考虑过骨传导耳机，对比了下价格后，我立马觉得还是入耳的更好，因为它不需要额外戴耳塞了，它本身就是耳塞 🌝。

### 正文开始
夏天到了，游泳的最佳时节也到了，每次去游泳馆，只要戴上我心爱的 Walkman 扑通入水后，整个游泳馆就会只剩下我这最靓的仔。

不过美中不足的是，除了偶尔会被蛙泳的人踹脸，就剩下我的 Walkman 里面的音乐却是几年前的这件事了。在这过去的几年里，我的个人音乐库里面的红心歌曲也已经更新了好多，现在有必要把 Walkman 里面的歌单更新一下了。

上周末从游泳馆回家的路上，一直想着要更新歌单，想着想着，一回到家，思绪就跟我的游泳装备一起，被扔到一边了。

直到隔天晚上，偶然瞥到游泳装备才又想起了这件事。于是，那天晚上我大概花了一个小时才把这件事情搞定：

1. 把 Walkman 从游泳装备中取出；
2. 打开电脑；
3. 忘记连接线，又去我的杂物箱里面拿到数据连接线；
4. 把电脑跟 Walkman 连接；
5. 先清空 Walkman 里面 Music 文件夹；
6. 打开了我的音乐下载文件夹，随机挑了几百个音乐（对的，手动，挑到眼花）；
7. 开始漫长的拷贝过程（估算了下，得有接近 20 分钟）；

所以夫人你看，我那天晚上在客厅的一个小时就是这么过的，真不是跟其它小姐姐在聊天。

### 简易版方案
显然，实在不能忍受着这个效率，我得想办法节约自己的时间。

回头看到了自己家那台一直在吃灰的群晖，我突然有了灵感。用群晖的 USB Copy 功能直接导出歌曲不就行了。

说干就干，简单设置下 USB Copy ，然后把 Walkman 插入群晖前面的 USB 口，然后它就开始复制了。

下面是简单的教程：
第一步，打开 USB Copy：

![方案1-01](media/16921668954200/option1-01.png)

第二步，选择数据导出：
![方案1-02](media/16921668954200/option1-02.png)

第三步，设置任务，来源选一个你挑好的音乐文件夹列表，注意：

1. 大小不能超过 Walkman 本身的大小吗，不然会导致失败
2. 目的地记得选 Walkman 专门的文件夹，截图未体现
3. 复制模式必须是镜像，其他模式都是用来备份目的的

![方案1-03](media/16921668954200/option1-03.png)

第四步，选择触发时间：
![方案1-04](media/16921668954200/option1-04.png)

最后一步，选择文件过滤，我只为听歌，因此这里只选音频：
![方案1-05](media/16921668954200/option1-05.png)

创建完成后，可以插上去试试，不过我的情况比较特别（因为想把空间利用率拉满，折腾一次可以顶好久），所以我等了好久也没听见“哔”声，再去群晖上瞧一眼，果然是挂了。群晖提示我空间不够，原因也很简单，因为我的 Walkman 可用的空间也就 3.5GB 不到，而之前电脑上拷贝的歌曲已经把 Walkman 的空间占满了，虽然我设置的复制策略是镜像，但是实际执行的时候，群晖是不会先把空间删掉腾出来再进行复制的，这样就会导致没有足够的交换空间导致复制失败。

解决的方案也是有的，那就是留足足够的空间，因为大多数情况下，我一次游泳也不会听那么多的歌曲，也没那么多时间来听，那么，实际上我只向里面拷贝几十首歌就行了，算一首歌10M的话，顶多算个 500M 就行了，那么问题也就迎刃而解了。

不过，如果你跟我一样有些强迫症，非要把空间利用率拉满，那么，现在就只能邀请脚本小子出手了。

### 强迫症方案
简单规划了我的的歌曲更新流程，因为本来 USB 这几年只是用来充电了，这次顺便就能把歌单同步跟充电，这两件事一起做了。

1. 游泳回到家，把 Walkman 直接插入群晖的任意一个 USB 口；
2. 等待一个晚上，充电+歌单同步；
3. 下次游泳前，把 Walkman 拔出，放入装备包；

是的，就那么简单，但是，为了能达到这种流程，我需要准备以下几个事情：

1. 定期同步电脑中的歌曲到群晖
2. 写一个脚本
    1. 每天晚上定时执行
    2. 随机选取我的歌曲，做成一个歌单
    3. 把歌单中的歌曲拷贝到 Walkman
    4. 拷贝完成后弹出，方便随时拔出

那么脚本的话，我就贴在下面了，自取即可。

```bash
#!/bin/bash

set -e

# Walkman 上自带的文件，用来标志
marker_filename="default-capability.xml"

# Walkman 默认目录
desc_dirname="MUSIC"

# 最大空间，默认 3.5G 不到，留下100M左右用来当作交换空间
max_size=$((3400 * 1024 * 1024))

# 音乐文件所在目录
music_dir=/volume1/music/Music

# 要放音乐链接的临时目录
music_symlink_dir=/volume1/music/walkman

rm -rf $music_symlink_dir || true
mkdir -p $music_symlink_dir

music_dir_size=$(du -sb $music_dir | cut -f1)
if [ $music_dir_size -lt $max_size ]; then
  echo "音乐源目录 $music_dir_size 小于设置的最大值 $max_size ，将最大值设置为 $max_size"
  max_size=$music_dir_size
fi

for line in $(cat /tmp/usbguidtab); do
  usb_dev=$(echo "$line" | cut -d= -f1)

  mount_root=$(mount | grep "$usb_dev" | awk '{print $3}')
  if [ ! -d "$mount_root" ]; then
    echo "跳过：$usb_dev 非U盘储存设备，或者挂载识别，可尝试插拔"
    continue
  fi

  echo "USB device $usb_dev mount on $mount_root"
  
  walkman_capability_file="$mount_root/$marker_filename"
  if [ ! -f "$walkman_capability_file" ]; then
    echo "跳过：$mount_root: 标志文件 $marker_filename 不存在"
    continue
  fi

  walkman_music_dir="$mount_root/$desc_dirname"
  if [ ! -d "$walkman_music_dir" ]; then
    echo "跳过：$mount_root: 目的地文件夹 $desc_dirname 不存在"
    continue
  fi

  # 先找出所有音频文件
  files=()
  while IFS=  read -r -d $'\0'; do
      files+=("$REPLY")
  done < <(find $music_dir -type f \( -iname \*.mp3 -o -iname \*.m4a -o -iname \*.wav \) -not -path "*/@eaDir/*" -print0)
  echo "源文件夹音乐数量：${#files[@]}"


  size=0
  while [ $size -lt $max_size ]; do
    index=$((RANDOM % ${#files[@]}))
    file="${files[$index]}"

    if [ -n "$file" ]; then
      echo "选中音乐文件：$file"

      next_size=$(( size + $(du -sb "$file" | awk '{print $1}') ))
      if [ "$next_size" -gt "$max_size" ]; then
        break
      fi

      ln "$file" $music_symlink_dir
      size=$next_size

      # 删除已选中的文件,确保每次选择不同的文件
      unset "files[$index]"
    fi
  done

  rsync -av --delete-before "$music_symlink_dir/" "$walkman_music_dir/" 2>&1
  rm -rf ${music_symlink_dir:?}/

  sync # 刷盘
  /usr/syno/bin/synousbdisk -umount "$usb_dev" # 安全弹出，方便拔出
  echo 2 > /dev/ttyS1 # 哔一声用来提醒
done
```

怎么用？想学啊？我教你啊。

### 怎么使用
打开群晖的系统面板，任务计划。

第一步，新增，计划的任务，用户定义的脚本。
![方案2-01](media/16921668954200/option2-01.png)

第二步，常规 Tab，任务名称随便填了，比如我填的就是 Walkman，用户账户需要选择 root，因为最后弹出 Walkman 需要 root 权限（admin 实测权限不够，截图的账号不正确，实际应为 root）。

> 这里需要提醒一句，对于不理解脚本的小白来说，轻易不要相信他人给的脚本，尤其是需要高权限运行的情况下。如果是恶意脚本，轻则被投毒挂马挖矿，重则被加密勒索或者数据全毁，慎重，慎重，慎重。

![方案2-02](media/16921668954200/option2-02.png)

第三步，点击计划 Tab，可以先留空，我就是留着它默认时间的，每天凌晨执行就行。
![方案2-03](media/16921668954200/option2-03.png)

第四步，任务设置，通知设置这边，如果想收邮件通知的话就勾选，不需要也无所谓，最后将上面的脚本粘贴到用户定义的脚本里面就行。（如果你不是跟我一样的 Walkman，理论上也可以用，但是需要你能修改脚本。）

![方案2-04](media/16921668954200/option2-04.png)

最后一步，点击确定即可。
![方案2-05](media/16921668954200/option2-05.png)


你可以尝试将 Walkman 连接到群晖，然后选中任务，点击”运行“，手动执行一遍，测试一下。另外如果你设置了邮件通知，那么在任务结束的时候，你应该会收到任务完成的邮件提示。

### 最后

这个脚本是临时写的，一眼看过去问题还是有不少的，不过目前在我的使用习惯下勉强凑合了，希望在这里抛砖引玉了，因为这个脚本稍稍修改下，就能支持把播客，说书，相声（游泳时听郭德纲，想想就挺带感的。。。）之类的音频也放进去，显然在遇到这种经常需要更新音频的情况下，这个流程就显得更契合了。

最后的最后，这个流程唯二的问题就是：

1. 在游泳之后，忘记把 Walkman 从游泳装备取出去插进群晖；
2. 在游泳之前，忘记把 Walkman 拔出放入游泳装备；

不过相信我，忘个几次之后，记性还是会长的。

***
{% post_link footer %}
***
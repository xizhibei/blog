---
title: RPATH 简介以及 CMake 中的处理
date: 2021-02-12 16:37:45
tags: [Linux,C/C++,CMake]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/161
---
<!-- en_title: a-brief-intro-of-rpath -->

所谓的 RPATH，就是硬编码在可执行文件或者动态库中的一个或多个路径，被动态链接加载器用来搜索依赖库。<sup>[1]</sup>

这个值是存在可执行文件或者动态库的 ELF 结构中的 `.dynamic` 小节中，它可以用 readelf 或者 objdump 查看。

具体就是 `readelf -d a.out | grep RPATH` 或者 `objdump -x a.out | grep RPATH`。

### Linux 中的动态链接加载器搜索路径

至于搜索路径，除了 RPATH，链接加载器在 Linux 中，还会有另外几个关键的路径，他们的搜索顺序如下：<sup>[2]</sup>

-   **LD_LIBRARY_PATH**：环境变量，也是一个或多个路径；
-   **RUNPATH**：与 **RPATH** 一样，但是搜索顺序在 **LD_LIBRARY_PATH** 后面，只在比较新的系统中被支持；
-   **/etc/ld.so.conf**：即链接加载器的配置文件；
-   内置的路径，比如 /lib 以及 /usr/lib；

至于为何需要那么多的可配置方式，就在于不同的程序会有不同的需求，比如对于不同版本库的需求，就需要单独设置 **RPATH**，用来指定依赖库的位置，而不是使用系统相关的 **LD_LIBRARY_PATH**，因为这个环境变量可能会破坏其它程序的运行。

下面来说说 CMake 中的 RPATH。

### CMake 中的 RPATH

跟 RPATH 相关的设置有如下几个（MacOS 相关的今天按下不表）：

-   BUILD_RPATH (version>=3.8)：编译时的 RPATH，在你想要从编译目录中运行程序可能会需要；
-   INSTALL_RPATH：安装时的 RPATH，在你想要从安装目录中运行程序可能会需要；
-   SKIP_BUILD_RPATH：跳过编译时的 RPATH 配置；
-   BUILD_WITH_INSTALL_RPATH：在编译时使用安装时的 RPATH 配置，安装目录与编译目录的依赖路径一致时使用；
-   INSTALL_RPATH_USE_LINK_PATH：将链接时的 RPATH 配置用作安装时的 RPATH，安装目录与链接的依赖路径一致时使用；
-   BUILD_RPATH_USE_ORIGIN (version>=3.14)：是否在编译时使用 `$ORIGIN`，相对路径；
-   INSTALL_REMOVE_ENVIRONMENT_RPATH (version>=3.16)：安装时是否移除工具链相关的 RPATH；

这些设置，可以使用 `set_target_properties` 单独设置在 target 上，也可以在加上 `CMAKE_` 前缀后，设置成全局配置。至于如何使用，完全取决于你想要如何运行你的程序，比如从编译目录中或者安装目录中运行，可能就需要完全不同的配置。

其实在大多数场景下，我们都不需要设置这些东西，因为一旦设置了 RPATH，很可能会**不方便移植**，但是如果你需要单独的依赖库路径的时候，这些东西就需要了。

而如果你真的需要 RPATH，建议的做法是 **使用相对路径，这样就会更容易移植到不同的机器上**，比如 Linux 系统中，可以使用 `$origin`。<sup>[3]</sup>

```cmake
set(CMAKE_INSTALL_RPATH "$origin/../lib")
```

### Ref

1.  [wikipedia - Rpath][1]
2.  [CMake/RPATH-handling][2]
3.  [RPATH and $ORIGIN][3]

[1]: https://en.wikipedia.org/wiki/Rpath

[2]: https://gitlab.kitware.com/cmake/community/-/wikis/doc/cmake/RPATH-handling

[3]: https://cmake.org/pipermail/cmake/2008-January/019290.html


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/161 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
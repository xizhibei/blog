---
title: 【CMake 系列】（二）第三方依赖管理
date: 2020-03-15 23:18:50
tags: [CMake,C|C++]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/134
---
 <!-- en_title: cmake-2-third-party-dependances-management -->

接着上次的[【CMake 系列】（一）入门](https://github.com/xizhibei/blog/issues/133) 继续讲。

这次，主要说说 CMake 的依赖管理。

### 依赖管理

当我们说 CMake 的依赖管理的时候，往往说的是 C/C++ 项目的依赖管理，但是这门古老的语言，到目前为止，还是没有一个官方大一统的依赖管理工具。

而回头看看它的后来者，Ruby 有 `gem`、Node.js 有 `npm`、 Golang 有 `go mod`、Rust 有 `cargo`。

你可能会提到 C++ 在 C++20 中，引入了 Module，只是目前 [编译器的支持](https://zh.cppreference.com/w/cpp/compiler_support) 还是不够，更别提那些著名 C++ 项目的支持了。假如之后能做到如现代语言一条命令安装完所有依赖就能直接使用的话，家祭无忘告乃翁。

那么，CMake 给我们提供了什么样的支持？可以这么说，支持 CMake 的项目，基本上都会提供一个类似于 `xxx-config.cmake` 或者 `xxxConfig.cmake` 的文件，它们的作用就是提供查找与引入到当前项目以供使用。

### CMake `find_package`

先来看看它长什么样：

```cmake
find_package(<PackageName> [version] [EXACT] [QUIET] [MODULE]
             [REQUIRED] [[COMPONENTS] [components...]]
             [OPTIONAL_COMPONENTS components...]
             [NO_POLICY_SCOPE])
```

于是，如果你需要引入 OpenCV 这个依赖，那么，你就需要在你编译项目文件之前，写上那么一句话：

```cmake
find_package(OpenCV 3.4.9 REQUIRED)
```

这句话的就说明，你需要查找 OpenCV 这个依赖，并且版本是 `3.4.9`（版本的兼容逻辑由包自己控制，如果不是 `EXACT`的话它会自动查找兼容的包），且不能缺少，也就是 `REQUIRED`。当然，如果你不是必须要这个依赖，可以使用 `QUIET` 这个关键字。

然后在需要用到的地方：

```cmake
target_link_libraries(lib PUBLIC ${OpenCV_LIBS})
```

注意这里的 `PUBLIC` 关键字，这个关键字表示，如果有其它的库或者可执行程序依赖 lib，那么你不用再次声明需要 OpenCV 相关的库了，CMake 会自动将依赖加进去。另外，如果你使用的是 CMake 3.5 版本以下的话，还需要这样做：

```cmake
target_include_directories(lib PUBLIC ${OpenCV_INCLUDE_DIRS})
```

另外，如果你查找的依赖，需要子模块依赖，比如 Boost，你就要用到 `COMPONENTS` 或者 `OPTIONAL_COMPONENTS`：

```cmake
find_package(Boost 1.50 REQUIRED COMPONENTS filesystem)
target_link_libraries(lib PUBLIC Boost::filesystem)
```

### 第三方依赖管理

现在问题来了，我既然可以用 `find_package` 这么方便地管理包，那查找的包怎么来呢？

同学，这才是关键，如果你做的是本地机器开发，那么有部分可以直接安装（另外也有部分的交叉编译库，可以搜索确定），比如在 Ubuntu 上面，你需要 OpenCV 的话，直接 `sudo apt install libopencv-dev` 即可，而在 MacOS 上，可以 `brew install opencv`。

如果你是在进行交叉编译，或者目前系统中的开发库版本不满足要求，那么，你就要进行源码编译了。

这时候，问题就来了，源码如何放在我们开发的项目中？直接拷贝进来？看过我之前 [如何克隆一个大 Git 项目](https://github.com/xizhibei/blog/issues/131) 文章的同学，这个错误就不要犯了。

那该如何操作？很简单，可以使用 `git submodule`。

你可以将相应的代码库放在专门的文件夹下，比如 `extern` 或者 `third_party` 等等。

然后通过类似这样的命令： `git submodule add https://github.com/opencv/opencv -b 3.4 extern/opencv` 来添加即可。

对于用户，它需要 `git submodule update --init --recursive`，或者在克隆的时候添加 `--recursive` 参数。

然后，你需要在你的 CMakeLists.txt 中，加入额外的配置步骤，如果项目的 CMakeLists.txt 支持当做模块，你可以直接添加为子目录：`add_subdirectory(extern/opencv)`。

我尝试过这种方式，但是遇到了一时无法解决的交叉编译的问题，就放弃了，因为有些项目写的 CMakeLists.txt 并不标准，不支持它作为其它项目的子模块，并且也不是所有项目都支持 CMake。当然，你也可以通过给项目写 patch 来修改，或者通过写专门的 bash 脚本来解决。

这里有个前提，它需要使用者知道 `git submodule` 的使用方案，如果你不喜欢这种方式，你还有其它三个方案：

1.  ExternalProject：编译时运行，无法在配置时使用 `add_subdirectory`
2.  [DownloadProject](https://github.com/Crascit/DownloadProject)：配置时运行，可以 `add_subdirectory`；
3.  FetchContent (CMake 3.11+)：方案二的官方版本，更简便一些，只是在比较高的版本才有，鉴于目前大部分机器上的 CMake 版本比较低，可能会要求用户升级后才能使用；

目前，我在团队项目中，使用的是 ExternalProject，为什么？因为**单独作为一个步骤，这样可以预先编译好各个平台依赖的库，节约其它团队成员不必要的时间。**

我将相关的第三方依赖做成可以一行命令编译的版本，这样每次都可以在服务器上，利用服务器高性能 CPU 快速编译好，然后将生成物直接保存在公共存储空间，最后其他人使用的时候，可以直接下载使用，当然这里会对产物进行签名验证。

并且，连下载的步骤也可以通过 CMake 在配置阶段，直接下载使用，大大提高了团队的开发效率。


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/134 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
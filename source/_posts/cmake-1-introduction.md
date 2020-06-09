---
title: 【CMake系列】（一）入门
date: 2020-03-09 20:09:15
tags: [C/C++,CMake]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/133
---
<!-- en_title: cmake-1-introduction -->

自从上次在[为何 C++ 静态链接库顺序很重要](https://github.com/xizhibei/blog/issues/100)捡回了 C++，自此开始了不归路。

今天我们来说说，CMake 这个现代 C++ 项目的利器。

### 前言

为什么我们需要 CMake ？ 对于 C++ 开发者来说，他们会习惯于使用 GNU Make 来编译 C++ 项目，对于简单项目来说，这无可厚非，再加上有那么多的开源工具可用，尤其是 autotools 系列，用起来还是挺方便的。目前仍有非常多的 C++ 项目，需要你先使用 `./configure` 来预处理，然后再进行编译，这比只用 Make 来说，方便很多倍，也就是对初学者非常友好 (高阶用户在此就不说了，毕竟如能把 Vim 用到飞起的高手并不多)。

在我个人看来，autotools 系列不那么简洁（当我看见当前目录生成一堆临时文件的时候，会非常讨厌，相对的，CMake 可以有专门的编译目录真是拯救了我的强迫症），由于没有怎么使用过，不便于说出更多其它意见，也无法细致对比。有兴趣的也可以看看 [What are the differences between Autotools, Cmake and Scons?](https://stackoverflow.com/questions/4071880/what-are-the-differences-between-autotools-cmake-and-scons) 上的讨论。

从入手难度来说，CMake 是初学者的福音，不过有点麻烦的是，你需要学习一门新的语言，只是相对于编程语言来说，它还是非常简单的。

### 准备

大多数情况下，你只需要直接安装即可，比如下面三个命令你可以按照自己的机器选择：

```bash
brew install cmake
sudo apt install cmake
pip install cmake
```

其它的方式就可以直接在[官网去下载](https://cmake.org/download/)后安装。

### 一个简单例子

让我们从一个最简单的项目开始。

```cpp
// main.cpp
#include <stdio.h>

int main(int argc, char *argv[])
{
    printf("Hello world");
    return 0;
}
```

我们就可以在当前目录下创建一个 CMakeLists.txt：

```cmake
# CMake 最低版本号要求，你也可以设置版本范围，比如 3.1...3.15
cmake_minimum_required (VERSION 3.0)

# 项目信息，可设置版本号以及描述
project (demo VERSION 0.1.0 DESCRIPTION "Demo project")

# 生成一个 demo 的可执行文件
add_executable(demo main.cpp)
```

然后，执行经典的四条命令，就可以编译出可执行文件了：

```bash
mkdir build
cd build
cmake ..
make
```

不同于 Make，CMake 可以将配置的过程大大简化，三行语句，你就可以写出强大的跨平台编译脚本了，你可以从输出看到，一系列的步骤，都自动化完成了：

    -- The C compiler identification is GNU 7.4.0
    -- The CXX compiler identification is GNU 7.4.0                                               
    -- Check for working C compiler: /usr/bin/cc                                                                 
    -- Check for working C compiler: /usr/bin/cc -- works            
    -- Detecting C compiler ABI info          
    -- Detecting C compiler ABI info - done
    -- Detecting C compile features
    -- Detecting C compile features - done                                                           
    -- Check for working CXX compiler: /usr/bin/c++
    -- Check for working CXX compiler: /usr/bin/c++ -- works
    -- Detecting CXX compiler ABI info
    -- Detecting CXX compiler ABI info - done
    -- Detecting CXX compile features
    -- Detecting CXX compile features - done
    -- Configuring done
    -- Generating done
    -- Build files have been written to: /home/xizhibei/demo/build

是不很简单？再来个复杂点的例子。

### 一个稍复杂的例子

现在，随着你加入了更多的功能，你会需要改下你的 CMakeLists.txt。

比如你现在的项目结构是这样的：

    --- root
      |-- CMakeLists.txt
      |-- main.cpp
      |-- include/
      |------ a.h
      |------ b.h
      |-- lib/
      |------ a.cpp
      |------ b.cpp

那么，对应着的修改如下：

```cmake
cmake_minimum_required (VERSION 3.0)

project (demo VERSION 0.1.0 DESCRIPTION "Demo project")

# 添加 demo_lib 静态库
add_libary(demo_lib STATIC lib/a.cpp lib/b.cpp)

# 指定头文件所在位置
target_include_directories(demo_lib PUBLIC ${CMAKE_SOURCE_DIR}/include}

# 同上
add_executable(demo main.cpp)

# 这里不需要再次 target_include_directories 了，因为我们在设置了 include 是 demo_lib 需要的，CMake 会自动添加

# 将 demo_lib 库链接至 demo 执行文件
target_link_libraries(demo demo_lib)
```

其实按照标准一些的方式，我们应该在 lib 下创建一个新的 CMakeLists.txt，然后通过 `add_subdirectory(lib)` 来做，这里这样做是为了节约篇幅。

于是，一个简单的 C++ 项目就完成了。

### 其它

一个简单的例子完成了，但是该如何添加第三方依赖？怎么添加编译选项？怎么测试？怎么添加文档？

不急，之后我会慢慢道来，争取写一个比较长的系列。

### Ref

1.  <http://www.cmake.org/>


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/133 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
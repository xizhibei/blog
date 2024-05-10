---
title: 【CMake 系列】（十）编译速度以及程序性能优化相关
date: 2020-07-29 17:31:23
categories: [CMake]
tags: [C/C++,CMake]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/145
---
<!-- en_title: cmake-10-refine-compile-speed-and-program-performance -->

写 C/C++ 的同学都知道，项目稍大点，编译速度就开始拖后腿了，这对于我们来说是个又爱又恨的时候：急着改代码的时候，慢能消耗我们的耐心，能将我们逼疯，而我们想暂时休息会儿的时候，却可以借此去散步喝茶了。

另外，程序运行时的速度，又是另外一个关键的速度了，编译速度慢我们可以忍，但是运行速度慢可忍不了，就算我们忍得了，领导或者用户也是无法忍的。

话说回来，为了我们自己的开发效率，提升编译速度是无可非议的，今天我们就来说说，如何在 CMake 中优化编译以及以及程序本身。

### 编译速度优化

#### Ninja Generator

CMake 的默认 Generator 是 Unix Makefiles，也就是最常见的 make 命令，但是另一个 Generator Ninja 却是更好的选择，如果你没有用过，建议试试。

#### CCache

最简单，也是效果最好的，就是开启编译缓存，ccache 便是我们需要的工具。

它的原理也很简单，就是包装编译器，接收编译参数、文件，当检测到没有对应缓存的时候，调用编译器，将生成物缓存到文件中去，下次如果编译参数以及文件没有变化，就能够直接从缓存文件中提取，这样，就可以大大减少重复编译时候的时间。

在 CMake 早期版本中 （2.8 Unix Makefiles 以及 3.4 Ninja 之前的版本），没有 ccache 的支持，我们需要手动设置：`CMAKE_C_COMPILER` 以及 `CMAKE_CXX_COMPILER`，将 ccache 作为前缀即可：

```cmake
set(CMAKE_C_COMPILER ccache gcc)
set(CMAKE_CXX_COMPILER ccache g++)
```

而另外较新版本中，就更容易了：

```cmake
find_program(CCACHE_PROGRAM ccache)
if(CCACHE_PROGRAM)
  message(STATUS "Set up ccache ...")
  set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE ccache)
  set_property(GLOBAL PROPERTY RULE_LAUNCH_LINK ccache)
endif()
```

然后，XCode generator 可参考 [Using ccache with CMake][1]。

或许你会怀疑它究竟有多少效果，下面的结果是我在一台机器上运行 `ccache -s` 的统计结果：

    cache directory                     /home/me/.ccache
    primary config                      /home/me/.ccache/ccache.conf
    secondary config      (readonly)    /etc/ccache.conf
    stats zero time                     Tue Apr  7 16:06:27 2020
    cache hit (direct)                 41056
    cache hit (preprocessed)            7179
    cache miss                         25047
    cache hit rate                     65.82 %
    called for link                    10928
    called for preprocessing            5929
    compile failed                      3055
    preprocessor error                  1325
    can't use precompiled header          86
    bad compiler arguments                56
    autoconf compile/link               3428
    no input file                        616
    cleanups performed                    90
    files in cache                     25512
    cache size                           4.5 GB
    max cache size                       5.0 GB

可以这么说，它在过去几个月的开发过程中，帮我节约了大约 65.82% 的编译时间。

#### Precompiled headers (PCH) 以及 Unity builds<sup>[2]</sup>

**Precompiled headers**：也就是预编译头，可以大大将少 C++ 头文件的重复编译时间，你可以将一些第三方库，比如 nlohmann/json 、spdlog/spdlog.h、Boost 以及 项目中很少变动的 C++ 头文件加到预编译中：

```cmake
target_precompile_headers(<my_target> PRIVATE my_pch.h)
```

但是，生成的中间文件，会非常大，占用比较大的磁盘空间。

**Unity builds**：也可以按照字面意义上去理解，即一体化编译，将多个 CPP 文件合并到一起进行编译，这样的话：编译器可以解析更少的次数、相同模版的优化、更少编译器调用次数、链接器也会更友好。

使用也很简单：

```cmake
set(CMAKE_UNITY_BUILD ON)
```

```cmake
set_target_properties(<target> PROPERTIES UNITY_BUILD ON)
```

然而，这两个算是高级招数，所以不是所有的项目都适合用，没准用了之后会**增加项目的维护成本**，如果不知道怎么用，很可能你用无法编译成功。

具体的使用，也会挺复杂，有不少的坑，如果各位有兴趣，下次单独讲讲。

#### 其它

-   gcc 换成 clang；
-   静态链接换成动态链接；
-   换台高性能的机器，换个更好的 CPU 以及 SSD 磁盘，甚至用上内存磁盘（这种算是用钱换性能了，但是效果还是非常显著的）；

### 程序性能优化

对于 CMake 来说，最简单优化的莫过于将 Debug 改为 Release 模式。

另外，就是 [Interprocedural optimization](https://en.wikipedia.org/wiki/Interprocedural_optimization)，你可以理解为程序级别的 Release 模式，因为普通的 Release 模式是单个文件级别的。

当然，不是每个编译器都支持，你需要先检查：

```cmake
include(CheckIPOSupported)
check_ipo_supported(RESULT _IsIPOSupported)
  if(_IsIPOSupported)
  message(STATUS "Turn on INTERPROCEDURAL_OPTIMIZATION")
  set(CMAKE_INTERPROCEDURAL_OPTIMIZATION TRUE)
endif()
```

其实在性能优化上面，编译器能做的比较有限，更多的还是在于编码阶段，对整个程序的优化。

而业务逻辑上面，算法上面，等待，都不是编译器能解决的问题，却是能最终影响结果的。

### Ref

1.  [Using ccache with CMake][1]
2.  [CMake 3.16 added support for precompiled headers & unity builds - what you need to know][2]

[1]: https://crascit.com/2016/04/09/using-ccache-with-cmake/

[2]: https://onqtam.com/programming/2019-12-20-pch-unity-cmake-3-16/


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/145 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
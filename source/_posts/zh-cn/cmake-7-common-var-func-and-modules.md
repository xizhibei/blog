---
title: 【CMake 系列】（七）常用变量、函数以及模块
date: 2020-06-02 18:52:11
categories: [CMake]
tags: [C/C++,CMake]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/140
---
<!-- en_title: cmake-7-common-var-func-and-modules -->

用了 CMake 较长一段时间后，在笔记本里面记录了不少知识，这些知识其实应该放在这个系列文章的开始来讲，因为算是很入门的部分，这里就简单总结下。

### 配置期间

#### 生成配置文件

```cmake
configure_file("${PROJECT_SOURCE_DIR}/include/config.h.in"
               "${PROJECT_BINARY_DIR}/include/config.h")
```

比如，你可以将 cmake 中，project 命令中设置的版本，通过这个方式传递给程序：

```cpp
// config.h.in
#pragma once

#define MY_VERSION_MAJOR @PROJECT_VERSION_MAJOR@
#define MY_VERSION_MINOR @PROJECT_VERSION_MINOR@
#define MY_VERSION_PATCH @PROJECT_VERSION_PATCH@
#define MY_VERSION_TWEAK @PROJECT_VERSION_TWEAK@
#define MY_VERSION "@PROJECT_VERSION@"
```

通过两个 `@` 符号，就可以将 cmake 中的变量传递到我们所需要编译的程序中。

#### 防手贱

禁止在源目录编译以及修改，可以在不小心在当前目录编译的时候，报错退出，防止污染源代码：

```cmake
set(CMAKE_DISABLE_IN_SOURCE_BUILD ON)
set(CMAKE_DISABLE_SOURCE_CHANGES ON)
```

#### 第三方库的查找

这里需要用到 `CMAKE_FIND_ROOT_PATH` 以及 `CMAKE_PREFIX_PATH`，因为 CMake 回去系统默认的地方查找对应的库，如果你需要用到放在其他地方的库，可以在这个变量中添加。

另外，对于单个库，也可以使用这两个变量：

-   `<PackageName>_ROOT`：用来指定头文件以及库、可执行文件的路径；
-   `<PackageName>_DIR`：用来指定库的 CMake 文件路径；

### 编译期间

#### 编译器

假如在系统中存在多种编译器或者版本，可以通过设置以下两个变量来设置 C 以及 C++ 的编译器：

```cmake
CMAKE_C_COMPILER=/path/to/gcc
CMAKE_CXX_COMPILER=/path/to/g++
```

#### FLAGS

如果需要自定义编译配置，还可以设置以下的变量，大部分情况下，你都不需要配置，CMake 会根据环境以及其它变量自动配置：

```cmake
CMAKE_C_FALGS=
CMAKE_CXX_FALGS=-fopenmp
```

#### 特性

如果你说需要上面的 `FALGS` 来配置 `-std=c++17`，那也不需要，你可以设置其他的变量来达到这个目的，比如全局的：

```cmake
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS ON)
```

以及更被建议的局部做法：

```cmake
add_library(myTarget lib.cpp)
set_target_properties(myTarget PROPERTIES
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED YES
    CXX_EXTENSIONS NO
)
```

另外，如果想要 `-fPIC`，也有专门的变量：`CMAKE_POSITION_INDEPENDENT_CODE`，当然，这个也建议在局部做：

```cmake
set_target_properties(myTarget PROPERTIES POSITION_INDEPENDENT_CODE ON)
```

#### 预处理定义

```cmake
add_compile_definitions(-DTEST) # 全局
target_compile_definitions(-DTEST) # 局部
```

#### 类别

编译类别 `CMAKE_BUILD_TYPE` 我们常用的也就 `Release` 与 `Debug`，由于编译环境的不同，也会对这个值进行限制，具体需要参考 `CMAKE_CONFIGURATION_TYPES`，比如 还可以有 `RelWithDebInfo` 以及 `MinSizeRel`。

这个变量，会决定编译是否优化以及带上调试信息，千万不要给你们公司的私有程序以 Debug 模型发布出去了，原因？一个是代码没优化，性能会比较差，另外就是会泄露源码。

#### 动态库与静态库

需要用到 `BUILD_SHARED_LIBS` 这个变量，常常被用到 `option` 里面提供给用户进行配置，这个变量控制的是 `add_libary(myLib ...)` 最后生成的类别。

或许你会奇怪为什么没有 `BUILD_STATIC_LIBS`，其实默认就是 `static`，也就是相当于 `BUILD_SHARED_LIBS=OFF`。

另外，还有个小技巧，如果你需要同时编译动态库与静态库，可以用类似以下的方式来做到：

```cmake
add_libary(myLib STATIC lib.cpp)

add_libary(mySharedLib SHARED lib.cpp)
set_target_properties(mySharedLib PROPERTIES OUTPUT_NAME myLib)
```

### 几个有用的模块

ExternalProject 就不用多说了，前面在 [【CMake 系列】（三）ExternalProject 实践](https://github.com/xizhibei/blog/issues/135) 专门介绍过。

注意：这几个模块需要通过 `include` 来引入后才能使用。

#### CMakePrintHelpers

非常适合用来调试，`cmake_print_variables` 帮助你打印出变量的值以及 `cmake_print_properties` 可以打印出 target 中的一些属性。

下面就是一个打印出 `include` 路径的例子：

```cmake
cmake_print_properties(TARGETS foo bar PROPERTIES
                       LOCATION INTERFACE_INCLUDE_DIRECTORIES)
```

#### WriteCompilerDetectionHeader

有些时候，为了写跨平台的代码，我们需要判别编译器是否支持一些特性，CMake 就提供了这个模块，它可以帮助你生成一个预定义头文件，帮你把一些编译器支持的特性全部罗列出来：

```cmake
write_compiler_detection_header(
  FILE "${PROJECT_BINARY_DIR}/include/foo_compiler_detection.h"
  PREFIX MY_PREFIX
  COMPILERS GNU Clang AppleClang MSVC
  FEATURES cxx_constexpr)
```

这里的编译特性还可以有：

-   cxx_constexpr
-   cxx_deleted_functions
-   cxx_extern_templates
-   cxx_variadic_templates
-   cxx_noexcept
-   cxx_final
-   cxx_override

#### FeatureSummary

这个模块适合在项目初始化完成的最后，打印出一些总结性信息：

```cmake
feature_summary(WHAT ALL)
```

然后，你还可以给这个总结添加更多说明：

```cmake
set_package_properties(LibXml2 PROPERTIES
                       TYPE RECOMMENDED
                       PURPOSE "Enables HTML-import in MyWordProcessor")
                       
option(WITH_FOO "Help for foo" ON)
add_feature_info(Foo WITH_FOO "The Foo feature provides very cool stuff.")
```

这样，你就可以看到更多的总结信息了。

### 安装

这个就太简单了，但是又非常常见，怕初学者不清楚，这里就提示下：

直接设置 `CMAKE_INSTALL_PREFIX` 即可，最后执行安装命令的时候，会将对应的文件安装到制定的目录。

### 最后

上面简单罗列了我们团队项目中常用的，也是经过我挑选之后的，毕竟那么多的特性，不可能在这一篇文章中全部列出，详细的还是需要看 CMake 官方文档。另外，文中大部分的例子也是来自于 CMake 官方文档。


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/140 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
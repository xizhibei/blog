---
title: 【CMake 系列】（五）安装、打包与导出
date: 2020-04-20 18:43:22
tags: [C/C++,CMake]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/137
---
<!-- en_title: cmake-5-install-package-and-export -->

### 前言

今天这篇，可以算是接着上次的 [第三方依赖管理](https://github.com/xizhibei/blog/issues/134)，因为今天说的是怎样成为第三方依赖。

当你开发库的时候，就需要考虑，其它人如何使用你的库。

就目前而言，目前有三种方式可以使用第三方库：

1.  子文件夹（下载后编译、Git 克隆编译）；
2.  安装编译产物（各平台现有库，自己编译库下载配置）；
3.  导出编译目录；

下面分别来说说，该如何操作。

### 子文件夹

对使用者而言，这种方式是三者中最简单的，使用者能够将库作为子文件，成为当前项目的一部分，因此他能够直接使用子文件中，第三方库的任何现成的 `CMake Target`，方便、快捷。

不过，作为第三方库的开发者，有时候容易犯一个错误，那便是混淆了 `CMAKE_SOURCE_DIR` 与 `CMAKE_PROJECT_DIR`，以及 `CMAKE_BINARY_DIR` 与 `CMAKE_BINARY_DIR`，这几个变量的区别。

当使用者将你的库作为第三方库来使用的时候，`CMAKE_SOURCE_DIR` 以及 `CMAKE_BINARY_DIR` 就会变成使用者所在项目的变量了。

说一个例子，假如使用者项目结构如下：

    project-root
    - build/
    - src/
    - extern
        - your-lib-root
            - src
            - CMakeLists.txt
    - CMakeLists.txt

那么，在你的库中，CMake 获取的 `CMAKE_SOURCE_DIR` 就会是 `project-root`，而不是你可能想要的 `project-root/extern/your-lib-root`，`CMAKE_BINARY_DIR` 同理。

因此，正确的做法是使用 `PROJECT_SOURCE_DIR` 以及 `PROJECT_BINARY_DIR`，他们的获取是 CMake 根据遇到的最近的 `project()` 命令来决定的。

### 安装编译产物

这是大部分第三方库开发者的选择，因为可以直接提供编译后产物，减少编译时间，另外有些私有库也能借此不暴露源码。

CMake 为此提供了完善的支持，主要是**安装与打包**。

##### 安装命令

首先是安装，我们来看看具体的 `install` 命令：

```cmake
install(TARGETS <target>... [...])
install({FILES | PROGRAMS} <file>... [...])
install(DIRECTORY <dir>... [...])
install(SCRIPT <file> [...])
install(CODE <code> [...])
install(EXPORT <export-name> [...])
```

其中我们常用的有 TARGETS、FILES、PROGRAMS、DIRECTORY 以及 EXPORT，下面依次来说说如何使用。

-   TARGETS：安装编译后的产物 target：library 以及 executable 都可以作为参数；
-   FILES：安装其它文件，比如配置文件；
-   PROGRAMS：安装可执行文件，脚本之类的，与 FILES 一样，区别在于可执行权限；
-   DIRECTORY：安装整个目录，比如文档目录，另外，你可以利用 `FILES_MATCHING PATTERN "*.h"` 参数来安装库所需要的头文件；
-   CODE 与 SCRIPT：这两样属于高级模式了，你可以通过它们来实现自定义安装；

下面来个例子：

```cmake
# 安装编译产物
install(TARGETS myExe mySharedLib myStaticLib
        RUNTIME DESTINATION bin
        LIBRARY DESTINATION lib
        ARCHIVE DESTINATION lib)

# 安装 include 文件
install(DIRECTORY include/ DESTINATION include/myproj
        FILES_MATCHING PATTERN "*.h")

# 安装文档
install(DIRECTORY "${CMAKE_BINARY_DIR}/docs/docs/"
          DESTINATION share/doc/QUSDK/html)
```

##### 导出

如果你并不想要支持 CMake 的 `find_package`，那么这一步可以略过。

一般来说，支持 `find_package` 需要 `myLibConfig.cmake` 这个文件，以及如果还要支持版本查找的话，还需要 `myLibConfigVersion.cmake` 这个文件。目前在新的版本中，只需要少量配置，CMake 就能为你自动生成这些文件。

首先对应的，需要修改上面的 install targets：

```cmake
install(TARGETS myLib
        EXPORT myLib # 加上了这个 EXPORT
        RUNTIME DESTINATION bin
        LIBRARY DESTINATION lib
        ARCHIVE DESTINATION lib)
```

```cmake
install(
  EXPORT myLib
  FILE myLibTargets.cmake
  NAMESPACE myLib::
  DESTINATION lib/cmake/myLib)

include(CMakePackageConfigHelpers)

configure_package_config_file(
  myLibConfig.cmake.in ${PROJECT_BINARY_DIR}/myLibConfig.cmake
  INSTALL_DESTINATION lib/cmake/myLib)

write_basic_package_version_file(
  myLibConfigVersion.cmake
  VERSION ${PACKAGE_VERSION}
  COMPATIBILITY SameMajorVersion)

install(FILES "${PROJECT_BINARY_DIR}/myLibConfig.cmake"
              "${PROJECT_BINARY_DIR}/myLibConfigVersion.cmake"
        DESTINATION lib/cmake/myLib)
```

其中 `myLibConfig.cmake.in`主要是为了确保第三方依赖，你也可以在这里进行一些预处理，它的内容如下：

```cmake
include(CMakeFindDependencyMacro)

# 作为例子，myLib 需要 OpenCV 这个依赖
find_dependency(OpenCV REQUIRED)

include("${CMAKE_CURRENT_LIST_DIR}/myLibTargets.cmake")
```

在使用的时候，按如下方式即可：

```cmake
find_package(myLib REQUIRED)
target_link_libraries(main myLib::myLib)
```

##### 打包

当你配置完了安装文件，接下来就需要发布了，CMake 给你提供了 CPack，由于它的使用很简单，这里就简单提下：

```cmake
set(CPACK_PACKAGE_VENDOR ${PROJECT_NAME})

# 设置版本
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY ${PROJECT_DESCRIPTION})
set(CPACK_PACKAGE_VERSION_MAJOR ${PROJECT_VERSION_MAJOR})
set(CPACK_PACKAGE_VERSION_MINOR ${PROJECT_VERSION_MINOR})
set(CPACK_PACKAGE_VERSION_PATCH ${PROJECT_VERSION_PATCH})

# 设置打包类型，这里定义了 tgz 以及 zip 格式
set(CPACK_GENERATOR "TGZ;ZIP")
set(CPACK_SOURCE_GENERATOR "TGZ;ZIP")

include(CPack)
```

就这样简单配置，就可以在编译完成之后，使用 `make package` 或者 `cpack` 命令完成打包了。

最后，将结果上传，分发即可。

### 导出编译目录

这种方式其实也挺简单，因为这种方式不需要第三方库作为子文件夹放在使用者的项目中，它只需要导出编译目录，然后将 target 导出到 `$HOME/.cmake/packages` 供使用。

于是，我们在上面安装的基础上，直接两行代码就能搞定了：

```cmake
set(CMAKE_EXPORT_PACKAGE_REGISTRY ON)
export(PACKAGE myLib)
```

这里需要注意下，CMAKE_EXPORT_PACKAGE_REGISTRY 在 3.15 版本之前是默认 `ON` 的，但是之后默认就变成 `OFF` 了，因为修改用户 Home 目录下的内容，会被认为是 **出其不意** 的。

然后，可以在新项目中，直接使用 `find_package` 即可引入依赖。


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/137 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
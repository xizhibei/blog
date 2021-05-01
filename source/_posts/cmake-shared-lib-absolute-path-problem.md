---
title: CMake 动态链接库绝对路径问题
date: 2021-02-12 16:48:46
tags: [C/C++,CMake]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/162
---
<!-- en_title: cmake-shared-lib-absolute-path-problem -->

今天这篇文章算是对 [【CMake 系列】（五）安装、打包与导出](https://github.com/xizhibei/blog/issues/137) 的一个补充。其实我本打算跟上篇文章放在一起，毕竟都属于动态链接库相关的知识，但是这样一来就不容易被出现问题的同学们检索到了（才不是为了再水一篇文章 doge）。

### 问题的由来

是因为这个问题困扰了我不少时间，在好几个项目里面都遇到了这个问题。

那就是链接动态库的时候，编译出来的可执行文件会带有编译时的绝对路径，于是你将程序拷贝到其它地方运行的时候，必须把动态库放到绝对路径里面去，而不是放在系统里面相关的 lib 路径下面。

举一个例子，假如我们要实现一个 `FooConfig.cmake`，这个库中既有静态库也有动态库，那么如果我们要在项目中使用，大概的实现方式是：

```cmake
find_path(FOO_INCLUDE_DIRS NAMES foo.h)

get_filename_component(_IMPORT_PREFIX "${FOO_INCLUDE_DIRS}" PATH)
set(FOO_LIBRARY_DIRS ${_IMPORT_PREFIX}/lib)

if(NOT FOO_FIND_COMPONENTS)
  set(FOO_FIND_COMPONENTS foo bar)
endif()

set(FOO_USE_SHARED 1)
set(_CMAKE_FIND_LIBRARY_SUFFIXES ${CMAKE_FIND_LIBRARY_SUFFIXES})
if(FOO_USE_SHARED)
  set(CMAKE_FIND_LIBRARY_SUFFIXES .so)
else()
  set(CMAKE_FIND_LIBRARY_SUFFIXES .a)
endif()

foreach(lib ${FOO_FIND_COMPONENTS})
  set(_lib_location "_lib_location-NOTFOUND")
  find_library(_lib_location NAMES "${lib}")
  if(NOT _lib_location)
    message(FATAL_ERROR "FOO lib '${lib}' is not found")
  endif()

  set(_lib_name FOO::${lib})
  add_library(${_lib_name} UNKNWON IMPORTED)
  set_target_properties(
    ${_lib_name}
    PROPERTIES INTERFACE_INCLUDE_DIRECTORIES "${FOO_INCLUDE_DIRS}"
               IMPORTED_LOCATION_RELEASE "${_lib_location}"
               IMPORTED_CONFIGURATIONS RELEASE)

  list(APPEND FOO_LIBS "${_lib_name}")

  unset(_lib_location) # clean
  unset(_lib_name) # clean
endforeach()
set(CMAKE_FIND_LIBRARY_SUFFIXES ${_CMAKE_FIND_LIBRARY_SUFFIXES})

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Reader REQUIRED_VARS FOO_INCLUDE_DIRS
                                                       FOO_LIBS)

mark_as_advanced(FOO_INCLUDE_DIRS FOO_LIBS)

# cleanup
unset(_IMPORT_PREFIX)
unset(_CMAKE_FIND_LIBRARY_SUFFIXES)
```

将它命名为 `FooConfig.cmake` 然后放在位于项目根目录的 cmake 文件夹下，并且在项目中这样使用：

```cmake
find_package(Foo REQUIRED HINTS ${PROJECT_SOURCE_DIR}/cmake)
add_executable(main main.cpp)
target_link_libraries(main PRIVATE ${FOO_LIBS})
```

最后，假如我们查找的库在 `/path/to/foo/home` 下面，那么我们用在项目中得到的结果会是这样的：

```bash
$ readelf -d a.out | grep NEEDED
Dynamic section at offset 0xb5ddb4 contains 2 entries:
  Tag        Type                         Name/Value
 0x00000001 (NEEDED)                     Shared library: [/path/to/foo/home/lib/libfoo.so]
 0x00000001 (NEEDED)                     Shared library: [/path/to/foo/home/lib/libbar.so]
```

这里就出现了绝对路径，当初这个问题折磨了我很久，一直以为是 RPATH 的问题，最后发现是 CMake 本身的问题。

### 如何解决

出现这个问题的原因就是库的 Package Find Config 不对，我研究了挺长时间，最后在官方的[讨论](https://gitlab.kitware.com/cmake/cmake/-/issues/18052)中找到了原因以及答案：

1.  缺少了 `IMPORTED_NO_SONAM`E 的属性；
2.  引入动态库的时候，使用了 `UNKNWON` 类型的库；

于是，将上面的代码改下即可：

```cmake
# ...

if(FOO_USE_SHARED)
  set(FOO_LIB_TYPE "SHARED")
  set(CMAKE_FIND_LIBRARY_SUFFIXES .so)
else()
  set(FOO_LIB_TYPE "STATIC")
  set(CMAKE_FIND_LIBRARY_SUFFIXES .a)
endif()

# ...

set_target_properties(
    ${_lib_name}
    PROPERTIES INTERFACE_INCLUDE_DIRECTORIES "${FOO_INCLUDE_DIRS}"
               IMPORTED_NO_SONAME_RELEASE true
               IMPORTED_LOCATION_RELEASE "${_lib_location}"
               IMPORTED_CONFIGURATIONS RELEASE)

# ...
```


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/162 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
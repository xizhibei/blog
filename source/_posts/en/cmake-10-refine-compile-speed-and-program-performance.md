---
title: "(CMake Series) Part 10 - Enhancing Compilation Speed and Program Performance"
date: 2020-07-29 17:31:23
categories: [CMake]
tags: [C/C++, CMake, Performance Optimization]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/145
---
<!-- en_title: cmake-10-refine-compile-speed-and-program-performance -->

Every C/C++ developer knows that as projects grow, compilation speed can start to drag, a love-hate situation: it tests our patience and drives us crazy when we're eager to modify code, yet it provides a perfect excuse for a break to walk or sip some tea when we need a pause.

Additionally, the runtime speed of the program is another critical factor—slow compile times are bearable, but slow execution is not, not just for us but for our bosses and users too.

That said, for our own development efficiency, enhancing compilation speed is indisputably beneficial. Today, let’s discuss how to optimize both compilation and program performance within CMake.

### Compilation Speed Optimization

#### Ninja Generator

The default generator in CMake is Unix Makefiles, which uses the common `make` command. However, the Ninja generator is a better choice. If you haven't used it, I recommend giving it a try.

#### CCache

The simplest and most effective tool for speeding up compilation is enabling a compilation cache, and `ccache` is the tool we need.

Its principle is straightforward: it wraps the compiler, receives compilation parameters and files, and when it detects that there's no corresponding cache, it calls the compiler to store the output in a file. If the compilation parameters and files haven’t changed, it retrieves the output directly from the cache file, greatly reducing recompilation time.

In earlier versions of CMake (before 2.8 for Unix Makefiles and 3.4 for Ninja), there was no support for ccache, and we had to manually set `CMAKE_C_COMPILER` and `CMAKE_CXX_COMPILER` to prefix with ccache:

```cmake
set(CMAKE_C_COMPILER ccache gcc)
set(CMAKE_CXX_COMPILER ccache g++)
```

In newer versions, it's even easier:

```cmake
find_program(CCACHE_PROGRAM ccache)
if(CCACHE_PROGRAM)
  message(STATUS "Setting up ccache ...")
  set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE ccache)
  set_property(GLOBAL PROPERTY RULE_LAUNCH_LINK ccache)
endif()
```

Then, refer to [Using ccache with CMake][1] for the XCode generator.

You might wonder how effective it is. Below are the results I got from running `ccache -s` on one machine:

```
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
```

In the past few months, it saved me approximately 65.82% of compilation time.

#### Precompiled headers (PCH) and Unity builds<sup>[2]</sup>

**Precompiled headers**: These significantly reduce the repetitive compilation time of C++ header files. You can add headers of some third-party libraries, like nlohmann/json, spdlog/spdlog.h, Boost, and rarely changed project headers into precompilation:

```cmake
target_precompile_headers(<my_target> PRIVATE my_pch.h)
```

However, the intermediate files generated will be quite large, taking up significant disk space.

**Unity builds**: As the name suggests, this involves merging multiple CPP files into a single compilation unit. This reduces the number of times the compiler needs to parse, optimizes the same templates, reduces the number of compiler invocations, and makes the linker more efficient.

It’s simple to use:

```cmake
set(CMAKE_UNITY_BUILD ON)
```

```cmake
set_target_properties(<target> PROPERTIES UNITY_BUILD ON)
```

However, these techniques are advanced and not suitable for all projects as they might **increase project maintenance costs**. If used incorrectly, they may lead to compilation failures.

#### Other Tips

-   Switching from gcc to clang;
-   Changing from static to dynamic linking;
-   Upgrading to a high-performance machine with a better CPU and SSD, or even using a RAM disk (these are cases of trading money for performance but are very effective).

### Program Performance Optimization

For CMake, the simplest optimization is switching from Debug to Release mode.

Additionally, consider [Interprocedural optimization](https://en.wikipedia.org/wiki/Interprocedural_optimization), which can be understood as a program-level Release mode because the ordinary Release mode optimizes at the individual file level.

Not every compiler supports it, so you need to check first:

```cmake
include(CheckIPOSupported)
check_ipo_supported(RESULT _IsIPOSupported)
if(_IsIPOSupported)
  message(STATUS "Turning on INTERPROCEDURAL_OPTIMIZATION")
  set(CMAKE_INTERPROCEDURAL_OPTIMIZATION TRUE)
endif()
```

In terms of performance optimization, compilers have limited capabilities; more often, optimization should occur during the coding phase of the entire program.

Issues such as business logic, algorithms, and waiting times are not within the compiler's capabilities to resolve, yet they are crucial in impacting the final outcome.

### Ref

1.  [Using ccache with CMake][1]
2.  [CMake 3.16 added support for precompiled headers & unity builds - what you need to know][2]

[1]: https://crascit.com/2016/04/09/using-ccache-with-cmake/

[2]: https://onqtam.com/programming/2019-12-20-pch-unity-cmake-3-16/


***
First published on GitHub issues: https://github.com/xizhibei/blog/issues/145, welcome to Star and Watch

{% post_link footer_en %}
***

---
title: 【CMake 系列】（四）用 GoogleTest 测试
date: 2020-04-05 23:37:59
categories: [CMake]
tags: [C/C++,CMake,测试]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/136
---
<!-- en_title: cmake-4-test-with-google-test -->

今天我们来说说，CMake 测试。

不过，其实我们还是在说 C++ 的测试。

CMake 给我们提供了完善的测试支持，比如它有一个专门的模块 CTest。

### CMake 原生测试支持

CMake 原生支持的测试很简单，只有两个函数：

```cmake
enable_testing()
add_test(NAME <name> COMMAND <command> [<arg>...]
         [CONFIGURATIONS <config>...]
         [WORKING_DIRECTORY <dir>]
         [COMMAND_EXPAND_LISTS])
```

这个用法，简单来说，就是你需要先实现一个可以接受输入参数的可执行程序，用 `add_executable` 就可以，不用管这个可执行程序的存放目录，CMake 会帮你自动填上。

```cmake
enable_testing()

add_executable(test_example test.cpp)
target_link_libraries(test_example example_lib)

add_test(NAME test_example1 COMMAND test_example --arg1=a --arg2=b)
add_test(NAME test_example2 COMMAND test_example --arg1=c --arg2=d)
```

然后，通过 `add_test` 注册你的测试用例后，就完成了准备，之后就可以在编译完成后，用以下三种方式来运行来运行测试用例。

-   `make test`
-   `cmake --build . --target test`
-   `ctest`

当然了，你也可以用 CTest 来结合 CDash 一起使用，CDash 就是一个可以记录测试日志的地方，你可以去 <https://my.cdash.org/index.php> 一探究竟，一般来说，项目大了之后就会有这方面的需求。

### GoogleTest

除了上面的 ctest，我们还有强大的 [GoogleTest](https://github.com/google/googletest)，这是目前用得比较广泛的 C++ 测试框架。不同于上面需要自己实现测试框架逻辑、解析参数，GoogleTest 提供了测试框架，以及 Mock。

CMake 也提供了 GoogleTest 的支持:

```cmake
gtest_add_tests(TARGET target
                [SOURCES src1...]
                [EXTRA_ARGS arg1...]
                [WORKING_DIRECTORY dir]
                [TEST_PREFIX prefix]
                [TEST_SUFFIX suffix]
                [SKIP_DEPENDENCY]
                [TEST_LIST outVar]
)
```

它是用来取代 `add_test` 的，通过扫描源代码，它就能读出所有的测试用例，省却了两边重复写的问题，但是它有个问题：一旦测试用例改变，它就需要重新跑 cmake，不然无法知道改变后的测试用例。

因此，CMake 自从 3.10 提供了新的方法：

```cmake
gtest_discover_tests(target
                     [EXTRA_ARGS arg1...]
                     [WORKING_DIRECTORY dir]
                     [TEST_PREFIX prefix]
                     [TEST_SUFFIX suffix]
                     [NO_PRETTY_TYPES] [NO_PRETTY_VALUES]
                     [PROPERTIES name1 value1...]
                     [TEST_LIST var]
                     [DISCOVERY_TIMEOUT seconds]
)
```

相比较于 `gtest_add_tests`，`gtest_discover_tests` 是通过获取编译后的可执行程序里面的测试用例来达到注册的目的，因此会更鲁棒，在测试用例改变的情况下，不需要重新运行 cmake（其实原理也不神奇，你用编译后的程序运行时加上 `--gtest_list_tests` 参数就明白了）。

使用也很简单，在有 GoogleTest 依赖存在的情况下（不知道的需要复习前两篇文章的内容），通过 `find_package` 引入依赖。

```cmake
enable_testing()
include(GoogleTest)
find_package(GTest 1.10.0)

add_executable(test test.cpp)
target_link_libraries(test GTest::gtest GTest::gtest_main GTest::gmock
                        GTest::gmock_main)
gtest_discover_tests(test)
```

至于 GoogleTest 本身，也就是看文档写测试用例了（有兴趣的可以留言，有机会我另外写一篇），另外，我之前在 [Golang 中的测试](https://github.com/xizhibei/blog/issues/95) 也提到过该如何写单元测试，其实在这里道理也是一样的，结合 GoogleTest 提供的 Mock，我们写单元测试可以变得很简单。

### Ref

1.  [Testing With CTest](https://gitlab.kitware.com/cmake/community/-/wikis/doc/ctest/Testing-With-CTest)


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/136 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
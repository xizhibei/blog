---
title: "(CMake Series) Part 4 - Testing with GoogleTest"
date: 2020-04-05 23:37:59
categories: [CMake]
tags: [C/C++, CMake, Build Systems, Testing, GoogleTest]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/136
---
<!-- en_title: cmake-4-test-with-google-test -->

Today, let's talk about testing with CMake.

But actually, we are still talking about testing in C++.

CMake provides us with comprehensive testing support, such as its dedicated module, CTest.

### Native CMake Testing Support

Native testing support in CMake is quite simple, involving only two functions:

```cmake
enable_testing()
add_test(NAME <name> COMMAND <command> [<arg>...]
         [CONFIGURATIONS <config>...]
         [WORKING_DIRECTORY <dir>]
         [COMMAND_EXPAND_LISTS])
```

Simply put, you first need to implement an executable program that can take input parameters using `add_executable`, without worrying about the location of this executable as CMake will handle it automatically.

```cmake
enable_testing()

add_executable(test_example test.cpp)
target_link_libraries(test_example example_lib)

add_test(NAME test_example1 COMMAND test_example --arg1=a --arg2=b)
add_test(NAME test_example2 COMMAND test_example --arg1=c --arg2=d)
```

After registering your test cases with `add_test`, the setup is complete. You can then run the test cases using one of the following three methods after compilation:

- `make test`
- `cmake --build . --target test`
- `ctest`

Of course, you can also use CTest in conjunction with CDash, which is a place that can log test results. You can explore more at <https://my.cdash.org/index.php>. Generally, there is a need for this kind of capability as projects grow larger.

### GoogleTest

Besides the above ctest, we also have the powerful [GoogleTest](https://github.com/google/googletest), which is currently the most widely used C++ testing framework. Unlike the need to implement your own testing framework logic and parse parameters, GoogleTest provides a testing framework as well as Mock.

CMake also supports GoogleTest:

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

This is meant to replace `add_test`. By scanning the source code, it can identify all test cases, avoiding the need to rewrite them on both sides. However, it has an issue: once the test cases are changed, it requires re-running cmake to recognize the updated test cases.

Thus, since CMake 3.10, a new method has been provided:

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

Compared to `gtest_add_tests`, `gtest_discover_tests` registers tests by fetching them from the compiled executable, making it more robust. In case of test case changes, it does not require re-running cmake (the principle is not magical, just run the compiled program with `--gtest_list_tests` to see).

Using it is straightforward, assuming GoogleTest dependencies are present (if not, review the content from the first two articles). Introduce the dependency with `find_package`.

```cmake
enable_testing()
include(GoogleTest)
find_package(GTest 1.10.0)

add_executable(test test.cpp)
target_link_libraries(test GTest::gtest GTest::gtest_main GTest::gmock
                        GTest::gmock_main)
gtest_discover_tests(test)
```

Regarding GoogleTest itself, it's a matter of reading the documentation to write test cases (those interested can leave a comment, and I might write a separate article). Also, as I've mentioned in [Testing in Golang](https://github.com/xizhibei/blog/issues/95), the principles for writing unit tests are the same here. Combined with GoogleTest's Mock, we can make unit testing very straightforward.

### Ref

1. [Testing With CTest](https://gitlab.kitware.com/cmake/community/-/wikis/doc/ctest/Testing-With-CTest)


***
First published on Github issues: https://github.com/xizhibei/blog/issues/136, feel free to Star and Watch

{% post_link footer_en %}
***

---
title: "(CMake Series) Part 7 - Common Variables, Functions, and Modules"
date: 2020-06-02 18:52:11
categories: [CMake]
tags: [C++, CMake, Build Systems]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/140
---
<!-- en_title: cmake-7-common-var-func-and-modules -->

After using CMake for quite some time, I have recorded a lot of knowledge in my notebook. Actually, this knowledge should have been introduced at the beginning of this series, as it includes some fundamental aspects. Here, I will provide a brief summary.

### During Configuration

#### Generating Configuration Files

```cmake
configure_file("${PROJECT_SOURCE_DIR}/include/config.h.in"
               "${PROJECT_BINARY_DIR}/include/config.h")
```

For example, you can pass the version set in the CMake `project` command to your program using this method:

```cpp
// config.h.in
#pragma once

#define MY_VERSION_MAJOR @PROJECT_VERSION_MAJOR@
#define MY_VERSION_MINOR @PROJECT_VERSION_MINOR@
#define MY_VERSION_PATCH @PROJECT_VERSION_PATCH@
#define MY_VERSION_TWEAK @PROJECT_VERSION_TWEAK@
#define MY_VERSION "@PROJECT_VERSION@"
```

By using two `@` symbols, you can transfer variables from CMake to the program you need to compile.

#### Guard Against Accidental Builds in Source Directory

To prevent building and modifying in the source directory, you can error out if a build is accidentally started in the current directory, avoiding contamination of the source code:

```cmake
set(CMAKE_DISABLE_IN_SOURCE_BUILD ON)
set(CMAKE_DISABLE_SOURCE_CHANGES ON)
```

#### Finding Third-party Libraries

This requires the use of `CMAKE_FIND_ROOT_PATH` and `CMAKE_PREFIX_PATH`, as CMake will look for libraries in the system's default locations. If you need to use libraries located elsewhere, you can add them to this variable.

Also, for individual libraries, you can use these two variables:

- `<PackageName>_ROOT`: To specify the path of headers, libraries, and executables;
- `<PackageName>_DIR`: To specify the path to the library's CMake file;

### During Compilation

#### Compilers

If there are multiple compilers or versions available in the system, you can set the following two variables for C and C++ compilers:

```cmake
CMAKE_C_COMPILER=/path/to/gcc
CMAKE_CXX_COMPILER=/path/to/g++
```

#### FLAGS

To customize build configurations, you can also set the following variables. Most of the time, you don't need to configure them, as CMake will automatically configure based on the environment and other variables:

```cmake
CMAKE_C_FLAGS=
CMAKE_CXX_FLAGS=-fopenmp
```

#### Features

If you need the above `FLAGS` to configure `-std=c++17`, that’s also unnecessary. You can set other variables to achieve this purpose, such as globally:

```cmake
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS ON)
```

And a more recommended local approach:

```cmake
add_library(myTarget lib.cpp)
set_target_properties(myTarget PROPERTIES
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED YES
    CXX_EXTENSIONS NO
)
```

Additionally, if you want `-fPIC`, there's a specific variable for that: `CMAKE_POSITION_INDEPENDENT_CODE`, which, of course, is also recommended to be set locally:

```cmake
set_target_properties(myTarget PROPERTIES POSITION_INDEPENDENT_CODE ON)
```

#### Preprocessor Definitions

```cmake
add_compile_definitions(-DTEST) # Globally
target_compile_definitions(-DTEST) # Locally
```

#### Build Types

The commonly used compilation categories `CMAKE_BUILD_TYPE` are `Release` and `Debug`. Due to different compilation environments, this value will also be constrained. For reference, you can also have `RelWithDebInfo` and `MinSizeRel`.

This variable determines whether the compilation will be optimized and include debugging information. Do not release your company's private programs in Debug mode, as the code will be unoptimized, performance will be poorer, and it could leak source code.

#### Dynamic and Static Libraries

You need to use the `BUILD_SHARED_LIBS` variable, which is often used in `option` to allow users to configure. This variable controls whether `add_library(myLib ...)` will generate a static or shared library.

Perhaps you might wonder why there is no `BUILD_STATIC_LIBS`; by default, it is `static`, which is equivalent to `BUILD_SHARED_LIBS=OFF`.

Moreover, there's a little trick if you need to compile both dynamic and static libraries at the same time:

```cmake
add_library(myLib STATIC lib.cpp)

add_library(mySharedLib SHARED lib.cpp)
set_target_properties(mySharedLib PROPERTIES OUTPUT_NAME myLib)
```

### Useful Modules

ExternalProject doesn’t need much introduction, as it was specially covered in [【CMake Series】(3) ExternalProject Practice](https://github.com/xizhibei/blog/issues/135).

Note: These modules need to be included before they can be used.

#### CMakePrintHelpers

Very suitable for debugging, `cmake_print_variables` helps you print the values of variables and `cmake_print_properties` can print some properties of targets.

Below is an example of printing out the `include` paths:

```cmake
cmake_print_properties(TARGETS foo bar PROPERTIES
                       LOCATION INTERFACE_INCLUDE_DIRECTORIES)
```

#### WriteCompilerDetectionHeader

Sometimes, to write cross-platform code, we need to determine if a compiler supports certain features. CMake provides this module, which helps you generate a predefined header file, listing all the supported compiler features:

```cmake
write_compiler_detection_header(
  FILE "${PROJECT_BINARY_DIR}/include/foo_compiler_detection.h"
  PREFIX MY_PREFIX
  COMPILERS GNU Clang AppleClang MSVC
  FEATURES cxx_constexpr)
```

Here are more compiler features:

- cxx_constexpr
- cxx_deleted_functions
- cxx_extern_templates
- cxx_variadic_templates
- cxx_noexcept
- cxx_final
- cxx_override

#### FeatureSummary

This module is suitable at the end of project initialization, to print out some summary information:

```cmake
feature_summary(WHAT ALL)
```

Then, you can add more descriptions to this summary:

```cmake
set_package_properties(LibXml2 PROPERTIES
                       TYPE RECOMMENDED
                       PURPOSE "Enables HTML-import in MyWordProcessor")
                       
option(WITH_FOO "Help for foo" ON)
add_feature_info(Foo WITH_FOO "The Foo feature provides very cool stuff.")
```

This way, you can see more summary information.

### Installation

This is very straightforward, yet very common. To avoid confusion for beginners, here’s a tip:

Simply set `CMAKE_INSTALL_PREFIX`, and when you execute the installation command, the corresponding files will be installed in the designated directory.

### Conclusion

Above, I've briefly listed what our team commonly uses, also chosen by me after screening, because so many features cannot possibly be listed in one article. For details, you still need to refer to the official CMake documentation. Additionally, most examples in the text are also from the CMake official documentation.

***
First published on GitHub issues: https://github.com/xizhibei/blog/issues/140, welcome to Star and Watch

{% post_link footer_en %}
***

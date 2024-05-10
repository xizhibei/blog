---
title: (CMake Series) Part 1 - Introduction
date: 2020-03-09 20:09:15
categories: [CMake]
tags: [C/C++,CMake,Build Systems,Tutorial]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/133
---
<!-- en_title: cmake-1-introduction -->
<!-- toc -->

Since the last time I picked up C++ in [Why the Order of C++ Static Libraries Matters](https://github.com/xizhibei/blog/issues/100), I've embarked on a point of no return.

Today, let's talk about CMake, a powerful tool for modern C++ projects.

### Introduction

Why do we need CMake? For C++ developers, they are accustomed to using GNU Make to compile C++ projects, which is fine for simple projects. Furthermore, there are so many open-source tools available, especially the autotools series, which are quite convenient. Many C++ projects still require you to use `./configure` to preprocess before compiling, which is much more convenient than using Make alone, thus very friendly to beginners (not to mention advanced users, as not many can make Vim fly).

Personally, I find the autotools series less tidy (I really dislike it when I see a bunch of temporary files generated in the current directory; conversely, CMake's dedicated build directory is a godsend for my OCD). Since I haven’t used it much, I can't comment further or make detailed comparisons. Those interested can also check out the discussion on [What are the differences between Autotools, Cmake, and Scons?](https://stackoverflow.com/questions/4071880/what-are-the-differences-between-autotools-cmake-and-scons).

In terms of accessibility, CMake is a blessing for beginners, although the tricky part is that you need to learn a new language, which is still very simple compared to programming languages.

### Preparation

In most cases, you can just install it directly with one of the following commands depending on your machine:

```bash
brew install cmake
sudo apt install cmake
pip install cmake
```

Alternatively, you can directly download and install it from the [official website](https://cmake.org/download/).

### A Simple Example

Let's start with the simplest project.

```cpp
// main.cpp
#include <stdio.h>

int main(int argc, char *argv[])
{
    printf("Hello world");
    return 0;
}
```

You can then create a CMakeLists.txt in the current directory:

```cmake
# Minimum version of CMake required, you can also set a version range, such as 3.1...3.15
cmake_minimum_required (VERSION 3.0)

# Project information, version number, and description can be set
project (demo VERSION 0.1.0 DESCRIPTION "Demo project")

# Create an executable named demo
add_executable(demo main.cpp)
```

Next, execute the classic four commands to compile the executable:

```bash
mkdir build
cd build
cmake ..
make
```

Unlike Make, CMake greatly simplifies the configuration process. With just a few lines, you can write powerful cross-platform compilation scripts. You can see from the output that a series of steps have been automated:

```
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
```

Simple, right? Let's try a more complex example.

### A Slightly More Complex Example

As you add more features to your project, you'll need to update your CMakeLists.txt.

Suppose your project structure looks like this:

```
    --- root
      |-- CMakeLists.txt
      |-- main.cpp
      |-- include/
      |------ a.h
      |------ b.h
      |-- lib/
      |------ a.cpp
      |------ b.cpp
```

Corresponding changes are as follows:

```cmake
cmake_minimum_required (VERSION 3.0)

project (demo VERSION 0.1.0 DESCRIPTION "Demo project")

# Add a static library called demo_lib
add_library(demo_lib STATIC lib/a.cpp lib/b.cpp)

# Specify the location of header files
target_include_directories(demo_lib PUBLIC ${CMAKE_SOURCE_DIR}/include)

# As above
add_executable(demo main.cpp)

# No need to set target_include_directories again since we have already set includes for demo_lib, CMake will automatically add them

# Link the demo_lib library to the demo executable
target_link_libraries(demo demo_lib)
```

Following a more standard approach, we should create a new CMakeLists.txt under the lib directory and include it with `add_subdirectory(lib)`. However, this approach is used here to save space.

Thus, a simple C++ project is complete.

### Other

We've completed a simple example, but how do we add third-party dependencies? How do we add compilation options? How do we test? How do we add documentation?

Don't worry, I'll gradually explain these in a lengthy series.

### Ref

1.  <http://www.cmake.org/>

***
First published on Github issues: https://github.com/xizhibei/blog/issues/133, welcome to Star and Watch

{% post_link footer_en %}
***

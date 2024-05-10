---
title: "(CMake Series) Part 2 - Third-Party Dependency Management"
date: 2020-03-15 23:18:50
categories: [CMake]
tags: [C/C++, CMake, Build Systems, Dependency Management]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/134
---
 <!-- en_title: cmake-2-third-party-dependency-management -->

Continuing from the last [(CMake Series) Part 1 - Introduction](/en/2020/03/09/cmake-1-introduction/).

This time, let's talk about dependency management in CMake.

### Dependency Management

When we talk about dependency management in CMake, we are often referring to the management of dependencies in C/C++ projects. However, this ancient language still lacks a unified official dependency management tool to date.

Looking at its successors, Ruby has `gem`, Node.js has `npm`, Golang has `go mod`, and Rust has `cargo`.

You might mention that C++ introduced Modules in C++20, but currently, [compiler support](https://en.cppreference.com/w/cpp/compiler_support) is still insufficient, not to mention support from famous C++ projects. If in the future it becomes as simple as modern languages to install all dependencies with one command and use them directly, it would be greatly beneficial.

So, what kind of support does CMake provide? Essentially, projects supported by CMake usually provide a file named `xxx-config.cmake` or `xxxConfig.cmake`. Their role is to provide the means to find and incorporate them into the current project for use.

### CMake `find_package`

Let's see what it looks like:

```cmake
find_package(<PackageName> [version] [EXACT] [QUIET] [MODULE]
             [REQUIRED] [[COMPONENTS] [components...]]
             [OPTIONAL_COMPONENTS components...]
             [NO_POLICY_SCOPE])
```

Thus, if you need to include the OpenCV dependency, you need to write the following line before compiling your project files:

```cmake
find_package(OpenCV 3.4.9 REQUIRED)
```

This line means that you need to find the OpenCV dependency with version `3.4.9` (version compatibility logic is controlled by the package itself if not `EXACT`), and it is mandatory, which is indicated by `REQUIRED`. Of course, if this dependency is not crucial, you can use the `QUIET` keyword.

Then at the point of use:

```cmake
target_link_libraries(lib PUBLIC ${OpenCV_LIBS})
```

Note the `PUBLIC` keyword here, which means that if other libraries or executable programs depend on lib, you don't need to declare the need for OpenCV related libraries again, CMake will automatically add the dependency. Also, if you are using CMake version 3.5 or below, you also need to do this:

```cmake
target_include_directories(lib PUBLIC ${OpenCV_INCLUDE_DIRS})
```

Moreover, if your found dependency requires sub-module dependencies, like Boost, you would need to use `COMPONENTS` or `OPTIONAL_COMPONENTS`:

```cmake
find_package(Boost 1.50 REQUIRED COMPONENTS filesystem)
target_link_libraries(lib PUBLIC Boost::filesystem)
```

### Third-Party Dependency Management

Now, the question arises, since I can use `find_package` to manage packages so conveniently, where do these packages come from?

Friend, that's the key. If you're developing on a local machine, some can be installed directly (and there are also some cross-compilation libraries, which can be searched to confirm), such as on Ubuntu, if you need OpenCV, simply `sudo apt install libopencv-dev`; and on MacOS, `brew install opencv`.

If you are cross-compiling, or if the current development library version in your system does not meet your requirements, then you will need to compile from source.

At this point, the question arises, how should the source code be placed in our development project? Just copy it in? For those who have read my previous article on [how to clone a large Git project](https://github.com/xizhibei/blog/issues/131), you would know not to make this mistake.

So, what should be done? It's simple, use `git submodule`.

You can place the respective code repository in a specific folder, such as `extern` or `third_party`, etc.

Then you can add it with a command like this: `git submodule add https://github.com/opencv/opencv -b 3.4 extern/opencv`.

For users, they need to use `git submodule update --init --recursive`, or add the `--recursive` parameter when cloning.

Then, you need to add extra configuration steps to your CMakeLists.txt. If the project's CMakeLists.txt supports being used as a module, you can directly add it as a subdirectory: `add_subdirectory(extern/opencv)`.

I have tried this method, but encountered insurmountable cross-compilation issues at the time, so I gave up, as some projects' CMakeLists.txt are not standard, do not support being used as submodules of other projects, and not all projects support CMake. Of course, you can also modify by writing patches for the project or by writing specialized bash scripts to solve these issues.

Here's a prerequisite, it requires the user to know the usage plan of `git submodule`. If you do not like this method, you have three other options:

1. ExternalProject: Runs during build, cannot use `add_subdirectory` at configuration time.
2. [DownloadProject](https://github.com/Crascit/DownloadProject): Runs at configuration time, can `add_subdirectory`;
3. FetchContent (CMake 3.11+): The official version of the second solution, simpler but only available in higher versions, considering most machines have lower versions of CMake, it may require users to upgrade to use;

Currently, in our team projects, we are using ExternalProject, because **as a separate step, it allows pre-compiling libraries dependent on various platforms, saving unnecessary time for other team members.**

I've made the third-party dependencies compilable with one line of command, so every time it can be quickly compiled on a server with high-performance CPU, then the build artifacts are directly saved in a public storage space, and later others can directly download and use them, of course, the artifacts are signed for verification.

Moreover, even the downloading step can be done by CMake during the configuration stage, greatly improving the team's development efficiency.


***
Originally published on Github issues: https://github.com/xizhibei/blog/issues/134, feel free to Star and Watch

{% post_link footer_en %}
***

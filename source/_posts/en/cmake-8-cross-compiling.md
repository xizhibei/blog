---
title: "(CMake Series) Part 8 - Cross Compiling"
date: 2020-06-15 19:52:56
categories: [CMake]
tags: [C/C++, CMake, Build Systems, Cross Compilation]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/141
---
<!-- en_title: cmake-8-cross-compiling -->

Today, let's talk about a slightly more challenging aspect of CMake: cross-compiling.

Although cross-compiling can be complex, CMake provides robust support for it, using a `CMAKE_TOOLCHAIN_FILE` to specify the cross-compilation toolchain, which resolves most issues.

### Example

Let's discuss an example where we need to compile executable programs or libraries for `aarch64` (ARM architecture 64-bit). Here is what a typical toolchain configuration might look like:

```cmake
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

# Cross-compilers
set(CMAKE_C_COMPILER aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER aarch64-linux-gnu-g++)

# Setting search rules, which is crucial as cross-compilation dependencies
# are generally not located in system directories but in specialized paths
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

# If you're compiling third-party libraries and cannot modify the source code,
# it's not recommended to modify flags here
# Setting CXX flags, C flags follow the same principle
set(CMAKE_CXX_FLAGS "-march=armv8-a -fopenmp ${CMAKE_CXX_FLAGS}")

# Other settings
add_definitions(-D__ARM_NEON)
add_definitions(-DLINUX)
```

Then, just slightly modify the previous four commands:

```bash
mkdir build
cd build
cmake .. -DCMAKE_TOOLCHAIN_FILE=/path/to/toochain.cmake
make
```

As you can see, it's quite straightforward. Now, let's talk about cross-compiling for two well-known platforms.

### Android

Android has the famous Android NDK, which already includes Toolchain support in newer versions. Thus, knowing the path to the Android NDK, you can use it directly:

```cmake
CMAKE .. -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake
```

Of course, there are a few other parameters that need to be set:

```bash
CMAKE .. -DANDROID_NDK=$ANDROID_NDK \
        -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
        -DANDROID_ABI="arm64-v8a" \
        -DANDROID_ARM_NEON=ON \
        -DANDROID_TOOLCHAIN=clang \
        -DANDROID_PLATFORM=android-19 \
```

With the above settings, you can proceed directly to compilation.

As expected, if you haven't compiled before, you're likely to encounter missing library issues. In general, adding `target_link_libraries(myLib PUBLIC android log)` should resolve them.

Indeed, CMake natively supports Android compilation, but I prefer to use the Android NDK's official Toolchain, which is better maintained.

### iOS

Actually, iOS is even simpler, just use the method provided by CMake. However, you will need to cross-compile on a Mac, basically just install Xcode and start compiling.

Note that Apple's closed ecosystem requires that its compilation must be within its own system, like changing the Generator to Xcode:

```bash
cmake .. \
        -GXcode \
        -DCMAKE_INSTALL_PREFIX=$build_dir/install \
        -DCMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM="<your-sign-key-id>" \
        -DCMAKE_SYSTEM_NAME=iOS \
        "-DCMAKE_OSX_ARCHITECTURES=armv7;arm64;i386;x86_64" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=9.3 \
        -DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO \
        -DCMAKE_IOS_INSTALL_COMBINED=YES
```

Additionally, in CMakeLists.txt, you also need to modify the attributes of the compilation target:

```cmake
if(IOS)
set_target_properties(
  your-lib
  PROPERTIES PUBLIC_HEADER "${PROJECT_INCLUDE_FILES}"
             MACOSX_FRAMEWORK_IDENTIFIER com.your-com-name.awesome-lib
             VERSION ${PROJECT_VERSION}
             SOVERSION "${PROJECT_VERSION_MAJOR}.0.0"
             FRAMEWORK TRUE
             FRAMEWORK_VERSION C)
endif()
```

The properties here are just examples; you need to modify them according to your requirements.

### Other Obvious Pitfalls

#### Dependencies Vary Greatly Across Target Programs

You need to use the following variables to control the compilation steps:

1.  CMAKE_CROSSCOMPILING: Whether in a cross-compiling environment;
2.  ANDROID: The Android compiling environment;
3.  APPLE: Whether it's an Apple series compiling environment;
4.  IOS: Whether it's an Apple mobile environment;
5.  UNIX: Whether it's UNIX or UNIX-like environments;
6.  WIN32, MSVC: Whether it's Windows

Also, you need to distinguish the code for different target platforms in the source code.

#### Compiled Programs Cannot Run Directly on the Compilation Host

If your program depends on executables compiled to perform operations, you'll encounter obstacles here. However, there are solutions, such as separating the compilation process and compiling the executables for the respective platforms in advance and using them in subsequent compilation steps.

### Conclusion

In my view, the method of cross-compiling provided by CMake is very simple and elegant. By simply switching different Toolchain files, you can easily port your code to other platforms.


***
First published on GitHub issues: https://github.com/xizhibei/blog/issues/141, welcome to Star and Watch

{% post_link footer_en %}
***

---
title: 【CMake 系列】（八）交叉编译
date: 2020-06-15 19:52:56
categories: [CMake]
tags: [C/C++,CMake]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/141
---
<!-- en_title: cmake-8-cross-compiling -->

今天来说说，CMake 中稍许有些难度的部分：交叉编译。

虽说交叉编译有些难度，但是相对于其它的工具，CMake 的交叉编译支持还是很强大的，用一个 `CMAKE_TOOLCHAIN_FILE` 文件参数来制定交叉编译工具链就能解决大部分问题了。

### 例子

下面来说说一个例子，比如我们现在需要编译 `aarch64`（即 ARM architecture 64 位）上的可执行程序，或者库，我们就需要类似以下的工具链配置：

```cmake
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

# 交叉编译器
set(CMAKE_C_COMPILER aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER aarch64-linux-gnu-g++)

# 设置搜索规则，这里需要重点注意，因为交叉编译所需要的依赖
# 一般不会放在系统目录下，而是会有专门的路径
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

# 假如你在编译第三方的库，无法修改源代码，不然不建议在这里修改 flags
# 设置编译 CXX flags，C flags 也是一样
set(CMAKE_CXX_FLAGS "-march=armv8-a -fopenmp ${CMAKE_CXX_FLAGS}")

# 其他设置
add_definitions(-D__ARM_NEON)
add_definitions(-DLINUX)
```

然后，稍稍修改之前的四条命令即可：

```bash
mkdir build
cd build
cmake .. -DCMAKE_TOOLCHAIN_FILE=/path/to/toochain.cmake
make
```

到这里，是不是觉得很简单？下面来说说两个著名平台的交叉编译。

### Android

Android 有大名鼎鼎的 Android NDK，在比较新的版本中，其实已经有了 Toolchain 支持，所以在知道 Android NDK 的路径后，就可以直接使用：

```cmake
CMAKE .. -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake
```

当然，对应的，它还有几个参数还需要设置：

```bash
CMAKE .. -DANDROID_NDK=$ANDROID_NDK \
        -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
        -DANDROID_ABI="arm64-v8a" \
        -DANDROID_ARM_NEON=ON \
        -DANDROID_TOOLCHAIN=clang \
        -DANDROID_PLATFORM=android-19 \
```

按照如上的配置之后就可以直接进行编译了。

当然，不出所料的话，如果你之前没有编译过，你大概率会遇到缺少库的问题，一般情况下，加上`target_link_libraries(myLib PUBLIC android log)` 即可。

其实，CMake 也原生支持 Android 的编译，不过我在使用的时候，还是倾向于使用 Android NDK 官方自己维护的 Toolchain，毕竟官方自己维护的动力也强一些。

### iOS

其实 iOS 反而更简单，直接使用 CMake 提供的方式即可，不过，这里就需要在 Mac 上交叉编译了，基本上安装完 Xcode 就可以开始编译了。

这里还需要注意，苹果的封闭特性，导致了它的编译必须在它的体系内编译，比如这里的这里的 Generator 就需要改为 Xcode。

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

另外，在 CMakeLists.txt 中， 还需要修改编译对象的属性：

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

这里的属性只是举例，你需要按照自己的要求修改。

### 另外几个明显的坑

#### 不同目标程序的依赖完全不一样

你需要使用以下几个变量来控制编译步骤：

1.  CMAKE_CROSSCOMPILING：是否处于交叉编译环境；
2.  ANDROID：安卓的编译环境；
3.  APPLE：是否是苹果系列的编译环境；
4.  IOS：是否是苹果手机环境；
5.  UNIX：是否是 UNIX 或者 UNIX-like 的环境；
6.  WIN32、MSVC：是否是 Windows

另外，也需要在源代码中，区分不同目标平台的代码。

#### 编译程序无法直接在编译主机上运行

假如你的程序依赖编译后的可执行文件来进行操作，那么这里就会遇到障碍了，不过方案也是有的，比如分开编译过程，将对应平台的可执行文件编译好放在专门的地方，在后续的编译步骤中直接调用。

### 最后

CMake 提供的交叉编译方式在我看来是非常简单以及优雅的，只需要切换不同的 Toolchain 文件便可以轻松将你的代码移植到其他平台。


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/141 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
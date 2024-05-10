---
title: 【CMake 系列】（三）ExternalProject 实践
date: 2020-03-23 23:22:44
categories: [CMake]
tags: [C/C++,CMake]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/135
---
<!-- en_title: cmake-3-external-project-practise -->

[上次](https://github.com/xizhibei/blog/issues/134) 说了第三方依赖管理，提到了我们团队在使用 `ExternalProject` 来管理依赖，这次来说说具体实践，以及一个基于 CMake 的开源依赖管理工具 [vcpkg](https://github.com/microsoft/vcpkg)。

### ExternalProject 实践

来看看它长什么样：

```cmake
ExternalProject_Add(<name> [<option>...])
ExternalProject_Add_Step(<name> <step> [<option>...])
ExternalProject_Get_Property
ExternalProject_Add_StepTargets(<name> [NO_DEPENDS] <step1> [<step2>...])
```

是不是很简单，显然不是，文档里写成这样是因为参数太多了，惊不惊喜？

其实大部分参数用不到，我就挑选一些常用的参数来说说，从步骤来说，它主要分以下几步：

-   目录配置
    -   PREFIX：目录前缀，建议选个自己看得顺眼的；
    -   DOWNLOAD_DIR：这个重要了，建议选个编译目录同级的，这样删掉编译目录后，就相当于缓存目录了，下次再编译就可以节约下载时间；
-   下载
    -   URL & URL_HASH：包的下载与校验，建议即使有 Git 项目也使用，这样可以进一步减少下载时间（就国内的网络克隆 GitHub 而言 T_T）；
    -   GIT_REPOSITORY & GIT_TAG：Git 项目克隆，建议加上 `GIT_SHALLOW`，减少克隆项目的体积；
-   更新
    -   PATCH_COMMAND 这个可以修改后的源文件，比如你可以作为临时 BUG 的修改方案，毕竟项目的维护者不一定会及时改掉；
-   配置
    -   CONFIGURE_COMMAND：非 CMake 项目的配置参数，可以执行配置命令，如 `./configure --prefix=${CMAKE_INSTALL_PREFIX}`，另外需要配置 `BUILD_IN_SOURCE true`；
    -   CMAKE_ARGS：CMake 项目的配置参数，如 `-DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}`；
-   编译
    -   多数情况下可略过
-   测试
    -   TEST_COMMAND： 需要测试编译机器执行情况的可以设置，多数情况下可略过，留空即可：`TEST_COMMAND ""`；
-   安装
    -   INSTALL_COMMAND：多数情况下也可以略过，执行的标准 `make install` 命令，如果不是这个安装命令，可以修改；
-   其它
    -   DEPENDS：有其它依赖的，可以配置这个选项，它会理清这些依赖的关系，然后依次编译；

在配置的时候，正如你看到的，我会通过设置 `prefix` 为 `${CMAKE_INSTALL_PREFIX}` 将所有的第三方依赖安装在一个可配置的统一目录，这样就很方便一起打包。另外，这样有另一个好处，如果有依赖关系，大部分情况就能自动解决。

至于 `ExternalProject_Add_Step` 跟其它两个就略过了，不怎么用到，但是你想要编译文档的话，还是可以用的。而 `ExternalProject_Get_Property` 对于在你将 `ExternalProject` 作为主项目编译步骤时使用有些用处，只是考虑到它不是在配置时下载编译，毕竟如 `target_link_libraies` 这类方法需要求你已经有编译产物了，因此不怎么会用到。

当你编译完成后，可以将所有的编译产物打包上传至公共存储空间，然后再在主目录下的 `CMakeLists.txt` 中写个下载步骤即可，这样，你的所有团队成员们都可以省去第三方代码的编译时间了。

具体代码当做课后作业了，提示如下：

```cmake
file(DOWNLOAD <url> <file> [...])
file(UPLOAD <file> <url> [...])
```

或许你会觉得，这么做着实有点闹腾，不怕，接下来就介绍一个很方便的工具。

### vcpkg

这里必须狠狠夸夸微软，今年来给开源界贡献了非常多的产品以及工具，vcpkg 就是其中的一个。

简单来说，它就是基于 CMake 的一个包管理工具，在安装完成后，一条命令就能安装绝大多数的依赖，也有越来越多的第三方包也开始接受并提供 vcpkg 的支持。虽然还没有囊括所有的第三方包，交叉编译也存在一定的问题，但是我相信如果接下来能有包管理工具统一 C/C++ 的话，vcpkg 就是候选之一。

它的安装很简单：

```bash
git clone https://github.com/Microsoft/vcpkg.git
cd vcpkg
./bootstrap-vcpkg.sh
```

如果需要安装包：

```bash
vcpkg install opencv
```

然后在你的项目中，使用 `find_package` 即可：

```cmake
find_package(OpenCV REQUIRED)
target_link_libraries(target ${OpenCV_LIBS})
```

最后，在 CMake 配置阶段：

```bash
cmake .. -DCMAKE_TOOLCHAIN_FILE=path/to/vcpkg/scripts/buildsystems/vcpkg.cmake
```

就可以了，对于 OpenCV 这类有着系统支持的包，或许没有提升太多的效率，但是对于一些没有多少系统支持的包，比如 GoogleTest、nlohmann-json、prometheus-cpp 等，再也不需要费劲去自己下载编译了。

之后，为了方便随时运行 vcpkg，可以将它加到系统 PATH：

```bash
export PATH="path/to/vcpkg/:$PATH"
```

是不是很简单？只是，目前它还是不完善，我之所以不在现有的团队项目中使用它，就是因为交叉编译的问题没解决，它目前支持的交叉编译不多，比如面对 Android 还有 iOS 的交叉编译，它就基本上成了废物一般，打算等日后它完善了再用。

另外，它相对于我上面的方案来说，编译时间还是不能省去的。


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/135 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
---
title: "(CMake Series) Part 3 - ExternalProject Practice"
date: 2020-03-23 23:22:44
categories: [CMake]
tags: [C/C++, CMake, Build Systems, Dependency Management]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/135
---
<!-- en_title: cmake-3-external-project-practice -->

Last time we talked about [Third-Party Dependency Management](/en/2020/03/15/cmake-2-third-party-dependances-management/) and mentioned our team's use of `ExternalProject` to manage dependencies. This time, let's discuss the practical implementation and an open-source dependency management tool based on CMake, [vcpkg](https://github.com/microsoft/vcpkg).

### ExternalProject Practice

Let's take a look at what it looks like:

```cmake
ExternalProject_Add(<name> [<option>...])
ExternalProject_Add_Step(<name> <step> [<option>...])
ExternalProject_Get_Property
ExternalProject_Add_StepTargets(<name> [NO_DEPENDS] <step1> [<step2>...])
```

It may look simple, but it's not, as the documentation makes it seem due to the multitude of options available—surprised yet?

In fact, most of the parameters are unnecessary for basic use. I will select some commonly used parameters and discuss them. The steps are mainly divided as follows:

- **Directory Configuration**
    - **PREFIX**: Directory prefix, choose one that you find visually appealing;
    - **DOWNLOAD_DIR**: This is important; it's recommended to choose a directory at the same level as the build directory, so it serves as a cache directory after the build directory is deleted, saving download time on subsequent builds;
- **Download**
    - **URL & URL_HASH**: Download and verification of the package, recommended even for Git projects, as it can further reduce download times (especially cloning from GitHub in China);
    - **GIT_REPOSITORY & GIT_TAG**: Cloning of Git projects, it's advisable to add `GIT_SHALLOW` to reduce the clone size;
- **Update**
    - **PATCH_COMMAND**: This can modify the source files after they're fetched, such as for temporary bug fixes, especially since project maintainers may not always make timely changes;
- **Configuration**
    - **CONFIGURE_COMMAND**: For non-CMake projects, this parameter allows running configuration commands like `./configure --prefix=${CMAKE_INSTALL_PREFIX}`, also set `BUILD_IN_SOURCE true`;
    - **CMAKE_ARGS**: Configuration parameters for CMake projects, like `-DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}`;
- **Build**
    - Mostly skippable;
- **Test**
    - **TEST_COMMAND**: If you need to test the build on the machine, set this; otherwise, it's often skippable, just leave it empty: `TEST_COMMAND ""`;
- **Install**
    - **INSTALL_COMMAND**: Also mostly skippable, executes the standard `make install` command, but can be changed if not using this command;
- **Others**
    - **DEPENDS**: If there are other dependencies, configure this option; it will clarify these dependencies' relationships and then compile them in order;

As you can see, I configure `prefix` as `${CMAKE_INSTALL_PREFIX}` to install all third-party dependencies into a configurable unified directory, which makes it easy to bundle them together. Additionally, if there are dependency relationships, most issues can be automatically resolved.

Regarding `ExternalProject_Add_Step` and the other two, they are not used much, but they can be useful if you want to compile documentation. While `ExternalProject_Get_Property` has some use when you compile `ExternalProject` as a main project build step, it is generally not used since it's not downloaded and built at configuration time, considering methods like `target_link_libraries` need you to already have the build products.

After compiling, you can package all the build artifacts and upload them to a public storage space. Then, simply write a download step in the main `CMakeLists.txt`. This way, all your team members can save time on compiling third-party code.

The specific code is left as homework, hints as follows:

```cmake
file(DOWNLOAD <url> <file> [...])
file(UPLOAD <file> <url> [...])
```

You might think this process is somewhat tedious, but fear not, I'll introduce a very convenient tool next.

### vcpkg

Here, I must praise Microsoft for contributing many products and tools to the open-source community this year, with vcpkg being one of them.

Simply put, it is a package management tool based on CMake. Once installed, most dependencies can be installed with a single command, and more and more third-party packages are starting to accept and offer vcpkg support. Although it hasn't encompassed all third-party packages yet, and there are certain issues with cross-compiling, I believe vcpkg could be one of the candidates if there's an initiative to unify C/C++ package management tools.

Installation is straightforward:

```cmake
git clone https://github.com/Microsoft/vcpkg.git
cd vcpkg
./bootstrap-vcpkg.sh
```

To install packages:

```cmake
vcpkg install opencv
```

Then, in your project, use `find_package`:

```cmake
find_package(OpenCV REQUIRED)
target_link_libraries(target ${OpenCV_LIBS})
```

Lastly, during the CMake configuration phase:

```cmake
cmake .. -DCMAKE_TOOLCHAIN_FILE=path/to/vcpkg/scripts/buildsystems/vcpkg.cmake
```

For packages like OpenCV that have system support, this may not improve efficiency much, but for some less supported packages like GoogleTest, nlohmann-json, prometheus-cpp, etc., there's no need to hassle with downloading and compiling them yourself.

Later, to conveniently run vcpkg at any time, you can add it to your system PATH:

```cmake
export PATH="path/to/vcpkg/:$PATH"
```

Simple, right? However, it's still not perfect. The reason I don't use it in existing team projects is due to unresolved issues with cross-compiling. It currently supports very few cross-compilation scenarios, like for Android and iOS, where it is almost useless. I plan to wait until it's improved to use it.

Additionally, compared to my earlier solution, it still doesn't save compilation time.


***
First published on Github issues: https://github.com/xizhibei/blog/issues/135, feel free to Star and Watch

{% post_link footer %}
***

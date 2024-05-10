---
title: (CMake Series) Part 5 - Installation, Packaging, and Export
date: 2020-04-20 18:43:22
categories: [CMake]
tags: [C/C++, CMake, Build System]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/137
---
<!-- en_title: cmake-5-install-package-and-export -->

### Introduction

Today's article can be considered a continuation of the previous [Third-Party Dependency Management](/en/2020/03/15/cmake-2-third-party-dependances-management/), as today we're discussing how to become a third-party dependency.

When you're developing a library, you need to consider how others will use your library.

Currently, there are three ways to use third-party libraries:

1.  Subfolder (download and compile, Git clone and compile);
2.  Install compiled products (existing libraries on various platforms, configure after compiling your own library);
3.  Export compile directory;

Let's discuss each of these methods.

### Subfolder

For users, this method is the simplest of the three; users can treat the library as a subfolder, making it a part of the current project, and thus they can directly use any pre-existing `CMake Target` within that subfolder, which is convenient and quick.

However, as the developer of a third-party library, it's easy to make a mistake, namely confusing `CMAKE_SOURCE_DIR` with `CMAKE_PROJECT_DIR`, and `CMAKE_BINARY_DIR` with `CMAKE_BINARY_DIR`. These variables differ.

When users use your library as a third-party library, `CMAKE_SOURCE_DIR` and `CMAKE_BINARY_DIR` will become the variables of the user's project.

For example, suppose the user's project structure is as follows:

```
    project-root
    - build/
    - src/
    - extern
        - your-lib-root
            - src
            - CMakeLists.txt
    - CMakeLists.txt
```

In your library, CMake will identify `CMAKE_SOURCE_DIR` as `project-root`, not the `project-root/extern/your-lib-root` you might want, and `CMAKE_BINARY_DIR` similarly.

Therefore, the correct approach is to use `PROJECT_SOURCE_DIR` and `PROJECT_BINARY_DIR`, which CMake determines based on the most recent `project()` command encountered.

### Install Compiled Products

This is the choice of most third-party library developers, as it directly provides compiled products, reducing compile time, and some private libraries also use this method to protect their source code.

CMake provides comprehensive support for this, mainly **installation and packaging**.

##### Installation Commands

First, let's look at the specific `install` command:

```cmake
install(TARGETS <target>... [...])
install({FILES | PROGRAMS} <file>... [...])
install(DIRECTORY <dir>... [...])
install(SCRIPT <file> [...])
install(CODE <code> [...])
install(EXPORT <export-name> [...])
```

Among these, we commonly use TARGETS, FILES, PROGRAMS, DIRECTORY, and EXPORT. Let's discuss how to use each.

-   TARGETS: Install the compiled product targets: both library and executable can be parameters;
-   FILES: Install other files, such as configuration files;
-   PROGRAMS: Install executable files, scripts, etc., similar to FILES, but with executable permissions;
-   DIRECTORY: Install an entire directory, such as a documentation directory. Additionally, you can use the `FILES_MATCHING PATTERN "*.h"` parameter to install the headers needed by the library;
-   CODE and SCRIPT: These two are advanced modes; you can use them to implement custom installations;

Here's an example:

```cmake
# Install compiled products
install(TARGETS myExe mySharedLib myStaticLib
        RUNTIME DESTINATION bin
        LIBRARY DESTINATION lib
        ARCHIVE DESTINATION lib)

# Install include files
install(DIRECTORY include/ DESTINATION include/myproj
        FILES_MATCHING PATTERN "*.h")

# Install documentation
install(DIRECTORY "${CMAKE_BINARY_DIR}/docs/docs/"
          DESTINATION share/doc/QUSDK/html)
```

##### Export

If you don't want to support CMake's `find_package`, you can skip this step.

Typically, supporting `find_package` requires a `myLibConfig.cmake` file, and for version checking, a `myLibConfigVersion.cmake` file. In newer versions, CMake can generate these files for you with minimal configuration.

First, modify the above install targets accordingly:

```cmake
install(TARGETS myLib
        EXPORT myLib # Added this EXPORT
        RUNTIME DESTINATION bin
        LIBRARY DESTINATION lib
        ARCHIVE DESTINATION lib)
```

```cmake
install(
  EXPORT myLib
  FILE myLibTargets.cmake
  NAMESPACE myLib::
  DESTINATION lib/cmake/myLib)

include(CMakePackageConfigHelpers)

configure_package_config_file(
  myLibConfig.cmake.in ${PROJECT_BINARY_DIR}/myLibConfig.cmake
  INSTALL_DESTINATION lib/cmake/myLib)

write_basic_package_version_file(
  myLibConfigVersion.cmake
  VERSION ${PACKAGE_VERSION}
  COMPATIBILITY SameMajorVersion)

install(FILES "${PROJECT_BINARY_DIR}/myLibConfig.cmake"
              "${PROJECT_BINARY_DIR}/myLibConfigVersion.cmake"
        DESTINATION lib/cmake/myLib)
```

The content of `myLibConfig.cmake.in` mainly ensures third-party dependencies, and you can also do some preprocessing here. Its content is as follows:

```cmake
include(CMakeFindDependencyMacro)

# As an example, myLib requires the OpenCV dependency
find_dependency(OpenCV REQUIRED)

include("${CMAKE_CURRENT_LIST_DIR}/myLibTargets.cmake")
```

When using, you can do it as follows:

```cmake
find_package(myLib REQUIRED)
target_link_libraries(main myLib::myLib)
```

##### Packaging

After configuring the installation files, you need to release them next. CMake provides you with CPack, which is very simple to use, so I'll just briefly mention it here:

```cmake
set(CPACK_PACKAGE_VENDOR ${PROJECT_NAME})

# Set the version
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY ${PROJECT_DESCRIPTION})
set(CPACK_PACKAGE_VERSION_MAJOR ${PROJECT_VERSION_MAJOR})
set(CPACK_PACKAGE_VERSION_MINOR ${PROJECT_VERSION_MINOR})
set(CPACK_PACKAGE_VERSION_PATCH ${PROJECT_VERSION_PATCH})

# Set the packaging types, defining tgz and zip formats here
set(CPACK_GENERATOR "TGZ;ZIP")
set(CPACK_SOURCE_GENERATOR "TGZ;ZIP")

include(CPack)
```

With these simple settings, you can use the `make package` or `cpack` command to package after compiling.

Finally, upload and distribute the result.

### Export Compile Directory

This method is also quite simple because it does not require the third-party library to be placed in the user's project as a subfolder. It only needs to export the compile directory and then export the target to `$HOME/.cmake/packages` for use.

Thus, based on the installation we discussed above, it can be done with just two lines of code:

```cmake
set(CMAKE_EXPORT_PACKAGE_REGISTRY ON)
export(PACKAGE myLib)
```

Note that CMAKE_EXPORT_PACKAGE_REGISTRY was default `ON` before version 3.15, but then it was default `OFF`, as modifying user Home directory content is considered **unsolicited**.

Then, in a new project, you can directly use `find_package` to include the dependency.


***
Originally published on Github issues: https://github.com/xizhibei/blog/issues/137, feel free to Star and Watch

{% post_link footer_en %}
***

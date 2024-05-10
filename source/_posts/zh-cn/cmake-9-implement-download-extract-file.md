---
title: 【CMake 系列】（九）实战之如何下载依赖
date: 2020-06-30 19:35:08
categories: [CMake]
tags: [CMake]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/142
---
<!-- en_title: cmake-9-implement-download-extract-file -->

今天补下之前在 [ExternalProject 实践](https://github.com/xizhibei/blog/issues/135) 留下的坑：如何下载第三方依赖。

### 理清需求

由于大家的需求很可能是不一致的，这里选一个比较通用的需求：下载第三方依赖压缩包，于是我们就需要下载压缩包文件到本地，验证文件签名，然后解压到指定目录。

### CMake 提供的命令

我们要用到主要有以下两个命令：

-   file
    -   DOWNLOAD：下载文件
    -   INSTALL：安装文件到目录
    -   READ：读取文件内容
    -   REMOVE：删除文件
    -   REMOVE_RECURSE：递归删除文件
    -   MAKE_DIRECTORY：创建目录
-   cmake_parse_arguments：解析传入的函数参数
-   execute_process：运行外部命令（这里需要注意的是，外部命令很有可能运行在不同的操作系统，因此，尽量使用 CMake 提供的命令，这样可以在各个平台都能运行。）

### 实现

接下来我们一步步把功能实现。

#### 下载功能

```cmake
function(download_file url filename)
  message(STATUS "Download to ${filename} ...")
  file(DOWNLOAD ${url} ${filename})
endfunction()
```

这便是实现了一个最简单的下载函数，我们直接传入链接地址以及文件名即可下载 `download_file('http://example.com/1.zip', '2.zip')`。

接下来，我们开始添油加醋，慢慢实现自己的需求。

#### 文件签名验证

```cmake
function(download_file_with_hash url filename hash_type hash)
  message(STATUS "Download to ${filename} ...")
  file(DOWNLOAD ${url} ${filename} EXPECTED_HASH ${hash_type}=${hash})
endfunction()
```

于是，调用方式变为 `download_file_with_hash('http://example.com/1.zip', '2.zip', 'SHA1', 'xxxxxxxxxxxxxxx')`。

#### 解压文件

```cmake
function(extract_file filename extract_dir)
  message(STATUS "Extract to ${extract_dir} ...")

  # 创建临时目录，用来解压，如果已经存在，则删除
  # 这里用的解压命令，是 cmake 内部实现的解压命令，可以实现跨平台解压：
  # cmake -E tar -xf filename.tgz
  set(temp_dir ${CMAKE_BINARY_DIR}/tmp_for_extract.dir)
  if(EXISTS ${temp_dir})
    file(REMOVE_RECURSE ${temp_dir})
  endif()
  file(MAKE_DIRECTORY ${temp_dir})
  execute_process(COMMAND ${CMAKE_COMMAND} -E tar -xf ${filename}
                  WORKING_DIRECTORY ${temp_dir})

  # 这里比较关键，解压之后的临时目录中，可能是单个文件夹，里面包含着我们需要的内容，
  # 也可能是直接就包含着我们需要的内容，因此，这里就统一处理，如果包含单独的文件夹
  # 则将安装源目录设置为临时目录的下级目录
  file(GLOB contents "${temp_dir}/*")
  list(LENGTH contents n)
  if(NOT n EQUAL 1 OR NOT IS_DIRECTORY "${contents}")
    set(contents "${temp_dir}")
  endif()

  get_filename_component(contents ${contents} ABSOLUTE)
  # 这里选择 INSTALL 而不是 COPY，因为可以打印出文件拷贝的状态
  file(INSTALL "${contents}/" DESTINATION ${extract_dir})
  
  # 别忘删除临时目录
  file(REMOVE_RECURSE ${temp_dir})
endfunction()
```

#### 下载后解压

```cmake
download_file('http://example.com/1.zip', '2.zip', 'SHA1', 'xxxxxxxxxxxxxxx')
extract_file('2.zip', '/path/to/install')
```

是不是很简单？现在我们加入更多的功能。

#### 文件缓存

很多时候，如果下载的文件存在，我们只需要验证它的签名即可，即我们不用重复下载。

```cmake
if(EXISTS ${filename})
    # 获取文件真实 HASH
    file(${hash_type} ${filename} _ACTUAL_CHKSUM)
    if(NOT (${hash} STREQUAL ${_ACTUAL_CHKSUM}))
      # 如果签名不一致，则还是需要重新下载文件
      message(STATUS "Expect ${DAE_HASH_TYPE}=${_EXPECT_HASH}")
      message(STATUS "Actual ${DAE_HASH_TYPE}=${_ACTUAL_CHKSUM}")
      message(WARNING "File hash mismatch, remove & retry ...")
      file(REMOVE ${filename})
      download_file_with_hash(${url} ${filename} ${hash_type} ${hash})
    else()
      message(STATUS "Using exists local file ${filename}")
    endif()
else()
    download_file_with_hash(${url} ${filename} ${hash_type} ${hash})
endif()
```

### 参数解析

最后，我们将这个过程封装成一个单独的函数，并且加上参数解析。

```cmake
function(download_and_extract)
  set(options REMOVE_EXTRACT_DIR_IF_EXISTS)
  set(oneValueArgs DESTINATION RENAME)
  set(multiValueArgs)
  set(oneValueArgs URL FILENAME HASH_TYPE HASH EXTRACT_DIR)
  cmake_parse_arguments(DAE "${options}" "${oneValueArgs}" "${multiValueArgs}"
                        ${ARGN})
  if(NOT DEFINED DAE_URL)
    message(FATAL_ERROR "Missing URL")
  endif()
  if(NOT DEFINED DAE_FILENAME)
    message(FATAL_ERROR "Missing FILENAME")
  endif()
  if(NOT DEFINED DAE_HASH_TYPE)
    message(FATAL_ERROR "Missing HASH_TYPE")
  endif()
  if(NOT DEFINED DAE_HASH)
    message(FATAL_ERROR "Missing HASH")
  endif()
  if(NOT DEFINED DAE_EXTRACT_DIR)
    message(FATAL_ERROR "Missing EXTRACT_DIR")
  endif()

  if(EXISTS ${DAE_EXTRACT_DIR})
    if(DAE_REMOVE_EXTRACT_DIR_IF_EXISTS)
      message(STATUS "${DAE_EXTRACT_DIR} already exists, removing...")
      file(REMOVE_RECURSE ${DAE_EXTRACT_DIR})
    else()
      message(
        STATUS "${DAE_EXTRACT_DIR} already exists, skip download & extract")
      return()
    endif()
  endif()

  if(EXISTS ${DAE_FILENAME})
    file(${DAE_HASH_TYPE} ${DAE_FILENAME} _ACTUAL_CHKSUM)

    if(NOT (${_EXPECT_HASH} STREQUAL ${_ACTUAL_CHKSUM}))
      message(STATUS "Expect ${DAE_HASH_TYPE}=${_EXPECT_HASH}")
      message(STATUS "Actual ${DAE_HASH_TYPE}=${_ACTUAL_CHKSUM}")
      message(WARNING "File hash mismatch, remove & retry ...")
      file(REMOVE ${DAE_FILENAME})
      download_file_with_hash(${DAE_URL} ${DAE_FILENAME} ${DAE_HASH_TYPE}
                              ${_EXPECT_HASH})
    else()
      message(STATUS "Using exists local file ${DAE_FILENAME}")
    endif()
  else()
    download_file_with_hash(${DAE_URL} ${DAE_FILENAME} ${DAE_HASH_TYPE}
                            ${_EXPECT_HASH})
  endif()
  extract_file(${DAE_FILENAME} ${DAE_EXTRACT_DIR})
endfunction()
```

于是，一个完整的文件下载解压函数就完成了，我们可以在项目中，这样使用自己实现的函数：

```cmake
download_and_extract(
    URL https://example.com/1.tar.gz
    FILENAME /tmp/1.tar.gz
    HASH_TYPE SHA1
    HASH xxxxxxxx
    EXTRACT_DIR /tmp/example_dir)
```


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/142 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
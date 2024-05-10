---
title: "(CMake Series) Part 9 - Practical Tips: How to Download Dependencies"
date: 2020-06-30 19:35:08
categories: [CMake]
tags: [CMake, Build Systems]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/142
---
<!-- en_title: cmake-9-implement-download-extract-file -->
<!-- toc -->

Today, I'll address a topic I previously mentioned in [ExternalProject Practices](/en/2020/03/23/cmake-3-external-project-practise/): how to download third-party dependencies.

### Clarifying Requirements

Since everyone's needs might differ, let's discuss a common requirement: downloading a third-party dependency archive. Thus, we need to download the archive file locally, verify the file signature, and then extract it to a designated directory.

### Commands Provided by CMake

We will mainly use the following commands:

```
-   file
    -   DOWNLOAD: Downloads a file
    -   INSTALL: Installs files into a directory
    -   READ: Reads the contents of a file
    -   REMOVE: Deletes a file
    -   REMOVE_RECURSE: Recursively deletes files
    -   MAKE_DIRECTORY: Creates a directory
-   cmake_parse_arguments: Parses function arguments
-   execute_process: Executes external commands (note that external commands may run on different operating systems, so try to use commands provided by CMake to ensure compatibility across platforms.)
```

### Implementation

Let's implement these features step by step.

#### Download Function

```cmake
function(download_file url filename)
  message(STATUS "Downloading to ${filename} ...")
  file(DOWNLOAD ${url} ${filename})
endfunction()
```

This is a simple download function where you pass the URL and the filename to download, like `download_file('http://example.com/1.zip', '2.zip')`.

Next, let's enhance this function to meet our specific needs.

#### File Signature Verification

```cmake
function(download_file_with_hash url filename hash_type hash)
  message(STATUS "Downloading to ${filename} ...")
  file(DOWNLOAD ${url} ${filename} EXPECTED_HASH ${hash_type}=${hash})
endfunction()
```

Thus, the usage changes to `download_file_with_hash('http://example.com/1.zip', '2.zip', 'SHA1', 'xxxxxxxxxxxxxxx')`.

#### Extracting Files

```cmake
function(extract_file filename extract_dir)
  message(STATUS "Extracting to ${extract_dir} ...")

  # Create a temporary directory for extraction; if it already exists, delete it
  # The following command uses CMake's internal extraction command, enabling cross-platform extraction:
  # cmake -E tar -xf filename.tgz
  set(temp_dir ${CMAKE_BINARY_DIR}/tmp_for_extract.dir)
  if(EXISTS ${temp_dir})
    file(REMOVE_RECURSE ${temp_dir})
  endif()
  file(MAKE_DIRECTORY ${temp_dir})
  execute_process(COMMAND ${CMAKE_COMMAND} -E tar -xf ${filename}
                  WORKING_DIRECTORY ${temp_dir})

  # This step is crucial as the temporary directory might contain a single folder with our desired content
  # or directly contain the files we need. Here, handle both cases uniformly by setting the source directory
  # to the subdirectory of the temporary directory if it contains a single folder
  file(GLOB contents "${temp_dir}/*")
  list(LENGTH contents n)
  if(NOT n EQUAL 1 OR NOT IS_DIRECTORY "${contents}")
    set(contents "${temp_dir}")
  endif()

  get_filename_component(contents ${contents} ABSOLUTE)
  # Choose INSTALL over COPY to display file copying status
  file(INSTALL "${contents}/" DESTINATION ${extract_dir})
  
  # Don't forget to delete the temporary directory
  file(REMOVE_RECURSE ${temp_dir})
endfunction()
```

#### Download and Extract

```cmake
download_file_with_hash('http://example.com/1.zip', '2.zip', 'SHA1', 'xxxxxxxxxxxxxxx')
extract_file('2.zip', '/path/to/install')
```

Simple, right? Now let's add more functionality.

#### File Caching

Often, if the downloaded file exists, we only need to verify its signature, meaning we don't need to download it again.

```cmake
if(EXISTS ${filename})
    # Get the actual file hash
    file(${hash_type} ${filename} _ACTUAL_CHKSUM)
    if(NOT (${hash} STREQUAL ${_ACTUAL_CHKSUM}))
      # If the signature does not match, re-download the file
      message(STATUS "Expected ${hash_type}=${hash}")
      message(STATUS "Actual ${hash_type}=${_ACTUAL_CHKSUM}")
      message(WARNING "File hash mismatch, removing & retrying...")
      file(REMOVE ${filename})
      download_file_with_hash(${url} ${filename} ${hash_type} ${hash})
    else()
      message(STATUS "Using existing local file ${filename}")
    endif()
else()
    download_file_with_hash(${url} ${filename} ${hash_type} ${hash})
endif()
```

### Argument Parsing

Finally, let's wrap this process into a single function and add argument parsing.

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

    if(NOT (${hash} STREQUAL ${_ACTUAL_CHKSUM}))
      message(STATUS "Expected ${DAE_HASH_TYPE}=${hash}")
      message(STATUS "Actual ${DAE_HASH_TYPE}=${_ACTUAL_CHKSUM}")
      message(WARNING "File hash mismatch, removing & retrying...")
      file(REMOVE ${DAE_FILENAME})
      download_file_with_hash(${DAE_URL} ${DAE_FILENAME} ${DAE_HASH_TYPE}
                              ${hash})
    else()
      message(STATUS "Using existing local file ${DAE_FILENAME}")
    endif()
  else()
    download_file_with_hash(${DAE_URL} ${DAE_FILENAME} ${DAE_HASH_TYPE}
                            ${hash})
  endif()
  extract_file(${DAE_FILENAME} ${DAE_EXTRACT_DIR})
endfunction()
```

Thus, a complete file download and extraction function is ready. You can use the function you've implemented in your projects like this:

```cmake
download_and_extract(
    URL https://example.com/1.tar.gz
    FILENAME /tmp/1.tar.gz
    HASH_TYPE SHA1
    HASH xxxxxxxx
    EXTRACT_DIR /tmp/example_dir)
```


***
First published on GitHub issues: https://github.com/xizhibei/blog/issues/142, welcome to Star and Watch

{% post_link footer_en %}
***

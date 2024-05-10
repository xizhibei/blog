---
title: 【CMake 系列】（六）用 Doxygen、Sphinx 与 Breathe 创建文档
date: 2020-05-19 19:13:32
categories: [CMake]
tags: [文档,C/C++,CMake]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/139
---
<!-- en_title: cmake-6-docs-with-doxygen-sphinx-breathe -->

今天，来说说 CMake 中另外一个可能比较枯燥的环节：文档。

### 前言

说起文档，就不得不提文档的维护了，如果纯手写，难免会遇到代码与文档不一致的情况，理想的状态下，最好全部由解析代码后生成，再加上开发人员少量写的说明性文档即可。

之前我也在 [你的团队需要更好的 API 文档流程](https://github.com/xizhibei/blog/issues/85) 里说过，好的 API 文档的特点也是类似。

至于我们今天要说的 C/C++ 的文档，主流的方案就是 **Doxygen + Sphinx + Breathe**，其它的工具相对显得小众了，可以去[维基上看看](https://en.wikipedia.org/wiki/Comparison_of_documentation_generators) （实际上我也没有细看 :P）。

### 准备环境

1.  安装 Doxygen：`sudo apt install doxygen`；
2.  安装 Sphinx 与 Breathe: `pip3 install Sphinx breathe`，注意 目前 Sphinx 需要 Python3，这里也是用 pip3 安装的；

下面来依次介绍下它们三个。

#### Doxygen

[Doxygen](http://www.doxygen.nl/manual/index.html) 算是 C/C++ 中最有名的，历史悠久（1997/10/26 发布了第一个版本），众多开源的 C/C++ 也是选择了它作为文档工具。

Doxygen 的原理很简单，就是给函数、变量声明等地方加上 comments，然后通过解析它们来生成对应的文档。

如下，就是[官网](http://www.doxygen.nl/manual/docblocks.html#cppblock)里面给出的一个小例子：

```c
 /*! \fn int open(const char *pathname,int flags)
    \brief Opens a file descriptor.
 
    \param pathname The name of the descriptor.
    \param flags Opening flags.
*/
```

其它内容也很容易学习，这里不再赘述。

使用 Doxygen 也很简单，你可以三步走：

1.  运行 `doxygen -g Doxyfile` 来生成配置；
2.  按需求修改配置；
3.  运行 `doxygen` 生成文档；

如果你配置了 HTML 的输出，那就可以直接在浏览器打开。

到这里，Doxygen 能做到很简单就能生成文档了，但还是差一些，因为这样生成的文档，比较不符合现代的审美。

那该怎么办呢？接下来就该 Sphinx 上场了。

#### Sphinx 与 Breathe

Sphinx 目前的『市场』占有率非常高，因为它有免费的文档托管 [Read the Docs](https://readthedocs.org/)，支持线上预览以及版本历史等，由此大多数的 Python 文档都是选择它来生成文档的。

对的，你没听错，一开始它确实是为了 Python 文档而出现的，后来也逐渐支持其它语言，包括 C/C++，只是，Doxygen 与 Sphinx 不能直接关联，即 Sphinx 不能直接使用 Doxygen 生成的内容来生成 Sphinx 文档，它还需要一个插件来做适配，Breathe 就是为了连接 Doxygen 与 Sphinx 而生。

Sphinx 默认的解析文档是 `reStructureText`，你可以认为是高级版本的 `Markdown`，也就是比它功能更强大。当然，你也可以使用 [Markdown 来写文档](https://www.sphinx-doc.org/en/master/usage/markdown.html)，它有一个专门的插件来做这件事。

所以，操作流程大致如下：

1.  Doxygen 解析源码文件中的 comments 生成 xml 文档素材；
2.  Sphinx 使用 Breathe 插件解析的 xml 文档素材，以及解析现成的 `reStructureText` 文档，生成最后的 HTML 或者其他文档类型；

具体的操作参考 [Breathe 文档](https://breathe.readthedocs.io/en/latest/quickstart.html) 以及 [sampledoc tutorial](https://matplotlib.org/sampledoc/index.html) 进行：

开始之前需要准备 `index.rst`：

```rst
My Awesome project's documentation!
===================================

.. doxygenindex::
   :project: doxygen_docs

Indices and tables
==================

* :ref:`genindex`
* :ref:`search`
```

1.  将 `Doxygen` 中的 `GENERATE_XML` 设置为 `YES`；
2.  用 `sphinx-quickstart` 这个交互式命令生成 `conf.py`，与 `index.rst` 放在一起，然后还可以进一步修改里面的相关内容；
3.  确保 Breathe 在 Python path 内，不在的话，需要在 `conf.py` 内加上 `sys.path.append("/path/to/breathe/")`；
4.  在 `conf.py` 加上 Breathe 需要的配置：`breathe_projects = {"myproject": "/path/to/doxygen/xml"}`，`breathe_default_project = "myproject"`；
5.  执行 `sphinx-build -b html -c /path/to/conf.py_dir /path/to/doxygen/xml /output/dir`

最后，就能看到生成的 HTML 文档了，对比下之前 Doxygen 直接生成的 HTML 文档，会发现美观了很多。

### CMake 配置

终于来到了 CMake 环节，我们该如何把上述的复杂步骤结合起来？

CMake 提供了很简单的 `doxygen_add_docs`，通过简单配置，你就能生成 Doxygen 文档：

```cmake
find_package(Doxygen REQUIRED)

# 这里只是举例，其它 Doxygen 配置加上 `DOXYGEN_` 前缀即可
set(DOXYGEN_GENERATE_HTML YES)
set(DOXYGEN_EXTRACT_ALL YES)
set(DOXYGEN_BUILTIN_STL_SUPPORT YES)

doxygen_add_docs(doxygen_docs "${PROJECT_SOURCE_DIR}/src")
```

那么 Sphinx 呢？我找到一个现成可以用的：[cmake-sphinx](https://github.com/k0ekk0ek/cmake-sphinx) ，但是需要修改一部分，大体上这里的功能可以完全满足我们的使用。

```cmake
# 别忘了生成 XML，同时可以去掉上面的 DOXYGEN_GENERATE_HTML
set(DOXYGEN_GENERATE_XML YES) 

find_package(Sphinx REQUIRED COMPONENTS breathe)
set(SPHINX_VERSION ${PROJECT_VERSION})
set(SPHINX_LANGUAGE zh_CN)
sphinx_add_docs(
  docs
  BREATHE_PROJECTS
  doxygen_docs
  BUILDER
  html
  SOURCE_DIRECTORY
  .)
```

然后，在编译目录下，打开 `docs/docs/index.html` 就能看到美观的文档了。

### Ref

1.  [Clear, Functional C++ Documentation with Sphinx + Breathe + Doxygen + CMake](https://devblogs.microsoft.com/cppblog/clear-functional-c-documentation-with-sphinx-breathe-doxygen-cmake/)


***
首发于 Github issues: https://github.com/xizhibei/blog/issues/139 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
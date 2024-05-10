---
title: (CMake Series) Part 6 - Creating Documentation with Doxygen, Sphinx, and Breathe
date: 2020-05-19 19:13:32
categories: [CMake]
tags: [C/C++, CMake, Documentation, Sphinx, Doxygen, Breathe]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/139
---
<!-- en_title: cmake-6-docs-with-doxygen-sphinx-breathe -->

Today, let's talk about another perhaps less exciting aspect of CMake: documentation.

### Introduction

When it comes to documentation, we must address its maintenance. If purely handwritten, it's inevitable that the code and documentation may not align. Ideally, documentation should be generated from parsed code, supplemented by minimal explanatory texts written by developers.

I've discussed the characteristics of good API documentation before in [Your Team Needs a Better API Documentation Process](https://github.com/xizhibei/blog/issues/85).

For C/C++ documentation that we'll talk about today, the mainstream solution is **Doxygen + Sphinx + Breathe**. Other tools are relatively niche, but you can check them out on [Wikipedia](https://en.wikipedia.org/wiki/Comparison_of_documentation_generators) (although I haven't looked in detail :P).

### Preparing the Environment

1.  Install Doxygen: `sudo apt install doxygen`;
2.  Install Sphinx and Breathe: `pip3 install Sphinx breathe`, note that Sphinx currently requires Python3, so it's also installed with pip3 here;

Let's introduce them one by one.

#### Doxygen

[Doxygen](http://www.doxygen.nl/manual/index.html) is probably the most famous in C/C++, with a long history (the first version was released on 1997/10/26), and many open-source C/C++ projects choose it as their documentation tool.

The principle behind Doxygen is simple: add comments to functions, variable declarations, etc., and then generate corresponding documentation by parsing these comments.

Below is a small example from the [official website](http://www.doxygen.nl/manual/docblocks.html#cppblock):

```c
 /*! \fn int open(const char *pathname,int flags)
    \brief Opens a file descriptor.
 
    \param pathname The name of the descriptor.
    \param flags Opening flags.
*/
```

Other content is easy to learn, so I won't elaborate here.

Using Doxygen is also straightforward, you can simply:

1.  Run `doxygen -g Doxyfile` to generate a configuration;
2.  Modify the configuration as needed;
3.  Run `doxygen` to generate the documentation;

If you configured HTML output, you can open it directly in a browser.

At this point, Doxygen can easily generate documentation, but it's still lacking, as such documentation does not meet modern aesthetic standards.

So, what should we do? That's where Sphinx comes in.

#### Sphinx and Breathe

Sphinx currently has a very high "market" share because it offers free documentation hosting [Read the Docs](https://readthedocs.org/), which supports online previews and version history, etc., making it the choice for most Python documentation.

Yes, you heard right, it originally appeared for Python documentation, but it gradually started supporting other languages, including C/C++. However, Doxygen and Sphinx cannot directly connect, meaning Sphinx cannot directly use Doxygen-generated content to produce Sphinx documentation. It needs a plugin to adapt, and Breathe is born to link Doxygen and Sphinx.

Sphinx's default parsing document is `reStructuredText`, which you can think of as an advanced version of `Markdown`, meaning it's more powerful. Of course, you can also use [Markdown to write documentation](https://www.sphinx-doc.org/en/master/usage/markdown.html), there is a specific plugin for this.

So, the operation process is roughly as follows:

1.  Doxygen parses comments in source code files to generate XML documentation materials;
2.  Sphinx uses the Breathe plugin to parse the XML documentation materials and parse existing `reStructuredText` documents to generate the final HTML or other document types;

Refer to the [Breathe documentation](https://breathe.readthedocs.io/en/latest/quickstart.html) and [sampledoc tutorial](https://matplotlib.org/sampledoc/index.html) for specific operations:

Start by preparing `index.rst`:

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

1.  Set `GENERATE_XML` to `YES` in `Doxygen`;
2.  Use `sphinx-quickstart` this interactive command to generate `conf.py`, put it together with `index.rst`, and then you can further modify the related content inside;
3.  Ensure Breathe is in the Python path, if not, add `sys.path.append("/path/to/breathe/")` in `conf.py`;
4.  Add Breathe required configurations in `conf.py`: `breathe_projects = {"myproject": "/path/to/doxygen/xml"}`, `breathe_default_project = "myproject"`;
5.  Run `sphinx-build -b html -c /path/to/conf.py_dir /path/to/doxygen/xml /output/dir`

Finally, you can see the generated HTML documentation, which will be much more visually appealing compared to the HTML documentation directly generated by Doxygen.

### CMake Configuration

Finally, we reach the CMake section, how can we combine the above complex steps?

CMake provides a very simple `doxygen_add_docs`, with simple configuration, you can generate Doxygen documentation:

```cmake
find_package(Doxygen REQUIRED)

# This is just an example, other Doxygen configurations add `DOXYGEN_` prefix
set(DOXYGEN_GENERATE_HTML YES)
set(DOXYGEN_EXTRACT_ALL YES)
set(DOXYGEN_BUILTIN_STL_SUPPORT YES)

doxygen_add_docs(doxygen_docs "${PROJECT_SOURCE_DIR}/src")
```

What about Sphinx? I found a ready-to-use one: [cmake-sphinx](https://github.com/k0ekk0ek/cmake-sphinx), but it needs some modification, generally this feature can fully meet our needs.

```cmake
# Don't forget to generate XML, you can also remove the above DOXYGEN_GENERATE_HTML
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

Then, open `docs/docs/index.html` in the build directory to see the beautifully formatted documentation.

### Ref

1.  [Clear, Functional C++ Documentation with Sphinx + Breathe + Doxygen + CMake](https://devblogs.microsoft.com/cppblog/clear-functional-c-documentation-with-sphinx-breathe-doxygen-cmake/)


***
Originally published on Github issues: https://github.com/xizhibei/blog/issues/139, feel free to Star and Watch

{% post_link footer_en %}
***

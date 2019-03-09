---
title: 为何 C++ 静态链接库顺序很重要
date: 2019-02-24 19:27:09
tags: [C&#x2F;C++]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/100
---
<!-- en_title: why-library-order-matters-in-cpp-static-linking -->

自从换了新环境，逐渐接触了一些机器学习相关库的过程中，不可避免的开始捡回 C/C++ 的一些知识，之后也会写一些 C/C++ 相关的文章。

### 一个编译错误
今天，我们从一个编译错误说起，之后再复习相关的知识：

```
$ g++ bar.cpp
bar.cpp:(.text+0x20): undefined reference to `foo`
```

从字面上理解的话，就是 `foo` 引用没有被定义，一般来说，这种错误多半是由于链接器链接的时候没有找到 `foo` 的定义，也就是说，你提供的库不对，或者，不够。

如果有点懵，我们简单复习下 C/C++ 项目的编译。

### 编译步骤
我们在编译一个 C/C++ 项目时，大致有这么三个步骤 [1]：

1. ** 预处理 **：将 `#include` 以及 `#define` 相关的代码，预处理成纯 C/C++ 代码；
2. ** 编译 **：编译成目标文件，即 obj 文件，一般都是 `.o` 文件；
3. ** 链接 **：将 obj 文件，与相关的库文件链接在一起，最终生成一个可执行文件或者库文件；

所以，这个错误是在第三个步骤出错的，检查下你的编译选项，然后添加正确的库基本上就能解决了。

```
$ g++ -L -lfoo bar.cpp
```

显然，如果解决问题那么简单，我是不会拿它写博客的 :P。

问题还没解决，上面的解决方式显然能够解决大部分情况，然而有些情况下，我们的编译选项中，明明定义了所有的库，为什么还是编译不通过？

就不卖关子了，答案是 ** 静态链接时库的顺序也会造成这个问题 **。

至于原因，就需要了解链接过程的一些细节了。

### 链接过程
我们在编译的过程中，有两种链接方式，动态与静态。

- ** 静态链接 **：即将依赖库与调用程序链接成一个完成的库或者可执行文件，运行的时候会将整个程序装到内存中，方便部署但是体积较大，依赖库升级的时候需要重新编译；
- ** 动态链接 **：即将依赖库与调用程序分离，不组装成单个文件，而是在运行的时候，当调用到动态库的库时，才会将依赖库装载到内存中，这样会方便与其它程序共享以及升级，可执行文件的体积小，但是不方便部署；

今天我们遇到的问题，发生在静态链接过程中，而链接过程的细节如下：

静态库中，包含着所有的 obj(*.o) 文件，连接器从左至右搜索，维护着一个 **undefined 列表 **，一旦遇到没有定义的内容，就会将它加到列表中，如果搜索到了定义的内容，则抽取出 obj 文件，进行链接，并将 undefined 内容移出列表，而其它 obj 文件就会被丢弃（为了减少最终的体积大小），于是一个静态库如果不能在搜索过程中被链接，它就会被丢弃，而在后面一旦遇到依赖它的库，就会造成引用无法被链接，一直留在 **undefined 列表 ** 中，最终导致编译错误。

拿一个简单的例子来说明 [2]：

```bash
$ cat a.cpp
extern int a;
int main() {
  return a;
}

$ cat b.cpp
extern int b;
int a = b;

$ cat d.cpp
int b;
```

```bash
$ g++ -c b.cpp -o b.o
$ ar cr libb.a b.o
$ g++ -c d.cpp -o d.o
$ ar cr libd.a d.o

$ g++ a.cpp -L. -ld -lb # 错误顺序
$ g++ a.cpp -L. -lb -ld # 正确顺序
```

我们可以看到，d 是 b 的依赖，如果 d 先于 b 出现，由于无法链接 d 就会被抛弃，而造成 b 中的 `extern int b` 无法被链接，造成错误。

至于动态链接，链接器会对依赖进行整理，避免这个问题。

### 知识拓展之环形引用
如果是环形引用（这里只是为了说明问题，实际编程中，这种问题应该尽量避免），情况又改如何？[3]

我们修改下上面的例子：

```bash
$ cat a.cpp
extern int a;
int main() {
  return a;
}

$ cat b.cpp
extern int b;
int a = b;
int d;

$ cat d.cpp
extern int d;
int b = d;
```

运行编译后，你会发现

```bash
$ g++ a.cpp -L. -lb -ld
```

这种方式是能顺利编译的，为什么？

留给你思考，然后我们再来个复杂点的：

```bash
$ cat a.cpp
extern int a;
int main() {
  return a;
}

$ cat b.cpp
extern int b;
int a = b;
int d;

$ cat d.cpp
extern int d;
extern int e;
int b = d + e;

$ cat e.cpp
int e
```

再运行上面的编译后:

```bash
$ g++ -c e.cpp -o e.o
$ g++ -c b.cpp -o b.o
$ ar cr libb.a b.o e.o # 注意这里，把 b 与 e 在同一个静态库 libb.a 里面
$ g++ -c d.cpp -o d.o
$ ar cr libd.a d.o
```

会发现那两种方式都不能解决问题。

而下面这种方式却能解决

```bash
$ g++ a.cpp -L. -lb -ld -lb
```

为什么？

很简单，因为回顾下链接的过程就能发现，当链接器遇到第一个 `lb` 时，会将 b 加入 **undefined 列表 **，而遇到 `ld` 时，会将 b 与 `ld` 链接，同时将 d 与 e 加入 **undefined 列表 **，最后遇到 第二个 `lb` 时，重复同样的过程，然后顺利链接。

但是，反过来：

```bash
$ g++ a.cpp -L. -ld -lb -ld
```

却会失败，为什么？也留给你了 :P。

### 知识拓展之性能影响
链接顺序也会影响性能？

是的，比如 math 相关的性能加强库 libmopt 便是一个例子 [4]，顺序不对会造成连接器使用系统默认的库，而不是你指定的库。

### Ref
1. https://stackoverflow.com/questions/6264249/how-does-the-compilation-linking-process-work
2. https://stackoverflow.com/questions/45135/why-does-the-order-in-which-libraries-are-linked-sometimes-cause-errors-in-gcc
3. https://eli.thegreenplace.net/2013/07/09/library-order-in-static-linking
4. https://blogs.oracle.com/d/library-order-is-important

***
首发于 Github issues: https://github.com/xizhibei/blog/issues/100 ，欢迎 Star 以及 Watch

{% post_link footer %}
***
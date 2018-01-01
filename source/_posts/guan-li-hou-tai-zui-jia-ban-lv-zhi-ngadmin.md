---
title: 管理后台最佳伴侣之 NgAdmin
date: 2016-04-28 22:40:04
tags: [Angular]
author: xizhibei
issue_link: https://github.com/xizhibei/blog/issues/8
---
这几天为了给系统新做个后台，到处找开源项目，真给我找到了，https://github.com/marmelab/ng-admin

用完只能说，太方便了~~~ 这么好的项目为啥我现在才发现，之前我是使用 angular 一步步搭起来了，自从用了 ng-admin 之后，2 天时间系统已经成形了，结合 rest API，后台的开发很简单，待我这个项目做好之后写篇总结。

不过可以先贴段代码，这里是跟后台交互的 API，自定义的接口风格都可以在这里修改，由于我实现的后台使用的是 mongoose，因此可以根据它的查询风格修改如下：

``` js
import store from 'store';

export function requestInterceptor(RestangularProvider) {
  // use the custom query parameters function to format the API request correctly
  RestangularProvider.addFullRequestInterceptor(function (element, operation, what, url, headers, params) {
    if (operation == "getList") {
      // custom pagination params
      if (params._page) {
        params.skip = (params._page - 1) * params._perPage;
        params.limit = params._perPage;
        delete params._page;
        delete params._perPage;
      }
      // custom sort params
      if (params._sortField) {
        let field = params._sortField;
        if (params._sortField === 'id') {
          field = '_id';
        }
        params.sort = `${params._sortDir === 'ASC' ? '':'-'}${field}`;
        delete params._sortField;
        delete params._sortDir;
      }
      // custom filters
      if (params._filters) {
        params.filters = params._filters;
        delete params._filters;
      }
    }
    const token = store.get('JWT_TOKEN');
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }
    return {params: params, headers: headers};
  });
}

export function responseInterceptor(RestangularProvider) {
  RestangularProvider.addResponseInterceptor(function (data, operation, what, url, response) {
    // your intercepter logic here

    return data;
  });
}
```

然后在后台的接口直接使用传过来的参数：

``` js
export function getAdminDataList(Model, query) {
  const filters = JSON.parse(query.filters);
  let q = Model.find(filters);

  if (query.sort) {
    q = q.sort(query.sort);
  }
  if (query.limit) {
    q = q.limit(Number(query.limit));
  }
  if (query.skip) {
    q = q.skip(Number(query.skip));
  }
  return q.exec();
}
```
### 关于管理后台

一些开发团队往往有这样的想法：『管理后台是给自己人用的，差点无所谓』。我却认为，你做的管理后台是给员工用的，如果差的话，他们用着难受，尤其是客服，他们的态度会被影响，然后传染给你的用户。同时，管理后台是工具，如果差的话就意味着效率低，效率低对团队意味着什么，我也不用细说了。

> 退一步说，管理后台的使用者也是你的用户，建议让管理后台的产品或者开发人员去客服边上待上几个小时，当他们看到自己做的东西让别人那么难受的时候，就会知道该怎么做了。
> ** 来自一个给客服同事造成困扰的工程师 **


***
原链接: https://github.com/xizhibei/blog/issues/8

![知识共享许可协议](https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png "署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）")

本文采用 [署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh) 进行许可。

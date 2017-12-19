---
title: kubernetes 中的权限管理
date: 2017-12-17 14:31:31
tags: [DevOps,kubernetes]
author: xizhibei
---
<!-- en_title: authorization-in-k8s -->

Kubernetes 发展好快，在我写这篇总结的同时，`1.9.0` 版本已经在昨日（2017.12.16）正式发布，而上次在正式环境中部署已经是半年前了，我花了点时间将集群升级到了 `1.8.4` 版本，其中变化最明显的就是权限了，已经可以用上 RBAC 了，而我也在发现报错的时候才意识到需要将以前 k8s 的基础应用也全部加上了权限（当然了，`1.6` 其实就开始有了）。

<!-- more -->

目前，k8s 中一共有 4 种权限模式：

- Node: 一种特殊目的的授权模式，主要用来让 kubelets 遵从 node 的编排规则，实际上是 RBAC 的一部分，相当于只定义了 node 这个角色以及它的权限； 
- ABAC: Attribute-based access control；
- RBAC: Role-based access control；
- Webhook: 以 HTTP Callback 的方式，利用外部授权接口来进行权限控制；

对于大部分人来说，RBAC 就能起到很好的权限控制效果了（k8s 的 RBAC 实现是一个非常优秀的样例，详细研究下它的设计将对你未来对于其它系统的权限设计会有很好的启发作用，比如你们公司管理后台权限设计）。下面将详细介绍下。

### 基础

#### 样例
```yaml
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: default
  name: example
rules:
- apiGroups: [""] #"" 说明是 core API group
  resources: ["pods"] # 可用来操作的对象
  verbs: # 可以进行的操作
    - get
    - list
    - create
    - update
    - patch
    - watch
    - proxy
    - redirect
    - delete
    - deletecollection
```


#### Role & ClusterRole
两种角色，很好区分，role 限定于单个 namespace，而 ClusterRole 则是没有这个限制的，主要是用来给一些基础服务用的。

#### RoleBinding & ClusterRoleBinding
这个就相当于具体的权限授权列表了，所有的 Role 会与具体的 ServiceAccount、User 以及 Group 等绑定，而他们的区别就是分别对应 Role & ClusterRole。


#### Aggregated ClusterRoles
这是 1.9 引入的新功能，简而言之，你可以利用标签来组合一些列的 ClusterRoles，具体样例如下：

```yaml
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: monitoring
aggregationRule:
  clusterRoleSelectors:
  - matchLabels:
      rbac.example.com/aggregate-to-monitoring: "true"
# 所有带有 rbac.example.com/aggregate-to-monitoring: "true" 这个标签的都会被组合
# 然后自动生成 rules
rules: [] 
```

### 实践：生成用户账户
在官方文档中，也没有介绍应该如何生成具体的 User 账户（在 [设计文档](https://github.com/kubernetes/kubernetes/blob/587d164307de060d271f10f2386f39153360fba9/docs/design/access.md) 中，提到过 userAccount，但目前还没有实现），但其实生成账户很简单，因为 User 账户是根据 SSL 证书生成的，你只要根据 k8s 的 ca 证书来生成对应的账户即可。

比如目前我需要生成一个 xizhibei 的账户：

```bash
# 在当前目录下添加目录，用来存放证书
mkdir certs
# 设置一些变量
KUBE_URL=https://k8s-master01.zs:6443
CLUSTER=k8s.cluster
CRT_DAYS=365
USER_NAME=xizhibei

# CA 证书可以在 master node 上找到
# 一般就在 /etc/kubernetes/ssl 或者 /etc/kubernetes/pki 里面
CA_CRT_PATH=/etc/kubernetes/ssl/ca.pem
CA_KEY_PATH=/etc/kubernetes/ssl/ca-key.pem

# 生成私有密钥
openssl genrsa -out certs/$USER_NAME.key 2048

# 用私钥生成证书，CN 表示用户名，O 表示用户组
openssl req -new -key certs/$USER_NAME.key -out certs/$USER_NAME.csr \
-subj "/CN=$USER_NAME/O=example"

# 然后用 CA 证书来给刚才生成的证书来签名
# 在这个例子中，我们给 xizhibei 这个账户签发了一张有效期为一年的证书
openssl x509 -req -in certs/$USER_NAME.csr -CA $CA_CRT_PATH -CAkey $CA_KEY_PATH \
-CAcreateserial -out certs/$USER_NAME.crt -days $CRT_DAYS
```

好了，这样你就生成了一个账户，接下来，需要设置下 kubectl 的配置：

```bash
# 存放 kubectl config 的文件
export KUBECONFIG=/root/k8s-$USER_NAME.conf

# 设置 cluster
kubectl config set-cluster $CLUSTER --server="$KUBE_URL" \
--certificate-authority="$CA_CRT_PATH" --embed-certs=true

# 设置私钥以及已签名证书
kubectl config set-credentials $USER_NAME --client-certificate=certs/$USER_NAME.crt  \
--client-key=certs/$USER_NAME.key --embed-certs=true

# 设置 context
kubectl config set-context $USER_NAME-context --cluster=$CLUSTER --user=$USER_NAME
kubectl config use-context $USER_NAME-context
```

你可以使用 `kubectl get pods -n example --kubeconfig /root/k8s-xizhibei.conf` 来确认是否可以可用，不出所料的话，你会被告知没有权限，因为现在只是生成了一个账户，你还不可以操作具体的资源。

> Error from server (Forbidden): pods is forbidden: User "xizhibei" cannot list pods in the namespace "example"

下面，就需要你配置具体的 Role 以及 RoleBinding 来授权你刚刚生成的账户，比如我想给刚刚生成的账户授权只能对部署进行操作：

```yaml
# new-user.yaml
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  namespace: example
  name: deployment-manager
rules:
- apiGroups: ["","extensions","apps"]
  resources: ["deployments", "replicasets", "pods"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: deployment-manager-binding
  namespace: example
subjects:
- kind: User
  name: xizhibei@example.com
  apiGroup: ""
roleRef:
  kind: ClusterRole
  name: admin
  apiGroup: ""
```

然后 `kubectl create -f ./new-user.yaml`（注意，你得使用管理员账户，而不是刚刚生成的用户账户）。

接下来，这个用户就能进行操作了，使用 `kubectl get pods -n example --kubeconfig /root/k8s-xizhibei.conf`，你就能看到 pods 的列表了。

### P.S.
似乎又写了一篇水文，通篇还是以介绍与总结为主，没有具体的思考内容在里面。但是回顾起来，你会发现这对于我们设计管理后台的权限还是挺有启发的。比如目前管理后台中有订单，用户以及付费记录三种资源，那么对于管理员账户来说，我们就可以设计如下的 RBAC 模型：

```
Account:
	- name, type: string
	- roles, type: [string] # 这里就相当于 rolebinding 了

Role:
	- name
	- rules
	  - name, type: string
	  - verbs, type: [string]
	  - resources, type: [string]

Resource: enum(order, user, payment)

Verb: enum(get, list, update, create, delete, deleteCollection)

对应的其中一条完整记录：

Account:
	- xizibei
	- ['edit', 'view']

Role:
	- 'view'
	- ['get', 'list']
	- ['order', 'user', 'payment']
```

### Ref
- https://en.wikipedia.org/wiki/Role-based_access_control
- https://kubernetes.io/docs/admin/authorization/rbac/
- https://docs.bitnami.com/kubernetes/how-to/configure-rbac-in-your-kubernetes-cluster/



***
原链接: https://github.com/xizhibei/blog/issues/64

![知识共享许可协议](https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png "署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）")

本文采用 [署名 - 非商业性使用 - 相同方式共享（BY-NC-SA）](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh) 进行许可。

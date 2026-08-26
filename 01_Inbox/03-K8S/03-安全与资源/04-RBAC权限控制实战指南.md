# K8s RBAC 权限控制实战指南

## 1. RBAC 概述

RBAC（Role-Based Access Control，基于角色的访问控制）是 Kubernetes 中控制用户对集群资源操作权限的核心安全机制。

### 四个核心对象

| 对象 | 作用域 | 说明 |
|------|--------|------|
| **Role** | 命名空间级别 | 定义命名空间内的权限集合 |
| **ClusterRole** | 集群级别 | 定义跨命名空间或集群级资源的权限集合 |
| **RoleBinding** | 命名空间级别 | 将 Role/ClusterRole 绑定到用户/组/ServiceAccount |
| **ClusterRoleBinding** | 集群级别 | 将 ClusterRole 绑定到用户/组/ServiceAccount（全集群生效） |

---

## 2. RBAC 工作原理

```
用户/ServiceAccount
      ↓
   RoleBinding / ClusterRoleBinding
      ↓
   Role / ClusterRole
      ↓
   对资源的操作权限 (verbs: get, list, watch, create, update, delete...)
```

---

## 3. 核心配置示例

### 3.1 创建 Role（命名空间级别）

```yaml
# 允许在 default 命名空间内读取 Pod
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default
  name: pod-reader
rules:
- apiGroups: [""]       # "" 表示核心 API 组
  resources: ["pods"]
  verbs: ["get", "watch", "list"]
```

### 3.2 创建 ClusterRole（集群级别）

```yaml
# 允许读取集群中所有命名空间的 Pod
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-pod-reader
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "watch", "list"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch"]
```

### 3.3 RoleBinding（绑定到用户）

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods-binding
  namespace: default
subjects:
- kind: User
  name: jane          # 用户名
  apiGroup: rbac.authorization.k8s.io
- kind: ServiceAccount
  name: my-sa
  namespace: default
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

### 3.4 ClusterRoleBinding（集群级别绑定）

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: read-pods-global
subjects:
- kind: Group
  name: developers    # 用户组
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-pod-reader
  apiGroup: rbac.authorization.k8s.io
```

---

## 4. ServiceAccount 与 RBAC

在 Pod 中访问 Kubernetes API 时，需要使用 ServiceAccount：

```bash
# 创建 ServiceAccount
kubectl create serviceaccount my-app-sa -n production

# 绑定角色
kubectl create rolebinding my-app-binding \
  --clusterrole=view \
  --serviceaccount=production:my-app-sa \
  --namespace=production
```

在 Pod 中引用 ServiceAccount：
```yaml
spec:
  serviceAccountName: my-app-sa
```

---

## 5. 常用 verbs 说明

| Verb | HTTP 方法 | 说明 |
|------|-----------|------|
| get | GET | 获取单个资源 |
| list | GET | 列出资源列表 |
| watch | GET + watch | 监听资源变化 |
| create | POST | 创建资源 |
| update | PUT | 全量更新资源 |
| patch | PATCH | 局部更新资源 |
| delete | DELETE | 删除资源 |
| deletecollection | DELETE | 删除资源集合 |

---

## 6. 权限检查命令

```bash
# 检查用户是否有权限执行某操作
kubectl auth can-i get pods --as jane -n default
kubectl auth can-i create deployments --as jane --namespace production

# 列出某用户的所有权限
kubectl auth can-i --list --as jane -n default

# 查看当前用户权限
kubectl auth can-i --list
```

---

## 7. 典型应用场景

| 场景 | 方案 |
|------|------|
| 开发人员只读某命名空间 | Role(view) + RoleBinding |
| 运维人员全集群管理 | ClusterRole(admin) + ClusterRoleBinding |
| CI/CD 机器人部署权限 | ServiceAccount + ClusterRole(deploy) |
| 监控组件读取集群状态 | ClusterRole(view) + ClusterRoleBinding |

---

## 8. 相关参考

- [安全认证与准入控制](./02-安全认证与准入控制.md)
- [集群资源](./01-集群资源.md)

---

> [!TIP] 💡 关联技术与延伸阅读
>
> * [安全认证与鉴权全景](./02-安全认证与准入控制.md)
> * [安全与权限核心考点梳理](../08-应用与实战/01-高级K8s工程师面试全景复习计划与冲刺指南.md)

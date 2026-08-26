# 🏛️ StatefulSet (有状态负载) 编排原理与核心机制

在 Kubernetes 中，像 Nginx, Tomcat 这种可以随时被替代、重启后 IP 变化不影响整体服务、不依赖本地存储状态的程序被称为**无状态服务（Stateless）**。
然而，像 MySQL 主从集群、Redis 集群、Kafka 等，每个实例之间存在不对等关系（如 Master-Slave），或者每个实例必须绑定专属的持久化数据，这类应用被称为**有状态服务（Stateful）**。为了编排此类服务，Kubernetes 引入了 `StatefulSet` 控制器。

---

## 一、 有状态服务与无状态服务的本质区别

| 特征维度 | 无状态服务 (Deployment) | 有状态服务 (StatefulSet) |
| :--- | :--- | :--- |
| **实例对等性** | 所有 Pod 完全对等，像流水线上的商品，名字是随机 Hash。 | 每个 Pod 都有固定的序号标识（从 0 到 N-1），彼此不对等。 |
| **网络标识稳定性**| Pod 漂移或重启后，IP 和主机名完全随机变化，通过 Service 统一暴露。 | Pod 重启后，其 Hostname 与 DNS 域名完全不变，保持稳定的网络身份。 |
| **数据卷挂载** | 多个 Pod 副本一般挂载同一个共享存储卷，数据实时同步共享。 | 每个 Pod 拥有自己专属的持久化卷（PVC），Pod 漂移后自动重新绑定。 |
| **部署与下线顺序**| 副本并行拉起或销毁，无任何顺序要求。 | 严格按照序号顺序递增创建（0 到 N-1），递减销毁（N-1 到 0）。 |

---

## 二、 StatefulSet 的三大核心要素

StatefulSet 控制器是通过整合以下三大核心组件来实现其特性的：

```text
┌────────────────────────────────────────────────────────┐
│                      StatefulSet                       │
└─────┬───────────────────┬───────────────────┬──────────┘
      │                   │                   │
      ▼                   ▼                   ▼
┌──────────────┐    ┌──────────────┐    ┌─────────────────────┐
│ 1. Headless  │    │ 2. Ordinal   │    │ 3. volumeClaim      │
│    Service   │    │    Indexing  │    │    Templates        │
│(稳定网络域名)│    │ (0 到 N-1)   │    │ (自动创建专属 PVC)  │
└──────────────┘    └──────────────┘    └─────────────────────┘
```

1.  **Headless Service (无头服务)**：
    *   **定义**：一个没有配置 ClusterIP (`clusterIP: None`) 的 Service。
    *   **作用**：不会为该 Service 分配虚拟 IP，而是通过 DNS 直接解析出后端所有绑定的有状态 Pod 的具体 IP。它为每个 Pod 生成一条固定的、可解析的二级域名。
2.  **Ordinal Indexing (序号机制)**：
    *   StatefulSet 会对它管理的 Pod 进行从 `0` 到 `N-1` 的硬性编号。Pod 的名字格式固定为：`$(StatefulSet名称)-$(序号)`。这个名字在 Pod 重启或迁移节点后绝对保持不变。
---

### 💡 架构关键辨析：为什么普通 Service 无法用于 StatefulSet？为什么必须配 Headless Service (`clusterIP: None`)？

> **核心结论**：普通 Service 是“随机抽查的前台总机”，而 Headless Service 是“按工号精准直连的内部专线”。分布式有状态数据库需要建立节点间的固定拓扑，必须使用 Headless Service！

#### 1. 现实物理比喻：前台总机 vs 工号内线
* **普通 Service (VIP 随机负载)**：类似于公司 400 客服总机。客户打进来，系统随机分发给任意一个客服。对于无状态 Nginx 副本完全没问题。
* **Headless Service (DNS 直连专线)**：类似于直接拨打“1 号窗口主库 (`mysql-0`)”或“2 号窗口从库 (`mysql-1`)”的直拨内线。MySQL 从库必须精准向 `mysql-0` 发起 Binlog 主从复制，**绝不能随机打给另一个从库！**

#### 2. 3 大核心设计决策

1. **禁用 `kube-proxy` 负载均衡 (VIP)**：
   设置 `clusterIP: None` 后，`kube-proxy` 不会为该 Service 在宿主机上创建任何 iptables / IPVS 负载均衡规则。
2. **DNS A 记录直返真实 IP 列表**：
   当应用查询普通 Service 时，DNS 只返回一个虚拟 ClusterIP；而查询 Headless Service 时，CoreDNS 会**直接返回其后端挂载的所有有状态 Pod 的真实 IP 数组列表**。
3. **固定的 Pod 级二级域名 (FQDN)**：
   CoreDNS 会为每个 Pod 自动注入独立的 DNS A 记录：
   `$(pod-name).$(service-name).$(namespace).svc.cluster.local`
   例如：`redis-0.redis-hs.default.svc.cluster.local`。即便 `redis-0` 挂掉重新调度到了新的 Node 获得了全新的 Pod IP，**该 DNS 域名依然 100% 保持不变**，其他节点可以通过该域名瞬间重新连上它！

---

## 三、 本章子导览目录

*   📖 [StatefulSet 拓扑状态与存储状态维护](./04-StatefulSet/基础.md)

```yaml
spec:
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      partition: 2              # 仅更新索引 >= 2 的 Pod
```
* **效果**：即使修改了 Pod 镜像版本，只有索引大于等于 2 的 Pod（如 `web-2`）会被滚动更新，`web-0` 和 `web-1` 继续保持旧版本运行。确认稳定后将 `partition` 调为 0，完成全量升级。

---

> [!TIP] 💡 关联技术与延伸阅读
>
> * [持久化存储 PV/PVC/StorageClass 详解](../05-集群存储/01-存储基础与持久化.md)
> * [Headless Service 与 DNS 域名解析](../04-集群网络/08-CoreDNS底层架构与服务发现技术深度指南.md)

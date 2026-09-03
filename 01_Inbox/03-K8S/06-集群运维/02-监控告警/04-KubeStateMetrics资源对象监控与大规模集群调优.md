# kube-state-metrics 资源对象监控与大规模集群调优

## 一、 核心工作原理与 Informer 架构

**kube-state-metrics (KSM)** 是 Kubernetes 原生可观测体系中不可或缺的基石。与 node_exporter（关注硬件物理）和 cAdvisor（关注容器物理资源）不同，KSM 并不衡量 CPU/内存消耗，而是充当 **Kubernetes 声明式对象状态（Declarative State）的翻译官**。

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        Kubernetes API Server (etcd)                    │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ List & Watch 长连接长轮询
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                      kube-state-metrics 内部架构                        │
│                                                                        │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │               client-go SharedInformer 框架                     │   │
│   │  - Reflector: 监听 Pod, Node, Deployment, PVC 等对象变更       │   │
│   │  - DeltaFIFO: 增量事件队列                                     │   │
│   │  - Indexer (Cache): 在内存维护全量资源对象的本地状态镜像       │   │
│   └───────────────────────────────┬────────────────────────────────┘   │
│                                   │ 动态渲染                               │
│                                   ▼                                    │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │                 Prometheus 格式指标生成生成器                   │   │
│   │  - 暴露端点：:8080/metrics (业务状态指标)                     │   │
│   │  - 暴露端点：:8081/metrics (KSM 自身遥测性能指标)              │   │
│   └────────────────────────────────────────────────────────────────┘   │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Prometheus Scrape
                                    ▼
```

1. **零 etcd 直接读取**：KSM 绝不直接连接 etcd，而是通过客户端标准 `SharedInformer` 机制建立与 kube-apiserver 的长连接，大幅减轻 API 控制面负载。
2. **纯内存状态字典**：当 Prometheus 访问 `:8080/metrics` 时，KSM 只是将内存中已同步好的对象属性即时格式化为 Prometheus 文本协议输出，无磁盘 IO 瓶颈。

---

## 二、 生产必备指标库与告警规则映射

### 1. Pod 异常退出的“死亡原因”捕获

在故障排查中，普通监控只能看到 Pod 重启了，但无法得知原因。KSM 提供了精准的根因标签：

- **容器因内存溢出死亡（OOMKilled 捕获）**：
  ```promql
  kube_pod_container_status_last_terminated_reason{reason="OOMKilled"} == 1
  ```
- **Pod 镜像拉取失败（ImagePullBackOff 预警）**：
  ```promql
  kube_pod_container_status_waiting_reason{reason=~"ImagePullBackOff|ErrImagePull"} == 1
  ```
- **Pod 崩溃循环（CrashLoopBackOff 探测）**：
  ```promql
  kube_pod_container_status_waiting_reason{reason="CrashLoopBackOff"} == 1
  ```

### 2. 工作负载健康度与副本偏差

- **Deployment 副本实际存活数低于预期（副本漂移）**：
  ```promql
  (kube_deployment_spec_replicas - kube_deployment_status_replicas_available) > 0
  ```
- **DaemonSet 未调度就绪节点数**：
  ```promql
  kube_daemonset_status_number_unavailable > 0
  ```
- **StatefulSet 未就绪副本数**：
  ```promql
  (kube_statefulset_status_replicas - kube_statefulset_status_replicas_ready) > 0
  ```

### 3. 集群节点与持久化存储（PVC）

- **节点发生网络脱管或 Kubelet 停止响应（NotReady 判定）**：
  ```promql
  kube_node_status_condition{condition="Ready", status="true"} == 0
  ```
- **PVC 处于未绑定（Pending / Lost）挂起状态**：
  ```promql
  kube_persistentvolumeclaim_status_phase{phase!="Bound"} == 1
  ```

---

## 三、 大规模集群生产调优实战（防 OOM 与降时序）

在千级节点或数万 Pod 的大规模生产环境中，KSM 默认抓取所有对象和全部 Label 会导致自身内存飙涨至数十 GB。必须采取以下调优策略：

### 1. 精确裁剪资源白名单 (`--resources`)

很多集群不需要监控 `certificatesigningrequests`、`leases` 或 `mutatingwebhookconfigurations`。只保留核心资源：

```bash
--resources=daemonsets,deployments,endpoints,horizontalpodautoscalers,ingresses,jobs,cronjobs,namespaces,nodes,persistentvolumeclaims,persistentvolumes,pods,replicasets,services,statefulsets
```

### 2. 标签白名单限制 (`--metric-labels-allowlist`)

开发者常在 Pod 上打随机版本号、Git Commit Hash 或发布时间戳等高基数标签。如果不加限制，Prometheus 时序库将迅速崩溃：

```bash
# 仅允许透传关键业务标签，阻断临时哈希污染
--metric-labels-allowlist=pods=[app,release,tier,environment],deployments=[app,release]
```

### 3. 水平分片（Horizontal Sharding 解决千节点集群瓶颈）

对于超过 1,000 节点的大型集群，KSM 官方推荐采用 **StatefulSet 水平分片** 部署，将不同 Hash 环的资源分散到不同 Pod 处理：

```yaml
# Pod 0 启动参数：
- --shard=0
- --total-shards=2

# Pod 1 启动参数：
- --shard=1
- --total-shards=2
```

---

> [!TIP] 💡 关联技术与延伸阅读
>
> * [Prometheus 与 Alertmanager 企业级架构设计与生产落地](./01-Prometheus与Alertmanager架构设计与生产落地.md)
> * [cAdvisor 容器运行时指标全景与双轨采集对比](./03-cAdvisor容器运行时指标全景与双轨采集对比.md)
> * [MetricsServer 安装与 x509 证书排障](../02-MetricsServer安装与x509证书排障.md)
> * [kube-state-metrics 生产部署清单 (YAML)](../../../../05-Install/monitoring/06-kube-state-metrics.yaml)

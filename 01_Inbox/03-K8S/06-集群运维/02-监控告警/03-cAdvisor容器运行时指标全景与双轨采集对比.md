# cAdvisor 容器运行时指标全景与双轨采集对比

## 一、 核心定位与技术工作原理

**cAdvisor (Container Advisor)** 是 Google 开源的容器资源分析与性能监控工具。它不依赖容器内安装任何 Agent，而是直接运行在宿主机上，通过挂载和读取 Linux 内核的 **cgroup（Control Groups）** 层级树与虚拟文件系统（`/sys/fs/cgroup`），实时解构每个容器的 CPU、内存、文件系统以及网络使用情况。

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        Linux Kernel & Cgroups                          │
│                                                                        │
│   cgroup v1: /sys/fs/cgroup/{cpu,memory,blkio,pids}/kubepods/...       │
│   cgroup v2: /sys/fs/cgroup/kubepods.slice/... (Unified Hierarchy)     │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ 自动探测 cgroup 统计接口
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│               【双轨采集方案对比 (Dual-Track Architecture)】            │
│                                                                        │
│   【方案 A：Kubelet 内嵌 cAdvisor】    │   【方案 B：独立 cAdvisor DaemonSet】 │
│   - 原生集成在 Kubelet 进程内           │   - 以 DaemonSet 独立运行在节点上    │
│   - 访问入口：https://<NodeIP>:10250/   │   - 访问入口：http://<NodeIP>:8080/  │
│     metrics/cadvisor                   │     metrics                          │
│   - 权限：依赖 Bearer Token 与 RBAC    │   - 权限：无需 RBAC，直接挂载 host    │
│   - 资源：零额外 Pod 调度开销          │   - 资源：每节点需消耗 150m CPU /    │
│   - 【推荐】：官方生产推荐标准        │           200Mi 内存                 │
└───────────────────────────────────┴────────────────────────────────────┘
```

---

## 二、 双轨采集模式深度对比与选型决策树

| 评估维度 | 方案 A：Kubelet 内嵌 cAdvisor (主流) | 方案 B：独立 cAdvisor DaemonSet (备选) |
| :--- | :--- | :--- |
| **部署形态** | 无需额外部署，Kubelet 随节点自启 | 需部署 DaemonSet（`07-cadvisor-daemonset.yaml`） |
| **安全与认证** | 强制走 Kubelet 10250 端口，需 K8S RBAC ServiceAccount Token 认证及 TLS 加密 | 默认走明文 HTTP 8080/8088 端口，通常无鉴权（需通过 NetworkPolicy 隔离） |
| **Kubelet 负载** | Prometheus 高频或并发抓取时，可能增加 Kubelet 主进程 CPU 开销与垃圾回收 | 物理隔离，高频采样（如 5s/次）绝不影响 Kubelet 节点核心控制循环 |
| **适用场景** | **95% 以上的标准 Kubernetes 生产集群首选** | 1. 边缘节点或无 Kubelet 的纯 Docker / containerd 宿主机；<br>2. 银行/军工等严格禁止给 Prometheus 授予 Node Proxy 权限的环境；<br>3. 需开启 cAdvisor 深度 Profiling 特性的定制化场景。 |

---

## 三、 Cgroups v1 与 v2（containerd 1.6+ / 2.0+）适配红线

随着 Linux 内核发展与 Kubernetes v1.25+ 正式将 **cgroup v2** 列入 GA，容器运行时（containerd、CRI-O）的指标采集路径发生了重大变化：

### 1. 核心环境要求
- **cAdvisor 版本**：必须使用 **v0.43.0+**（推荐 v0.49.x），旧版本因沿用 cgroup v1 绝对路径会在内核 5.8+ 的 cgroup v2 环境下静默失效，导致指标全部为 0。
- **Containerd 驱动配置**：`/etc/containerd/config.toml` 中必须确保配置使用 `SystemdCgroup = true`：
  ```toml
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    SystemdCgroup = true
  ```
- **挂载点规范**：在 cgroup v2 下，独立 DaemonSet 挂载必须采用只读挂载统一层级：
  ```yaml
  volumeMounts:
    - name: cgroup
      mountPath: /sys/fs/cgroup
      readOnly: true
  ```

---

## 四、 核心指标深度解构：WorkingSet vs Usage 终极辨析

在配置 Pod 内存告警与 HPA 扩缩容时，**选择错误的内存指标会导致严重的“假警报”或“容器被杀却未告警”**：

### 1. 为什么 OOM 预警必须使用 `working_set_bytes`？

Linux 内存模型中包含：`Total Memory = RSS (进程匿名页) + Cache (页缓存) + Swap`。

```text
┌────────────────────────────────────────────────────────────────────────┐
│                  container_memory_usage_bytes (总内存)                  │
│  ┌─────────────────────────────────┬─────────────────────────────────┐  │
│  │    RSS (匿名页，不可回收)        │     PageCache (文件缓存页)      │  │
│  │                                 ├────────────────┬────────────────┤  │
│  │  - Java 堆内存                   │ Inactive File  │  Active File   │  │
│  │  - Go/C++ 内存空间              │ (随时可释放)   │ (近期被访问)   │  │
│  └─────────────────────────────────┴────────────────┴────────────────┘  │
│                                                     ▲                    │
│                                                     │ 扣除可回收页       │
│  ┌──────────────────────────────────────────────────┴────────────────┐  │
│  │           container_memory_working_set_bytes (工作集内存)          │  │
│  │    = usage_bytes - total_inactive_file (K8s OOM 裁决核心指标)     │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

- **`container_memory_usage_bytes`**：包含了所有的文件 PageCache。在大量读取磁盘（如 Elasticsearch、MySQL、日志处理）的容器中，该指标几乎永远接近 100%，**但只要内存紧张，内核会无损丢弃 Inactive PageCache，绝不会触发 OOM**。
- **`container_memory_working_set_bytes`**：剔除了容易回收的 `inactive_file` 页面，反映了**容器无法被回收的刚性内存需求**。
- **SRE 判定红线**：Kubernetes Kubelet Eviction 驱逐机制与内核 OOM Killer 杀死容器的依据**完全基于 Working Set**！

### 2. 容器黄金 PromQL 计算公式

- **Pod 内存使用率 (%)（真实防 OOM 指标）**：
  ```promql
  sum(container_memory_working_set_bytes{container!=""}) by (namespace, pod)
  /
  sum(kube_pod_container_resource_limits{resource="memory"}) by (namespace, pod) * 100
  ```
- **Pod CPU 瞬时使用核心数 (Cores)**：
  ```promql
  sum(rate(container_cpu_usage_seconds_total{container!=""}[5m])) by (namespace, pod)
  ```
- **CPU 限流惩罚占比 (Throttling Ratio %)**（超过 20% 说明即使 CPU 没跑满，由于 CFS 配额周期也被强制限频，引发应用响应毛刺）：
  ```promql
  sum(increase(container_cpu_cfs_throttled_periods_total[5m])) by (namespace, pod)
  /
  sum(increase(container_cpu_cfs_periods_total[5m])) by (namespace, pod) * 100
  ```

---

## 五、 生产环境高基数过滤（Metric Relabeling 优化）

cAdvisor 默认会为宿主机上每一个 systemd slice、非容器 cgroup 路径生成指标。在几百个 Pod 的集群中，这些无名指标占据了 60% 以上的无用时序。在 `prometheus.yml` 中必须配置清洗：

```yaml
metric_relabel_configs:
  # 丢弃无容器名称的临时控制组与父级 Slice
  - source_labels: [container]
    regex: '^$'
    action: drop
  # 丢弃无 ID 的残留孤儿序列
  - source_labels: [id]
    regex: '^$'
    action: drop
  # 丢弃极高基数且冷门的网络指标
  - source_labels: [__name__]
    regex: 'container_(network_tcp_usage_total|network_udp_usage_total|tasks_state)'
    action: drop
```

---

> [!TIP] 💡 关联技术与延伸阅读
>
> * [kube-state-metrics 资源对象监控与大规模集群调优](./04-KubeStateMetrics资源对象监控与大规模集群调优.md)
> * [NodeExporter 宿主机全方位监控与指标基线](./02-NodeExporter宿主机全方位监控与指标基线.md)
> * [生产级 cAdvisor 独立 DaemonSet 清单](../../../../05-Install/monitoring/07-cadvisor-daemonset.yaml)
> * [万级节点与十万级 Pod 大规模集群调优指南](../07-万级节点与十万级Pod大规模集群调优指南.md)

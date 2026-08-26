# 📈 kube-state-metrics 配置与监控架构指南

在构建 Kubernetes 生产级监控系统（Prometheus + Grafana）时，**kube-state-metrics (KSM)** 是不可或缺的基石组件。它专注于抓取 Kubernetes 各种资源对象的**状态元数据**，并将其转换为 Prometheus 兼容的指标格式。本文将详细解析 KSM 的工作原理、部署清单及监控集成配置。

---

## 一、 KSM 与 Metrics Server 的深层对比

虽然两者都与“指标 (Metrics)”相关，但其工作定位、技术实现和应用场景截然不同：

| 特性维度 | Metrics Server (核心指标管道) | kube-state-metrics (资源对象状态指标) |
| :--- | :--- | :--- |
| **主要定位** | 监控节点与 Pod 的**瞬时物理资源消耗**（CPU/Memory）。 | 监控 Kubernetes **声明式资源对象的状态与属性**。 |
| **数据源** | 定期轮询各节点 Kubelet / cAdvisor 的 API。 | 通过 Informer 监听 K8S API Server，读取 etcd 中对象的实时定义。 |
| **数据存储** | 缓存在内存中，仅保留最新的单点数值（无历史时序）。 | 不保存历史数据，仅在 `/metrics` 端口暴露实时状态，由 Prometheus 抓取。 |
| **主要用途** | 供给 HPA 自动扩缩容，以及 `kubectl top` 命令行查询。 | 供给 Prometheus 存储时序数据，通过 Grafana 画布绘制资源大图并触发告警。 |
| **指标示例** | `pod_cpu_usage_seconds_total` (Pod CPU 消耗量) | `kube_pod_status_phase{phase="Failed"}` (Pod 失败状态计数)<br>`kube_deployment_spec_paused` (Deployment 暂停状态) |

---

## 二、 kube-state-metrics 工作架构

KSM 并不是从容器或节点内部抓取 CPU/内存使用率，而是充当 **Kubernetes 资源声明状态的“翻译官”**：

```text
┌────────────────┐          Informer 监听变化         ┌──────────────────────┐
│   API Server   │ ────────────────────────────────> │  kube-state-metrics  │
└───────▲────────┘                                   └──────────┬───────────┘
        │                                                       │
        │ 读写配置                                               │ 暴露 /metrics 接口
        │                                                       ▼
┌───────┴────────┐                                   ┌──────────────────────┐
│  Kubectl / Crd │                                   │  Prometheus Server   │
└────────────────┘                                   └──────────────────────┘
```

1. **API 监听 (Informer)**：KSM 内部使用 Kubernetes client-go 库的 Informer 机制，同 API Server 建立长连接，实时接收 Namespace, Node, Pod, Deployment, DaemonSet, StatefulSet, Job, CronJob, PVC 等几乎所有核心资源对象的生命周期变更。
2. **状态内存映射**：KSM 在内存中维护一份这些资源对象最新状态的映射表。
3. **指标转换与暴露**：当访问 KSM 的默认端口（`8080`/`8081`）下的 `/metrics` 路径时，KSM 会动态将内存中的资源状态数据拼接成标准的 Prometheus 文本协议并返回，以供 Prometheus 进行拉取（Scrape）。

---

## 三、 快速部署 Kubernetes v1.25+ 兼容的 KSM (v2.3.0+)

我们可以通过官方的单文件清单或拆解配置进行部署。以下是核心 Deployment 与 Service 的 YAML 配置段：

### 1. 部署资源清单 (ksm-deployment.yaml)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kube-state-metrics
  namespace: kube-system
  labels:
    app.kubernetes.io/name: kube-state-metrics
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: kube-state-metrics
  template:
    metadata:
      labels:
        app.kubernetes.io/name: kube-state-metrics
    spec:
      serviceAccountName: kube-state-metrics # 需要绑定具有集群级只读权限的 ServiceAccount
      containers:
      - name: kube-state-metrics
        image: registry.cn-hangzhou.aliyuncs.com/google_containers/kube-state-metrics:v2.3.0 # 国内高速源
        ports:
        - name: http-metrics
          containerPort: 8080   # 暴露资源状态指标端口
        - name: telemetry
          containerPort: 8081   # 暴露 KSM 自身的运行健康指标
        resources:
          limits:
            cpu: 250m
            memory: 512Mi
          requests:
            cpu: 50m
            memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: kube-state-metrics
  namespace: kube-system
  labels:
    app.kubernetes.io/name: kube-state-metrics
spec:
  ports:
  - name: http-metrics
    port: 8080
    targetPort: http-metrics
  - name: telemetry
    port: 8081
    targetPort: telemetry
  selector:
    app.kubernetes.io/name: kube-state-metrics
```

*(注意：KSM 还需要配合一套 ClusterRole 及 ClusterRoleBinding，声明对集群中所有 Pod, Node, Deployment 等资源的 `list` 与 `watch` 权限，详细配置可拉取官方 Github 的 rbac 定义文件。)*

---

## 四、 Prometheus 抓取对接配置

### 1. Prometheus 静态抓取配置 (prometheus.yml)
如果您使用的是传统静态配置部署的 Prometheus，在 `prometheus.yml` 中追加以下抓取作业（Job）：

```yaml
scrape_configs:
  - job_name: 'kube-state-metrics'
    static_configs:
      - targets: ['kube-state-metrics.kube-system.svc.cluster.local:8080']
```

### 2. Prometheus Operator 动态抓取配置 (ServiceMonitor)
如果您使用的是云原生 Prometheus Operator (Kube-Prometheus-Stack)，应创建一个 `ServiceMonitor` 自定义资源，使得 Prometheus 控制器自动生成抓取配置：

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: kube-state-metrics
  namespace: kube-system
  labels:
    release: prometheus # 必须与 Prometheus 实例关联的 Label 保持一致
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: kube-state-metrics
  endpoints:
  - port: http-metrics
    interval: 30s
    honorLabels: true   # 保留指标本来的标签，避免被 Prometheus 重写冲突
```

---

## 五、 常用运维核心监控指标

KSM 暴露的指标数量非常庞大，在生产运维中，以下几个核心指标经常被用来编写 Grafana 仪表盘和报警规则：

### 1. Pod 运行状态报警
* **指标**：`kube_pod_status_phase{phase="Failed"}` / `kube_pod_status_phase{phase="Pending"}`
* **用途**：判断集群内是否有 Pod 处于 Fail（如 OOM 被杀、启动崩溃）或 Pending（资源不足调度卡住）状态。

### 2. Deployment 副本未就绪
* **指标**：`kube_deployment_status_replicas_unavailable`
* **公式**：`kube_deployment_status_replicas_unavailable > 0`
* **用途**：当 Deployment 中不可用的副本数大于 0 时，说明滚动更新过程中有副本崩溃，需立即告警。

### 3. PVC 绑定状态监控
* **指标**：`kube_persistentvolumeclaim_status_phase{phase="Pending"}`
* **用途**：用于发现由于 StorageClass 自动配置失败导致 PVC 一直处于待绑定（Pending）状态的故障。

---

> [!TIP] 💡 关联技术与延伸阅读
>
> * [Prometheus 完整监控体系架构](./08-云原生可观测性架构Prometheus_Thanos_Tempo与eBPF链路追踪.md)
> * [Metrics Server vs kube-state-metrics 监控定位对比](../01-组件原理/09-Metrics_Server与API聚合层原理.md)

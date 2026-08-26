# 🎯 Pod 节点亲和性、污点、容忍度与调度属性

在 Kubernetes 中，将工作负载合理分发到不同的物理或虚拟节点上，是设计高可用、隔离性好的分布式集群的基础。虽然调度决策由 `kube-scheduler` 做出，但调度参数完全在 Pod 的 Spec 字段中声明。本章将深度剖析 Pod 的五大调度机制与 YAML 实战。

---

## 一、 静态与基础调度

### 1. nodeName (强行绑定)
*   **机制**：直接指定节点名称。设置后，该 Pod 会**完全绕过 kube-scheduler**，直接由目标节点上的 Kubelet 接管启动。
*   **应用场景**：常用于特定运维脚本、指定单节点调试。
*   **YAML**：
    ```yaml
    spec:
      nodeName: k8s-node-01
    ```

### 2. nodeSelector (基础标签选择器)
*   **机制**：键值对匹配。只有拥有对应 Label 的节点才会被调度。如果节点不存在或标签不匹配，Pod 将处于 `Pending` 状态。
*   **YAML**：
    ```yaml
    spec:
      nodeSelector:
        disktype: ssd # 仅调度到打上了 disktype=ssd 标签的 Node
    ```

---

## 二、 节点亲和性 (Node Affinity)

Node Affinity 是对 `nodeSelector` 的高阶扩展，支持更复杂的逻辑匹配（如 In, NotIn, Exists, DoesNotExist, Gt, Lt）并区分为“硬亲和”与“软亲和”。

```text
                  ┌──────────────────────────────────────────┐
                  │              Node Affinity               │
                  └────────────┬────────────────────┬────────┘
                               │                    │
                               ▼                    ▼
                 ┌────────────────────────┐  ┌────────────────────────┐
                 │ 1. 硬亲和 (Required)   │  │ 2. 软亲和 (Preferred)  │
                 │ - 必须满足，否则 Pending│  │ - 优先满足，带权重 (1-100)│
                 └────────────────────────┘  └────────────────────────┘
```

### YAML 配置示例：
```yaml
spec:
  affinity:
    nodeAffinity:
      # 1. 硬亲和：必须运行在属于华东区且非 CPU 隔离节点的 Node 上
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: topology.kubernetes.io/zone
            operator: In
            values:
            - cn-hangzhou-a
            - cn-hangzhou-b
          - key: node-role.kubernetes.io/edge
            operator: NotIn
            values:
            - "true"
      # 2. 软亲和：尽量运行在 SSD 存储的节点上，权重设为 80 (权重越高优先级越高)
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 80
        preference:
          matchExpressions:
          - key: disktype
            operator: In
            values:
            - ssd
```

---

## 三、 Pod 亲和性与反亲和性 (Pod Affinity & Anti-Affinity)

与节点亲和性不同，Pod 亲和性解决的是**“Pod 与 Pod 之间的位置亲密关系”**（例如：把 Web Pod 和 Redis 缓存 Pod 调度在同一个机架/拓扑域，以降低网络延迟）。

### 1. 拓扑域 (TopologyKey)
在配置 Pod 亲和性时，必须指定 `topologyKey`（拓扑键）。Kubernetes 根据 Node 上的这个 Label 判定哪些 Node 属于同一个“域”。
*   `topologyKey: kubernetes.io/hostname`：每一个独立的 Node 就是一个拓扑域。
*   `topologyKey: topology.kubernetes.io/zone`：每一个可用区（Zone）是一个拓扑域。

### 2. Pod 反亲和性 (Pod Anti-Affinity)
> [!IMPORTANT]
> **生产高可用防灾保障**：为了防止一个物理节点或一个机房可用区宕机导致某个微服务的所有副本同时瘫痪，必须配置 Pod 反亲和性，强行将副本打散分发。

#### 生产高可用打散 YAML 示例：
```yaml
spec:
  affinity:
    # 强制将副本打散，不允许两个相同的 web-app Pod 调度在同一个物理 Node 上
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - web-app
        topologyKey: "kubernetes.io/hostname"
```

---

## 四、 污点与容忍度 (Taints & Tolerations)

亲和性是 Pod 倾向于选择哪些 Node；而**污点 (Taints) 则是 Node 主动排斥哪些 Pod**。

```text
Node (打上污点: key=value:effect) ────▶ 默认排斥所有 Pod
                                                │
                                    ┌───────────┴───────────┐
                                    ▼                       ▼
                            Pod (配置了 Tolerations)     普通 Pod (未配置)
                            [ 允许调度并运行在此节点 ]    [ 被无情排斥，无法调度 ]
```

### 1. 污点的影响效果 (Effect)
*   **`NoSchedule`**：如果 Pod 没有配置容忍度，绝对无法调度到该节点。但已运行在此节点上的 Pod 不会被驱逐。
*   **`PreferNoSchedule`**：软限制。尽量不调度，但若集群内无其他 Node 可用，调度器也可能被迫调度过去。
*   **`NoExecute`**：如果 Node 突然被打上此污点，**所有没有容忍度的 Pod 会被节点立刻驱逐杀死**。

### 2. 命令行操作污点
```bash
# 1. 给节点 node-01 打上污点，标明为专属 GPU 节点
kubectl taint nodes node-01 gpu-node=true:NoSchedule

# 2. 移除污点 (末尾加减号)
kubectl taint nodes node-01 gpu-node=true:NoSchedule-
```

### 3. Pod Spec 中配置容忍度 (Tolerations)
以下 Pod 可以正常调度到拥有 `gpu-node=true:NoSchedule` 污点的节点上：

```yaml
spec:
  containers:
  - name: deep-learning
    image: tensorflow/tensorflow:latest
  # 配置容忍度
  tolerations:
  - key: "gpu-node"
    operator: "Equal"
    value: "true"
    effect: "NoSchedule"
```
*   **注意**：如果不填 `value` 且 `operator` 设为 `Exists`，代表容忍这个 key 下的任何值：
    ```yaml
    tolerations:
    - key: "gpu-node"
      operator: "Exists"
      effect: "NoSchedule"
    ```

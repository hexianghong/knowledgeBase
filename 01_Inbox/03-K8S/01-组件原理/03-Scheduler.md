# ⏱️ kube-scheduler 架构设计与调度流程详解

`kube-scheduler` 是 Kubernetes 的核心组件之一，负责为新创建的未绑定节点的 Pod 选定一个最合适的 Node。

---

## 一、 调度器双循环架构设计

kube-scheduler 的高性能源于其内部两个相互独立的控制循环共同协作：**Informer 监控环 (Informer Path)** 与 **调度主循环环 (Scheduling Path)**。

```text
 etcd ──(Watch)──▶ Informer (Informer Path) 
                      │
                      ▼
               调度队列 PriorityQueue 
                      │
                      ▼ (Pop Pod)
               [ 调度主循环 (Scheduling Path) ]
                      │
                      ├─▶ 1. 过滤阶段 (Predicates / Filtering)
                      │
                      ├─▶ 2. 打分阶段 (Priorities / Scoring)
                      │
                      └─▶ 3. 乐观绑定阶段 (Assume / Bind) ──▶ 更新 Cache 并异步提交给 APIServer
```

### 1. 第一循环：Informer 环 (Informer Path)
*   **职责**：启动各类 Informer（Pod, Node, Service, PV 等）以长连接监听 etcd。
*   **动作**：一旦监听到新创建、且 `spec.nodeName` 为空的待调度 Pod，便将该 Pod 的 Key 推进内部的 **优先级调度队列 (PriorityQueue)**。
*   **缓存更新**：调度器在本地维护了一个高效只读的 **Scheduler Cache**，所有的节点数据均从 Cache 直接读取以提供微秒级的计算效率，而不直接查询 API Server。

> 💡 **关联链接**：想了解包含抢占、驱逐与亲和力的完整调度策略配置？请参阅 [调度策略(污点、亲和、驱逐、抢占).md](./03-Scheduler/调度策略(污点、亲和、驱逐、抢占).md)。

### 2. 第二循环：调度主循环 (Scheduling Path)
*   这是一个单线程的死循环，串行处理每一个待调度 Pod：
    1.  **出队 (Pop)**：从优先级队列头部取出优先级最高的一个 Pod。
    2.  **过滤 (Predicates / Filtering)**：并发执行一组过滤算法，筛选出可以运行该 Pod 的候选节点列表。
    3.  **打分 (Priorities / Scoring)**：并发执行一组打分算法，为每一个候选节点评分（0~10分）。
    4.  **选定节点**：选出得分最高的一个节点。若存在多个同分节点，则随机轮询（Round-robin）选择一个。

---

## 二、 乐观绑定 (Assume) 与并发无锁化设计

为了极大程度榨取吞吐性能，kube-scheduler 采用了两项关键的架构设计：

### 1. 乐观绑定机制 (Assume)
如果调度器在选定节点后，直接同步向 API Server 发起 Bind 请求（写 etcd 并阻塞等待网络 IO），整个调度管道会变得极其缓慢。
*   **Assume 阶段**：在选定节点后，调度器会优先更新本地的 **Scheduler Cache**（在 Cache 中，Pod 已经“假装”被绑定到了该节点并占用了对应的资源）。这一步纯内存操作，耗时极短。
*   **异步 Bind 阶段**：在 Assume 完成后，调度器立刻启动一个独立的 Goroutine 协程去异步地向 API Server 提交真正的 Bind HTTP 请求。而调度器主线程则可以立即去调度下一个 Pod。
*   **Admit 二次确证**：由于采用“乐观”绑定，节点上的 `kubelet` 在最终拉起 Pod 前，还会运行一个叫 **Admit** 的操作，重新计算一遍 `GeneralPredicates`（如资源是否冲突等）作为本地防线的二次确认，防止冲突。

### 2. 并发无锁化设计
*   在 **Filtering 阶段**，调度器会启动 16 个 Goroutine（可配），以**节点为粒度**并发计算所有节点的过滤规则。
*   在 **Scoring 阶段**，打分逻辑采用类似于 **MapReduce** 的并行计算，各协程并行得出单项分数，最后汇总乘以权重加权。
*   整个核心调度路径上不存在任何全局锁，避免了多核心竞争带来的锁损耗。

---

## 三、 调度阶段过滤与打分算法列表

调度器通过一系列插件式算法执行过滤与打分：

### 1. 过滤阶段 (Predicates / Filtering) 常用策略
*   **GeneralPredicates**：
    *   `PodFitsResources`：检查节点的 CPU、内存、Pod 容纳上限等资源是否够用（只计算 `requests` 字段）。
    *   `PodFitsHostPorts`：检查 Pod 申请的 `hostPort` 宿主机端口是否与节点上已被占用的端口冲突。
    *   `PodMatchNodeSelector`：检查 Pod 的 `nodeSelector` / `nodeAffinity` 是否与节点 Labels 匹配。
*   **卷冲突过滤**：
    *   `NoDiskConflict`：检查多个 Pod 挂载的持久卷是否有排他性冲突（如 AWS EBS 等块存储不支持多写）。
    *   `MaxPDVolumeCountPredicate`：检查挂载的磁盘数是否超过该节点允许的上限值。
    *   `VolumeBindingPredicate`：检查 Pod 的 PVC 能否与节点的存储拓扑匹配。
*   **污点与健康度**：
    *   `PodToleratesNodeTaints`：检查 Pod 是否有容忍该节点污点 (Taints) 的 Tolerations 规则。
    *   `NodeMemoryPressurePredicate`：检查节点内存压力，防止调度到内存耗尽的节点。

### 2. 打分阶段 (Priorities / Scoring) 常用策略
*   `LeastRequestedPriority`：**资源空闲优先**。选择 CPU/Memory 被申请最少的节点，算法偏向于将负载“打散”到各个节点。
*   `BalancedResourceAllocation`：**资源平衡优先**。偏向于选择 CPU 申请百分比和内存申请百分比最接近的节点，防止出现 CPU 耗尽而内存闲置的单向资源倾斜。
*   `ImageLocalityPriority`：**镜像就近优先**。如果节点上已经下载了 Pod 运行所需的大镜像，其得分就会拔高，能够显著降低 Pod 拉起耗时。
*   `InterPodAffinityPriority`：**Pod 亲和性打分**。倾向于将相关联的 Pod（如 Web 和 DB）调度到相同的拓扑节点上。

---

## 四、 优先级与抢占机制 (Priority & Preemption)

当集群资源不足导致一个高优先级的 Pod（称为“抢占者 Preemptor”）调度失败时，系统将触发**抢占逻辑**，而非直接搁置。

```text
调度队列 unschedulableQ (Pod 调度失败入队)
          │
          ▼ 触发抢占算法
模拟删除低优先级 Pod ──▶ 检查抢占者是否可通过过滤 ──▶ 确定“最佳牺牲者列表” (Victims)
                                                             │
                                                             ▼ 执行
更新抢占者 nominatedNodeName ──▶ 异步删除牺牲者 Pod ──▶ 重新排队 activeQ
```

### 1. 优先级定义 (PriorityClass)
用户需预先定义 `PriorityClass` 资源：
```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000000          # 优先级数值，越大代表越优先，最高不超过 10 亿 (1,000,000,000)
globalDefault: false
description: "核心业务高优 Pod 使用"
```
> [!NOTE]
> 10 亿以上的值（如系统关键组件）被 Kubernetes 保留用于自身组件的 System Pod，保证系统组件在任何情况下都不被普通应用抢占。

### 2. 抢占机制两队列设计
调度器内部使用两个队列进行队列调度控制：
*   `activeQ`：存储所有等待运行、准备进入下一个调度周期的 Pod。
*   `unschedulableQ`：存储调度失败的 Pod。

### 3. 抢占与模拟删除的具体步骤
1.  **判定抢占可行性**：如果抢占者的调度失败是由无法通过抢占解决的规则（如 `nodeSelector` / `nodeName` 不匹配）引起的，则直接跳过，不启动抢占。
2.  **内存副本模拟抢占**：复制一份本地 `Scheduler Cache` 内存副本，在此副本上针对每个节点，从优先级最低的 Pod 开始逐一模拟“删除”。
3.  **筛选最佳牺牲者 (Victims)**：每模拟删除一个，都计算抢占者能否在该节点上调度成功。最终在所有可以成功的节点结果里筛选出“代价最小”（删除 Pod 最少、优先级最低）的节点作为被抢占节点。
4.  **设置 nominatedNodeName**：
    *   调度器向 API Server 提交更新，将抢占者的 `spec.nominatedNodeName` 字段设置为被选中的被抢占 Node 的名称。
    *   调度器启动 Goroutine，异步调用 API 接口正式删除“牺牲者” Pod（执行优雅关机流程，有 30s 宽限期）。
5.  **重新入队 activeQ**：抢占者会被重新推回调度队列 `activeQ` 的头部。在新的调度周期到来时，调度器会再次评估它。在牺牲者彻底退出后，抢占者就可以正式调度并运行到该 Node 节点上。

### 4. 双重过滤保护机制 (Double Predicates)
为了保证安全，调度器在为任何 Pod 计算是否可以调度到某节点时，如果该节点有“潜在抢占者”（即存在 nominatedNodeName 字段为此 Node 名的 Pod），调度器会运行**两遍过滤算法**：
1.  **第一遍**：假设“潜在抢占者”已经运行在此节点上，计算当前 Pod 能否在此节点运行（防止与高优先级 Pod 发生反亲和性冲突）。
2.  **第二遍**：正常计算，不考虑抢占者（因为抢占者最终不一定会跑在这个节点上）。
只有两次过滤均成功通过，当前 Pod 才能绑定到该节点。

---

## 五、 Scheduling Framework 11 个扩展插件点与得分公式 (参考源: K8s 官方 Docs & Source Code)

### 1. Scheduling Framework 11 个扩展点
K8s 1.19+ 将调度器重构为高度模块化的插件框架，每个 Pod 经过调度链条时触发 11 个 Plugin 扩展点：

```text
[ PreFilter ] ──▶ [ Filter ] ──▶ [ PostFilter ] ──▶ [ PreScore ] ──▶ [ Score ] ──▶ [ Reserve ] ──▶ [ Permit ] ──▶ [ PreBind ] ──▶ [ Bind ] ──▶ [ PostBind ]
```

* **关键扩展点职责**：
  1. `PreFilter`：预处理 Pod 数据（如预计算 Pod 拓扑需求）。
  2. `Filter`：过滤非法 Node（等价于原 Predicates）。
  3. `PostFilter`：当找不到合规节点时触发（抢占机制 Preemption 在此阶段执行）。
  4. `PreScore`：执行打分前的数据准备。
  5. `Score`：为候选节点评定单项分数 (0~100)。
  6. `Reserve`：在内存 Scheduler Cache 中锁住节点资源（乐观绑定）。
  7. `Permit`：阻止或延迟 Pod 绑定（用于 Batch Gang Scheduling 批处理死锁控制）。
  8. `PreBind`：执行挂载卷网络配置等预绑定操作。
  9. `Bind`：向 APIServer 写入 `Binding` 对象，修改 Pod 的 `spec.nodeName`。
  10. `PostBind`：绑定完成后清理资源或上报监控指标。

### 2. 打分算法物理公式 (Scoring Formula)
某个 Node $N$ 在打分阶段的最终综合得分计算公式为：

$$\text{FinalScore}(N) = \frac{\sum_{i=1}^{M} (\text{Score}_i(N) \times \text{Weight}_i)}{\sum_{i=1}^{M} \text{Weight}_i}$$

* **LeastRequestedPriority 资源空闲推导公式**：
  $$\text{Score}_{\text{CPU}} = \frac{\text{NodeCapacity}_{\text{CPU}} - \sum \text{Requested}_{\text{CPU}}}{\text{NodeCapacity}_{\text{CPU}}} \times 10$$
  它鼓励优先填满 CPU 闲置率最高的节点，达到全集群均衡打散效果。

---

## 六、 Scheduler 高可用机制、Framework 跨版本配置迁移与 PDB 排障

### 1. Scheduler 主备高可用与选主机制

`kube-scheduler` 同样采用基于 Lease 租约锁的主备（Active-Passive）高可用架构：
* 多个实例在 `kube-system` 下争抢名为 `kube-scheduler` 的 `coordination.k8s.io/v1 Lease` 锁。
* 抢占到锁的 Leader 实例激活 Informer 监听与 Scheduling Path 主循环；Standby 实例仅维持热备，不计算调度。
* 当 Master 节点发生物理故障时，Standby 实例在 15 秒后自动接管。

```yaml
# kube-scheduler 启动参数指定高可用选主
--leader-elect=true
--leader-elect-lease-duration=15s
--leader-elect-renew-deadline=10s
--leader-elect-retry-period=2s
--leader-elect-resource-name=kube-scheduler
--leader-elect-resource-namespace=kube-system
```

---

### 2. Scheduling Framework 跨版本配置文件迁移实战

随着 Kubernetes 版本演进，`KubeSchedulerConfiguration` 配置文件的 API 版本从 `v1beta2` $\to$ `v1beta3` $\to$ `v1`（K8s 1.25+ 默认）。在控制面升级时，若直接使用旧配置会导致 Scheduler 启动崩溃。

#### 跨版本迁移要点：
* **API Version 升级**：必须将 `apiVersion: kubescheduler.config.k8s.io/v1beta3` 替换为 `kubescheduler.config.k8s.io/v1`。
* **默认插件启用机制**：`v1` 移除了废弃的 `Score` 插件命名（如 `NodeResourcesLeastAllocated`），统一归并在 `NodeResourcesFit` 下通过 `args.scoringStrategy` 配置。

```yaml
# 生产级 KubeSchedulerConfiguration v1 标准配置示例
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
leaderElection:
  leaderElect: true
  resourceName: kube-scheduler
  resourceNamespace: kube-system
profiles:
- schedulerName: default-scheduler
  plugins:
    score:
      enabled:
      - name: NodeResourcesFit
        weight: 1
      - name: ImageLocality
        weight: 1
  pluginConfig:
  - name: NodeResourcesFit
    args:
      scoringStrategy:
        type: LeastAllocated
        resources:
        - name: cpu
          weight: 1
        - name: memory
          weight: 1
percentageOfNodesToScore: 50
```

---

### 3. 调度器与排空升级中典型故障场景与深度解决方案 (Troubleshooting SOP)

#### 场景 1：节点升级排空时被 PDB (PodDisruptionBudget) 永久死锁
* **故障现象**：执行 `kubectl drain <node>` 命令无限阻塞，控制台持续输出：
  `Cannot evict pod as it would violate the pod's disruption budget.`
* **根本原因**：目标节点上的应用配置了 `PodDisruptionBudget (minAvailable: 1)`，且该应用副本总数恰好为 1，或者集群其他节点资源已满无法调度新副本。Eviction API 严格遵守 PDB 准则而拒绝驱逐。
* **排障与恢复 SOP**：
  ```bash
  # 1. 查找阻碍排空的 PDB 规则及当前 DisruptionsAllowed 状态
  kubectl get pdb -A
  
  # 2. 方案 A (推荐 - 优雅扩容)：将该 Deployment 临时扩容 1 个副本，待新副本在其他节点 Ready 后自动解除 PDB 阻塞
  kubectl scale deployment <app-name> --replicas=2 -n <namespace>
  
  # 3. 方案 B (紧急运维)：临时修改 PDB 的 minAvailable 为 0
  kubectl patch pdb <pdb-name> -n <namespace> --type='json' -p='[{"op": "replace", "path": "/spec/minAvailable", "value": 0}]'
  
  # 4. 方案 C (强制跳过 Eviction API 兜底)：
  kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data --disable-eviction --force
  ```

#### 场景 2：控制面升级后旧版本 Kubelet 节点出现亲和性调度异常
* **故障现象**：调度器升级到新版本后，旧版本 Kubelet 节点无法被正常调度，报错 `MatchNodeSelectorTerms failed`。
* **根本原因**：新版本调度器使用了新引入的 NodeSelector 匹配特性，而版本相差 $\ge 3$ 个次版本的旧 Kubelet 节点上报的 Node Labels 格式不兼容。
* **排障与恢复 SOP**：
  ```bash
  # 1. 检查节点版本偏离程度
  kubectl get nodes -o wide
  
  # 2. 遵守 Version Skew Policy，优先将 Worker 节点 Kubelet 逐台升级至与 APIServer/Scheduler 相差 1~2 个版本之内
  ```

---

> [!TIP] 💡 关联技术与延伸阅读
>
> * [调度策略：亲和力、污点与节点平滑维护实战](./03-Scheduler/调度策略(污点、亲和、驱逐、抢占).md)
> * [Pod 调度配置与高级策略](../02-集群负载/01-Pod/Pod调度.md)

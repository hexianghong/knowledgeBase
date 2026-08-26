# Kubernetes 生产级 Nacos 2.x 高可用集群部署与重启故障深度剖析指南

## 1. 概述与背景

在云原生微服务架构中，**Nacos** 作为核心的服务注册发现中心与分布式配置中心，承担着微服务调用路由与动态配置推送的关键职责。

自 Nacos 2.x 版本起，底层通信与数据一致性机制进行了颠覆性重构：
* **通信协议**：全面升级为基于 Netty 的 **gRPC 双向长连接流式通信**（替代 1.x 的 HTTP 短轮询与 UDP 推送）。
* **一致性引擎**：采用混合一致性模型，将临时实例（Ephemeral）的 **Distro AP 协议** 与持久化实例/配置元数据的 **SOFAJRaft CP 协议** 深度整合。

当将 Nacos 2.x 容器化部署在 Kubernetes 上时，许多团队会遇到一个经典的生产级故障：
> **“首次部署能够按序启动成功，但运行一段时间或 Pod 自身发生重启（Crash / OOM / 节点迁移 / 滚动更新）后，集群陷入死锁、接口持续报 500、控制台提示 `No Leader`，整个微服务集群瞬间陷入瘫痪。”**

本文将从 **双协议内核机制、网络与存储反冲、资源/JVM 调优、高可用架构（SRE 视角）** 展开深度技术剖析，并提供经过生产级高并发检验的完整部署清单与应急运维 SOP。

---

## 2. Nacos 2.x 双协议引擎与重启雪崩机制

### 2.1 混合一致性模型拓扑

```
                              ┌──────────────────────────────────────────────┐
                              │            Microservice Client SDK           │
                              └──────────────────────┬───────────────────────┘
                                                     │
                                   ┌─────────────────┴─────────────────┐
                                   │  gRPC (9848) / HTTP (8848) Entry  │
                                   └─────────────────┬─────────────────┘
                                                     │
                    ┌────────────────────────────────┴────────────────────────────────┐
                    │                                                                 │
    ┌───────────────▼───────────────┐                                 ┌───────────────▼───────────────┐
    │     AP 模式: Distro 协议       │                                 │     CP 模式: SOFAJRaft 协议    │
    ├───────────────────────────────┤                                 ├───────────────────────────────┤
    │ • 职责：临时服务实例注册 (Ephemeral)   │                                 │ • 职责：持久化配置与元数据 (Persistent)  │
    │ • 机制：哈希环分片 + 对等广播同步    │                                 │ • 机制：强一致 Quorum + Raft Log/快照 │
    │ • 依赖：纯内存缓存 + 增量版本校验    │                                 │ • 依赖：磁盘状态存储 (protocol/raft)   │
    │ • 端口：9849 (Server gRPC)    │                                 │ • 端口：7848 (JRaft RPC)     │
    └───────────────────────────────┘                                 └───────────────────────────────┘
```

### 2.2 冷启动 vs 热重启时序差异剖析

为什么集群初次按序启动能跑通，而 Pod 热重启后必崩？

| 阶段 | 初始冷启动（0 -> 1 -> 2） | Pod 热重启（如 nacos-1 重建） |
|---|---|---|
| **PVC 存储状态** | 全新空白存储卷，无任何历史状态 | 存在历史 `data/protocol/raft` 日志快照与旧 `cluster.conf` |
| **网络与 DNS 状态** | 依次建立 Pod，域名随就绪逐步注册 | 重启 Pod 处于 `NotReady`，若未配置 `publishNotReadyAddresses` 则 DNS 无法解析 |
| **JRaft 恢复机制** | 节点无历史 Term，全新发起初始选举 | JRaft 强行读取 PVC 历史脏数据并绑定旧 IP，与当前在线集群 Term/CommitIndex 发生冲突 |
| **Quorum 仲裁判定** | 依次加入节点，逐步达到法定多数（2/3） | 重启节点连不上其他节点，选票无法达成 Quorum，全集群抛出 `RaftException` 拒服 |

---

## 3. 生产环境六大深水区缺陷与根因剖析

### 3.1 致命缺陷一：Headless Service 缺失 `publishNotReadyAddresses`（引发 DNS 寻址死锁）
* **错误配置表现**：
  使用已废弃的注解 `service.alpha.kubernetes.io/tolerate-unready-endpoints: "true"`。
* **底层原理**：
  在 Kubernetes 1.16+ 中，该注解已被官方彻底废弃并忽略。现代 K8s 必须在 Service 的 `spec` 中配置 `publishNotReadyAddresses: true`。
* **死锁链路**：
  1. `nacos-1` 发生重启，容器处于启动中（`NotReady` 状态）。
  2. CoreDNS 拒绝为未就绪 Pod 生成 Headless A 记录（`nacos-1.nacos-headless.namespace.svc.cluster.local`）。
  3. `peer-finder` 插件与 Nacos 无法解析到该 Pod，节点间 Raft 握手无法建立。
  4. Nacos 选主无法完成 -> 就绪探针无法通过 -> 永远处于 `NotReady` -> DNS 永远不解析。**形成不可自愈的死锁闭环**。

### 3.2 致命缺陷二：`/home/nacos/data` 持久化导致 JRaft 历史脏数据残留
* **底层原理**：
  在挂载外部 MySQL 的生产架构中，**业务配置和元数据已在 MySQL 数据库持久化**。容器本地的 `/home/nacos/data` 目录主要存储：
  * `data/protocol/raft/`：SOFAJRaft 的 RocksDB 日志、快照、Term 选主状态与 Peer 历史 IP。
  * `data/cluster.conf`：动态生成的集群节点列表。
* **崩溃机制**：
  当 Pod 重启分配到新 IP（或集群节点发生变动）时，JRaft 会强制从 PVC 恢复历史状态。由于历史快照记录的节点拓扑与当前集群不一致，导致 JRaft 节点抛出 `RaftException: [No Leader]`，Raft 状态机无法完成 Replay，Nacos 所有核心接口返回 500。
* **生产解决方案**：在容器启动命令前置执行清理：
  ```bash
  rm -rf /home/nacos/data/protocol/raft /home/nacos/data/cluster.conf
  ```

### 3.3 致命缺陷三：环境变量 `NACOS_REPLICAS` 与 StatefulSet `replicas` 不匹配
* **容错仲裁公式**：
  $$Quorum = \lfloor N / 2 \rfloor + 1$$
* **故障机制**：
  若 StatefulSet 配置 `replicas: 3`，但环境变量误配为 `NACOS_REPLICAS: "2"`：
  * `peer-finder` 仅生成包含 2 个节点的节点表，`nacos-2` 无法正常加入。
  * 当 `nacos-0` 重启时，剩余存活节点无法达成法定仲裁，集群发生脑裂保护。

### 3.4 致命缺陷四：缺少 JRaft 核心选举端口 `7848`
* **Nacos 2.x 端口矩阵完整定义**：
  * `8848`：HTTP 客户端与控制台 OpenAPI 端口。
  * `9848`（8848 + 1000）：客户端 gRPC 长连接请求端口。
  * `9849`（8848 + 1001）：服务端间 gRPC 数据同步与 Distro 广播端口。
  * `7848`（8848 - 1000）：**SOFAJRaft 选举与强一致数据复制专用端口**。
* 若 Headless Service 或容器 ports 遗漏 `7848`，会导致跨 Pod 的 Raft 心跳与选主 RPC 失败。

### 3.5 稳定性隐患五：缺失精准探针与优雅停机
* 若无健康探针，未完全启动的节点会接收外部流量导致请求报错；假死节点无法被 K8s 重建。
* 若无 `lifecycle.preStop`，Pod 被销毁时 gRPC 长连接被强制断开（RST），客户端会产生大量连接异常。

### 3.6 稳定性隐患六：JVM 内存模型与 CPU Throttling
* Nacos 2.x gRPC 基于 Netty，大量使用堆外直接内存（Direct Memory）。若 JVM `-Xmx` 占满容器 Limit，极易触发系统 OOM-Killer。
* CPU 限额过低会导致 CFS Quota 节流，JRaft 心跳（默认 5s）延迟超出选举超时时间，引发无休止的重新选举。

---

## 4. 生产级黄金标准（Golden Standard）架构部署

完整的生产级配置文件已归档在 [./05-Install/nacos/nacos.yaml](../../../05-Install/nacos/nacos.yaml)。

### 4.1 生产级 YAML 核心编排要点

```yaml
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: nacos-pdb
spec:
  minAvailable: 2 # 确保节点维护时始终保留 Quorum 所需的至少 2 个活跃 Pod
  selector:
    matchLabels:
      app: nacos
---
apiVersion: v1
kind: Service
metadata:
  name: nacos-headless
spec:
  clusterIP: None
  publishNotReadyAddresses: true # 💡 破除 DNS 寻址死锁
  ports:
    - port: 8848
      name: server
      targetPort: 8848
    - port: 9848
      name: client-rpc
      targetPort: 9848
    - port: 9849
      name: raft-rpc
      targetPort: 9849
    - port: 7848
      name: jraft-port          # 💡 开放 JRaft 端口
      targetPort: 7848
  selector:
    app: nacos
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: nacos
spec:
  serviceName: nacos-headless
  replicas: 3
  podManagementPolicy: Parallel # 💡 并行启动，加速集群整体选举收敛
  template:
    metadata:
      labels:
        app: nacos
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchExpressions:
                    - key: "app"
                      operator: In
                      values:
                        - nacos
                topologyKey: "kubernetes.io/hostname" # 强反亲和避免单机故障
      containers:
        - name: nacos
          image: registry-hz.rubikstack.com/library/nacos-server:v2.1.0
          command:
            - bash
            - -c
            - |
              echo ">>> [Init] Cleaning up stale Raft runtime and dynamic cluster metadata..."
              rm -rf /home/nacos/data/protocol/raft
              rm -rf /home/nacos/data/cluster.conf
              echo ">>> [Init] Starting Nacos Server..."
              exec /home/nacos/bin/docker-startup.sh
          lifecycle:
            preStop:
              exec:
                command:
                  - /bin/sh
                  - -c
                  - "/home/nacos/bin/shutdown.sh > /dev/null 2>&1; sleep 5"
          resources:
            requests:
              cpu: "1000m"
              memory: "2Gi"
            limits:
              cpu: "2000m"
              memory: "4Gi"
          env:
            - name: JVM_XMS
              value: "2048m"
            - name: JVM_XMX
              value: "2048m"
            - name: JVM_XMN
              value: "1024m"
            - name: NACOS_REPLICAS
              value: "3"
            - name: PREFER_HOST_MODE
              value: "hostname"
          readinessProbe:
            httpGet:
              path: /nacos/v1/console/health/readiness
              port: 8848
            initialDelaySeconds: 25
            periodSeconds: 10
            timeoutSeconds: 3
          livenessProbe:
            httpGet:
              path: /nacos/v1/console/health/liveness
              port: 8848
            initialDelaySeconds: 45
            periodSeconds: 15
            timeoutSeconds: 5
```

---

## 5. 生产环境 SRE 应急排障与平滑变更 SOP

### 5.1 场景一：集群故障（No Leader / 500 拒服）应急抢救 SOP

当生产 Nacos 重启后陷入瘫痪时，执行以下排查恢复命令：

```bash
# 1. 验证 CoreDNS 对 Headless Service 的域名解析
kubectl exec -it nacos-0 -c nacos -- nslookup nacos-headless

# 2. 紧急切除全节点 Raft 历史脏数据
for pod in nacos-0 nacos-1 nacos-2; do
  echo "Cleaning raft data on $pod..."
  kubectl exec $pod -c nacos -- rm -rf /home/nacos/data/protocol/raft /home/nacos/data/cluster.conf
done

# 3. 滚动重启 StatefulSet 触发全新选举
kubectl rollout restart statefulset nacos

# 4. 实时跟踪 Leader 选主日志
kubectl logs -f nacos-0 -c nacos --tail=100 | grep -E "LEADER|FOLLOWER|RaftGroup|Member"
```

### 5.2 场景二：生产环境零宕机平滑滚动更新 SOP

1. **核验 PDB 状态**：
   ```bash
   kubectl get pdb nacos-pdb
   ```
2. **执行滚动更新**：
   ```bash
   kubectl set image statefulset/nacos nacos=registry-hz.rubikstack.com/library/nacos-server:v2.2.3
   kubectl rollout status statefulset/nacos
   ```
3. **客户端状态监控**：观察微服务客户端日志，确认 gRPC 长连接在单个 Pod 重启时平滑漂移至存活节点，无报错中断。

---

## 6. 配置文件索引

* 生产部署清单：[./05-Install/nacos/nacos.yaml](../../../05-Install/nacos/nacos.yaml)
* StatefulSet 核心编排：[./05-Install/nacos/nacos-sts.yaml](../../../05-Install/nacos/nacos-sts.yaml)
* 数据库初始化与存储：[./05-Install/nacos/nacos-mysql.yaml](../../../05-Install/nacos/nacos-mysql.yaml)
* Ingress 路由规则：[./05-Install/nacos/nacos-ingress.yaml](../../../05-Install/nacos/nacos-ingress.yaml)

---

> [!TIP] 💡 关联技术与延伸阅读
>
> * [StatefulSet 有状态副本集原理与生命周期管理](../02-集群负载/04-StatefulSet.md)
> * [CoreDNS 核心解析与服务发现机制](../04-集群网络/04-CoreDNS核心解析与服务发现.md)
> * [Pod 优雅停机与无损发布实战](../02-集群负载/06-Pod优雅停机与无损发布.md)
> * [Ingress 基础全景与七层负载均衡指南](../04-集群网络/05-1-Ingress基础全景与进化延伸指南.md)
> * [etcd 备份与恢复实战指南](./11-etcd备份与恢复实战指南.md)

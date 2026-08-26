# Flannel 网络模式深度解析与 Calico 对比

## 1. Flannel 概述

Flannel 是 CoreOS 开发的一个专为 Kubernetes 设计的 **Overlay 网络插件**，负责为集群中的每个节点分配一个子网，并实现 Pod 跨节点通信。

### 核心设计原则
- 每个节点分配一个独立的 Pod CIDR 子网（如 `10.244.1.0/24`）
- 使用 etcd 或 Kubernetes API 存储子网分配信息
- 通过不同的 Backend（后端）实现跨节点数据包转发

---

## 2. Flannel 的四种工作模式

### 2.1 VXLAN 模式（默认推荐）

VXLAN（Virtual Extensible LAN）是一种隧道技术，将二层帧封装在 UDP 数据包中进行传输。

**关键组件：**
- `flannel.1`：VTEP（VXLAN Tunnel Endpoint）虚拟网络接口
- `cni0`：本节点的 Pod 网桥
- VNI（VXLAN Network Identifier）：默认为 1

**数据流向：** Pod → cni0 → flannel.1(封装 UDP/8472) → eth0 → 物理网络 → 目标节点解封装

**优点：** 支持任意网络拓扑，无需节点在同一二层，配置简单，支持大规模集群

**缺点：** 额外的封装/解封装开销（CPU 消耗约增加 10-15%），增加 MTU overhead（通常需要设置 MTU=1450）

**适用场景：** 云环境、不同 VLAN 节点之间、跨 IDC 部署

---

### 2.2 host-gw 模式（高性能首选）

将每个节点作为其所管理子网的网关，直接通过 **L3 路由** 转发 Pod 间流量，无需封装。

路由表示例（Node1 上）：
```bash
10.244.0.0/24 via 192.168.1.3 dev eth0   # 到 Node3 子网的路由
10.244.2.0/24 via 192.168.1.2 dev eth0   # 到 Node2 子网的路由
```

**优点：** 最高性能，无封装开销，接近原生网络性能，延迟最低

**缺点：** 强制要求所有节点在同一二层网络（同一个 L2 广播域），跨 VLAN、跨 IDC 场景不适用

**适用场景：** 物理机房同二层网络、裸金属部署（BareMetel）

---

### 2.3 UDP 模式（已废弃）

最早期的实现，在**用户空间**完成数据包封装，性能最差，已在新版本废弃，**不推荐生产使用**。

数据流向：Pod → 内核空间 → tun0 → flanneld进程(用户空间) → UDP封装 → 物理网卡

---

### 2.4 IPIP 模式

将 IP 数据包封装在另一个 IP 数据包中（IP-in-IP 隧道），相比 VXLAN 封装开销更小。

---

## 3. Flannel 与 Calico 深度对比

| 对比维度 | Flannel | Calico |
|---------|---------|--------|
| **路由层次** | 二层（Overlay 为主） | 三层（BGP 路由为主） |
| **网络策略（NetworkPolicy）** | 不支持 | 完整支持 |
| **性能** | VXLAN 有封装开销；host-gw 接近原生 | BGP 模式接近原生，无封装开销 |
| **跨子网通信** | VXLAN 模式支持 | BGP 需要支持 BGP 的路由器；IPIP 模式可跨子网 |
| **部署复杂度** | 简单，开箱即用 | 稍复杂，需了解 BGP |
| **IP 地址管理** | 节点级子网分配 | 更细粒度的 IPAM |
| **数据平面** | 内核 VXLAN / 路由 | Felix(iptables/eBPF) + BIRD(BGP) |
| **适用场景** | 简单集群、无网络隔离需求 | 生产级、需要安全隔离的集群 |
| **IP 固定** | 不支持 Pod IP 固定 | 支持（通过 Calico IPAM） |

### Calico 核心组件

Calico 工作在 **OSI 第三层（网络层）**，使用 BGP 协议交换路由信息：
- **Felix**：在每个节点运行，负责写入 iptables/eBPF 规则，实现数据包转发和网络策略
- **BIRD**：标准 BGP 路由守护进程，负责向其他节点宣告本节点的 Pod 子网路由
- **confd**：监听 etcd/Kubernetes API，动态更新 BIRD 配置

---

## 4. Flannel 可以固定 Pod IP 吗？

**结论：Flannel 无法固定 Pod IP。**

原因：
1. Flannel 使用节点级 CIDR 子网分配，在子网内动态分配 IP
2. Pod 销毁重建后，IP 从子网池重新分配，无法保证相同

**解决方案：**

| 需求 | 方案 |
|------|------|
| 固定 Pod IP | 使用 **Calico + Calico IPAM** 或 **Whereabouts IPAM** |
| 固定节点 IP | 通过操作系统网络配置或云平台弹性 IP 实现 |
| 稳定网络标识 | 使用 **StatefulSet + Headless Service**（DNS 稳定，但 IP 仍可能变化） |

---

## 5. 生产选型建议

| 场景 | 推荐方案 |
|------|---------|
| 小规模集群、无网络隔离需求 | Flannel VXLAN 模式，运维简单 |
| 节点同一二层、需高性能 | Flannel host-gw 模式，接近原生 |
| 生产级、需 NetworkPolicy | Calico BGP 或 IPIP 模式 |
| 超大规模、极致性能+安全 | Cilium (eBPF 数据平面) |

---

## 6. 相关参考

- [Kubernetes 集群网络](./02-Kubernetes集群网络.md)
- [Calico 架构与深度剖析](./02-1-Calico架构与calico-node及kube-controllers深度剖析.md)
- [集群网络访问详细流程](./03-集群网络访问详细流程.md)

---

> [!TIP] 💡 关联技术与延伸阅读
>
> * [Calico BGP 路由模式对比](./02-1-Calico架构与calico-node及kube-controllers深度剖析.md)
> * [CNI 接口标准与插件机制](../01-组件原理/04-Kubelet/CNI.md)

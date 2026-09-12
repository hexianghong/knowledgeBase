# 04-集群网络

## 目录说明
本目录涵盖 Linux 虚拟网络基础设施、Kubernetes 核心网络架构与通信模型、Kube-Proxy/Service 底层转发引擎、CNI 规范与网络插件生态（Flannel、Calico、Cilium、Multus）、服务发现（CoreDNS）、南北向网关（Ingress）、故障排查与抓包、以及服务网格（Istio）底层网络拦截技术的完整全栈知识沉淀。

## 内容索引
| 名称 | 类型 | 说明 |
|------|------|------|
| [./01-Docker容器网络.md](./01-Docker容器网络.md) | 文件 | Linux 基础网络虚拟化（NetNS、Veth-Pair、Linux Bridge）与 Docker 四大网络模式及内核报文流向 |
| [./01-1-Linux虚拟网络进阶与隧道技术深度指南_tun-tap_IPIP_VXLAN_Macvlan_IPvlan.md](./01-1-Linux虚拟网络进阶与隧道技术深度指南_tun-tap_IPIP_VXLAN_Macvlan_IPvlan.md) | 文件 | tun/tap 用户态通信、IPIP 与 VXLAN 隧道封装与开销、Macvlan 5 种模式及 IPvlan L2/L3 旁路高性能网络机制（新增） |
| [./02-Kubernetes集群网络.md](./02-Kubernetes集群网络.md) | 文件 | Kubernetes 核心网络设计原则、4 大基础通信模型、Pause 容器与 CNI 交互全流程 |
| [./02-1-Calico架构与calico-node及kube-controllers深度剖析.md](./02-1-Calico架构与calico-node及kube-controllers深度剖析.md) | 文件 | Calico Felix、BIRD、BGP Peer 路由宣告、IPIP/VXLAN 跨子网通信与 NetworkPolicy 深度剖析 |
| [./02-2-Kube-Proxy底层实现机制与Service转发深度指南_userspace_iptables_IPVS_conntrack.md](./02-2-Kube-Proxy底层实现机制与Service转发深度指南_userspace_iptables_IPVS_conntrack.md) | 文件 | Kube-Proxy 四代转发引擎演进（userspace/iptables/IPVS/eBPF）、conntrack 状态机与生产级 table full 调优 SOP（新增） |
| [./02-3-CNI规范演进与容器网络插件生态全景指南.md](./02-3-CNI规范演进与容器网络插件生态全景指南.md) | 文件 | Docker CNM vs CNI 标准演化史、ADD/DEL/CHECK 协议时序、IPAM 分配模型与 Multus 多网卡平面架构（新增） |
| [./03-集群网络访问详细流程.md](./03-集群网络访问详细流程.md) | 文件 | Pod 到 Pod、Pod 到 Service、NodePort 与外网互访的全链路数据流与 NAT 细节 |
| [./04-eBPF与Cilium下一代网络架构原理.md](./04-eBPF与Cilium下一代网络架构原理.md) | 文件 | eBPF 技术原理、Cilium 数据平面、Sockops 绕过协议栈加速与 L7 深度安全可观测 |
| [./05-1-Ingress基础全景与进化延伸指南.md](./05-1-Ingress基础全景与进化延伸指南.md) | 文件 | Ingress 核心概念、Ingress Controller 通用工作框架与下一代 Gateway API 演进路线 |
| [./05-Ingress_Nginx高并发内核调优指南.md](./05-Ingress_Nginx高并发内核调优指南.md) | 文件 | Ingress-Nginx 高并发场景下的 Linux 内核参数调优、连接复用与生产调优 SOP |
| [./06-K8s集群网络故障诊断与抓包实战指南.md](./06-K8s集群网络故障诊断与抓包实战指南.md) | 文件 | 节点与 Pod 网络排障流程、tcpdump/wireshark 抓包实战、hairpin 环回与常见坑位 |
| [./07-Flannel网络模式深度解析与对比.md](./07-Flannel网络模式深度解析与对比.md) | 文件 | Flannel VXLAN/host-gw/UDP 模式深度解析、内核 FDB/ARP 协同机制与生产选型对比 |
| [./08-CoreDNS底层架构与服务发现技术深度指南.md](./08-CoreDNS底层架构与服务发现技术深度指南.md) | 文件 | CoreDNS 插件链架构、DNS 规范命名、ndots:5 放大机理、UDP 并发 DNAT 5 秒超时根因与弹性伸缩监控 SOP |
| [./09-ServiceMesh底层网络拦截与Istio-Sidecar流量劫持深度解密.md](./09-ServiceMesh底层网络拦截与Istio-Sidecar流量劫持深度解密.md) | 文件 | Sidecar 拓扑 NetNS 共享、iptables 规则链透明劫持入站 15006/出站 15001、UID 1337 避环与 Istio-CNI 零特权安全演进（新增） |
| [./assets/](./assets/) | 目录 | 架构拓扑原图与网络流转图静态资产目录 |

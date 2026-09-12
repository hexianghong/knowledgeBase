# ☸️ Kubernetes (K8S) 云原生架构与核心技术实战

本目录汇集了从 Kubernetes 核心组件原理、集群负载管理、安全与资源控制、网络架构、集群存储、运维排障、集群扩展到生产应用实战的全套深度技术文档。

---

## 📂 目录大纲导航

### [01-组件原理](./01-组件原理)
Kubernetes 核心架构设计与底层组件协同机制。
*   [00-生态概览.md](./01-组件原理/00-生态概览.md) —— Kubernetes 生态图景与组件边界。
*   [00-组件通信与原理概述.md](./01-组件原理/00-组件通信与原理概述.md) —— 各组件之间的通信模型、Pod 创建全生命周期。
*   [01-API_Server.md](./01-组件原理/01-API_Server.md) —— 集群的统一网关，访问控制细节与三层 delegation。
    *   [源码解析.md](./01-组件原理/01-API_Server/源码解析.md) —— 基于 go-restful 的路由注册机制与 Delegation 链条源码剖析。
*   [02-Controller_Manager.md](./01-组件原理/02-Controller_Manager.md) —— 各种资源控制器的协同工作机制及 Informer 内部原理。
*   [03-Scheduler.md](./01-组件原理/03-Scheduler.md) —— 调度工作流程说明。
    *   [调度策略(污点、亲和、驱逐、抢占).md](./01-组件原理/03-Scheduler/调度策略(污点、亲和、驱逐、抢占).md) —— 深度解析亲和力、污点/容忍度、Pod 抢占与驱逐算法。
*   [04-Kubelet.md](./01-组件原理/04-Kubelet.md) —— 节点侧 Pod 管家的基础功能。
    *   [CNI.md](./01-组件原理/04-Kubelet/CNI.md) —— 容器网络接口原理。
    *   [CRI.md](./01-组件原理/04-Kubelet/CRI.md) —— 容器运行时接口规范。
    *   [03-Docker与Containerd底层实现及Pause通信深度解析.md](./01-组件原理/04-Kubelet/03-Docker与Containerd底层实现及Pause通信深度解析.md) —— Docker vs Containerd Pause 容器通信与 NetNS 挂载差异。
    *   [04-Kubelet_PLEG与节点死锁故障深度解析.md](./01-组件原理/04-Kubelet/04-Kubelet_PLEG与节点死锁故障深度解析.md) —— Generic PLEG 状态机与 Node NotReady 故障定位。
*   [05-Kube_Proxy.md](./01-组件原理/05-Kube_Proxy.md) —— 负责流量的负载均衡规则生成 (iptables / IPVS)。
*   [06-Kubectl.md](./01-组件原理/06-Kubectl.md) —— 命令行客户端与 Master 通信逻辑。
*   [07-请求在各组件间的流转详细流程.md](./01-组件原理/07-请求在各组件间的流转详细流程.md) —— Pod 创建与删除在各组件间的通信与流转全景。
*   [08-etcd底层架构MVCC与高可用运维.md](./01-组件原理/08-etcd底层架构MVCC与高可用运维.md) —— Raft 一致性协议、MVCC 机制、B+Tree 存储引擎与 Defrag 排排 SOP。
*   [09-Metrics_Server与API聚合层原理.md](./01-组件原理/09-Metrics_Server与API聚合层原理.md) —— Metrics Server 双监控管线架构与 API 聚合层 (Aggregation Layer) 核心原理。

---

### [02-集群负载](./02-集群负载)
声明式 API 与各种负载控制器的应用与高可用配置。
*   [01-Pod.md](./02-集群负载/01-Pod.md) —— 最基本调度单元概述。
    *   [健康检查与可用性检查.md](./02-集群负载/01-Pod/健康检查与可用性检查.md) —— Startup, Liveness, Readiness 探针设计。
    *   [Pod调度.md](./02-集群负载/01-Pod/Pod调度.md) —— 节点选择器、亲和性及节点调度的实现。
*   [02-ReplicaSet.md](./02-集群负载/02-ReplicaSet.md) —— 基于标签选择器的副本数控制。
*   [03-Deployment.md](./02-集群负载/03-Deployment.md) —— 声明式滚动更新负载。
    *   [高级用法.md](./02-集群负载/03-Deployment/高级用法.md) / [yaml注解.md](./02-集群负载/03-Deployment/yaml注解.md)
*   [04-StatefulSet.md](./02-集群负载/04-StatefulSet.md) —— 有状态服务负载。
    *   [基础.md](./02-集群负载/04-StatefulSet/基础.md) —— 拓扑状态与存储状态维护。
*   [05-其他负载类型.md](./02-集群负载/05-其他负载类型.md) —— DaemonSet, Job 等说明。
*   [06-资源更新与优雅关闭.md](./02-集群负载/06-资源更新与优雅关闭.md) —— 资源滚动热更新理论。
    *   [优雅关闭服务.md](./02-集群负载/06-资源更新/优雅关闭服务.md) —— 使用 `terminationGracePeriodSeconds` 参数配合生命周期钩子实现无损关机。
    *   [conditions资源状态.md](./02-集群负载/06-资源更新/conditions资源状态.md) —— API 对象中的 conditions 字段状态转换。
*   [07-HPA与VPA弹性扩缩容底层算法与指标管道.md](./02-集群负载/07-HPA与VPA弹性扩缩容底层算法与指标管道.md) —— 扩缩容推导公式、Behavior 防震荡与 KEDA 事件驱动。

---

### [03-安全与资源](./03-安全与资源)
多租户隔离、资源配额限制与安全控制链条。
*   [01-集群资源.md](./03-安全与资源/01-集群资源.md) —— Namespace 隔离、ResourceQuota 与 LimitRange 的硬限制配置。
*   [02-安全认证与准入控制.md](./03-安全与资源/02-安全认证与准入控制.md) —— 集群的认证机制 (CA, ServiceAccount)、授权 (RBAC) 和 Admission Controller。

---

### [04-集群网络](./04-集群网络)
从 Linux 系统物理层到容器层、以及 K8S 集群内部的综合网络协议体系。
*   [01-Docker容器网络.md](./04-集群网络/01-Docker容器网络.md) —— Linux 系统网络前置（veth-pair, bridge, route table）及 Docker 四大网络模式。
*   [02-Kubernetes集群网络.md](./04-集群网络/02-Kubernetes集群网络.md) —— K8S 四层网络模型结构与 Flannel/Calico/Cilium 二/三层物理数据流。
*   [02-1-Calico架构与calico-node及kube-controllers深度剖析.md](./04-集群网络/02-1-Calico架构与calico-node及kube-controllers深度剖析.md) —— 深入剖析 Calico 纯三层架构、calico-node（Felix/BIRD/confd）与 calico-kube-controllers 生命周期控制面、IPAM 机制及生产排障。
*   [03-集群网络访问详细流程.md](./04-集群网络/03-集群网络访问详细流程.md) —— kube-proxy 概率链、CoreDNS ndots:5 陷阱与 NodeLocal DNSCache 免 DNAT 机制。
*   [04-eBPF与Cilium下一代网络架构原理.md](./04-集群网络/04-eBPF与Cilium下一代网络架构原理.md) —— eBPF 字节码、SockOps 绕过 TCP 协议栈与 XDP 极速转发。
*   [05-Ingress_Nginx高并发内核调优指南.md](./04-集群网络/05-Ingress_Nginx高并发内核调优指南.md) —— 高并发 sysctl、ConfigMap 黄金模版与滚动更新零 502 报错配置。
*   [06-K8s集群网络故障诊断与抓包实战指南.md](./04-集群网络/06-K8s集群网络故障诊断与抓包实战指南.md) —— nsenter 穿透 Pod NetNS 抓包 SOP 与 8 大高级 tcpdump 过滤表达式。
*   [07-Flannel网络模式深度解析与对比.md](./04-集群网络/07-Flannel网络模式深度解析与对比.md) —— Flannel VXLAN/host-gw/UDP 模式深度解析，与 Calico 对比及生产选型建议。
*   [08-CoreDNS底层架构与服务发现技术深度指南.md](./04-集群网络/08-CoreDNS底层架构与服务发现技术深度指南.md) —— CoreDNS 插件链架构、RFC 命名寻址规范、ndots:5 放大机理、UDP 并发 DNAT 5 秒超时根因与弹性伸缩监控 SOP。

---

### [05-集群存储](./05-集群存储)
持久化卷 (PV/PVC) 声明与 CSI 存储挂载机制。
*   [01-CSI架构与存储挂载全链路机制.md](./05-集群存储/01-CSI架构与存储挂载全链路机制.md) —— CSI 挂载 4 阶段 (Provision/Attach/Mount/Bind Mount) 时序图与 VolumeAttachment 解锁。

---

### [06-集群运维](./06-集群运维)
集群多版本部署搭建、高难故障定位、万级节点调优与指标采集。
*   [01-K8S集群部署安装指南.md](./06-集群运维/01-K8S集群部署安装指南.md) —— 现代 Containerd 与传统 Docker 双部署实战方案。
*   [02-MetricsServer安装与x509证书排障.md](./06-集群运维/02-MetricsServer安装与x509证书排障.md) —— 解决 metrics API not available 的配置修改与证书跳过。
*   [03-kube-state-metrics配置与监控架构.md](./06-集群运维/03-kube-state-metrics配置与监控架构.md) —— 处理核心对象状态时序采集的 Prometheus 对接部署。
*   [06-生产级高难故障排查与实战方案.md](./06-集群运维/06-生产级高难故障排查与实战方案.md) —— PLEG 挂起、Ingress 502/504、etcd NOSPACE 救援、PMTU 黑洞与 OOMKilled 定位。
*   [07-万级节点与十万级Pod大规模集群调优指南.md](./06-集群运维/07-万级节点与十万级Pod大规模集群调优指南.md) —— APF 流控参数、Kubelet 调优与 Linux sysctl 内核矩阵。
*   [08-云原生可观测性架构Prometheus_Thanos_Tempo与eBPF链路追踪.md](./06-集群运维/08-云原生可观测性架构Prometheus_Thanos_Tempo与eBPF链路追踪.md) —— 告警与可观测性架构实战。
*   [10-Kubernetes生产级EFK(Elasticsearch+Fluentd+Fluentbit+Kibana)企业级架构、高可用集群部署与底层原理深度实战指南.md](./06-集群运维/10-Kubernetes生产级EFK(Elasticsearch+Fluentd+Fluentbit+Kibana)企业级架构、高可用集群部署与底层原理深度实战指南.md) —— 深度整合 ES 8.18+ 显式角色与安全机制、Lucene 9/10 FST/FOR 底层原理、3 节点高可用 StatefulSet 编排、Fluent Bit 极轻量采集与 Fluentd 复杂多行堆栈熔合管道、Kibana/ES|QL 可视化及全生命周期调优排障 SOP。
*   [13-Kubernetes容器与服务日志轮转治理与防爆盘深度实战指南.md](./06-集群运维/13-Kubernetes容器与服务日志轮转治理与防爆盘深度实战指南.md) —— 容器日志流转机理、Kubelet ContainerLogManager 轮转与固定大小配置、容器运行时 CRI 参数、Java/Go 框架级滚动与 Linux 句柄泄漏排障决策树。


---

### [07-集群扩展](./07-集群扩展)
存储侧（Ceph）、容器引擎侧（Containerd/Docker）、Operator 开发、渐进式交付（Argo）与认证考试准备。
*   [01-Argo概述与Rollouts金丝雀发布.md](./07-集群扩展/01-Argo概述与Rollouts金丝雀发布.md) —— Argo 渐进式发布、金丝雀/蓝绿控制器实战与指标监测。
*   [02-Docker与Containerd容器运行时底座.md](./07-集群扩展/02-Docker与Containerd容器运行时底座.md) —— 容器底层双引擎对比、OCI规范、命名空间与 ctr/crictl 对照。
*   [03-Ceph分布式存储架构与部署实战.md](./07-集群扩展/03-Ceph分布式存储架构与部署实战.md) —— RADOS 统一存储与 CRUSH 算法。
*   [04-Helm包制作指南.md](./07-集群扩展/05-Helm包制作与高级模版语法.md) —— 从零开始编写 Helm Chart，模板渲染与打包规则。
*   [05-CKA模拟考试.md](./07-集群扩展/06-CKA模拟考试核心实战指南.md) —— 考试模拟题、答题策略与常用核心命令参考。
*   [07-Operator开发与Controller-Runtime原理.md](./07-集群扩展/07-Operator开发与Controller-Runtime原理.md) —— controller-runtime 架构、Reconciler 幂等性与 Finalizer 异步销毁。

---

### [08-应用与实战](./08-应用与实战)
集群日常运维提效与业务平滑无损发布实战。
*   [01-集群巡检指南.md](./08-应用与实战/01-集群健康巡检与脚本自动化.md) —— 集群的日常健康度巡检指标与检测命令。
*   [02-应用的无损上线与下线.md](./08-应用与实战/02-云原生应用无损上下线实践.md) —— 结合 preStop、ReadinessProbe 避免发布过程流量丢失。
*   [03-CRD开发流程.md](./08-应用与实战/03-CRD与Kubebuilder开发流程.md) —— K8S 自定义资源定义开发生命周期及流程。
*   [04-Kubectl效率调优与K9s实战.md](./08-应用与实战/04-Kubectl效率调优与K9s实战.md) —— 提效别名配置、多环境上下文/命名空间一键切换及 K9s 交互控制。


---

## 🌐 经过 10 轮思考筛选的 Kubernetes (K8S) Top 20 权威参考网站库

### 🧠 10 轮筛选与“优秀”评估标准说明
1. **获取渠道**：结合 Kubernetes 控制面设计原稿 (KEPs)、CNCF 规范、大厂（Datadog/Cloudflare/Uber）大规模 K8s 实践及核心 Maintainer 专栏。
2. **“优秀”评估三大铁律**：
   - **绝对权威性**：是否直接出自 K8s 官方或 CNCF 毕业级底层组件。
   - **源码与内核深度**：是否涵盖 Linux 内核、eBPF、CSI 挂载 4 阶段、CNI 封包等硬核原理。
   - **生产实践价值**：是否经过万级 Node/十万级 Pod 生产规模与故障排错（PLEG、Conntrack 丢包、APF 流控）验证。

---

### 📚 Top 20 权威 K8s 网站地址列表

#### 1. 官方控制面与架构规范类 (Official Spec & Architecture)
1. **[Kubernetes Official Documentation & Blog](https://kubernetes.io/docs/)** (`https://kubernetes.io/docs/`)
   * **价值**：API 权威定义、控制面组件（APIServer/Kubelet/ControllerManager）官方指南与版本 Release Notes。
2. **[Kubernetes Enhancement Proposals (KEPs)](https://github.com/kubernetes/enhancements)** (`https://github.com/kubernetes/enhancements`)
   * **价值**：K8s 所有新特性与核心设计的原始提案、物理架构设计图与技术折衷思考。
3. **[CNCF (Cloud Native Computing Foundation)](https://www.cncf.io/)** (`https://www.cncf.io/`)
   * **价值**：云原生全景图 (Landscape)、KubeCon 权威技术演讲 PPT/视频与云原生项目毕业标准。
4. **[Kubebuilder Official Book](https://book.kubebuilder.io/)** (`https://book.kubebuilder.io/`)
   * **价值**：Kubernetes CRD、Operator 开发与 controller-runtime 架构权威指南。
5. **[Kubernetes Community & Slack Archives](https://kubernetes.slack.com/)** (`https://kubernetes.slack.com/`)
   * **价值**：全球顶级 K8s Maintainer 与 SIG (Special Interest Group) 工作组讨论沉淀。

#### 2. K8s 网络与 CNI 核心类 (Networking & CNI)
6. **[Cilium Documentation & eBPF for K8s](https://docs.cilium.io/)** (`https://docs.cilium.io/` / `https://ebpf.io/`)
   * **价值**：eBPF 代替 Kube-Proxy、SockOps 套接字层加速、XDP 极速转发与 Cilium Service Mesh 原理。
7. **[Project Calico Official Documentation](https://docs.tigera.io/calico/latest/about/)** (`https://docs.tigera.io/calico/`)
   * **价值**：BGP 路由宣告 (BIRD)、Felix 机制、IPIP 隧道与高并发 NetworkPolicy 生产配置。
8. **[Flannel CNI GitHub Repo & Architecture](https://github.flannel.io/flannel/)** (`https://github.com/flannel-io/flannel`)
   * **价值**：Flannel VXLAN UDP 8472 外层封包解包机制与 `flannel.1` VTEP 物理流转。
9. **[CoreDNS Official Documentation](https://coredns.io/exploring/)** (`https://coredns.io/exploring/`)
   * **价值**：K8s 服务发现 DNS 插件、ndots:5 解析性能坑点与 NodeLocal DNSCache 拦截 SOP。

#### 3. K8s 存储与容器运行时接口类 (CSI, CRI & Storage)
10. **[Kubernetes CSI Developer Documentation](https://kubernetes-csi.github.io/docs/)** (`https://kubernetes-csi.github.io/docs/`)
    * **价值**：CSI 挂载 4 阶段 (Provision/Attach/Mount/Bind Mount) 时序图与存储插件开发规范。
11. **[Containerd Official Documentation](https://containerd.io/docs/)** (`https://containerd.io/docs/`)
    * **价值**：cri-plugin 架构、OCI runtime-spec、runc 容器隔离与 overlay2 镜像层原理。
12. **[Rook Cloud Native Storage for K8s](https://rook.io/docs/rook/latest/)** (`https://rook.io/docs/rook/latest/`)
    * **价值**：Ceph 在 Kubernetes 上的 Operator 部署、PV/PVC 自动化调度与分布式存储运维。
13. **[Open Container Initiative (OCI) Specs](https://opencontainers.org/)** (`https://opencontainers.org/`)
    * **价值**：image-spec 与 runtime-spec 容器标准定义。

#### 4. 大厂百万级 Pod 生产工程与调优 (Production Engineering at Scale)
14. **[Datadog Engineering Blog (K8s at Scale)](https://www.datadoghq.com/blog/tag/kubernetes/)** (`https://www.datadoghq.com/blog/tag/kubernetes/`)
    * **价值**：数十万 Pod 规模下的 K8s 生产事故复盘、PLEG 卡顿分析与 APF 流控调优。
15. **[Cloudflare K8s Infrastructure Blog](https://blog.cloudflare.com/tag/kubernetes/)** (`https://blog.cloudflare.com/tag/kubernetes/`)
    * **价值**：跨数据中心 K8s 集群管理、Ingress-Nginx 极限调优与 Linux 内核参数矩阵。
16. **[Uber Engineering (K8s Architecture)](https://www.uber.com/blog/tag/kubernetes/)** (`https://www.uber.com/blog/tag/kubernetes/`)
    * **价值**：大规模异构集群调度、微服务网格 Mesh 演进与自动化自愈实践。
17. **[AWS Containers Blog (EKS Deep Dives)](https://aws.amazon.com/blogs/containers/)** (`https://aws.amazon.com/blogs/containers/`)
    * **价值**：云原生 Managed K8s 节点 Autoscaling、VPC CNI 原生网络与 Pod IP 直接绑定技术。

#### 5. 可观测性、渐进式交付与安全生态 (Observability & GitOps)
18. **[Argo Project Documentation](https://argoproj.github.io/)** (`https://argoproj.github.io/`)
    * **价值**：GitOps 声明式交付、Argo Rollouts 金丝雀/蓝绿发布及无损上线/下线 SOP。
19. **[Prometheus Operator Documentation](https://prometheus-operator.dev/)** (`https://prometheus-operator.dev/`)
    * **价值**：kube-state-metrics 采集、PromQL 高阶表达式与 ServiceMonitor 告警规则范式。
20. **[Sysdig Official Blog (K8s Security & Inspection)](https://sysdig.com/blog/)** (`https://sysdig.com/blog/`)
    * **价值**：基于 eBPF 的 K8s 容器运行时安全检测、Falco 规则与内核级可观测性。

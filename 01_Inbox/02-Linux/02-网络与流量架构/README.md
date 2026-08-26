# 02-网络与流量架构

## 目录说明
涵盖 Linux 内核网络协议栈底层机制（NAPI 软中断、数据包流转）、TCP 状态机调优、Netfilter/iptables 深度架构、TC 流量整形 QoS、IPVS 四层负载均衡三大模式及 eBPF 网络加速。

## 内容索引
| 名称 | 类型 | 说明 |
|------|------|------|
| [./01-Linux网络协议栈与排错指南.md](./01-Linux网络协议栈与排错指南.md) | 文件 | NAPI 软中断收包、TCP 状态机调优、Netfilter/iptables 四表五链与生产抓包排错 SOP |
| [./02-Linux高级网络架构与流量控制(TC_BPF)指南.md](./02-Linux高级网络架构与流量控制(TC_BPF)指南.md) | 文件 | Linux TC 流量整形与 QoS、HTB/Netem 弱网模拟、LVS/IPVS 负载均衡三大模式、网卡 Bonding 链路聚合及 tc-bpf 加速 |

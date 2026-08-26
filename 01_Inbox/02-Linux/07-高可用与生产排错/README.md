# 07-高可用与生产排错

## 目录说明
涵盖 Linux 高可用集群架构（Keepalived VRRP、Corosync/Pacemaker）、生产环境常见 CPU/内存/网络/磁盘高频故障应急止损手册，以及复杂疑难杂症深度案例集。

## 内容索引
| 名称 | 类型 | 说明 |
|------|------|------|
| [./01-Linux高可用集群与Keepalived_Corosync指南.md](./01-Linux高可用集群与Keepalived_Corosync指南.md) | 文件 | VRRP 协议原理、Keepalived VIP 漂移与脑裂防护、Corosync/Pacemaker 高可用栈实战 |
| [./02-高级运维生产高频故障排查手册.md](./02-高级运维生产高频故障排查手册.md) | 文件 | 生产环境高频出现的 CPU 假死、内存泄漏、句柄泄露、网络丢包与磁盘只读紧急止损手册 |
| [./03-高级运维生产复杂故障深度案例集(Case_Study).md](./03-高级运维生产复杂故障深度案例集(Case_Study).md) | 文件 | 复杂疑难杂症实战复盘（死锁、跨机房丢包、内核态内存泄漏、D 状态进程堆积） |

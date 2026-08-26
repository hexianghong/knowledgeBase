# 03-系统性能与调优

## 目录说明
涵盖 Linux 进程生命周期与 CFS 完全公平调度器调优、内存管理机制与 OOM-Killer 排障、块设备 IO 子系统调度优化，以及系统级内核参数 sysctl 调优模板。

## 内容索引
| 名称 | 类型 | 说明 |
|------|------|------|
| [./01-Linux进程与CPU性能调优指南.md](./01-Linux进程与CPU性能调优指南.md) | 文件 | CFS 完全公平调度器、CPU 上下文切换、绑核 (CPU Affinity) 与高负载排查 |
| [./02-Linux内存管理与OOM故障诊断指南.md](./02-Linux内存管理与OOM故障诊断指南.md) | 文件 | 虚拟内存空间、Page Cache 与 Buffer、匿名页、Swap 机制与内核 OOM-Killer 评分与救急 |
| [./03-Linux_IO子系统与存储调优指南.md](./03-Linux_IO子系统与存储调优指南.md) | 文件 | 通用块层、IO 调度算法（mq-deadline/BFQ）、iostat 性能指标深度解读与磁盘队列调优 |
| [./04-Linux内核参数调优与sysctl实战指南.md](./04-Linux内核参数调优与sysctl实战指南.md) | 文件 | /proc/sys 映射机制、TCP 拥塞与连接队列溢出诊断、系统 limits 与生产三大场景 sysctl 模板 |

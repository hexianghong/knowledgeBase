# MySQL 生产级终极排障指南 (MySQL Ultimate Troubleshooting Guide)

## 目录说明
本目录汇聚了针对 MySQL 8.0 生产环境的体系化排障手册与经典故障决策矩阵。涵盖慢 SQL 与索引失效、行锁表锁与死锁、InnoDB 磁盘 I/O 抖动、Linux 内核参数、主从复制与 MGR 脑裂、备份恢复与网络超时等全维度疑难杂症。

## 内容索引
| 名称 | 类型 | 核心内容说明 |
| :--- | :--- | :--- |
| [./00_README_Master_Index.md](./00_README_Master_Index.md) | 索引 | MySQL 生产排障全景总索引与全局决策树导航 |
| [./01_SQL_And_Index_Optimization.md](./01_SQL_And_Index_Optimization.md) | 专题 | 慢查询治理、执行计划分析、隐式转换与深度分页优化 |
| [./02_Locks_And_Concurrency.md](./02_Locks_And_Concurrency.md) | 专题 | 行锁/表锁/MDL锁争用分析、间隙锁死锁与高并发锁排查 |
| [./03_InnoDB_Storage_And_Disk.md](./03_InnoDB_Storage_And_Disk.md) | 专题 | InnoDB 脏页刷新抖动、Redo/Undo 暴涨与磁盘 I/O 瓶颈定位 |
| [./04_System_Resource_And_Kernel.md](./04_System_Resource_And_Kernel.md) | 专题 | CPU 飙升 100%、OOM 内存溢出、句柄耗尽与内核网络调优 |
| [./05_Replication_And_MGR.md](./05_Replication_And_MGR.md) | 专题 | 主从延迟严重、GTID 冲突断开、MGR 节点失联与脑裂恢复 |
| [./06_Ops_Network_And_Backup.md](./06_Ops_Network_And_Backup.md) | 专题 | XtraBackup 备份还原失败、网络丢包超时与运维操作排障 |
| [./mysql_top20_troubleshooting.md](./mysql_top20_troubleshooting.md) | 实战 | MySQL 生产环境 TOP 20 极高频必救故障速查手册 |
| [./mysql_top100_troubleshooting.md](./mysql_top100_troubleshooting.md) | 实战 | MySQL 生产环境 TOP 100 全场景故障排查与实战大典 |

---

> [!TIP] 💡 关联技术与部署
> * MySQL 底层原理与架构专题：[`../../01_Inbox/01-Mysql/README.md`](../../01_Inbox/01-Mysql/README.md)
> * MySQL 8.0 物理恢复与灾难恢复 SOP：[`../../05-Install/mysql/mysql8.0.43_huazhuo_prod/mysql_recover_README.md`](../../05-Install/mysql/mysql8.0.43_huazhuo_prod/mysql_recover_README.md)

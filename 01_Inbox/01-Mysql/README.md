# MySQL 数据库全栈知识库与资深 DBA 生产级进阶指南

此知识库（`01-Mysql`）包含了针对**生产级高可用、高性能、高安全基线**与 **MySQL 5.7 vs 8.0/8.4 全景版本演进**深度重构的完整技术文档体系。知识库涵盖了从 SQL 现代高阶语法、InnoDB 物理存储与内存内核机制、代价优化器（CBO）、物理/逻辑日志系统，到 MGR 组复制、Orchestrator 容灾自愈、大表在线无锁 DDL、PITR 灾难恢复、分布式数据库选型，以及高级 DBA 面试指南与生产排障 SOP。

---

## 📁 1. [01-基础和原理](01-基础和原理/)
涵盖 MySQL 逻辑架构、连接池、优化器代价模型及现代 SQL 高级特性：
- **[01-SQL基础与语法.md](01-基础和原理/01-SQL基础与语法.md)**：SQL 语法内核、Online DDL 三大算法（`INSTANT`/`INPLACE`/`COPY`）、MDL 锁排查、递归 CTE、窗口函数、JSON 虚拟列、降序与不可见索引及 5.7 vs 8.0 语法特性矩阵。
- **[02-MySQL架构设计.md](01-基础和原理/02-MySQL架构设计.md)**：插件式逻辑架构、5.7 vs 8.0 架构演进对比、Thread Pool 模型、CBO 代价优化器、Handler API 及四大系统数据库生产诊断指南。

---

## 📁 2. [02-进阶特性](02-进阶特性/)
探讨 InnoDB 物理底层、B+Tree 数学推导、MVCC 动态 ReadView 与锁相容矩阵：
- **[01-存储引擎与InnoDB.md](02-进阶特性/01-存储引擎与InnoDB.md)**：表空间五层物理结构、7 区数据页布局与 Slot 二分查找、Buffer Pool 冷热分段 LRU 算法、Doublewrite Buffer 抗页断裂、Redo 动态容量扩缩及 5.7 vs 8.0 引擎对比。
- **[02-索引原理与优化.md](02-进阶特性/02-索引原理与优化.md)**：B+Tree 扇出数与树高数学推导、聚簇与二级索引回表、ICP 索引条件下推、MRR 多范围读取、深分页调优及 5.7 vs 8.0 索引特性对比。
- **[03-事务与锁机制.md](02-进阶特性/03-事务与锁机制.md)**：ACID 物理保障、Undo 链与 ReadView 动态判定树、Next-Key Lock 锁退化规则、NOWAIT/SKIP LOCKED 高并发实战及死锁日志解析。
- **[04-性能分析与优化.md](02-进阶特性/04-性能分析与优化.md)**：慢日志 `pt-query-digest` 分析、EXPLAIN 各列详解与 `EXPLAIN ANALYZE` 真实执行树、Hash Join、MySQL 8.0 Optimizer Hints 及深分页/`COUNT(*)` 调优。
- **[05-视图_存储过程_触发器.md](02-进阶特性/05-视图_存储过程_触发器.md)**：视图 `MERGE` 与 `TEMPTABLE` 算法、微服务架构下存储过程选型争论、触发器执行顺序编排、DEFINER 安全防御及 MySQL 9.0 JavaScript (MLE) 扩展。

---

## 📁 3. [03-运维与管理](03-运维与管理/)
数据库生产高可用运维、XtraBackup 物理热备、安全审计与故障应急 SOP：
- **[01-日志管理.md](03-运维与管理/01-日志管理.md)**：WAL 预写机制、ARIES 崩溃恢复算法三阶段、Redo/Binlog 两阶段提交（2PC）崩溃边界判定、BLGC 组提交三阶段及 5.7 vs 8.0 日志对比。
- **[02-主从复制与高可用.md](03-运维与管理/02-主从复制与高可用.md)**：GTID 自动定位与空事务注入、MTS Writeset 并行复制、无损半同步、MGR Paxos 组复制、Orchestrator + ProxySQL 容灾架构及分布式 DB 选型。
- **[03-日常运维与工具.md](03-运维与管理/03-日常运维与工具.md)**：`Too Many Connections` 应急解锁、`gh-ost` 无触发器在线 DDL、MySQL 8.0 Clone Plugin 秒级从库搭建及 `mydumper/myloader` 并行备份。
- **[04-数据备份与恢复.md](03-运维与管理/04-数据备份与恢复.md)**：Percona XtraBackup 物理热备 Prepare 原理、8.0 备份锁 (Backup Locks)、基于 Binlog 的点对点精准恢复（PITR）与误删数据 Flashback 闪回。
- **[05-用户与权限管理.md](03-运维与管理/05-用户与权限管理.md)**：MySQL 5.7 vs 8.0 权限体系全景对比、动态权限（Dynamic Privileges）拆解 SUPER、RBAC 角色管理、双密码（Dual Passwords）零停机轮换、`caching_sha2_password` 驱动兼容及安全审计与应急救援。
- **[06-参数调优与配置.md](03-运维与管理/06-参数调优与配置.md)**：核心参数详解、Linux OS 内核级调优（THP/Swappiness/NUMA）、MySQL 8.0 `SET PERSIST` 参数持久化及 4核16G / 16核64G 生产配置模板。
- **[07-巡检报告与规范.md](03-运维与管理/07-巡检报告与规范.md)**：日常健康检查 Checklist、5.7 vs 8.0 巡检视图适配及一键自动化 Shell 巡检脚本。
- **[08-常见问题与故障排查.md](03-运维与管理/08-常见问题与故障排查.md)**：表空间空洞收缩、自增 ID 溢出与持久化、长事务 Undo 回溯、MDL 锁排查及线上 CPU 100% 应急止血 SOP。
- **[09-生产环境主从迁移实战.md](03-运维与管理/09-生产环境主从迁移实战.md)**：百 G 级生产大库无缝迁移实战、5.7 升 8.0 跨版本迁移排雷 Checklist、导入提速调优及秒级割接 SOP。

---

## 📁 4. [04-OCP认证](04-OCP认证/)
- **[mysql_ocp.md](04-OCP认证/mysql_ocp.md)**：MySQL 908 OCP 认证全套真题解析、考点剖析与备考拓展。

---

## 📁 5. [05-参考资源](05-参考资源/)
- **[Top10_优质学习网站.md](05-参考资源/Top10_优质学习网站.md)**：精选 MySQL、TiDB、OceanBase 与 Vitess 核心学习网站。
- **[链接.md](05-参考资源/链接.md)**：收集的 MySQL 官方文档、Percona 博客与内核解析文章精选。

---

## 📁 6. 🚀 [06-高级DBA面试与进阶指南](06-高级DBA面试与进阶指南/)
面向高级数据库工程师 (Senior DBA / Database Infrastructure Engineer) 的专业面试备考与架构演进指南：
- **[高级数据库工程师面试指南.md](06-高级DBA面试与进阶指南/高级数据库工程师面试指南.md)**：
  1. **高级 DBA 核心能力模型与职级矩阵**（P7/P8 技能树及职责要求）。
  2. **8 周高效备考计划与复习路线图**（按周划定核心攻克主题与实战产出）。
  3. **高频核心面试专题与 5.7 vs 8.0/8.4 架构演进深度解答**（InnoDB 内核、ReadView 算法、Next-Key Lock 退化、CBO 优化器、2PC 崩溃恢复、MGR Paxos 共识、TiDB/PolarDB 选型）。
  4. **真实生产故障突发应对 STAR 实战案例库**（CPU 100%、锁阻塞、大表死锁、主从复制延迟）。
  5. **模拟面试评分标准与考官视角 Scoring Rubric 评测表**。

---
*注：所有图片资源和静态图表均归口存放在对应 Markdown 文件同级的 `assets` 目录中。*

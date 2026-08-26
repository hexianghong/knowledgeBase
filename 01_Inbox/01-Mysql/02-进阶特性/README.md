# 02-进阶特性

## 目录说明
本目录深入探讨 MySQL 底层核心与高级进阶特性，涵盖 InnoDB 物理存储与内存架构、B+Tree 索引数学推导与高级优化、事务 ACID 与 MVCC 锁相容矩阵、慢查询与 EXPLAIN ANALYZE 深度调优，以及视图、存储过程与触发器在生产微服务架构下的最佳实践，重点对比 MySQL 5.7 与 8.0/9.0 的内核演进。

## 内容索引
| 名称 | 类型 | 说明 |
|------|------|------|
| [./01-存储引擎与InnoDB.md](./01-存储引擎与InnoDB.md) | 文件 | InnoDB 五层物理结构、7 区页结构、Buffer Pool 冷热分离、Doublewrite Buffer 抗页断裂及 5.7 vs 8.0 引擎对比 |
| [./02-索引原理与优化.md](./02-索引原理与优化.md) | 文件 | B+Tree 扇出数与树高推导、覆盖索引、ICP 索引下推、MRR、深分页调优及 5.7 vs 8.0 降序/不可见/函数索引 |
| [./03-事务与锁机制.md](./03-事务与锁机制.md) | 文件 | ACID 物理保障、Undo 链与 ReadView 判定树、Next-Key Lock 锁退化矩阵、NOWAIT/SKIP LOCKED 实战与死锁 SOP |
| [./04-性能分析与优化.md](./04-性能分析与优化.md) | 文件 | pt-query-digest 慢日志分析、EXPLAIN ANALYZE 真实执行树、Hash Join、Optimizer Hints 及高频慢 SQL 调优 |
| [./05-视图_存储过程_触发器.md](./05-视图_存储过程_触发器.md) | 文件 | 视图 MERGE/TEMPTABLE 算法、微服务存储过程选型辩证、触发器顺序编排与 MySQL 9.0 JavaScript (MLE) 扩展 |
| [./assets/](./assets/) | 目录 | 进阶特性架构图、索引结构图及流程图静态资源 |

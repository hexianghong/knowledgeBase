# Top 10 MySQL 原理与运维学习网站

结合权威官方文档、顶尖商业/开源公司博客、高质量的中文专栏以及实战问答社区，整理的10个最优质的 MySQL 学习与参考网站。

## 核心原理与底层架构（深挖必备）

**1. 数据库内核月报 (阿里淘宝数据库团队)**
*   **网址**：[mysql.taobao.org](http://mysql.taobao.org/)
*   **特点**：国内顶级的 MySQL 原理学习圣地。如果您想了解 InnoDB 引擎底层原理、B+ 树内部结构、事务隔离的实现源码、Redo/Undo log 细节，这里是最佳选择。

**2. 掘金小册 - 《MySQL 是怎样运行的》**
*   **网址**：[juejin.cn](https://juejin.cn/book/6844733769996304397)
*   **特点**：被公认为国内讲解 MySQL 底层原理最通俗易懂的读物。用非常接地气的语言配上清晰的图表，把极其枯燥的 InnoDB 存储引擎、索引、数据页结构讲得清清楚楚。

**3. MySQL 官方参考手册**
*   **网址**：[dev.mysql.com/doc/](https://dev.mysql.com/doc/)
*   **特点**：最权威、最全面的知识库。特别是其中的 InnoDB 存储引擎架构章节和优化（Optimization）章节，是解决最终疑难杂症的终极武器。

## 实战运维与性能调优（DBA 必看）

**4. Percona Database Blog**
*   **网址**：[percona.com/blog/](https://www.percona.com/blog/database-mysql/)
*   **特点**：Percona 是全球顶尖的 MySQL 开源咨询公司。他们的博客是性能调优和高阶运维管理的金矿，包含大量真实的线上故障排查案例、参数调优和高可用架构方案。

**5. 极客时间 - 《MySQL 实战 45 讲》**
*   **网址**：[time.geekbang.org](https://time.geekbang.org/column/intro/100020801)
*   **特点**：前阿里资深数据库专家丁奇撰写。完美地将“底层原理”与“日常运维实战”结合在了一起，讲解了慢查询优化、锁问题排查、主从延迟解决等日常痛点。

**6. DBA Stack Exchange**
*   **网址**：[dba.stackexchange.com](https://dba.stackexchange.com/questions/tagged/mysql)
*   **特点**：Stack Overflow 旗下的专业数据库管理员问答社区。遇到日常运维中遇到的古怪报错、复制中断等问题，去这里搜索往往能看到全球顶尖 DBA 的详尽解答。

**7. Planet MySQL**
*   **网址**：[planet.mysql.com](https://planet.mysql.com/)
*   **特点**：MySQL 官方的博客聚合平台。汇集了全球大量顶尖 MySQL 开发者、DBA 和架构师的博客，是紧跟 MySQL 最新特性、运维趋势最好的信息流。

## 基础入门与工具导航

**8. MySQL Tutorial**
*   **网址**：[mysqltutorial.org](https://www.mysqltutorial.org/)
*   **特点**：非常棒的实战教程网站，包含大量清晰的 SQL 语法讲解、存储过程/触发器指南以及基础的管理操作。

**9. Awesome MySQL (GitHub)**
*   **网址**：[github.com/shlomi-noach/awesome-mysql](https://github.com/shlomi-noach/awesome-mysql) （中文版见 [Awesome-MySQL-CN](https://github.com/thinkingqi/awesome-mysql-cn)）
*   **特点**：庞大的 MySQL 生态工具与资源导航站。收录了世界上最好用的 MySQL 备份工具、压测工具、监控脚本和中间件方案。

**10. LearnKu - MySQL 社区**
*   **网址**：[learnku.com/mysql](https://learnku.com/mysql)
*   **特点**：国内活跃度较高的开发者社区之一，沉淀了非常多高质量翻译的 MySQL 技术文章、日常运维踩坑记录以及面试总结。

---

## 资深数据库架构师进阶扩展网站

**11. PingCAP TiDB 官方文档与架构源码指南**
*   **网址**：[docs.pingcap.com/zh/tidb/stable](https://docs.pingcap.com/zh/tidb/stable)
*   **特点**：分布式 NewSQL 领域的标杆，深入解析 Percolator 分布式事务模型、Multi-Raft 共识与 HTAP 混用引擎。

**12. OceanBase 社区版内核与实战**
*   **网址**：[oceanbase.com/docs](https://www.oceanbase.com/docs)
*   **特点**：原生分布式关系型数据库，深入 LSM-Tree 存储引擎、多机房 Paxos 强一致架构。

**13. Vitess 分片与数据库横向扩展架构**
*   **网址**：[vitess.io](https://vitess.io/)
*   **特点**：用于扩展 MySQL 的云原生数据库中间件体系，适用于超大规模数据水平分片。

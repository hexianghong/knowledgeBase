# 02_Notes 日常工作处理总结每日专区 (Daily Work Summaries)

---

## 🎯 目录定位与核心原则

- **核心定位**：记录日常生产排障、架构改造、技术演进与运维变更的**每日工作处理总结专区**。
- **管理原则**：
  1. **每日一文 (One File Per Day)**：以标准自然日为单元，严格按 `YYYY-MM-DD.md` 命名（如 `2026-09-20.md`）；
  2. **一线实战沉淀**：不写空洞理论，坚持真实记录当日生产系统发生的重大故障、RCA 根因排查、关键处置指令、配置变更与执行避坑；
  3. **网状知识闭环**：日常记录中涉及的底层原理向上挂载至 `01_Inbox/` 专题，提炼出的全局避坑经验同步写入 `LEARNING.md` 与项目规范中。

---

## 📚 内容索引

| 日期文件 | 类型 | 核心处理内容与战果总结 |
| :--- | :--- | :--- |
| [./2026-09-20.md](./2026-09-20.md) | 文档 | **全链路生产攻坚、AI Agent 架构与全场景排障沉淀**<br>• MongoDB 78天宕机孤儿进程持锁排障与恢复<br>• 生产安全“资产未清严禁写操作”红线确立<br>• 6个 0/1 Pod 分类攻坚（UI 缩容止血、Linux 3.10 kmemcg 耗尽定性、ms-doctor 探针死锁治愈归队）<br>• PromQL 指标缺失 `<none>` 陷阱与 `unless` 黄金规则实战印证<br>• AI Agent 体系化架构深度梳理（Brain/Planning/Memory/Tools 四大支柱与 SRE 智能体演进）<br>• RocketMQ Dashboard 内存暴涨 14GB 根治（JVM 堆内存上限收敛与双重防线构建，释放内存 26GB+）<br>• 微服务 `ms-pub` 重启 3,818 次“坏节点”网络死锁定位（HikariCP 初始化超时与 CNI/SNAT 异常定性）<br>• MySQL HIS 核心库高频死锁（24次/分）RCA 根因排查（Seata 分布式事务 undo_log 并发碰撞与客户端链路定位） |

---

> [!TIP] 💡 关联导航
> 
> * 查阅底层架构原理与技术专题：[`../01_Inbox/README.md`](../01_Inbox/README.md)
> * 查阅阶段复习与学习规划：[`../03_Study_Plans/README.md`](../03_Study_Plans/README.md)
> * 查阅生产真实事故复盘与排障：[`../06_Troubleshooting/README.md`](../06_Troubleshooting/README.md)
> * 查阅 AI 经验备忘与自省记录：[`../LEARNING.md`](../LEARNING.md)

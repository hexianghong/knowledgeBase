# AI Lessons Learned & Self-Refinement Memory

> [!IMPORTANT]
> **Instructions**: This document serves as a structured, dynamic project memory. All critical mistakes made by the AI, code style corrections enforced by developers, or new project rules **must be recorded under their respective categories** to ensure the AI does not repeat errors.
> 
> **AI Operational Safeguard**: Whenever you are corrected by a developer, you must **proactively record the lesson under the matching category header** in this file.

---

## 1. 🛡️ Security, Environment & Infrastructure
- `[2026-08-28] [MySQL/Accounts]` 物理恢复 (XtraBackup / copy-back) 会全盘覆盖 `mysql.user` 表，root 密码已变更为源库备份时的密码，且老库可能缺少 `localhost` 或 `127.0.0.1` 权限导致 `mysqlsh` 报 Error 1045 / 1396。重置账号时必须使用 `CREATE USER IF NOT EXISTS` + `GRANT` 幂等补全 `localhost`, `127.0.0.1`, `%` 三者权限。
- `[2026-08-28] [MySQL/MGR/Router]` MGR 集群在主节点强制重建 (`dba.createCluster force`) 后，MySQL 集群元数据与 Router 账号被重建。原有 MySQL Router 启动会报超时，必须在 Router 节点上重新执行 `mysqlrouter --bootstrap root@<Node1_IP>:3306 --user=mysqlrouter --directory=/etc/mysqlrouter --force` 重新引导。
- `[2026-09-20] [SRE/ProductionSafety]` 生产环境排障红线：严禁在未摸清底层资产、拓扑与存活状态前执行任何写操作（如强杀进程、删锁文件、改配重启）。必须全量只读取证先行，先梳理详细说明后一次性给出完整检查脚本，经双人复核审批后方可推进。

---

## 2. ⚙️ Architecture, Database & API Contracts
- `[2026-08-28] [MySQL/MGR/GIPK]` MGR / InnoDB Cluster 强制要求所有表具备 Primary Key 才能进行 WriteSet 冲突认证。老库存在无主键表时 `dba.createCluster` 会拦截报错。首选解法为添加不可见主键 (`ADD COLUMN _mgr_pk_ BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY INVISIBLE`)，对业务 `SELECT *` 和全列 `INSERT` 100% 零侵入透明；同时开启 `sql_generate_invisible_primary_key = ON`。
- `[2026-08-28] [MySQL/Schema/AutoIncrement]` 表结构治理时，若表已有自增列（如 `increment_id int auto_increment`）但未设为主键，直接加 `_mgr_pk_ AUTO_INCREMENT` 会触发 `ERROR 1075: only one auto column`。治理脚本必须自适应分流：已有自增列直接提升为主键，无自增列加不可见主键。

---

## 3. 🛠️ DevOps, Shell Scripts & Operations
- `[2026-08-28] [MySQL/MGR/Recovery]` MGR 集群物理灾难恢复绝对不能在 3 个节点同时执行恢复脚本。只允许在 Node1 单节点执行 `mysql_recover_optimized.sh` 并引导集群，Node2 / Node3 必须清空数据并通过 `cluster.addInstance(..., {recoveryMethod: 'clone'})` 由 MySQL 8.0 Clone 插件自动秒级同步。
- `[2026-08-11] [Containerd/K8s]` Containerd 误禁用 cri 插件 (disabled_plugins=["cri"]) 会导致 Kubelet 报 rpc error: unknown service runtime.v1.RuntimeService，致使集群所有节点变为 NotReady。修复方案: 重置 containerd config default 并去除 disabled_plugins 中的 cri。

---

## 4. 🎨 Code Style, Frontend & Unit Testing
- `[2026-08-28] [7-Layer Architecture]` 知识库采用 7 层分层递进架构（`01_Inbox` 体系专题, `02_Notes` 提炼面试, `03_Study_Plans` 计划目标, `04_Resources` 静态素材, `05-Install` 工程交付, `06_Troubleshooting` 生产排障, `07_Templates` 规范模板），新建文档必须遵循模板并使用项目级相对路径。
- `[2026-08-10] [Path Specification]` 项目中所有的文件路径及 Markdown 关联链接必须且只能使用项目级别的相对路径（例如 `./01_Inbox/03-K8S/...` 或相对当前文件的路径），严禁包含本机绝对路径（如 `/Users/...` 或 `file:///Users/...`）。
- `[2026-09-18] [Rule/ExternalLinkPreservation]` 当用户提供外部链接（GitHub 仓库、技术文档、博客等）要求学习整理时，整理生成的文档必须在文首（Note 提示块）与文末（参考资料章节）强制保留原始完整链接地址，确保 100% 可溯源性。
- `[2026-09-20] [Rule/02_NotesDailySummary]` `02_Notes/` 目录专门用于记录日常工作处理总结，坚持“每日一个文件”（如 `YYYY-MM-DD.md`），全面沉淀生产故障排查、配置变更、实战调优与工作决策卡片。

---

> [!TIP]
> **Token Context Hygiene**: When entries in this file exceed 50 items, the AI should prompt the developer to summarize recurring items into global rules and purge stale temporary entries.

# 企业级云原生与基础架构全栈知识库 (GEMINI.md)

## 1. 业务背景与知识库架构 (Business Context & Architecture)
- **定位**：面向生产级 SRE、DevOps、云原生与数据库架构师的企业级深度知识沉淀库。
- **全生命周期 7 层架构**：
  1. `01_Inbox/`：深度技术专题底座（MySQL 底层原理、Linux 内核、K8s 源码剖析、AI Agent）；
  2. `02_Notes/`：全栈工程师面试题库与高浓度决策卡片（向上连接认知，向下挂载底层专题）；
  3. `03_Study_Plans/`：阶段攻坚路线图（Roadmap）与学习目标管理；
  4. `04_Resources/`：架构拓扑原图、PDF 白皮书与静态资产；
  5. `05-Install/`：企业级工程化交付包（MySQL 8.0 MGR、K8s 离线安装、自动化备份恢复）；
  6. `06_Troubleshooting/`：生产事故 RCA 复盘报告与全场景 TOP 故障诊断决策树；
  7. `07_Templates/`：标准化中枢，内置事故复盘、深度专题、运维 SOP、技术选型标准模板。

## 2. 项目核心规则 (Local Rules)
- **文件与链接路径规范**：知识库内部所有文档引用、图片嵌入和跳转链接**必须且只能使用项目级相对路径**（如 `./01_Inbox/...`），严禁使用绝对路径（如 `/Users/...` 或 `file:///Users/...`），保证跨设备 100% 0 死链。
- **临时文件规范**：创建辅助脚本或临时数据时，优先在项目根目录或 `./scratch/` 创建，严禁写入外部系统级目录（如 `/tmp`），用完后及时清理。
- **网状互联与延伸阅读规范**：编写或更新技术文档时，必须在正文进行自然引用，并在文末统一附加 GitHub 风格的 `> [!TIP] 💡 关联技术与延伸阅读` 提示块，形成网状闭环。
- **标准化模板规范**：新建事故复盘、技术专题、变更 SOP 时，必须优先使用 `./07_Templates/` 下的标准模板。

## 3. 本地核心自动化脚本 (Automation Scripts)
- **MGR 部署与生命周期**：`./05-Install/mysql/mysql8.0.43_huazhuo_prod/mysqld_install.sh`
- **MGR 一键物理恢复**：`./05-Install/mysql/mysql8.0.43_huazhuo_prod/mysql_recover_optimized.sh <备份集路径>`
- **MGR 无主键表智能治理**：`./05-Install/mysql/mysql8.0.43_huazhuo_prod/mysql_mgr_fix_pks.sh`
- **全集群健康验收**：`./05-Install/mysql/mysql8.0.43_huazhuo_prod/verify_mysql.sh`

## 4. 推荐 MCP 服务与工具协同
- **Filesystem MCP**：本地知识库文件索引与全文检索。
- **Git MCP**：版本受控管理与变更审计。

## 5. 核心模型与规范索引
- **全局根目录导航**：[README.md](./README.md)
- **AI 长期经验记忆库**：[LEARNING.md](./LEARNING.md)
- **工作区智能体规范**：[.agents/AGENTS.md](./.agents/AGENTS.md)

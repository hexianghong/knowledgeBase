# Workspace Rules

## 1. File Path & Link Specification (文件与链接路径规范)
- **严格使用项目相对路径**：知识库项目内的所有文件引用、文档关联链接（Markdown Links）以及说明文本中的路径，**必须且只能使用项目级别的相对路径**（例如 `./01_Inbox/03-K8S/04-集群网络/05-1-Ingress基础全景与进化延伸指南.md` 或相对当前文件的相对路径 `./xxx.md`）。
- **严禁使用绝对路径**：禁止使用任何包含特定用户本机主机的绝对路径（例如 `/Users/hexianghong/...` 或 `file:///Users/hexianghong/...`），以保证知识库在不同设备与部署环境下的可移植性与通用性。

## 2. Directory README Specification (目录 README 规范)
- **每个目录必须包含 README.md**：知识库内的**每一个文件夹**（包括根目录及所有子目录）都必须有一个 `README.md` 文件。
- **内容要求**：`README.md` 须列出并简要说明当前目录下**所有一级子目录或文件**的名称与用途，格式示例如下：
  ```markdown
  # 目录名称

  ## 目录说明
  简要描述本目录的整体用途。

  ## 内容索引
  | 名称 | 类型 | 说明 |
  |------|------|------|
  | ./子目录A/ | 目录 | 说明A |
  | ./文件B.md | 文件 | 说明B |
  ```
- **用途**：README.md 是 AI 导航知识库的核心索引，AI 在查找文件或分析项目结构时，应**优先读取**目标目录的 README.md，而非直接扫描全部文件内容。
- **及时更新**：每当目录下新增、删除或重命名文件/子目录时，必须同步更新对应的 `README.md`。

## 3. Temporary File Specification (临时文件规范)
- **优先在项目根目录或指定临时目录下创建**：创建任何执行脚本、辅助工具或中间临时文件时，**优先且必须在当前项目工作区内创建**（如项目根目录下的临时脚本、`./scratch/` 或 `./tmp/`），严禁使用项目外部路径或系统级临时目录（如 `/tmp`、`/var/tmp` 等），并在使用完毕后及时清理。

## 4. Cross-Document Reference Specification (跨文档技术点关联跳转规范)
- **网状知识关联原则**：编写或更新任何技术文档时，若内容中涉及、对比或依赖知识库中其他已有文档的技术点（如组件通信、运行时 CRI、网络插件 CNI/Calico/Flannel、服务发现 CoreDNS/kube-proxy、存储 CSI/Ceph、优雅停机/无损发布、安全准入、可观测性监控等），**必须建立可点击的相对路径跳转链接**。
- **正文内联自然引用**：在正文中首次提及关键概念、技术选型对比或时序流程流转时，将概念关键词直接加挂相对路径链接（如 `[Calico BGP 路由](../04-集群网络/02-1-Calico架构与calico-node及kube-controllers深度剖析.md)` 或 `[CRI 运行时接口](./04-Kubelet/CRI.md)`），避免在代码块和行内代码内建立破坏性链接。
- **标准化章末卡片**：技术专题文档末尾统一提供标准的 GitHub 风格提示块 `> [!TIP] 💡 关联技术与延伸阅读`，列出 2~5 篇强相关前置原理、底层实现或进阶实战文档的相对路径，形成闭环知识链。格式规范如下：
  ```markdown
  ---

  > [!TIP] 💡 关联技术与延伸阅读
  >
  > * [前置原理文档标题](相对路径.md)
  > * [底层实现/协作组件文档标题](相对路径.md)
  > * [进阶实战/调优排障文档标题](相对路径.md)
  ```
- **相对路径与有效性校验**：所有跳转链接必须精确计算相对当前文档目录的有效相对路径，严禁使用本机绝对路径（如 `/Users/...`），杜绝 404 死链。

## 5. Standard Template Specification (文档标准化模板规范)
- **模板优先原则**：编写新文章或整理文档时，必须优先使用 `./07_Templates/` 下的标准模板：
  - 生产事故与故障复盘：使用 [`./07_Templates/01_生产事故复盘与RCA根因分析模板.md`](../07_Templates/01_生产事故复盘与RCA根因分析模板.md)
  - 深度技术架构专题：使用 [`./07_Templates/02_技术专题深度架构文档模板.md`](../07_Templates/02_技术专题深度架构文档模板.md)
  - 变更与运维规程：使用 [`./07_Templates/03_生产环境运维SOP标准模板.md`](../07_Templates/03_生产环境运维SOP标准模板.md)
  - 技术选型评估：使用 [`./07_Templates/04_技术选型与对比评估模板.md`](../07_Templates/04_技术选型与对比评估模板.md)

## 6. SRE & Database Disaster Recovery Rules (数据库与集群运维红线)
- **MGR 单节点恢复原则**：MGR 集群执行物理恢复时，**严禁在多节点同时执行恢复脚本**；只需在 Node1（主节点）单机恢复后执行 `dba.createCluster('myCluster', {force: true})` 引导集群，Node2 / Node3 必须通过 `cluster.addInstance(..., {recoveryMethod: 'clone'})` 自动物理克隆入群。
- **无主键表治理规范**：MGR 环境中所有表必须具备主键。遇到历史无主键表时，使用 `PRIMARY KEY INVISIBLE`（不可见自增主键）或执行 `./05-Install/mysql/mysql8.0.43_huazhuo_prod/mysql_mgr_fix_pks.sh` 进行治理，禁止对业务产生字段侵入。
- **Router 重新引导规范**：集群强制重建（`createCluster force`）后，MySQL Router 必须重新执行 `--bootstrap ... --force`，方可启动服务。

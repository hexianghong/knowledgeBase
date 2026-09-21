# 待研究选题与攻坚灵感看板 (Research Backlog)

> **使用指南**：
> 1. **极速捕获**：日常突发奇想、生产踩坑或听到新技术时，花 10 秒在下方对应分类追加一行即可。
> 2. **定期转化**：周末或规划期挑出高优先级课题，攻坚完成后输出到 `01_Inbox/` 专题库并修改状态为 `已完成`。
> 3. **状态标记**：`💡 待调研` | `🔄 攻坚中` | `✅ 已沉淀` | `⏸️ 挂起/暂缓`

---

## 🚀 核心攻坚待办总览 (Quick Backlog)

| 编号 | 选题名称 | 领域 | 来源背景 / 触发契机 | 优先级 | 计划输出目标 | 当前状态 |
| :--- | :--- | :--- | :--- | :---: | :--- | :---: |
| **B01** | Linux 3.10 内核 cgroup kmem 内存泄漏与 ENOMEM 彻底根治方案 | Linux 内核 | 生产 Rancher 容器启动报 cgroup mkdir cannot allocate memory | P0 | 输出内核级内存排查与内核参数调优 SOP | 💡 待调研 |
| **B02** | Java NIO Selector 底层 epoll/pipe 句柄机制与 Client 连接池治理 | 高并发架构 | 生产 cloud-proxy 容器句柄暴涨至 17 万故障 | P1 | 梳理 OkHttp/K8s-Client 的长连接池与 Watch 泄露规避指南 | 💡 待调研 |
| **B03** | Kubernetes 证书链（CA/mTLS/Kubeconfig）底层认证机制与无 Rancher 运维 | K8s 云原生 | 生产集群 9443 端口阻断时利用本地 CA 签发管理员证书 | P1 | 沉淀 K8s 离线自愈与 API Server 鉴权深度专题 | 💡 待调研 |
| **B04** | ClickHouse 内存配额调优与高并发向量检索优化实践 | 数据库 | 生产宿主机高负载混跑业务稳定性评估 | P2 | 沉淀 ClickHouse 生产级资源隔离与压测报告 | 💡 待调研 |
| **B05** | AI 在现代 IDE 中的交互运行机制与本地资源动态加载体系 | AI Agent / IDE 架构 | 深入探索现代 AI 编程助手（Antigravity/Cursor等）上下文组装与本地扩展体系 | P1 | 深入剖析 IDE Agentic Loop、LSP/AST 代码上下文切片与本地 Skills/Rules/MCP 加载原理 | 💡 待调研 |
| **B06** | mksglu/context-mode 架构深度剖析与 AI Agent 上下文窗口沙箱优化 | AI Agent / 上下文工程 | 解决 Coding Agent 工具输出撑爆上下文（56KB+ 单次调用）、压缩失忆与 Prompt Cache 击穿难题 | P1 | 深入剖析 98% 压缩率沙箱机制、“Think in Code”范式与 SQLite FTS5+BM25 检索式持久化记忆方案 | 💡 待调研 |

---

## 📌 分领域选题孵化区 (Categorized Ideas)

### 1. 🐧 Linux 内核与操作系统底层
- [ ] **cgroup v1 vs v2 体系演进**：研究 systemd 与 containerd 迁移到 cgroup v2 后的内存控制器、psi（压力停顿信息）表现差异。
- [ ] **Linux 伙伴系统碎片化与透明大页 (THP)**：为什么高吞吐数据库经常要求关闭 THP？底层分配延迟如何用 perf / ftrace 抓取？
- [ ] **网络栈 SoftIRQ 软中断 CPU 飙高排查**：网卡多队列 RSS、RPS/RFS 配置与 NAPI 轮询调优实战。

---

### 2. ☸️ Kubernetes、容器与云原生架构
- [ ] **Kubelet PIDs Limit 与容器句柄上限双层防护**：如何通过 AdmissionWebhook 或 Kubelet 参数限制单个容器的最大 FD 与进程数。
- [ ] **RKE / RKE2 / K3s 架构演变与离线证书自愈体系**：深入研究 Rancher 各代架构中集群证书的自动轮转与故障救援方案。
- [ ] **Calico BGP 路由与大并发长连接跨节点性能调优**：大规模微服务集群下的 conntrack 表爆满与丢包诊断。

---

### 3. 🗄️ 数据库、分布式存储与中间件
- [ ] **MySQL 8.0 隐藏自增主键（Primary Key Invisible）对 MGR 性能的影响**：对大事务与冲突检测器的开销压测。
- [ ] **ClickHouse 分布式表写入合并机制与 I/O 放大优化**：如何解决大量小批量写入导致的 Too many parts 错误。

---

### 4. 🤖 AI Agent、自动化 SRE 与可观测性
- [ ] **AI Coding Agent 上下文窗口保护与沙箱隔离技术（深度参考 `mksglu/context-mode`）**：
  - *Context 膨胀痛点*：解决工具原始输出（Playwright 快照、curl 网页、git log、大文件全量 read）撑爆上下文（40% 快速流失）与压缩导致的“失忆”问题；
  - *“Think in Code” 编程范式变革*：让 LLM 从“数据流处理器”变为“代码生成器”（编写轻量脚本在沙箱中完成过滤/统计，仅将 stdout 结果输出到上下文，减少 100x 消耗）；
  - *长会话连续性与轻量检索架构*：基于 SQLite FTS5 全文索引 + BM25 算法的持久化事件追踪，替代笨重的会话回填与全量重放；
  - *多平台 Hook 拦截与透明路由*：分析 PreToolUse、SessionStart、PreCompact 在 Claude Code、Gemini CLI、Cursor 中的拦截重定向机制；
  - *大模型 Prompt Cache（KV-Cache）保护*：避免动态时间戳、乱序工具定义造成的 Prefix Cache 击穿。
- [ ] **AI 助手在现代 IDE 中的上下文感知与调度机制**：
  - *Context 组装*：当前活跃文件、光标上下文、编辑历史、LSP 符号表与 Repo Map 拓扑图切片算法；
  - *Agentic Loop 运行机制*：ReAct 循环、规划模式（Planning Mode）、工具调用（Tool Use）与沙箱执行拦截；
  - *代码变更渲染*：行内 Ghost Text 补全（FIM 机制）、虚拟 Diff 视图计算与原子替换（Replace Chunk）。
- [ ] **IDE 本地扩展与自定义配置的动态发现与加载机制**：
  - *规则注入体系*：工作区级（`.agents/rules/`、`AGENTS.md`、`GEMINI.md`）与全局级（`~/.config/...`）规则加载优先级与冲突裁决；
  - *Skills / Plugins 机制*：按需懒加载（Lazy Load）、Prompt Frontmatter 元数据驱动激活机制；
  - *本地 MCP 通信机制*：Model Context Protocol 基于 stdio / SSE 的本地进程间通信与工具注册。
- [ ] **Prometheus 容器句柄趋势告警（Predict/Deriv）优化**：将写死的硬阈值改为基于动态斜率与增长速率预测，提前 24 小时预警句柄泄漏。
- [ ] **基于 eBPF 的容器系统调用异常捕获**：自动追踪未被 close 的 FD 来源于哪一行应用代码。

---

## 📝 灵感捕获备忘板（草稿随记区）

> *平时在手机或终端有灵光一现的碎片想法，可直接粘贴在这里，后续再整理进上方表格：*

* 2026-09-16：研读开源热门项目 [`mksglu/context-mode`](https://github.com/mksglu/context-mode)，其“沙箱隔离（98% 压缩率）+ Think in Code + SQLite FTS5/BM25 检索式记忆”思想对解决大模型上下文膨胀与保护 Prompt Cache 极具实战指导价值，已录入 B06 攻坚清单。
* 2026-09-14：排查发现容器运行了 2 年多没重启，思考：生产环境是否有必要推行“Pod 最大存活周期（Pod TTL）”或季度滚动？

---

> [!TIP] 💡 成果流转与归档导航
>
> * 攻坚成果沉淀至深度专题：[`../../01_Inbox/README.md`](../../01_Inbox/README.md)
> * 沉淀为故障复盘实战案例：[`../../06_Troubleshooting/README.md`](../../06_Troubleshooting/README.md)

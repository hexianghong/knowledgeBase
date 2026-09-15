# 【课题立项】AI 在现代 IDE 中的运行机制与本地动态加载体系深度剖析

---

## 1. 调研背景与核心痛点 (Why)

随着以 **Google Antigravity、Cursor、GitHub Copilot Workspace、Windsurf** 为代表的新一代 AI 原生 IDE / 智能编程助手的兴起，软件开发模式正从传统的“代码手写”演进为“智能体人机协同（Pair Programming / Agentic Coding）”。

在日常使用中，我们经常观察到 AI 能够精准感知我们当前打开的文件、光标停留的位置、甚至能自动读取我们本地配置的 `.agents/` 规则、自动调用本地终端和文件系统。

本课题旨在**深入拆解其背后的工程实现架构**，搞清楚：
1. **AI 是如何“看见”并“理解”大型工程代码的？**
2. **IDE 内部的 Agentic 循环（推理 ──► 规划 ──► 工具调用 ──► 验证）是如何运作的？**
3. **本地规则（Rules）、自定义技能（Skills）、MCP 服务是如何被 IDE 动态发现、按需加载和注入上下文的？**

---

## 2. 核心架构全景：AI 在 IDE 中的三大核心支柱

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                             IDE 宿主环境 (VS Code / Electron)               │
├─────────────────────────────────────────────────────────────────────────────┤
│ 1. 上下文感知层 (Context Perception)                                        │
│    ├── 活跃编辑器状态: 当前文件、高亮代码块、光标 Cursor 坐标              │
│    ├── AST 语法分析 (Tree-sitter): 函数定义、类继承结构                     │
│    ├── 语言服务器协议 (LSP): Go-to-Definition、Find-References 符号图谱      │
│    └── 仓库全局地图 (Repo Map): PageRank 权重缩略代码树                      │
├─────────────────────────────────────────────────────────────────────────────┤
│ 2. 智能体决策与调度引擎 (Agentic Loop & Tool Execution)                    │
│    ├── 规划模式 (Planning Mode): implementation_plan.md 状态机机管           │
│    ├── 模型交互协议: Function Calling / Tool Calls / 流式输出 (Streaming)   │
│    ├── 虚拟文件补丁引擎: Fast Diff、Multi-Replacement Chunks 原子合并      │
│    └── 安全沙箱终端: Standard Sandbox (隔离环境) vs Bypass (主机实操)       │
├─────────────────────────────────────────────────────────────────────────────┤
│ 3. 本地自定义扩展与外挂加载系统 (Local Customization & MCP)                 │
│    ├── 多级规则继承 (Rules): 全局配置 (~/.config) ◄──► 工作区 (.agents)    │
│    ├── 技能按需动态装配 (Skills): YAML Frontmatter 语义匹配 + 按需延迟加载  │
│    └── 模型上下文协议 (MCP): 本地子进程守护 + JSON-RPC over stdio 双向通信  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. 核心解密要点 (Key Research Topics)

### 模块一：AI 如何在 IDE 中高效理解代码上下文？

1. **光标与局部上下文提取 (Cursor Context)**：
   * 不是将整个项目发给大模型，而是通过“滑动窗口 + 关键片段提取”；
   * 采用 **FIM (Fill-In-The-Middle)** 训练格式，截取光标前 2000 字符（Prefix）与光标后 1000 字符（Suffix），让模型进行中间预测。
2. **仓库地图压缩技术 (Repo Map / Skeleton Tree)**：
   * 基于 **Tree-sitter** 解析全工程文件，丢弃函数实现体，仅保留：函数名、入参出参类型、类签名；
   * 利用类似 **PageRank 算法**，按被依赖和引用频率为符号打分，在极有限的 Token 内给大模型构建全局架构拓扑。
3. **混合检索 (Hybrid Retrieval: BM25 + Vector + LSP)**：
   * 文本检索（Ripgrep / BM25）：极速匹配特定常量、报错字符串；
   * 语义向量（Embedding + 本地向量库）：模糊语义概念搜索；
   * LSP 跨文件引用跳转：确定某接口的所有实现类。

---

### 模块二：本地配置与扩展内容的动态加载机制（How Customizations Work）

#### 1. 规则注入机制 (Rules Engine)
* **分层优先级（Loading Priority）**：
  * **全局规则（Global Rules）**：存放在用户主目录（如 `/Users/<user>/.gemini/config/rules/`），对该用户的所有项目生效；
  * **工作区规则（Workspace Rules）**：存放在当前项目根目录（如 `.agents/rules/` 或 `GEMINI.md`、`AGENTS.md`），覆盖或补充全局规则；
* **动态注入时机**：在每个 Turn（轮次）构建 System Prompt 时，由 IDE 扫描工作区配置，将有效的 Markdown 规则作为静态约束（System Instruction）拼装至上下文头部。

#### 2. 技能按需延迟加载 (Skills Lazy-Loading)
* **设计目的**：避免一次性将数十个复杂技能的详细长文档全部塞入 Prompt 导致上下文爆炸；
* **两阶段装配原理**：
  1. **元数据注册阶段**：IDE 仅读取各技能目录下的 `SKILL.md` 的 YAML Frontmatter（包含 `name` 和 `description`），将极短的摘要注册在 System Prompt 中；
  2. **按需激活阶段**：当模型判断当前任务需要该技能时，通过执行 `view_file` 显式读取该技能的详细指南，临时加载至上下文工作区。

#### 3. 本地 MCP (Model Context Protocol) 进程加载机制
* **架构解耦**：IDE 不再内置所有数据库、Git、K8s 的连接代码，而是通过统一的开放协议连接外部工具；
* **本地加载原理**：
  * IDE 读取配置（如 `mcp_config.json`），在宿主机上启动子进程（如 `node server.js` 或 `python server.py`）；
  * IDE 与 MCP Server 之间通过 **标准输入输出（`stdio`）** 传递 **JSON-RPC 2.0** 消息；
  * MCP 协议向大模型暴露三类基本原语：**Tools（工具函数）**、**Resources（只读资源）**、**Prompts（预置提示词模板）**。

---

## 4. 阶段攻坚路线与实验规划 (Roadmap)

- [ ] **Stage 1 - 逆向与源码分析**：分析主流开源 AI 插件（如 Continue.dev、Aider、Roo Code）的客户端核心架构与 Prompt 拼装流水线。
- [ ] **Stage 2 - 本地 MCP 编写实操**：基于 Python/Node.js 手写一个最简的本地 MCP Server，并在 IDE 中完成挂载与工具调用。
- [ ] **Stage 3 - 上下文窗口预算分配研究**：总结大模型在 32K / 128K / 1M 窗口下，System Prompt、Memory、Chat History、Repo Map 的最佳 Token 预算切分模型。
- [ ] **Stage 4 - 输出深度专题文档**：在 `01_Inbox/04-AI/` 下输出完整的《企业级 AI 编程助手与 IDE Agent 底层架构指南》。

---

> [!TIP] 💡 关联技术与延伸阅读
>
> * [待研究选题与攻坚灵感看板](./BACKLOG.md)
> * [AI 智能体记忆库](../../LEARNING.md)
> * [工作区智能体规范与本地规则](../../.agents/AGENTS.md)

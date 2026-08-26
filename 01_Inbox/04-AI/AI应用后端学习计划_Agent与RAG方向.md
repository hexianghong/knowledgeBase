# AI 应用后端开发学习计划 (Agent 与 RAG 方向)

基于你的 Python、Golang 以及 DevOps 背景，本计划旨在帮助你快速掌握企业级 AI 应用开发（尤其是 RAG 和 Agent），并最终能将这些 AI 应用进行工程化落地。

---

## 阶段一：基础重塑 —— 掌握大模型的“原语” (预计 1-2 周)
这个阶段的核心是跳出传统的 API 调用思维，理解大模型是如何工作的，以及如何通过提示词和工具调用来控制它。

### 1. 核心大模型 API 与 Prompt 进阶
*   **学习目标**：熟练调用主流大模型 API（如 OpenAI、DeepSeek、阿里云通义），掌握结构化提示词。
*   **重点内容**：
    *   流式输出 (Streaming) 与长连接 (SSE) 的处理。
    *   System Prompt、User Prompt、Assistant Prompt 的角色区分与最佳实践。
    *   **Function Calling（工具调用/函数调用）**：**必学核心！** 这是开发 Agent 的基础，理解模型如何输出 JSON 参数来触发本地函数。
*   **实践项目**：用 Python (FastAPI) 或 Golang (Gin) 写一个支持历史上下文记忆和流式输出的终端聊天机器人。

---

## 阶段二：RAG (检索增强生成) 核心工程 (预计 2-3 周)
RAG 是目前解决大模型幻觉、接入私有数据的企业级标准方案。你的重点应放在数据流转和工程实现上。

### 1. 数据接入与处理 (Data Ingestion)
*   **学习目标**：掌握将各种格式的文件转化为模型可理解的数据。
*   **重点内容**：
    *   文档解析（PDF、Word、Markdown 解析库如 Unstructured）。
    *   **Chunking (分块策略)**：按字符切分、按语义切分、父子文档切分策略（这对最终 RAG 的准确率影响巨大）。

### 2. 向量化与向量数据库 (Embedding & Vector DB)
*   **学习目标**：理解 Embedding，熟练操作至少一款主流向量数据库。
*   **重点内容**：
    *   调用 Embedding 模型（如 BGE 系列）将文本转化为多维向量。
    *   **Milvus 或 Qdrant** 的部署与 CRUD 操作（结合你的运维背景，建议用 Docker 跑起来）。
    *   近似最近邻搜索（ANN）的简单原理与余弦相似度。

### 3. 高级检索策略 (Advanced Retrieval)
*   **重点内容**：多路召回（向量检索 + 关键词 BM25 检索）、重排模型（Reranker，如 BGE-Reranker）的使用。
*   **实践项目**：构建一个“个人知识库问答 API”。输入一个 PDF 文件夹，通过接口可以提问并返回带有引用出处的答案。

---

## 阶段三：Agent (智能体) 与工作流开发 (预计 2-3 周)
让大模型从“回答问题”进化到“执行任务”。

### 1. 掌握主流 Agent 框架
*   **学习目标**：理解 Agent 的运转逻辑，掌握至少一种主流框架。
*   **重点内容**：
    *   **LangChain**：了解其核心组件（Chains, Tools, Memory, Retrievers），但不要被它过度封装的概念绑架。
    *   **LangGraph**（推荐）：目前最火的基于图（Graph）的状态机工作流框架，非常适合构建复杂、可控的 Agent 逻辑。
    *   **ReAct 模式**：理解 Agent 是如何通过“思考 (Thought) -> 动作 (Action) -> 观察 (Observation)”循环来解决复杂问题的。

### 2. 多智能体协作 (Multi-Agent)
*   **重点内容**：了解 AutoGen 或 CrewAI，学习如何让多个赋予不同系统提示词的 Agent 协同工作（例如一个写代码，一个做测试）。
*   **实践项目**：开发一个“DevOps 助手 Agent”。给它提供查日志、重启 Pod、查询 K8s 状态的 Tools（利用你的老本行）。当你输入“服务 A 为什么报错”，Agent 能自动调取日志、分析原因并给出修复建议。

---

## 阶段四：工程化落地与 CI/CD (你的舒适区) (持续进行)
将写好的 AI 原型转化为企业级高可用服务。这是你相比纯算法工程师最大的优势。

*   **性能调优**：如何处理大模型接口的高延迟？（异步处理、队列 Celery/Kafka）。
*   **监控与可观测性 (LLMOps)**：接入 LangSmith 或 Phoenix，监控 RAG 的召回率、大模型的 Token 消耗成本、用户反馈。
*   **部署架构**：用 Go 编写一个网关，代理 Python 实现的 RAG 核心逻辑，提供高并发的对外 API。将整个系统 Docker 化并通过 CI/CD 流水线部署到 K8s。

---

## 🏁 总结与里程碑
整个计划大概需要 6-8 周时间。
*   **Milestone 1**：能用代码稳定调用带 Function Calling 的大模型 API。
*   **Milestone 2**：跑通一个私有数据的 RAG 查询接口。
*   **Milestone 3**：完成一个能实际调用本地脚本（如查询 K8s 状态）的 Agent 工具。

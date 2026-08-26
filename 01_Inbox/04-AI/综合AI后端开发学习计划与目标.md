# 综合 AI 后端开发学习计划与目标 (v2)
> 结合 DevOps/Python/Go 背景 + 《AI 智能体实战速成指南 (ai-agents-from-zero)》主线教材。
> 所有资料链接均经过三轮搜索验证，确保为当前社区公认的高质量内容。

## 🎯 总体目标
通过 **8-10周** 系统学习，转型为 **AI 智能体 / 大模型应用开发工程师**。
能手写高可用的 RAG 和多智能体工作流，并将其 Docker 化部署到生产环境。

---

## 📅 阶段一：基础认知与 API 核心 (预计 1-2 周)

**验收标准**：用 Python (FastAPI) 写一个支持多轮对话、流式输出、并能通过 Function Calling 调用本地函数的聊天后端。

---

### 1.1 Prompt Engineering (提示词工程)

**⭐ 首选 · 体系化学习**
- **Prompt Engineering Guide (官方中文版)**
  - 链接：https://www.promptingguide.ai/zh
  - GitHub：https://github.com/dair-ai/Prompt-Engineering-Guide （⭐ 77k+）
  - 说明：全球最权威的提示词工程指南，DAIR.AI 出品。涵盖 Zero-shot、Few-shot、思维链 (CoT)、自我一致性 (Self-Consistency)、ReAct 等所有核心技术，有完整的中文翻译站点。**从这里开始打基础。**

**📘 进阶 · 结构化提示词方法论**
- **LangGPT**
  - GitHub：https://github.com/langgptai/LangGPT
  - 说明：中文社区最实用的结构化提示词框架。用模块化模板 (Role/Profile/Rules/Workflow) 像写代码一样设计 Prompt，各大模型原生兼容。学完上面的基础后，用这个框架来规范你的提示词写法。

---

### 1.2 Function Calling / Tool Calling (工具调用)

> **这是整个学习计划中最重要的基础。** 大模型不会自己执行代码，它只负责输出你要执行的函数名和参数 (JSON)，由你的代码执行后再把结果告诉它。

**⭐ 首选 · 权威文档 (必读)**
- **OpenAI 官方文档：Function Calling**
  - 链接：https://platform.openai.com/docs/guides/function-calling
  - 说明：万剑归宗。大部分国产模型 (Qwen, DeepSeek) 的接口都完全兼容此格式。看懂这篇，就懂了行业标准。

**⭐ 首选 · 手写实战 (必做)**
- **OpenAI Cookbook**
  - GitHub：https://github.com/openai/openai-cookbook
  - 重点文件：`examples/How_to_call_functions_with_chat_models.ipynb`
  - 说明：OpenAI 官方维护的 Jupyter Notebook 实战教程。手把手教你手写 JSON Schema、处理多轮调用闭环和并行工具调用。**强烈建议手敲一遍，不要上来就用 LangChain 的封装。**

**📘 进阶 · 结构化输出**
- **OpenAI Structured Outputs 文档**
  - 链接：https://platform.openai.com/docs/guides/structured-outputs
  - 说明：设置 `strict: true` 可强制模型输出完全符合你定义的 JSON Schema，大幅减少解析错误。生产环境必备。

---

### 1.3 大模型 API 调用基础

- **OpenAI API Reference (Chat Completions)**
  - 链接：https://platform.openai.com/docs/api-reference/chat
  - 说明：理解 `stream: true` 的工作机制，System/User/Assistant/Tool 四种角色的区分。

- **DeepSeek API 文档**
  - 链接：https://api-docs.deepseek.com/
  - 说明：国产高性价比模型，完全兼容 OpenAI 格式。国内网络环境下的首选练手对象。

---

## 📅 阶段二：Agent 开发框架与工作流 (预计 3-4 周)

**验收标准**：跟着 `ai-agents-from-zero` 的实战项目（"电商问数" 或 "深度研搜"），手敲一遍基于 LangGraph 的多智能体协同代码，并能独立修改工作流逻辑。

---

### 2.1 LangChain 核心 (LCEL / Tools / Memory)

> **避坑提醒**：不要学 2023-2024 年的老旧代码（如 `AgentExecutor`），官方已全面转向 LangGraph 作为 Agent 运行核心。LangChain 现在的定位是"基础设施工具箱"。

**⭐ 首选 · 官方文档**
- **LangChain Python 官方文档**
  - 链接：https://python.langchain.com/docs/
  - 说明：英文原版，始终是最新最准确的。重点学习 LCEL (LangChain Expression Language) 管道语法、`@tool` 装饰器、以及 Memory 模块。

- **LangChain 中文文档**
  - 链接：https://langchain.com.cn/
  - 说明：社区维护的中文翻译版。当英文版看不懂时辅助参考，但注意可能落后于原版。

**📘 参考 · 开源教程**
- **LangChain-OpenTutorial**
  - GitHub：https://github.com/LangChain-OpenTutorial/LangChain-OpenTutorial
  - 说明：全球范围内广受好评的 LangChain 开源教程项目，内容深度贴合官方最新版本，含大量 Notebook 实战。

---

### 2.2 LangGraph 工作流 (核心重点！)

> **LangGraph 是本计划的绝对核心。** 它用状态图 (StateGraph) 编排 Agent 逻辑——定义 State（状态）、Nodes（节点）、Edges（边）——与你以前写 CI/CD Pipeline 的思维高度契合。

**⭐ 首选 · 官方文档 (必读)**
- **LangGraph 官方文档**
  - 链接：https://langchain-ai.github.io/langgraph/
  - 说明：最权威的 API 参考和概念指南。重点看 Concepts 章节中的 StateGraph、Checkpointing、Human-in-the-loop 和 Multi-agent 部分。

**⭐ 首选 · 实战项目 (必做)**
- **ai-agents-from-zero 实战项目 · 电商问数 (NL2SQL + LangGraph)**
  - 教程：https://didilili.github.io/ai-agents-from-zero/#/实战项目-电商问数/0-前言
  - 源码：https://github.com/didilili/shopkeeper-agent
  - 说明：你正在学的主线教材中的完整项目，含可运行源码。

- **ai-agents-from-zero 实战项目 · 深度研搜 (DeepAgents 多智能体)**
  - 教程：https://didilili.github.io/ai-agents-from-zero/#/实战项目-深度研搜/0-前言
  - 源码：https://github.com/didilili/deepsearch-agents
  - 说明：多智能体协作实战项目，含完整可运行源码。

**📘 辅助 · 中文 Notebook 教程**
- **NanGePlus/LangChain_V1_Test**
  - GitHub：https://github.com/NanGePlus/LangChain_V1_Test
  - 说明：基于 LangChain V1 的全家桶开发实践，含 RAG、MCP、多智能体协同等中文代码示例。B 站有配套视频讲解。

---

### 2.3 MCP (Model Context Protocol)

**⭐ 首选 · 官方文档**
- **MCP 官方文档**
  - 链接：https://modelcontextprotocol.io/
  - 说明：Anthropic 官方出品，最权威。理解 Host/Client/Server 三者关系，以及 Tools、Resources、Prompts 三大核心原语。

**⭐ 首选 · 官方参考实现**
- **modelcontextprotocol/servers (官方参考服务器)**
  - GitHub：https://github.com/modelcontextprotocol/servers
  - 说明：官方维护的参考实现合集（Filesystem、Git、PostgreSQL 等），是学习如何写一个标准 MCP Server 的最佳范例。

- **modelcontextprotocol/python-sdk (官方 Python SDK)**
  - GitHub：https://github.com/modelcontextprotocol/python-sdk
  - 说明：使用 `FastMCP` 高层封装，`@mcp.tool()` 装饰器将普通 Python 函数转化为 LLM 可调用的工具，写法类似 FastAPI 路由。

**📘 参考 · 社区资源**
- **awesome-mcp-servers**
  - GitHub：https://github.com/appcypher/awesome-mcp-servers
  - 说明：精选的 MCP Server 实现列表，涵盖各种场景（数据库、API、文件系统等），适合学习代码结构和寻找灵感。

---

### 2.4 ReAct 模式与多智能体

**📘 理论基础**
- **ReAct 论文原文**
  - 链接：https://arxiv.org/abs/2210.03629
  - 说明：理解 Agent "思考 (Thought) → 动作 (Action) → 观察 (Observation)" 循环的理论来源。建议至少读一遍摘要和方法论部分。

- **LangGraph Multi-Agent 官方概念文档**
  - 链接：https://langchain-ai.github.io/langgraph/concepts/multi_agent/
  - 说明：官方文档中的多智能体章节，讲解 Supervisor（监督者）和 Swarm 等协作模式。

---

## 📅 阶段三：RAG 检索增强工程 (预计 2 周)

**验收标准**：写一个 Python 接口，传入一个包含表格的 PDF 文件，能精准回答其中的数据并附带引用出处。

---

### 3.1 RAG 全链路教程 (必学)

**⭐ 首选 · 体系化学习**
- **NirDiamant/RAG_Techniques**
  - GitHub：https://github.com/NirDiamant/RAG_Techniques （⭐ 28.8k+）
  - 说明：**当前全球 RAG 教育领域的黄金标准。** 包含 Notebook 式教程，覆盖从基础检索、高级 Chunking 策略、混合检索、到 Agentic RAG 和评估的完整技术栈。**从这里开始你的 RAG 学习。**

**📘 参考 · 生产级资源清单**
- **awesome-rag-production**
  - GitHub：https://github.com/Yigtwxx/awesome-rag-production
  - 说明：专注于**生产级** RAG 系统的精选清单，覆盖部署、监控、安全和扩展等工程侧问题。适合从原型到上线阶段查阅。

---

### 3.2 Embedding 向量化模型

**⭐ 首选 · 模型选用**
- **BGE-M3 (BAAI)**
  - HuggingFace：https://huggingface.co/BAAI/bge-m3
  - 说明：智源研究院出品，中文最强的通用 Embedding 模型之一。支持密集向量 (Dense)、稀疏向量 (Sparse) 和多向量 (Multi-Vector) 三种检索方式，是做混合检索的标配。

**📘 参考 · 选型依据**
- **MTEB 排行榜 (Embedding 模型排名)**
  - 链接：https://huggingface.co/spaces/mteb/leaderboard
  - 说明：全球 Embedding 模型评测榜单，可按中文子榜筛选，是选型的权威依据。

---

### 3.3 向量数据库 (Milvus)

**⭐ 首选 · 官方文档**
- **Milvus 官方文档 (中文)**
  - 链接：https://milvus.io/docs/zh
  - 说明：重点看 "快速开始"、"嵌入函数 (Embedding Functions)" 和 "混合搜索 (Hybrid Search)" 章节。从 Milvus Lite (pip install 即可) 开始开发，生产迁移到 Docker Compose 部署的 Standalone 版本。

**⭐ 首选 · 官方实战代码**
- **Milvus Bootcamp (官方示例集)**
  - GitHub：https://github.com/milvus-io/bootcamp
  - 说明：Milvus 官方维护的实战代码合集，包含 RAG 完整链路实现、混合检索、图片搜索等多种场景的 Notebook。

---

### 3.4 重排模型 (Reranker)

- **BGE-Reranker-v2-m3 (BAAI)**
  - HuggingFace：https://huggingface.co/BAAI/bge-reranker-v2-m3
  - 说明：中文最佳重排模型，用于对向量检索 + BM25 粗排结果做精细化排序，显著提升 RAG 最终准确率。生产环境的企业级标配。

---

## 📅 阶段四：工程落地、运维与高并发 (预计 2 周)

**验收标准**：将 RAG 或 Agent 服务全量 Docker 化，能在 K8s 上一键拉起，Go 网关层带有 SSE 流式转发和并发限流。

---

### 4.1 大模型私有化部署

**⭐ 开发阶段 · Ollama**
- **Ollama 官方文档**
  - 链接：https://ollama.com/
  - GitHub：https://github.com/ollama/ollama （⭐ 130k+）
  - 说明：一行命令拉起 Llama3、Qwen2.5 等主流模型。适合本地开发和 Prompt 调试。Docker 部署加 `--gpus all` 即可。

**⭐ 生产阶段 · vLLM**
- **vLLM 官方文档**
  - 链接：https://docs.vllm.ai/
  - GitHub：https://github.com/vllm-project/vllm （⭐ 50k+）
  - 说明：企业级高并发推理引擎，核心技术 PagedAttention。接口完全兼容 OpenAI。生产环境首选。重点关注文档中的 Docker 部署、量化 (AWQ/FP8)、张量并行 (tensor-parallel-size) 和 K8s 部署章节。

---

### 4.2 Golang AI 网关 (SSE 流式 + 高并发)

> **这是你的核心竞争力所在。** 用 Go 写 AI 网关，处理大模型流式输出的高并发场景。

**⭐ 首选 · 源码学习**
- **Bifrost (高性能 Go AI 网关)**
  - GitHub：https://github.com/maximhq/bifrost
  - 说明：**当前 Go 语言 AI 网关的行业标准。** 性能极致（5000 RPS 仅 ~11µs 开销），原生支持 MCP、语义缓存 (Semantic Cache)。学习 Go 如何处理大规模并发 SSE 流式转发、Context 级联取消和内存池优化。

**📘 参考 · 轻量替代**
- **GoModel (轻量级 AI 网关)**
  - GitHub：https://github.com/ENTERPILOT/GoModel
  - 说明：轻量级、OpenAI 兼容的 AI 网关，支持流式输出、链路监控、成本跟踪和速率限制。代码量小，适合快速上手理解 AI 网关的核心架构。

**📘 参考 · Go AI 生态资源**
- **awesome-golang-ai**
  - GitHub：https://github.com/promacanthus/awesome-golang-ai
  - 说明：Go 在 AI 领域的实践资源汇总，涵盖框架、库和架构建议。

---

### 4.3 LLMOps 观测与评测

**⭐ 首选 · 开源自托管方案**
- **Langfuse (开源 LLM 可观测性平台)**
  - GitHub：https://github.com/langfuse/langfuse （⭐ 10k+）
  - 官网：https://langfuse.com/
  - 说明：**框架中立**（支持 LangChain、LlamaIndex、OpenAI SDK 等），支持 MIT 协议可本地 Docker 部署。提供链路追踪 (Tracing)、Prompt 管理、评估和成本监控。数据不出本地，合规性强。**对于有 DevOps 背景的你，自托管方案是更好的选择。**

**📘 参考 · LangChain 生态方案**
- **LangSmith**
  - 官网：https://smith.langchain.com/
  - 说明：LangChain 官方出品，与 LangChain/LangGraph 生态深度集成。追踪、调试、评估一站式体验。如果你深度使用 LangChain 生态，这是最丝滑的选择。

**⭐ 首选 · RAG 评估框架**
- **RAGAS**
  - GitHub：https://github.com/explodinggradients/ragas
  - 文档：https://docs.ragas.io/
  - 说明：**RAG 评估的行业标准库。** 核心指标：Faithfulness (忠实性)、Answer Relevancy (答案相关性)、Context Precision/Recall (上下文精准度/召回率)。可与 Langfuse/LangSmith 集成实现持续监控。

---

## 🚀 护城河建议

1.  **别人学业务，你学底层架构**：当教程教怎么写 Python 业务逻辑时，你要顺带思考——如果同时有 1000 个人调用这个 Agent，内存会不会爆？用 Go 怎么做一层中间件来拦住恶意请求？
2.  **避免陷入"调参"泥潭**：教程中的微调（LoRA/PEFT）内容只做了解即可。**把精力死死钉在"工程化落地、编排与流水线建设"上**，这才是你拿高薪的筹码！
3.  **评估驱动开发**：不要凭"感觉"优化 Prompt 和 RAG，用 RAGAS + Langfuse 量化你的每一次改动是变好了还是变差了。

# 阶段一：基础重塑 —— API 与 Function Calling 学习资料库

为了让你能够系统地掌握大模型的核心“原语”（尤其是工具调用 Function Calling），我为你精选了针对 Python 和 Golang 开发者的实战学习资源。

遵守**顶级规范**，本资料库已保存在项目目录中，你可以将其作为阶段一学习的**索引和书签**。

---

## 一、 核心概念与原理必读
在写代码之前，彻底弄懂 Function Calling 的数据流转机制（大模型不会自己执行代码，它只负责输出你要执行的函数名和参数，由你执行完后再把结果告诉它）。

1.  **[OpenAI 官方文档：Function Calling (权威指南)](https://platform.openai.com/docs/guides/function-calling)**
    *   **理由**：万剑归宗，大部分开源大模型（如 Qwen, DeepSeek）的接口都完全兼容 OpenAI 的格式。看懂了官方文档的例子，就懂了整个行业的标准。
2.  **[CSDN：大模型 Function-Calling 超全详解](https://blog.csdn.net/qq_40918859/article/details/136067056)** （或类似架构解析文章）
    *   **理由**：中文社区里将原理剖析得很透彻，通常包含“天气查询”这种最经典的 5 步工作流演示。

---

## 二、 Python 开发者资源 (极速构建原型)
Python 是大模型生态的第一语言，库最全，更新最快。

### 1. 必学实战代码库
*   **[LangChain 官方文档 - Tools & Tool Calling](https://python.langchain.com/v0.1/docs/modules/tools/)**
    *   **建议**：别学早期的 Agent 封装，直接看现在的 `@tool` 装饰器和 `bind_tools` 的用法，这是目前用 Python 快速构建工具库最优雅的方式。
*   **[OpenAI Cookbook (GitHub)](https://github.com/openai/openai-cookbook)**
    *   **建议**：里面有一个专栏叫 `How_to_call_functions_with_chat_models.ipynb`，这是最原汁原味的 Jupyter 笔记本实战教程，手把手教你手写 JSON 交互逻辑，**强烈建议手敲一遍，不要直接依赖 LangChain**。

### 2. 优质开源脚手架参考
*   **[llmfunctionclient](https://github.com/jimmymills/llmfunctionclient)**
    *   **用途**：一个非常轻量级的 Python 库，用于学习如何将普通的 Python 函数（通过类型提示 Type Hints）自动转化为 OpenAI 需要的 JSON Schema 格式。

---

## 三、 Golang 开发者资源 (工程化与高并发)
用 Go 开发 AI 后端的难点在于强类型系统如何优雅地处理大模型返回的动态 JSON。

### 1. 必学博客与实战思路
*   **[腾讯云开发者社区：给 AI 装上“手”：Go 语言 Function Calling 实践](https://cloud.tencent.com/developer/article/2381283)**
    *   **理由**：对于 Go 开发者来说，手写 JSON Schema 非常痛苦。这篇文章深入浅出地讲解了如何利用 Go 的 `Struct Tag` 和反射（Reflection）机制，自动生成大模型所需的工具描述。
*   **[秀才的进阶之路：Go语言调用大模型 API 实战](https://segmentfault.com/a/1190000044577881)**
    *   **理由**：更偏向工程化，涵盖了并发控制、流式返回（Stream）、超时处理等 DevOps 人员最关注的线上问题。

### 2. 优秀的 Go 语言 AI 框架源码学习
*   **[graft (GitHub)](https://github.com/Delavalom/graft)**
    *   **用途**：一个零第三方 SDK 依赖、强类型的 Go 框架。你可以通过阅读它的源码，学习如何在 Go 中优雅地封装针对多个大模型厂商（OpenAI, Anthropic）的 Function Calling 接口。
*   **[pi-agent-go (GitHub)](https://github.com/amit-timalsina/pi-agent-go)**
    *   **用途**：一个极简的 Go Agent 框架，适合学习如何用 Go 来实现 Agent 的并发执行和流式状态流转。

---

## 🛡️ 阶段一避坑指南（运维老兵忠告）

作为具备 DevOps 经验的开发者，你在写 Function Calling 时必须守住以下底线：

1.  **安全防护（不要搞出 RCE 漏洞）**：**绝对不要**使用类似 `eval()` 或者通过直接拼凑 Shell 命令的方式来执行模型返回的函数名。必须在代码里写死一个映射表（字典/Map），模型返回的名字只能用来匹配这个映射表中的方法。
2.  **死循环控制**：给你的 Agent 执行工具设置一个 `Max Steps`（最大执行步数）。大模型有时候会变笨，在一个错误上反复重试，你要在外部强制熔断它。
3.  **拥抱 Strict Mode (结构化输出)**：大模型返回的 JSON 有可能少个括号或者字段名拼错。现在很多 API（包括 OpenAI）支持 `Structured Outputs` 或 `strict: true` 开启强制模式，能大大减少你用 Go 解析 JSON 报错的概率。

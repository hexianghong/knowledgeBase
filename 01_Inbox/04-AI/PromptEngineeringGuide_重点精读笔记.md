# Prompt Engineering Guide 重点内容精读笔记
> 来源：https://www.promptingguide.ai/zh
> 本文档提取了 6 个与你学习路线最相关的核心章节，包含原文的关键概念、示例和代码。

---

## 一、少样本提示 (Few-Shot Prompting)

### 核心概念
大模型具备零样本 (Zero-shot) 能力，但面对复杂任务时效果不佳。**少样本提示 (Few-shot) 通过在提示词中提供几个"示例"来引导模型"照葫芦画瓢"**，实现上下文学习 (In-context Learning)。

### 关键示例

**教模型学一个虚构的新词：**
```
"whatpu"是一种生活在坦桑尼亚的毛茸茸小动物。使用 whatpu 造句：
我们在非洲旅行时看到了这些非常可爱的 whatpus。

"farduddle"的意思是快速上下跳跃。使用 farduddle 造句：
```
输出：`当我们赢了比赛，大家都开始 farduddle 来庆祝。`

→ 只给了 1 个示例 (1-shot)，模型就学会了。对于更难的任务，可以增加到 3-shot、5-shot、10-shot。

### 重要发现 (来自 Min et al., 2022)
- 示例中**标签空间和输入文本的分布**比标签本身是否正确更重要。
- 即使给了**随机标签**（把"正面"标成"负面"），只要**格式一致**，模型仍然能给出正确答案。
- 从真实标签分布中随机采样比均匀分布更有效。

### 局限性
Few-shot 对复杂推理任务（如数学计算）效果不佳。例如判断"一组数中的奇数之和是否为偶数"这种需要多步推理的任务，即使给了 4 个示例，模型仍然答错。→ 这就引出了下一个技术：**链式思考 (CoT)**。

### 💡 对你的价值
写后端 API 时，给大模型的 System Prompt 中带上 2-3 个"输入→输出"的示例，能大幅提升返回格式的稳定性（比如让它稳定输出 JSON）。

---

## 二、链式思考 CoT (Chain-of-Thought Prompting)

### 核心概念
**CoT 通过在示例中展示"推理过程"，让模型学会分步思考。** 这是解决算术、常识推理等复杂任务的关键技术。

### 关键示例

**不用 CoT（直接问，答错了）：**
```
问：我去市场买了 10 个苹果。给了邻居 2 个，给了修理工 2 个，又买了 5 个，吃了 1 个。我还剩几个？
答：11 个苹果  ← 错误！
```

**用 Zero-shot CoT（只需加一句"让我们一步步思考"）：**
```
问：我去市场买了 10 个苹果。给了邻居 2 个，给了修理工 2 个，又买了 5 个，吃了 1 个。我还剩几个？

让我们一步步思考。

答：
首先，你从 10 个苹果开始。
你给了邻居 2 个，修理工 2 个，还剩 6 个。
然后又买了 5 个，变成 11 个。
最后吃了 1 个，所以还剩 10 个。← 正确！
```

### 两种用法

| 用法 | 做法 | 适用场景 |
|---|---|---|
| **Few-shot CoT** | 在示例中展示完整的推理步骤 | 有足够的示例可以参考时 |
| **Zero-shot CoT** | 在提示词末尾加上"让我们一步步思考" | 没有示例时，快速提升复杂任务准确率 |

### 自动化 CoT (Auto-CoT)
手写推理链很费时间。Zhang et al. (2022) 提出 Auto-CoT：
1. **问题聚类**：把数据集中的问题自动分成几个类别
2. **演示采样**：每个类别选一个代表性问题，用 Zero-shot CoT 自动生成推理链

通过"多样性"来减少自动生成过程中可能出现的错误。

### 💡 对你的价值
- 开发 Agent 时，在 System Prompt 中加"请一步步分析问题"可以显著提升 Agent 处理复杂任务的成功率。
- 与你写 CI/CD Pipeline 的思维一致——把大任务拆成小步骤依次执行。

---

## 三、Prompt Chaining（提示链）

### 核心概念
**把一个复杂任务拆分成多个子任务，前一个提示词的输出作为下一个提示词的输入，形成一条"流水线"。** 这不仅提升了性能，还大大增强了 LLM 应用的**可调试性**和**可控性**。

### 核心优势
- **更高的准确率**：每一步只需处理一个小问题，而不是让模型一次性搞定所有事情。
- **透明可调试**：出了问题，你可以精确定位是哪一步出了错。
- **可控性强**：每一步都可以独立修改和优化。

### 关键示例：文档问答

**任务**：给定一篇长文档，回答用户的问题。

**Prompt 1（提取引用）：**
```
你是一个有帮助的助手。你的任务是根据文档回答问题。
第一步是从文档中提取与问题相关的引用。
请使用 <quotes></quotes> 标签输出引用列表。
如果没有相关引用，请回答"未找到相关引用！"

####
{{document}}
####
```

**Prompt 2（基于引用生成答案）：**
```
给定一组从文档中提取的相关引用（用 <quotes></quotes> 标签分隔）
和原始文档（用 #### 分隔），请回答问题。
确保答案准确、语气友好。

####
{{document}}
####

<quotes>
- 引用 1...
- 引用 2...
</quotes>
```

→ 第一个 Prompt 负责"找"，第二个 Prompt 负责"答"。两步分工比一步到位更准确。

### 💡 对你的价值
- **这就是 RAG 的思想原型！** RAG 本质上就是一个两步 Prompt Chaining：先检索 → 再生成。
- **与 LangGraph 的设计思想完全一致。** LangGraph 中的每个 Node（节点）就是一个子任务，Edge（边）就是数据传递。你在 LangGraph 中编排工作流，本质上就是在做 Prompt Chaining。
- **运维类比**：就像你在 CI/CD 中设计的 Pipeline → Build → Test → Deploy，每一步的输出是下一步的输入。

---

## 四、检索增强生成 RAG (Retrieval Augmented Generation)

### 核心概念
通用大模型的"知识"是静态的（训练数据截止到某个时间点），面对需要最新信息或私有数据的任务，会产生"幻觉"（编造不存在的内容）。

**RAG 的解决方案：先从外部知识库中"检索"相关信息，再把检索到的文档作为上下文注入 Prompt，最后让模型基于这些真实信息生成回答。**

### 工作流程
```
用户提问
    ↓
检索器 (Retriever) → 从向量数据库/知识库中找到相关文档片段
    ↓
将检索到的文档片段 + 用户问题 拼接成 Prompt
    ↓
生成器 (Generator / LLM) → 基于检索到的真实上下文生成回答
    ↓
输出答案
```

### 核心优势
- **减少幻觉**：模型基于真实检索到的文档回答，而非凭记忆编造。
- **知识可更新**：只需更新知识库中的文档，无需重新训练模型。
- **事实性更强**：在 Natural Questions、WebQuestions 等基准测试中，RAG 生成的回答更准确、具体、多样。

### 论文来源
Lewis et al., (2021) 提出了 RAG 的通用微调方案：
- **参数化记忆**：预训练的 seq2seq 模型
- **非参数化记忆**：Wikipedia 的密集向量索引，通过神经预训练检索器访问

### 💡 对你的价值
- **这是你学习计划阶段三的核心内容。** 这里的概述帮你理解"为什么需要 RAG"。
- 实际工程中，你需要把这个流程中的每一步都用代码实现：文档解析 → Embedding 向量化 → 存入 Milvus → 检索 → 拼接 Prompt → 调用 LLM。
- RAG 本质上是一个高级的 **Prompt Chaining**：Retriever 的输出是 Generator 的输入。

---

## 五、Function Calling (函数调用/工具调用)

### 核心概念
Function Calling 是某些大模型具备的能力：**不是生成自然语言文本，而是输出结构化数据（JSON），告诉你的代码"请调用这个函数，参数是这些"。** 模型本身不执行任何代码。

### 完整工作流程（6 步）
```
1. 用户发送查询 → "伦敦天气怎么样？"
2. 模型评估查询，对照已定义的函数列表
3. 模型决定调用某个函数 → 输出 JSON: {"name": "get_weather", "arguments": {"location": "London"}}
4. 你的代码接收 JSON，执行真正的函数 → 调用天气 API
5. 将函数执行结果回传给模型 → "伦敦当前 18°C，多云"
6. 模型基于函数返回值，生成自然语言回答 → "伦敦现在 18 度，多云。"
```

### 代码示例 (Python)
```python
# 第 1 步：定义函数的 JSON Schema
tools = [
    {
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": "获取指定城市的当前温度",
            "parameters": {
                "type": "object",
                "properties": {
                    "location": {
                        "type": "string",
                        "description": "城市和国家，例如：北京, 中国"
                    }
                },
                "required": ["location"]
            }
        }
    }
]

# 第 2 步：发送请求，带上函数定义
from openai import OpenAI
client = OpenAI()
response = client.chat.completions.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": "伦敦天气怎么样？"}],
    tools=tools
)

# 第 3 步：处理响应
# 模型返回 tool_call，包含函数名和参数
# 你执行真正的函数，将结果回传给模型
```

### 应用场景
| 场景 | 示例 |
|---|---|
| **数据检索** | 查询数据库、调用 API、搜索知识库 |
| **自动化操作** | 发送邮件、创建日历事件、更新记录 |
| **计算任务** | 执行数学计算、数据分析、文件操作 |
| **多步骤工作流** | 串联多个函数调用完成复杂任务 |

### 并行函数调用 (Parallel Function Calling)
现代模型支持同时调用多个函数。例如用户问"伦敦和巴黎的天气"，模型会同时发出两个函数调用请求。

### 最佳实践
1. **函数描述要清晰** — 模型完全依靠 `description` 字段来决定何时调用函数
2. **参数验证** — 执行前必须校验参数合法性
3. **错误处理** — 函数执行失败时把错误信息回传给模型，让它自我修正
4. **开启 `strict: true`** — 使用结构化输出强制模型输出完全符合 JSON Schema
5. **充分测试** — 用各种输入验证函数调用的鲁棒性

### 💡 对你的价值
- **这是 Agent 开发的基础中的基础。** Agent 的"手和脚"就是通过 Function Calling 实现的。
- **安全警告（运维视角）**：绝对不要用 `eval()` 或 `exec()` 来执行模型返回的函数名！必须在代码中维护一个函数白名单 (Map)，通过键值匹配来调用。
- 你在 LangGraph 中定义的每个 Tool，底层都是 Function Calling 机制。

---

## 六、ReAct 框架 (Reasoning + Acting)

### 核心概念
Yao et al., 2022 提出的 ReAct 框架让大模型**交替生成"推理轨迹"和"具体动作"**。这是目前 Agent 开发中最核心的架构模式。

- **推理轨迹 (Thought)**：让模型制定计划、追踪进度、处理异常
- **动作 (Action)**：与外部工具/环境交互（如搜索引擎、数据库）
- **观察 (Observation)**：从外部环境获取的反馈信息

### 与 CoT 的区别

| 维度 | CoT (链式思考) | ReAct |
|---|---|---|
| 信息来源 | 只使用模型内部知识 | 可以访问外部工具和环境 |
| 局限性 | 容易产生幻觉（编造事实） | 依赖检索质量，但事实性更强 |
| 最佳实践 | 适用于纯推理任务 | 适用于需要查阅外部信息的任务 |
| **最优方案** | **ReAct + CoT + Self-Consistency 组合使用，效果最好** |

### 关键示例：多跳问答

**问题**：除了 Apple Remote，还有什么设备能控制 Apple Remote 最初设计用来交互的程序？

```
Thought 1: 我需要搜索 Colorado orogeny，找到东部区域延伸到的地区，
           然后找到该地区的海拔范围。
Action 1:  Search[Colorado orogeny]
Observation 1: Colorado orogeny 是科罗拉多州及周边地区的一次造山运动。

Thought 2: 没有提到东部区域，我需要查找 eastern sector。
Action 2:  Lookup[eastern sector]
Observation 2: (结果 1/1) 东部区域延伸到 High Plains。

Thought 3: 东部区域延伸到 High Plains，我需要搜索其海拔范围。
Action 3:  Search[High Plains]
Observation 3: High Plains 指两个不同的陆地区域...

Thought 4: 我需要更精确地搜索 High Plains (United States)。
Action 4:  Search[High Plains (United States)]
Observation 4: High Plains 是大平原的子区域。从东到西，海拔从约
              1,800 英尺上升到 7,000 英尺 (550 到 2,130 米)。

Thought 5: 海拔范围是 1,800 到 7,000 英尺。
Action 5:  Finish[1,800 to 7,000 ft]
```

### 核心循环
```
Thought (思考) → Action (执行) → Observation (观察) → Thought → Action → ...
                                                      ↑                    |
                                                      └────────────────────┘
                                                         (循环直到完成)
```

### 论文实验结果
- 在知识密集型任务（HotPotQA、FEVER）上，ReAct 优于纯 CoT
- CoT 的主要问题是**事实幻觉**
- ReAct 的主要问题是**过度依赖检索质量**（搜到垃圾信息会带偏推理）
- **最佳方案：ReAct + CoT + Self-Consistency 组合切换**

### 💡 对你的价值
- **这就是 LangGraph Agent 的灵魂！** 你在 LangGraph 中定义的 Node 就是 Action，Edge 的条件判断就是 Thought，工具返回值就是 Observation。
- **运维场景实战**：你可以设计一个 DevOps Agent：
  - Thought: "用户说服务报错了，我需要先查看日志"
  - Action: `kubectl logs pod-xxx`
  - Observation: "发现 OOM Killed 错误"
  - Thought: "内存不足，需要查看资源配额"
  - Action: `kubectl describe pod pod-xxx`
  - ...循环，直到定位根因并给出修复建议
- **防死循环**：在工程实现中，必须设置 `max_steps`（最大循环次数），防止模型在错误上反复重试。

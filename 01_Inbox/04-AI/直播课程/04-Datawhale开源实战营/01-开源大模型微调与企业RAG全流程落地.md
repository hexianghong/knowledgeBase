# 开源大模型微调与企业 RAG 全流程实战

> **主办方/公众号**：Datawhale 开源社区  
> **分享主题**：从数据清洗、LLaMA-Factory 敏捷微调到企业级 RAG 知识库问答全链路闭环  
> **核心标签**：`LLaMA-Factory` `LoRA微调` `RAG知识库` `文档切分与清洗` `BGE-M3` `BCE-Reranker`

---

## 📺 课程与学习资源导航

- **📺 官方高清视频回放**：[Bilibili - Datawhale官方频道：动手学大模型与RAG实战](https://space.bilibili.com/436482484) / [Datawhale 视频号直播回放合集](https://www.datawhale.club/)
- **📦 讲义与教程仓库**：[Datawhale self-llm (GitHub)](https://github.com/datawhalechina/self-llm) / [prompt-engineering-for-developers](https://github.com/datawhalechina/prompt-engineering-for-developers)
- **💻 开源工具与参考仓库**：
  - 微调框架：[LLaMA-Factory (GitHub)](https://github.com/hiyouga/LLaMA-Factory)
  - 知识库系统：[LangChain-Chatchat (GitHub)](https://github.com/chatchat-space/Langchain-Chatchat)
  - 中文向量与重排模型：[FlagEmbedding (BGE-M3)](https://github.com/FlagOpen/FlagEmbedding)

---

## 1. 为什么“微调 + RAG”是企业落地的标准组合拳？

在实际业务场景中，单纯靠微调或单纯靠 RAG 均存在致命短板：

```mermaid
quadrantChart
    title 场景选型：微调 vs RAG 象限分析
    x-axis 实时外部知识依赖度 (低 --> 高)
    y-axis 业务专属风格/格式与推理规范要求 (低 --> 高)
    quadrant-1 组合拳 (微调注入风格 + RAG注入事实知识)
    quadrant-2 单独微调 (指令遵循 / 特定输出格式)
    quadrant-3 通用大模型 Base (无须改造)
    quadrant-4 单独 RAG (标准制度查询 / 静态文档问答)
    "智能医疗问诊 / 司法文书助手": [0.8, 0.85]
    "企业制度 FAQ": [0.9, 0.2]
    "代码补全 / 专属 DSL 生成": [0.2, 0.8]
    "闲聊与常识推理": [0.1, 0.2]
```

- **RAG 的核心职责**：解决**时效性知识召回与防幻觉**（提供准确保险条款、API 手册）。
- **微调的核心职责**：解决**领域专业表达、思维链（CoT）格式遵循与敏感合规表达**。

---

## 2. 企业级 RAG + 微调全流程数据拓扑

```mermaid
flowchart TB
    subgraph DataPrep["1. 文档解析与清洗管道 (Data Pipeline)"]
        RawDocs[PDF / Word / Markdown / Excel 企业文档] --> DocParser[多模态解析器: 提取正文/表格/层级]
        DocParser --> CleanEngine[数据清洗: 去除乱码/页眉页脚/敏感脱敏]
        CleanEngine --> ChunkSplitter[语义感知切块 (Semantic Chunking)]
    end

    subgraph VectorIndex["2. 向量化与多路索引 (Indexing)"]
        ChunkSplitter --> DenseEmbed[密集向量化: BGE-M3]
        ChunkSplitter --> SparseBM25[稀疏关键词分词: BM25 / Jieba]
        DenseEmbed --> MilvusDB[(Milvus / Qdrant 向量库)]
        SparseBM25 --> ElasticSearch[(ElasticSearch / 倒排索引)]
    end

    subgraph FineTuning["3. 领域风格微调 (LLaMA-Factory)"]
        DomainCorpus[业务高质量问答对] --> LoRATrain[LoRA / QLoRA 敏捷微调]
        LoRATrain --> MergedModel[领域适配版模型 (Qwen/LLaMA)]
    end

    subgraph QueryPipeline["4. 运行时检索与生成闭环 (Runtime)"]
        UserQuery[用户提问] --> QueryRewrite[Query 改写与拓展]
        QueryRewrite --> HybridSearch{多路召回}
        HybridSearch --> MilvusDB & ElasticSearch
        MilvusDB & ElasticSearch --> RRF[RRF 混合分数对齐]
        RRF --> Reranker[BGE-Reranker-Large 重排序]
        Reranker --> PromptAssembly[组装 Context 与 Prompt]
        PromptAssembly --> MergedModel
        MergedModel --> StreamingOutput[打字机流式输出 (SSE)]
    end
```

---

## 3. 核心实战代码与配置

### 3.1 基于 LLaMA-Factory 的企业 LoRA 微调配置

```yaml
### dataset_info.json 注册
{
  "enterprise_qa": {
    "file_name": "enterprise_qa_dataset.json",
    "columns": {
      "prompt": "instruction",
      "query": "input",
      "response": "output"
    }
  }
}
```

```bash
# 启动 LoRA 微调命令 (单卡 24G 显存 A10/4090 即可运行)
llamafactory-cli train \
    --stage sft \
    --do_train \
    --model_name_or_path Qwen/Qwen2.5-7B-Instruct \
    --dataset enterprise_qa \
    --template qwen \
    --finetuning_type lora \
    --lora_target all \
    --output_dir ./saves/qwen2.5-7b-lora \
    --overwrite_output_dir \
    --cutoff_len 2048 \
    --preprocessing_num_workers 16 \
    --per_device_train_batch_size 4 \
    --gradient_accumulation_steps 4 \
    --lr_scheduler_type cosine \
    --logging_steps 10 \
    --warmup_ratio 0.1 \
    --learning_rate 2e-4 \
    --num_train_epochs 3.0 \
    --plot_loss \
    --fp16
```

---

### 3.2 进阶 RAG 语义分块与混合召回实现 (Python 核心逻辑)

```python
from langchain_text_splitters import MarkdownHeaderTextSplitter, RecursiveCharacterTextSplitter
from FlagEmbedding import FlagReranker

# 1. 结构感知的两级切分 (保留文档骨架)
headers_to_split_on = [
    ("#", "Header_1"),
    ("##", "Header_2"),
    ("###", "Header_3"),
]
markdown_splitter = MarkdownHeaderTextSplitter(headers_to_split_on=headers_to_split_on)
text_splitter = RecursiveCharacterTextSplitter(
    chunk_size=500,
    chunk_overlap=50,
    separators=["\n\n", "\n", "。", "！", "？", " ", ""]
)

def process_enterprise_document(raw_markdown: str):
    header_splits = markdown_splitter.split_text(raw_markdown)
    final_chunks = text_splitter.split_documents(header_splits)
    return final_chunks

# 2. Reranker 重排序精准过滤 (Top-K 提纯)
reranker = FlagReranker('BAAI/bge-reranker-large', use_fp16=True)

def rerank_search_results(query: str, retrieved_docs: list, top_n: int = 3):
    pairs = [[query, doc.page_content] for doc in retrieved_docs]
    scores = reranker.compute_score(pairs)
    # 按分数降序排列
    scored_docs = sorted(zip(retrieved_docs, scores), key=lambda x: x[1], reverse=True)
    # 过滤低分噪音，保留高质量上下文
    filtered_docs = [doc for doc, score in scored_docs[:top_n] if score > 0.0]
    return filtered_docs
```

---

## 4. 生产落地关键避坑经验

1. **表格与复杂 PDF 切分崩溃**：
   - 常见坑：将 Markdown 表格横向腰斩，导致模型读取到残缺的行列，产生完全错误的数字。
   - 解决：对表格采用单独解析器转化为 HTML 或自然语言描述（`行_N: 字段A=xx, 字段B=yy`），作为一个不可分割的独立 Chunk 存入。
2. **LoRA 过拟合（Catastrophic Forgetting）**：
   - 现象：模型在专属领域问答很准，但基础逻辑推理能力严重退化。
   - 解决：在训练集中混合 **10%~20% 通用通用问答指令数据（General Alpaca Data）** 作为正则化约束。

---

## 5. 讲座 Q&A 精选

- **Q：企业构建知识库，切分 chunk_size 设置多大合适？**
  - **讲师解答**：没有放之四海而皆准的固定值。中文场景通常推荐 **300~500 字符** 配备 **50 字符 overlap**。对于条款密集型合同，可更小（200 字符）；对于综合分析报告，配合 Parent-Child 模式（小 Chunk 用于召回，大父块 Chunk 用于送入 LLM 上下文）。

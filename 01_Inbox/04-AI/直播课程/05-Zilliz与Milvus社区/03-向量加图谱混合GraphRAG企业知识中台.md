# 向量+图谱混合 GraphRAG 在企业知识中台的工程调优

> **主办方/公众号**：Zilliz 官方社区  
> **分享主题**：Milvus 向量语义检索与 NebulaGraph/Neo4j 实体关系图谱的双路融合中台架构  
> **核心标签**：`GraphRAG` `Milvus` `知识中台` `多跳推理` `双路召回`

---

## 📺 课程与学习资源导航

- **📺 官方视频回放**：[Bilibili - Zilliz 官方：GraphRAG 与企业知识中台架构](https://space.bilibili.com/401490289)
- **💻 开源工具仓库**：[Milvus-Bootcamp (GitHub)](https://github.com/milvus-io/bootcamp)

---

## 1. 双路混合召回执行拓扑

```mermaid
flowchart LR
    Query[用户复杂多跳提问] --> Router[双路召回分发器]
    
    Router -->|语义相似度路| Milvus[Milvus: 向量检索召回 Top-50 文本块]
    Router -->|实体因果关系路| GraphDB[图数据库: 实体识别 + 2-Hop 关联子图遍历]
    
    Milvus & GraphDB --> HybridRanker[知识拓扑加权重排器 (Graph-Aware Reranker)]
    HybridRanker --> PromptContext[组装结构化高信息密度上下文]
    PromptContext --> LLM[大模型生成严谨回答]
```

- **核心调优技巧**：先用 Milvus 召回最相关的候选 Chunk，从 Chunk 中抽取高频实体作为起点（Seed Entities），再向图数据库发起 1~2 跳扩展，**避免了全图遍历的指数级计算爆炸**。

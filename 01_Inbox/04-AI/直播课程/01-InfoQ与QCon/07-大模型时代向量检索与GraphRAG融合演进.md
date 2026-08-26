# 大模型时代向量检索与 GraphRAG 融合演进

> **主办方/公众号**：InfoQ 技术公开课  
> **分享主题**：从纯向量相似度检索向知识图谱增强生成（GraphRAG）的架构演进与落地实战  
> **核心标签**：`GraphRAG` `知识图谱 (Knowledge Graph)` `实体关系抽取` `多跳推理 (Multi-hop)` `混合召回`

---

## 📺 课程与学习资源导航

- **📺 官方视频回放**：[Bilibili - InfoQ 官方：GraphRAG 原理与企业实战](https://space.bilibili.com/393278857)
- **💻 开源工具与参考仓库**：
  - 微软 GraphRAG 官方实现：[microsoft/graphrag (GitHub)](https://github.com/microsoft/graphrag)
  - 图数据库引擎：[Neo4j (GitHub)](https://github.com/neo4j/neo4j) / [NebulaGraph](https://github.com/vesoft-inc/nebula)

---

## 1. 传统 RAG 与 GraphRAG 的核心能力对比

```mermaid
graph TD
    subgraph VectorRAG["传统向量 RAG (局部感知)"]
        V_Query[全局概括性提问: '这份 500 页财报中所有子公司的关联债务风险是什么？'] --> V_Fail[向量切片零散: 仅能抓取语义局部相似的段落，无法串联全局多跳关系，漏召率极高]
    end

    subgraph GraphRAG["GraphRAG (全局多跳拓扑推理)"]
        G_Query[全局多跳提问] --> G_Graph[知识图谱实体与社区聚类 (Community Summary)]
        G_Graph --> G_Success[自底向上聚合高层概要 + 精准溯源实体因果链条]
    end
```

---

## 2. GraphRAG 离线索引与在线多级检索拓扑

```mermaid
flowchart TB
    subgraph OfflinePipeline["1. 离线图谱构建流水线 (Offline Graph Indexing)"]
        RawDocs[企业海量文档] --> LLM_Extractor[大模型实体与关系三元组抽取]
        LLM_Extractor --> GraphDB[(图数据库 Neo4j: Nodes & Edges)]
        GraphDB --> LeidenClustering[Leiden 算法层次化社区聚类]
        LeidenClustering --> CommunitySummaries[(社区层级摘要库)]
    end

    subgraph OnlinePipeline["2. 在线混合召回引擎 (Online Hybrid Retrieval)"]
        UserQuery[用户全局分析请求] --> QueryIntent{意图分流}
        QueryIntent -->|全局宏观总结 (Global Search)| GlobalCommunitySearch[检索高层社区摘要库]
        QueryIntent -->|局部微观事实 (Local Search)| SubgraphTraverse[向量召回核心实体 + 扩展 2-Hop 邻居子图]
        GlobalCommunitySearch & SubgraphTraverse --> FusionAssembly[融合图谱上下文与原文 Chunk]
        FusionAssembly --> LLM_Response[生成结构化全面回答]
    end
```

---

## 3. 生产级避坑指南

1. **图谱构建成本爆炸**：
   - 常见坑：直接用 GPT-4 对上万份文档全量抽取实体三元组，Token 账单高达数万美元。
   - 优化：采用开源高性价比模型（如 Qwen2.5-14B / DeepSeek-V3）进行离线抽取，并设置实体合并（Entity Disambiguation）阈值，减少冗余节点。

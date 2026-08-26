# Milvus 2.5 全新架构解析：全文检索与标量倒排深度整合

> **主办方/公众号**：Zilliz 官方社区  
> **分享主题**：Milvus 2.5 原生内置 BM25 文本分析器、稀疏倒排索引与单引擎混合检索实现  
> **核心标签**：`Milvus 2.5` `原生全文检索 (Full-Text Search)` `BM25 内置` `Tantivy 倒排索引` `架构精简`

---

## 📺 课程与学习资源导航

- **📺 官方视频回放**：[Bilibili - Zilliz 官方：Milvus 2.5 全新功能大拆解](https://space.bilibili.com/401490289)
- **💻 开源文档**：[Milvus 2.5 官方文档](https://milvus.io/docs/zh)

---

## 1. 架构突破：告别“ElasticSearch + Milvus”双引擎冗余运维

传统企业在做 RAG 混合检索时，必须同时部署一套 ElasticSearch（做 BM25 关键词匹配）和一套 Milvus（做向量搜索），导致数据双写一致性差、运维成本高昂。

```mermaid
flowchart TD
    subgraph OldWay["传统双引擎模式 (臃肿脆弱)"]
        Raw[原始文档] --> ES[(ElasticSearch: 倒排索引)] & OldMilvus[(Milvus: 向量索引)]
        User[用户搜索] --> DualSearch[应用层双路请求 + 手动对齐 ID + 数据漂移排查]
    end

    subgraph NewMilvus25["Milvus 2.5 单引擎原生模式 (精简优雅)"]
        Raw2[原始文档 (Text)] --> Milvus25[(Milvus 2.5 统一存储引擎)]
        Milvus25 --> AutoAnalyze[内置 Jieba/Tantivy 分词 -> 自动生成 BM25 稀疏向量 + 密集 Embedding]
        User2[用户输入原始文本] --> OneCall[单次 SDK hybrid_search() 调用 -> 底层直接返回融合结果]
    end
```

- **运维收益**：彻底下掉 ElasticSearch 机器集群，**内存占用降低 40%，系统架构复杂度降低 50%**。

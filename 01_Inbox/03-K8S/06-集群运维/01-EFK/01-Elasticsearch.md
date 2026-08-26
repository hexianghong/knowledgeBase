# Elasticsearch 8.18+ 核心原理深度指南

> 基于 Apache Lucene 9.12+/10，涵盖节点角色、安全模型、Data Streams、ES|QL 与底层存储结构。

---

## 1. ES 8.18+ 显式节点角色机制

ES 8.x 完全摒弃旧版布尔开关，统一采用 `node.roles` 数组：

| 角色 | 职责 |
|------|------|
| `master` | 集群元数据变更、分片分配、主节点竞选 |
| `data_content` | 存储非时序常规业务索引数据 |
| `data_hot` | 高速写入时序日志分片（NVMe SSD） |
| `data_warm` | 历史日志只读分片（SATA SSD/HDD） |
| `data_cold` | 极低频访问历史数据，高级压缩 |
| `data_frozen` | 挂载对象存储（MinIO/S3）可搜索快照 |
| `ingest` | 运行 Ingest Pipeline，Grok/Date 预处理 |
| `remote_cluster_client` | 跨集群检索（CCS）/ 跨集群复制（CCR） |

---

## 2. 默认安全框架（Security by Default）

ES 8.18+ 默认强制开启：
- **Transport 层（9300）**：强制双向 mTLS 加密
- **REST HTTP（9200）**：强制 HTTPS
- **三维凭据**：elastic 超管密码 / Service Account Token / API Key（推荐采集器使用）

---

## 3. 时序数据流架构（Data Streams）

```
客户端写入: POST /logs-k8s-prod/_doc
                     │
                     ▼
┌────────────────────────────────────────────────────────┐
│              Data Stream: logs-k8s-prod                │
│  底层隐藏索引 1 (只读): .ds-logs-k8s-prod-2026.08.12  │
│  底层隐藏索引 2 (只读): .ds-logs-k8s-prod-2026.08.13  │
│  底层隐藏索引 3 (写):   .ds-logs-k8s-prod-2026.08.14  │ ← 写入
└────────────────────────────────────────────────────────┘
```

- 采集器只需写入逻辑别名，无需计算按天滚动的索引名
- 自动与 ILM 绑定，达到阈值自动 Rollover
- **强制要求**每条日志包含 `@timestamp`

---

## 4. ES|QL 管道化查询引擎

```sql
FROM logs-k8s-*
| WHERE @timestamp > NOW() - 15 MINUTES AND log.level == "ERROR"
| STATS error_count = COUNT() BY k8s.pod.name, k8s.namespace
| SORT error_count DESC
| LIMIT 10
```

- **向量化执行引擎**：利用 Java 21+ Vector API + CPU SIMD，列批量并行计算
- **按需裁剪加载**：仅加载查询涉及字段，大幅降低 I/O

---

## 5. Synthetic _source 降本技术

传统 ES 保留原始 JSON `_source` 造成约 40% 冗余。ES 8.18+ 的 Synthetic `_source`：
- 写入时不落盘原始 JSON
- 查询时从 `doc_values` 动态逆向合成 JSON
- 日志类索引磁盘占用降低 **30%~50%**

---

## 6. Lucene 9.12+/10 物理存储底层原理

### (1) 倒排索引三剑客

| 组件 | 存储位置 | 作用 |
|------|----------|------|
| FST（有限状态转换器） | JVM 堆内存 | 前缀压缩词典，O(k) 定位 |
| FOR（帧参考差值压缩） | 磁盘 | 稠密 DocID 列表压缩 |
| Roaring Bitmaps | 磁盘 | 稀疏数据 / 多条件过滤位图运算 |

### (2) Segment 不可变性与合并策略

- Segment 写入后**不可修改**，充分利用 OS Page Cache
- 删除只在 `.del` 位图标记，段合并时才真正物理删除
- `TieredMergePolicy` 分层合并，后台异步执行

---

## 7. 分布式写入全生命周期

```
[Fluent Bit / Fluentd]
      │ 1. POST /logs-k8s-prod/_bulk (HTTPS + API Key)
      ▼
[Coordinating Node]
      │ 2. 路由至 Primary Shard
      ▼
[Primary Shard (Data Hot)]
      ├─► 3. 写入 Index Buffer (JVM 内存)
      │       └─► 4. Refresh (默认1s，生产建议30s) → 新 Segment 进 OS Page Cache → 可检索
      ├─► 5. 写 Translog（顺序追加磁盘，防宕机丢失）
      │       └─► 6. Flush（30min或512MB）→ fsync 落盘，清空旧 Translog
      └─► 7. 并行同步至所有 Replica Shards
```

---

## 8. 生产写入调优要点

| 参数 | 推荐值 | 说明 |
|------|--------|------|
| `refresh_interval` | `30s` | 日志场景无需 1s 实时性，减少 Segment 数量，降低 40% CPU |
| Bulk 请求大小 | 5MB ~ 15MB | 1000 ~ 3000 条/批，最高写入吞吐 |
| JVM 堆内存 | ≤ 物理内存 50%，且 ≤ 31GB | 超 31GB 导致指针压缩失效 |
| `translog.durability` | `async` | 配合 `sync_interval: 30s` 大幅提升写入性能 |

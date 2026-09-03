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

---

## 9. ES 8.18 vs 7.17 全维度对比

> ES 7.17 是 7.x 系列的最终版本，也是升级至 8.x 的**唯一跳板版本**。以下从 7 个维度对比两代架构级差异。

### (1) 安全模型

| 维度 | 7.17 | 8.18 |
|------|------|------|
| TLS 加密 | **默认关闭**，需手动配置 `xpack.security` | **默认强制开启**，Transport 9300 双向 mTLS + REST 9200 HTTPS |
| 认证方式 | 手动创建用户/角色，Basic Auth | 首次启动自动生成 `elastic` 密码 + Enrollment Token 节点自动加入 |
| Kibana 接入 | 手动配置证书 + 用户名密码 | Enrollment Token **一键对接**，零配置安全连接 |
| Service Account | ❌ 不支持 | ✅ 内置 Service Account Token（适用于 Fleet/Beats/采集器） |
| API Key 管理 | 基础 API Key | 增强型 API Key，支持跨集群、细粒度权限、自动过期 |

### (2) 节点角色与配置

| 维度 | 7.17 | 8.18 |
|------|------|------|
| 配置方式 | 布尔开关：`node.master: true`，`node.data: true` | **统一数组**：`node.roles: [master, data_hot, ingest]` |
| 数据分层 | `data` 单一角色，ILM 手动绑定 | 细粒度角色：`data_hot` / `data_warm` / `data_cold` / `data_frozen` / `data_content` |
| Frozen 层 | 冻结索引（`_freeze` API，已 CRITICAL 级废弃） | **Searchable Snapshots**：挂载 S3/MinIO 对象存储，按需搜索，成本降低 90%+ |
| 默认行为 | 未配置时默认所有布尔为 true | 未配置 `node.roles` 时默认分配所有角色 |

### (3) 数据管理与索引

| 维度 | 7.17 | 8.18 |
|------|------|------|
| Mapping Types | 已废弃但仍可用（`_type` 字段） | **完全移除**，`_type` 相关 API 直接报错 |
| Data Streams | 7.9+ 引入，功能基础 | 深度优化：自动 Rollover、与 ILM/Data Tier 深度集成 |
| Synthetic `_source` | ❌ 不支持 | ✅ 不落盘原始 JSON，从 `doc_values` 动态重建，磁盘节省 30%~50% |
| TSDS（时序数据流） | ❌ 不支持 | ✅ 专用时序索引格式，自动排序+路由+降采样，监控指标场景性能飞跃 |
| Logsdb 索引模式 | ❌ 不支持 | ✅ 日志专属索引模式，底层利用 Synthetic Source + 高级排序优化 |

### (4) 查询与分析引擎

| 维度 | 7.17 | 8.18 |
|------|------|------|
| 查询语言 | Query DSL（JSON 嵌套，复杂分析冗长） | **ES\|QL**：管道化语法 + 向量化执行引擎，Java 21+ SIMD 加速 |
| kNN 向量搜索 | `script_score` 精确暴力搜索（全量扫描，不可扩展） | **原生近似 kNN**：`dense_vector` 字段 + HNSW 索引，低延迟向量召回 |
| 执行引擎 | 传统行式处理 | 列式批量处理 + CPU SIMD 向量化，聚合性能提升数倍 |
| Runtime Fields | 7.11+ 引入，基础支持 | 深度优化，与 ES\|QL 无缝配合 |

### (5) Lucene 底层引擎

| 维度 | 7.17（Lucene 8.x） | 8.18（Lucene 9.12+/10） |
|------|---------------------|------------------------|
| 向量索引 | 无原生支持 | 原生高维向量索引（HNSW），支持百万级向量低延迟检索 |
| 并行执行 | 基础多线程 | 增强搜索并行，自动利用多核 CPU |
| I/O 效率 | 标准磁盘 I/O | 优化高延迟存储（对象存储）读取 + 稀疏索引减少 I/O |
| 硬件加速 | 通用 JVM 优化 | Panama Vector API + SIMD 自动向量化，纯计算场景提升 30%+ |
| 分面聚合 | 标准 taxonomy 实现 | 分面聚合速度大幅提升，多维点索引优化 |

### (6) 客户端 API 与兼容性

| 维度 | 7.17 | 8.18 |
|------|------|------|
| Java 客户端 | High Level REST Client (HLRC) | **全新 Java API Client**（类型安全，HLRC 已废弃） |
| REST API 兼容 | 标准 7.x API | 内置 **REST 兼容模式**：通过 `Accept`/`Content-Type` Header 让 7.x 客户端临时对接 8.x |
| Python/Go/.NET | 各语言 7.x SDK | 必须升级至 8.x SDK，API 签名有破坏性变更 |
| `action.destructive_requires_name` | 默认 `false` | 默认 `true`，`DELETE /*` 等危险操作需显式指定索引名 |

### (7) 升级路径与关键注意事项

```
┌────────────────────────────────────────────────────┐
│              升级路径（唯一推荐）                    │
│                                                    │
│  ES 7.x (任意) ──► ES 7.17.x (最新补丁)           │
│       │                    │                       │
│       │  1. 解决所有废弃警告  │                     │
│       │  2. Kibana 升级助手   │                     │
│       │  3. 快照备份          │                     │
│       │                    ▼                       │
│       └──────────────► ES 8.18.x                   │
│                                                    │
│  ⚠️  不支持 7.0~7.16 直接跳至 8.x                  │
│  ⚠️  不支持 6.x 直接跳至 8.x                       │
└────────────────────────────────────────────────────┘
```

**升级前必做检查清单**：

| 序号 | 检查项 | 操作 |
|------|--------|------|
| 1 | 解决废弃 API 告警 | `GET /_migration/deprecations` 或 Kibana Upgrade Assistant |
| 2 | 移除 `_type` 引用 | 检查所有索引模板、应用代码中 Mapping Type 的使用 |
| 3 | 迁移节点配置 | `node.master: true` → `node.roles: [master]` |
| 4 | 升级客户端 SDK | Java HLRC → Java API Client；Python/Go/.NET 升级至 8.x 版本 |
| 5 | 解冻冻结索引 | `POST /<index>/_unfreeze`（8.18 已 CRITICAL 级废弃，9.0 将移除） |
| 6 | 安全配置预适配 | 提前规划证书/密码/Token 方案，8.x 默认强制安全 |
| 7 | 全量快照备份 | `PUT /_snapshot/backup/pre_upgrade_snap` |

---

> [!TIP] 💡 关联技术与延伸阅读
>
> * [Elasticsearch 8.18+ 核心原理深度指南（本文上半部分）](#1-es-818-显式节点角色机制)
> * [Elastic 官方迁移指南](https://www.elastic.co/guide/en/elasticsearch/reference/current/migration-guide.html)
> * [ES|QL 管道化查询引擎（本文第 4 章）](#4-esql-管道化查询引擎)

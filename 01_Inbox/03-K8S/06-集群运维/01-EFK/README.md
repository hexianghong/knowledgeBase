# 01-EFK

## 目录说明
EFK（Elasticsearch + Fluent Bit / Fluentd + Kibana）在 Kubernetes 上的知识文档，基于 Elastic Stack 8.18+。

> **部署 YAML 文件已迁移至** `./05-Install/kubenetes/efk/`

## 内容索引
| 名称 | 类型 | 说明 |
|------|------|------|
| [./01-Elasticsearch.md](./01-Elasticsearch.md) | 文件 | ES 8.18+ 核心原理：节点角色 / Data Streams / ES|QL / Lucene 底层 / 分布式写入链路 |
| [./02-FluentBit.md](./02-FluentBit.md) | 文件 | Fluent Bit 3.x 轻量边缘采集器：原理 / 配置 / K8S 部署 |
| [./03-Fluentd.md](./03-Fluentd.md) | 文件 | Fluentd 复杂管道：多行熔合 / Java 堆栈 / 字段裁剪 / ES 输出配置 |
| [./04-Kibana.md](./04-Kibana.md) | 文件 | Kibana 8.18：部署 SOP / ILM 生命周期 / ES|QL 实战 / 生产避坑指南 |

## 相关部署文件位置
`./05-Install/kubenetes/efk/` 目录包含：
- `01-namespace-rbac.yaml` — 命名空间与 RBAC
- `02-elasticsearch-svc.yaml` — ES Headless Service
- `elasticsearch-statefulset.yaml` — ES 3 节点 StatefulSet
- `fluent-bit-daemonset.yaml` — Fluent Bit DaemonSet
- `fluentd-pipeline.yaml` — Fluentd DaemonSet
- `kibana-secret.yaml` / `kibana.yaml` — Kibana 部署

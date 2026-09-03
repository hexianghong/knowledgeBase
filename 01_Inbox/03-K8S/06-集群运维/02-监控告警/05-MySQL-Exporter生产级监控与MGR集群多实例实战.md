# MySQL-Exporter 生产级监控与 MGR 集群多实例实战

## 一、 核心定位与技术架构

**mysqld_exporter** 是 Prometheus 官方针对 MySQL 及兼容分支（MariaDB、Percona）提供的指标采集组件。它通过标准 SQL 客户端连接数据库，定期查询 `information_schema`、`performance_schema` 及全局状态变量，将连接池水位、QPS/TPS、InnoDB 缓冲池命中率、行锁争用、主从/MGR 复制延迟等核心指标暴露为 Prometheus 文本协议。

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        MySQL 数据库与集群实例                          │
│                                                                        │
│   Node 1 (192.168.10.101:3306) - MGR Primary                          │
│   Node 2 (192.168.10.102:3306) - MGR Secondary                        │
│   Node 3 (192.168.10.103:3306) - MGR Secondary                        │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ TCP 3306 (认证与只读查询)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│              【部署形态对比：单实例 Agent vs 多目标探测 (Multi-Target)】│
│                                                                        │
│  【形态 A：独立 Deployment / Sidecar】 │  【形态 B：Multi-Target 集中探测】    │
│  - 每个 MySQL 部署一个独立 Exporter   │  - 仅部署 1 个 Exporter Pod           │
│  - 挂载独立的 .my.cnf 凭据            │  - Prometheus 通过 /probe 动态传参    │
│  - 易于隔离，适合单个业务独享数据库   │  - 极度节省 Pod 开销，最适合 MGR 集群 │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ HTTP GET /metrics 或 /probe
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        Prometheus Server 时序库                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 二、 生产最小化权限与安全加固规范

在生产环境中，**严禁使用 root 账号运行 Exporter**。必须遵循最小权限原则，并严格限制最大连接数，防止 Exporter 在极端情况下打满数据库连接：

```sql
-- 1. 创建专用监控账号并限制最大并发连接数为 5
CREATE USER 'exporter'@'%' IDENTIFIED BY 'Exporter@Password2026!' WITH MAX_USER_CONNECTIONS 5;

-- 2. 授予必要监控权限：
-- PROCESS: 允许查看完整 processlist，排查慢查询与锁阻塞
-- REPLICATION CLIENT: 允许查看主从/MGR 复制状态 (SHOW SLAVE STATUS / SHOW REPLICA STATUS)
-- SELECT ON *.*: 允许读取 performance_schema 与 sys 视图
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter'@'%';

-- 3. 刷新权限
FLUSH PRIVILEGES;
```

---

## 三、 MGR 高可用三节点集群多目标探测 (Multi-Target Pattern)

针对本知识库中采用的 `./05-Install/mysql/mysql8.0.43_huazhuo_prod/` 华卓生产级 MGR 3 节点集群，采用 **Multi-Target 探测模式** 是官方推荐的最佳实践：

### 1. Exporter 统一凭据配置 (`/etc/mysql/.my.cnf`)

```ini
[client]
user = exporter
password = Exporter@Password2026!

# 支持多节点分段配置
[client.mgr_node1]
host = 192.168.10.101
port = 3306

[client.mgr_node2]
host = 192.168.10.102
port = 3306

[client.mgr_node3]
host = 192.168.10.103
port = 3306
```

### 2. Prometheus 自动重写抓取规则 (`prometheus.yml`)

```yaml
scrape_configs:
  - job_name: 'mysql-mgr-cluster'
    metrics_path: /probe
    static_configs:
      - targets:
          - 192.168.10.101:3306
          - 192.168.10.102:3306
          - 192.168.10.103:3306
        labels:
          cluster: 'mgr-prod-01'
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      # 重定向请求至集中部署的 mysqld-exporter 服务
      - target_label: __address__
        replacement: mysqld-exporter.monitoring.svc:9104
```

---

## 四、 核心指标 PromQL 计算与生产避坑指南

### 1. 黄金监控指标与 PromQL

- **MySQL 实例在线状态 (1=UP, 0=DOWN)**：
  ```promql
  mysql_up
  ```
- **连接池饱和度 (%)（达到 85% 必须预警）**：
  ```promql
  (mysql_global_status_threads_connected / mysql_global_variables_max_connections) * 100
  ```
- **InnoDB 缓冲池命中率 (%)（低于 99% 说明内存不足，存在严重物理磁盘读）**：
  ```promql
  (1 - (rate(mysql_global_status_innodb_buffer_pool_reads[5m]) / rate(mysql_global_status_innodb_buffer_pool_read_requests[5m]))) * 100
  ```
- **主从/从节点复制延迟时间 (Seconds)**：
  ```promql
  mysql_slave_status_seconds_behind_master
  ```
- **慢查询速率 (QPS)**：
  ```promql
  rate(mysql_global_status_slow_queries[5m])
  ```

### 2. 生产关键避坑红线

> [!CAUTION]
> **Performance Schema 高并发开销陷阱**：
> 在每秒数万 QPS 的大型高并发事务库中，谨慎开启 `--collect.perf_schema.eventsstatements`。该参数会轮询 `events_statements_summary_by_digest` 内存表，可能引发互斥锁争用，导致数据库 CPU 额外增加 5%~10%。生产环境建议仅在压测或排障期动态开启，常规监控依靠 `info_schema` 核心指标即可满足 95% 以上需求。

---

> [!TIP] 💡 关联技术与延伸阅读
>
> * [Prometheus 与 Alertmanager 企业级架构设计与生产落地](./01-Prometheus与Alertmanager架构设计与生产落地.md)
> * [生产级 MySQL 8.0 MGR 高可用安装包与自动化脚本](../../../../05-Install/mysql/mysql8.0.43_huazhuo_prod/README.md)
> * [mysqld-exporter 部署清单 (YAML)](../../../../05-Install/monitoring/08-mysqld-exporter.yaml)
> * [生产级告警规则清单 (YAML)](../../../../05-Install/monitoring/09-alert-rules.yaml)

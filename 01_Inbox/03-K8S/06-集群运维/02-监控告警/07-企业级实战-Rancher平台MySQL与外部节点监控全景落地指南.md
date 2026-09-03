# 企业级实战：Rancher 体系下 MySQL 集群与外部裸金属节点纳管全景指南

## 一、 生产背景与业务痛点

在大型企业级医疗信息化（HIS）、数据中心（SJZX）及金融核心系统中，**数据库集群（MySQL MHA / MGR、MongoDB 等）通常部署在高性能外部独立物理机或专用虚拟机上**，以保障极高的 IOPS 和物理隔离；而云原生监控运维中心（如 Rancher Monitoring、Prometheus-Operator）则统一运行在 Kubernetes 容器集群中。

由此产生了一个核心架构命题：**如何利用 K8s 内的 Prometheus-Operator，无侵入、高可用、声明式地纳管集群外部海量数据库节点及宿主机物理指标？**

根据生产一线（华卓/Wowjoy 核心生产集群）实战经验，业界最优雅的标准落地范式是：**“宿主机 Systemd 守护 + K8s Service/Endpoints 静态映射 + ServiceMonitor 声明式发现 + PrometheusRule 智能告警”**。

```text
┌──────────────────────────────────────────────────────────────────────────────────┐
│                   K8S 内部监控平台 (cattle-monitoring-system)                    │
│                                                                                  │
│   ┌──────────────────────────────────────────────────────────────────────────┐   │
│   │                         Prometheus-Operator 控制器                       │   │
│   │                                                                          │   │
│   │   [ServiceMonitor]                     [ServiceMonitor]                  │   │
│   │   prometheus-mysql-exporter            mysql-node-exporter               │   │
│   └─────────────┬────────────────────────────────────────┬───────────────────┘   │
│                 │ 匹配 Service Selector                  │ 匹配 Service Selector │
│                 ▼                                        ▼                       │
│   ┌───────────────────────────┐            ┌───────────────────────────┐         │
│   │ Service: mysql-exporter   │            │ Service: node-exporter    │         │
│   │ (ClusterIP: :9104)        │            │ (ClusterIP 无选择器 :9100) │         │
│   └─────────────┬─────────────┘            └─────────────┬─────────────┘         │
│                 │                                        │                       │
│                 │ Pod 容器直连                           │ 静态 Endpoints 桥接   │
│                 ▼                                        ▼                       │
│   ┌───────────────────────────┐            ┌───────────────────────────┐         │
│   │ Deployment (Exporter Pod) │            │ Endpoints 静态绑定外部 IP │         │
│   │ mysql-his-mdsn01-exporter │            │ - 192.168.190.41 (HIS01)  │         │
│   │  (:9104 收集深度指标)     │            │ - 192.168.190.51 (SJZX01) │         │
│   └─────────────┬─────────────┘            │ - 192.168.190.44 (MHA)    │         │
└─────────────────┼──────────────────────────┴─────────────┬─────────────────────┘
                  │ 数据库 3306 协议                        │ HTTP :9100 物理指标拉取
                  ▼                                        ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                   外部物理机 / 专属虚机层 (HIS / 数据中心数据库基础设施)         │
│                                                                                  │
│   Node: his-mdsn01 (192.168.190.41)   ──> node_exporter.service (Systemd 守护)   │
│   Node: his-mdsn02 (192.168.190.42)   ──> node_exporter.service (资源配额控制)   │
│   Node: sjzx-mdsn01 (192.168.190.51)  ──> node_exporter.service (Systemd 守护)   │
│   Node: xtrabackup, canal, mongo...   ──> node_exporter.service                 │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## 二、 外部数据库 mysqld-exporter 容器化部署规范

在 K8s 内部运行 Exporter Pod 采集外部数据库，既保障了网络与密钥的统一纳管，又无需在物理机上侵入式安装 Python/Go 运行环境。

### 1. 数据库最小权限创建 (在 MySQL 主从节点执行)

```sql
-- 生产级专用监控只读账号 (限制主机段与最小权限)
CREATE USER 'prom'@'%' IDENTIFIED BY 'K9SFmY@FDprom2024';
GRANT SELECT, PROCESS, REPLICATION CLIENT ON *.* TO 'prom'@'%';
FLUSH PRIVILEGES;
```

### 2. ServiceMonitor 声明式采集清单 (`mysql-exporter-ServiceMonitor.yaml`)

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: prometheus-mysql-exporter
  namespace: cattle-monitoring-system
  labels:
    app: prometheus-mysql-exporter
spec:
  endpoints:
    - interval: 30s
      targetPort: 9104
      relabelings:
        # 将 Pod/Container 名字格式化为规范的 instance 实例标签
        - sourceLabels: [__meta_kubernetes_pod_container_name]
          regex: (.*)-exporter
          targetLabel: instance
  selector:
    matchLabels:
      app: prometheus-mysql-exporter
```

### 3. Service 与 Deployment 清单 (`mysql-exporter-deploy.yaml`)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: prometheus-mysql-exporter
  namespace: cattle-monitoring-system
  labels:
    app: prometheus-mysql-exporter
  annotations:
    prometheus.io/scrape: "true"
spec:
  ports:
    - name: mysql-exporter
      port: 9104
      protocol: TCP
  selector:
    app: prometheus-mysql-exporter
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql-his-mdsn01-exporter
  namespace: cattle-monitoring-system
  labels:
    app: prometheus-mysql-exporter
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus-mysql-exporter
  template:
    metadata:
      labels:
        app: prometheus-mysql-exporter
        name: mysql-his-mdsn01-exporter
    spec:
      containers:
        - name: mysql-his-mdsn01-exporter
          image: harbor.rubikstack.com/wowjoy/library/mysqld-exporter:latest
          imagePullPolicy: IfNotPresent
          command:
            - /bin/mysqld_exporter
          args:
            # 开启高价值深度排障采集器
            - --collect.info_schema.innodb_metrics
            - --collect.info_schema.tables
            - --collect.info_schema.processlist
            - --collect.info_schema.userstats
            - --collect.info_schema.tables.databases=*
            - --collect.engine_innodb_status
            - --collect.perf_schema.eventsstatements
            - --collect.auto_increment.columns
            - --collect.binlog_size
          env:
            - name: DATA_SOURCE_NAME
              value: prom:K9SFmY@FDprom2024@(10.20.41.64:3306)/
          ports:
            - name: 9104tcp
              containerPort: 9104
              protocol: TCP
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
```

---

## 三、 外部裸金属节点通过 Service+Endpoints 桥接纳管实战

针对 20+ 台外部独立物理机（HIS 主从、数据中心主从、MHA 仲裁节点、备份节点、MongoDB 等），无需在 K8s 中运行 20 个 DaemonSet，而是采用 **外部 Endpoints 静态桥接模式**。

### 1. 宿主机物理机 Systemd 规范化安装

在被监控的外部物理机上执行：

```bash
# 1. 解压安装包
tar -xzvf node_exporter-1.5.0.linux-amd64.tar.gz
chown -R root:root node_exporter-1.5.0.linux-amd64

# 2. 编写 Systemd 单元文件 (加入硬性资源隔离，防止内存泄露)
cat << 'EOF' > /usr/lib/systemd/system/node_exporter.service
[Unit]
Description=prometheus node_exporter
After=network.target

[Service]
Type=simple
ExecStart=/root/node_exporter-1.5.0.linux-amd64/node_exporter
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure
RestartSec=60s
# 核心加固：限制 node_exporter 最大内存 300M，CPU 限制 1 核
MemoryLimit=300M
CPUQuota=100%

[Install]
WantedBy=multi-user.target
EOF

# 3. 启动并配置开机自启
systemctl daemon-reload
systemctl enable --now node_exporter
systemctl status node_exporter
```

### 2. K8s 侧无选择器 Service 与 Endpoints 静态绑定

在 K8s 中创建一个**没有 `selector`** 的 Service，配合手动定义的 `Endpoints`，Prometheus-Operator 即可自动抓取外部 IP：

```yaml
# 1. 外部节点端点静态清单 (mysql-node-exporter-ep.yaml)
apiVersion: v1
kind: Endpoints
metadata:
  name: prometheus-mysql-node-exporter
  namespace: cattle-monitoring-system
  labels:
    app: prometheus-mysql-node-exporter
subsets:
  - ports:
      - name: mysql-exporter
        port: 9100
        protocol: TCP
    addresses:
      # HIS 核心数据库与高可用 MHA 仲裁节点
      - ip: 192.168.190.41
        nodeName: his-mdsn01
      - ip: 192.168.190.42
        nodeName: his-mdsn02
 
---
# 2. 外部节点无选择器 Service (mysql-node-exporter-svc.yaml)
apiVersion: v1
kind: Service
metadata:
  name: prometheus-mysql-node-exporter
  namespace: cattle-monitoring-system
  labels:
    app: prometheus-mysql-node-exporter
  annotations:
    prometheus.io/scrape: "true"
spec:
  ports:
    - name: mysql-exporter
      port: 9100
      targetPort: 9100
      protocol: TCP
  type: ClusterIP
---
# 3. 关联的 ServiceMonitor (mysql-node-exporter-servicemonitor.yaml)
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: mysql-node-exporter
  namespace: cattle-monitoring-system
  labels:
    app: prometheus-mysql-node-exporter
spec:
  jobLabel: mysql-node-exporter
  endpoints:
    - port: mysql-exporter
      interval: 15s
      honorLabels: true
      scheme: http
      relabelings:
        # 将 Endpoint 节点名称赋值为 instance 标签，直观可读
        - action: replace
          sourceLabels: [__meta_kubernetes_endpoint_node_name]
          regex: (.*)
          replacement: $1
          targetLabel: instance
  selector:
    matchLabels:
      app: prometheus-mysql-node-exporter
```

---

## 四、 生产级高频告警规则库 (PrometheusRule)

以下告警规则提炼自真实医疗与金融级高可用生产环境，涵盖自增主键溢出、死锁突增、线程打满及主从中断等高危故障：

### 1. MySQL 核心告警规则 (`mysql-alerting.yaml`)

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: prometheus-mysql-alerting
  namespace: cattle-monitoring-system
  labels:
    app: rancher-monitoring
    release: rancher-monitoring
spec:
  groups:
    - name: mysql-alerting
      rules:
        # 1. 数据库实例宕机 (for: 5m 判定或 1m 灵敏判定)
        - alert: MysqlDown
          expr: mysql_up == 0
          for: 5m
          labels:
            severity: critical
          annotations:
            description: "MySQL 实例 {{ $labels.instance }} 已宕机离线！"

        # 2. 5 分钟内连接异常中断激增
        - alert: TooManyAbortedConnections
          expr: increase(mysql_global_status_aborted_connects[5m]) > 10
          for: 5m
          labels:
            severity: warning
          annotations:
            description: "MySQL 实例 {{ $labels.instance }} 5分钟内产生 {{ printf \"%.2f\" $value }} 次异常连接中断 (Aborted Connections)。"

        # 3. 慢查询持续偏高 (QPS > 1)
        - alert: TooManySlowQueriesFromMysql
          expr: rate(mysql_global_status_slow_queries[5m]) > 1
          for: 5m
          labels:
            severity: warning
          annotations:
            description: "MySQL 实例 {{ $labels.instance }} 慢查询速率偏高 (当前: {{ printf \"%.2f\" $value }}/s)。"

        # 4. 1 分钟内慢查询突增 (>50 次)
        - alert: TooManySlowQueriesIn1Min
          expr: increase(mysql_global_status_slow_queries[1m]) > 50
          for: 2m
          labels:
            severity: warning
          annotations:
            description: "MySQL 实例 {{ $labels.instance }} 近 1 分钟慢查询突增 {{ printf \"%.2f\" $value }} 条。"

        # 5. 打开文件句柄数过高 (>70%)
        - alert: MysqlOpenFilesHigh
          expr: mysql_global_status_innodb_num_open_files / mysql_global_variables_open_files_limit * 100 > 70
          for: 5m
          labels:
            severity: warning
          annotations:
            description: "MySQL 实例 {{ $labels.instance }} 打开文件数已占上限的 {{ printf \"%.2f\" $value }}%。"

        # 6. 连接池打满预警 (>80%)
        - alert: MysqlUseTooManyConnections
          expr: mysql_global_status_threads_connected / mysql_global_variables_max_connections * 100 > 80
          for: 5m
          labels:
            severity: warning
          annotations:
            description: "MySQL 实例 {{ $labels.instance }} 连接数占比已达 {{ printf \"%.2f\" $value }}%。"

        # 7. 并发活跃执行线程暴增 (>50)
        - alert: MysqlHaveTooManyAliveConnections
          expr: mysql_global_status_threads_running > 50
          for: 3m
          labels:
            severity: critical
          annotations:
            description: "MySQL 实例 {{ $labels.instance }} 正在并发执行的活跃线程数达到 {{ $value }}，存在慢 SQL 堵塞或突发大事务！"

        # 8. QPS 异常冲高 (>8000)
        - alert: MysqlHighQPS
          expr: rate(mysql_global_status_questions[5m]) > 8000
          for: 5m
          labels:
            severity: warning
          annotations:
            description: "MySQL 实例 {{ $labels.instance }} QPS 持续超过 8000 (当前: {{ printf \"%.2f\" $value }})。"

        # 9. 主从复制 IO 线程中断
        - alert: SlaveIOThreadStopped
          expr: mysql_slave_status_slave_io_running != 1
          for: 1m
          labels:
            severity: critical
          annotations:
            description: "MySQL 从库 {{ $labels.instance }} Slave IO 线程停止，主从同步中断！"

        # 10. 主从复制 SQL 线程中断 (发生 SQL 冲突)
        - alert: SlaveSQLThreadStopped
          expr: mysql_slave_status_slave_sql_running != 1
          for: 1m
          labels:
            severity: critical
          annotations:
            description: "MySQL 从库 {{ $labels.instance }} Slave SQL 线程停止，可能存在主键冲突或数据不一致！"

        # 11. 主从复制延迟超 60 秒
        - alert: SlaveLaggingBehindMaster60s
          expr: mysql_slave_status_seconds_behind_master > 60
          for: 2m
          labels:
            severity: warning
          annotations:
            description: "MySQL 从库 {{ $labels.instance }} 复制延迟持续超过 60 秒 (当前延迟: {{ $value }}s)。"

        # 12. 自增主键即将在短时间内耗尽 (自增列使用率 > 80%)
        - alert: MySQLAutoIncrementUsageHigh
          expr: (mysql_info_schema_auto_increment_column / mysql_info_schema_auto_increment_column_max) * 100 > 80
          for: 5m
          labels:
            severity: warning
          annotations:
            description: "表 {{ $labels.schema }}.{{ $labels.table }} 自增主键使用率已达 {{ printf \"%.2f\" $value }}%，请尽快扩容避免锁表！"

        # 13. 1 分钟内捕获到死锁发生 (Deadlock)
        - alert: Mysql_Deadlock
          expr: increase(mysql_info_schema_innodb_metrics_lock_lock_deadlocks_total[1m]) > 0
          labels:
            severity: warning
          annotations:
            description: "MySQL 实例 {{ $labels.instance }} 近 1 分钟发生死锁 (次数: {{ printf \"%.2f\" $value }})。"

        # 14. 实例在 3 分钟内发生过异常重启 (Uptime < 180s)
        - alert: Mysql_Instance_Reboot
          expr: mysql_global_status_uptime < 180
          for: 1m
          labels:
            severity: critical
          annotations:
            description: "MySQL 实例 {{ $labels.instance }} 在 3 分钟内发生重启，当前已运行 {{ $value }} 秒，请排查 Crash 原因！"
```

### 2. 外部宿主机物理层告警 (`mysql-node-exporter-prometheusrule.yaml`)

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: mysql-node-alerting
  namespace: cattle-monitoring-system
  labels:
    prometheus: k8s
    role: alert-rules
spec:
  groups:
    - name: mysql-node-alerting
      rules:
        # 1. 物理机宕机 / node_exporter 离线
        - alert: NodeDown
          expr: up{job="prometheus-mysql-node-exporter"} == 0
          for: 1m
          labels:
            severity: critical
          annotations:
            description: "外部主机 {{ $labels.instance }} 离线，可能死机或网络中断！"

        # 2. 物理磁盘可用空间低于 10% (排除 boot 与 tmp)
        - alert: NodeFilesystemIsLessThan10%
          expr: node_filesystem_free_bytes{fstype=~"ext4|xfs",job="prometheus-mysql-node-exporter",mountpoint!~".*tmp|.*boot"} / node_filesystem_size_bytes{fstype=~"ext4|xfs",job="prometheus-mysql-node-exporter",mountpoint!~".*tmp|.*boot"} * 100 < 10
          for: 30m
          labels:
            severity: critical
          annotations:
            description: "主机 {{ $labels.instance }} 挂载点 {{ $labels.mountpoint }} 可用空间已不足 10% (当前剩余: {{ printf \"%.2f\" $value }}%)。"

        # 3. 真实物理内存可用率低于 10%
        - alert: NodeMemUsedHigh
          expr: (1 - (node_memory_MemAvailable_bytes{job="prometheus-mysql-node-exporter"} / node_memory_MemTotal_bytes{job="prometheus-mysql-node-exporter"})) * 100 > 90
          for: 5m
          labels:
            severity: critical
          annotations:
            description: "主机 {{ $labels.instance }} 内存使用率超过 90% (当前值: {{ printf \"%.2f\" $value }}%)。"

        # 4. CPU 持续高负荷 (>80%)
        - alert: NodeCPUHigh
          expr: ((1 - avg(irate(node_cpu_seconds_total{mode="idle",job="prometheus-mysql-node-exporter"}[1m])) by (instance))) * 100 > 80
          for: 1m
          labels:
            severity: critical
          annotations:
            description: "主机 {{ $labels.instance }} CPU 使用率持续超过 80% (当前值: {{ printf \"%.2f\" $value }}%)。"

        # 5. 运行进程数过多占用 CPU (>90%)
        - alert: NodeProcessHigh
          expr: sum by (process_name, instance) (rate(process_cpu_seconds_total{job="prometheus-mysql-node-exporter", mode!="idle"}[1m])) * 100 > 90
          for: 10m
          labels:
            severity: critical
          annotations:
            description: "主机 {{ $labels.instance }} 进程占用过多 CPU 资源！"

        # 6. 系统打开文件句柄数过高 (>90% of 64000)
        - alert: NodeFileDescriptorsHigh
          expr: sum(node_filefd_allocated{job="prometheus-mysql-node-exporter"}) by (instance) / 64000 * 100 > 90
          for: 10m
          labels:
            severity: warning
          annotations:
            description: "主机 {{ $labels.instance }} 打开的文件描述符已超 90%，存在 ulimit 耗尽风险！"

        # 7. 1 分钟平均负载超过总核数 80% (单核负载比 > 0.8)
        - alert: NodeLoad1High
          expr: (sum(node_load1{job="prometheus-mysql-node-exporter"}) by (instance)) / (count(node_cpu_seconds_total{job="prometheus-mysql-node-exporter",mode="system"}) by (instance)) > 0.8
          for: 1m
          labels:
            severity: warning
          annotations:
            description: "主机 {{ $labels.instance }} 1分钟平均负载超过 CPU 承载容量的 80%！"

        # 8. 5 分钟平均负载超过总核数 80%
        - alert: NodeLoad5High
          expr: (sum(node_load5{job="prometheus-mysql-node-exporter"}) by (instance)) / (count(node_cpu_seconds_total{job="prometheus-mysql-node-exporter",mode="system"}) by (instance)) > 0.8
          for: 1m
          labels:
            severity: warning
          annotations:
            description: "主机 {{ $labels.instance }} 5分钟平均负载超过 CPU 承载容量的 80%！"

        # 9. 15 分钟平均负载超过总核数 80%
        - alert: NodeLoad15High
          expr: (sum(node_load15{job="prometheus-mysql-node-exporter"}) by (instance)) / (count(node_cpu_seconds_total{job="prometheus-mysql-node-exporter",mode="system"}) by (instance)) > 0.8
          for: 1m
          labels:
            severity: warning
          annotations:
            description: "主机 {{ $labels.instance }} 15分钟平均负载超过 CPU 承载容量的 80%！"
```

---

## 五、 Grafana 可视化大盘与验收测试

### 1. 核心大盘导入 (Dashboard JSON)
在 Grafana 中进入 **Dashboards -> Import**，导入以下专用定制大盘：
- `MySQL-Nodes-Exporter.json`：针对外部数据库宿主机的 CPU、负载、内存（精确显示 used/buffers/cached/free）、磁盘空间（表格形式直观展现每个挂载点使用百分比）、网卡流量。
- `mysql-overview_rev5_wowjoy.json`：MySQL 实例总览（QPS、TPS、连接数、InnoDB 缓冲池）。
- `mysql-replication_rev1_wowjoy.json`：MySQL 主从与 MHA 复制拓扑与秒级延迟大屏。

### 2. Prometheus 界面验收清单
1. **Targets 状态核验**：
   - 访问 `http://<Prometheus-IP>:9090/targets`；
   - 检查 `serviceMonitor/cattle-monitoring-system/mysql-node-exporter/0` 是否为 `(20/20 up)`；
   - 检查 `serviceMonitor/cattle-monitoring-system/prometheus-mysql-exporter/0` 是否全部 `UP`。
2. **Rules 规则状态核验**：
   - 访问 `http://<Prometheus-IP>:9090/rules`；
   - 确认 `mysql-alerting` 与 `mysql-node-alerting` 规则组均处于绿色 `OK` 正常评估状态。

---

> [!TIP] 💡 关联技术与延伸阅读
>
> * [MySQL-Exporter 生产级监控与 MGR 集群多实例实战](./05-MySQL-Exporter生产级监控与MGR集群多实例实战.md)
> * [NodeExporter 宿主机全方位监控与指标基线](./02-NodeExporter宿主机全方位监控与指标基线.md)
> * [生产级监控缺口评估与 Operator 演进选型](./06-生产级监控体系缺口评估与Operator演进选型.md)
> * [外部数据库节点监控纳管清单 (YAML)](../../../../05-Install/monitoring/10-external-database-nodes-servicemonitor.yaml)

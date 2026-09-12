# MySQL-Exporter 生产级监控：MGR 组复制与 MHA 高可用集群实战指南

## 一、 核心定位与两大高可用架构（MGR vs MHA）监控视角

**mysqld_exporter** 是 Prometheus 官方针对 MySQL 及其衍生分支（MariaDB、Percona）提供的指标采集组件。在企业级生产环境中，数据库往往以高可用集群形态交付。知识库覆盖了两大主流高可用流派：
1. **MGR（MySQL Group Replication）**：基于 Paxos 协议的原生分布式多副本强一致架构（如知识库中 `./05-Install/mysql/mysql8.0.43_huazhuo_prod/` 华卓生产部署套件）；
2. **MHA（Master High Availability）**：基于传统主从复制（Replication）与外部仲裁守护的经典高可用架构（如医疗 HIS / 核心数据中心物理机集群）。

由于底层通信与故障倒换逻辑完全不同，mysqld_exporter 在抓取指标、拓扑发现及告警规则上有着截然不同的关注维度：

```text
┌────────────────────────────────────────────────────────────────────────┐
│                    【MGR 组复制架构监控拓扑】                          │
│                                                                        │
│   Node 1 (192.168.10.101:3306) [PRIMARY]                               │
│   Node 2 (192.168.10.102:3306) [SECONDARY]   ──> 内核 Paxos 通信       │
│   Node 3 (192.168.10.103:3306) [SECONDARY]                             │
│   核心抓取：group_replication 状态、单主/多主角色、事务冲突与流控配额  │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    │ Multi-Target 统一探测 /probe
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                    【MHA 传统主从高可用监控拓扑】                      │
│                                                                        │
│   Node 1: his-mdsn01 (192.168.190.41) [MASTER] (挂载 VIP 192...200)    │
│   Node 2: his-mdsn02 (192.168.190.42) [SLAVE / Candidate]              │
│   Node 3: his-mdsn03 (192.168.190.43) [SLAVE / Standby]                │
│   Manager: his-mha   (192.168.190.44) [仲裁切换机]                     │
│   核心抓取：read_only 状态漂移、Slave IO/SQL 线程、复制延迟、Relay 堆积│
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        Prometheus Server 时序库                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 二、 生产最小化权限与安全加固规范

在生产环境中，**严禁使用 root 账号运行 Exporter**。无论是 MGR 还是 MHA，均需遵循最小权限原则，并严格限制最大连接数，防止 Exporter 在数据库连接紧张时雪上加霜：

```sql
-- 1. 创建专用监控账号并限制最大并发连接数为 5 (MHA 主从集群只需在主库执行，自动同步至从库)
CREATE USER 'exporter'@'%' IDENTIFIED BY 'Exporter@Password2026!' WITH MAX_USER_CONNECTIONS 5;

-- 2. 授予必要监控权限：
-- PROCESS: 允许查看完整 processlist，排查慢查询与锁阻塞
-- REPLICATION CLIENT: 允许查看主从/MGR 复制状态 (SHOW REPLICA STATUS / SHOW SLAVE STATUS / Performance Schema)
-- SELECT ON *.*: 允许读取 performance_schema, information_schema 及 sys 视图
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter'@'%';

-- 3. 刷新权限
FLUSH PRIVILEGES;
```

---

## 三、 MHA 高可用集群深度监控实战

MHA 集群基于传统 Binlog/Relay log 复制，其故障自动切换（Failover）是动态改写主从拓扑的。针对 MHA 的监控必须具备**全链路防脑裂、防误写、从库复制健康保障**能力。

### 1. MHA 集群三大核心监控痛点

1. **动态角色转换与读写隔离破坏**：
   - 正常状态下，Master 必须为 `read_only = 0`，所有 Slave 必须严格为 `read_only = 1`；
   - 若运维误操作导致从库 `read_only = 0`，业务误写入从库将导致**主从数据双写分叉**；
   - 若 MHA 切换后旧主未被正确重置只读，将导致**双主脑裂冲突**。
2. **主从同步静默中断**：
   - 从库由于主键冲突、磁盘满或网络抖动，Slave IO 线程或 SQL 线程可能静默挂起。一旦发生故障，MHA 将因从库无法追平日志而拒绝切换或导致业务长时间中断。
3. **VIP 可达性与物理实例脱节**：
   - 物理实例虽然存活，但 VIP 可能因机房交换机 ARP 缓存未刷新或 keepalived 异常而脱落，导致应用无法连接。

### 2. 物理节点与业务 VIP 双轨探测架构

在 Prometheus 中，针对 MHA 集群推荐采用**物理实例 + VIP 端点双轨抓取**：

```yaml
scrape_configs:
  # 1. 物理节点全量指标抓取 (监控每个节点的硬件负载、复制延迟、Buffer Pool)
  - job_name: 'mysql-mha-nodes'
    metrics_path: /probe
    static_configs:
      - targets:
          - 192.168.190.41:3306 # his-mdsn01 (Master)
          - 192.168.190.42:3306 # his-mdsn02 (Candidate Slave)
          - 192.168.190.43:3306 # his-mdsn03 (Standby Slave)
        labels:
          cluster: 'his-mysql-mha'
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: mysqld-exporter.monitoring.svc:9104

  # 2. 业务 VIP 读写探测 (验证应用当前实际写入的数据库是否可用且处于非只读状态)
  - job_name: 'mysql-mha-vip'
    metrics_path: /probe
    static_configs:
      - targets:
          - 192.168.190.200:3306 # HIS 业务读写 VIP
        labels:
          cluster: 'his-mysql-mha'
          role: 'virtual-master'
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: mysqld-exporter.monitoring.svc:9104
```

---

## 四、 MGR 组复制集群生产级多目标采集 (Multi-Target Pattern)

针对 `./05-Install/mysql/mysql8.0.43_huazhuo_prod/` 的 MGR 3 节点集群，mysqld_exporter 同样采用集中式 Multi-Target 模式：

### 1. Exporter 凭据配置文件 (`/etc/mysql/.my.cnf`)

```ini
[client]
user = exporter
password = Exporter@Password2026!

# MGR 节点集群配置
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

### 2. Prometheus 自动抓取配置 (`prometheus.yml`)

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
      - target_label: __address__
        replacement: mysqld-exporter.monitoring.svc:9104
```

---

## 五、 MGR vs MHA 黄金指标与 PromQL 对比矩阵

| 监控维度 | MHA 集群核心关注指标 (传统主从) | MGR 集群核心关注指标 (组复制) | 生产告警阈值与判定条件 |
| :--- | :--- | :--- | :--- |
| **实例在线** | `mysql_up == 1` | `mysql_up == 1` | `== 0` 持续 1 分钟立即告警 |
| **主从/复制状态** | `mysql_slave_status_slave_io_running == 1`<br>`mysql_slave_status_slave_sql_running == 1` | `mysql_global_status_group_replication_member_status == 1` (ONLINE) | 线程不为 1 或状态变为 RECOVERING / UNREACHABLE |
| **复制延迟** | `mysql_slave_status_seconds_behind_master` | `mysql_global_status_group_replication_flow_control_paused_time` (流控时间) | MHA 延迟 > 30s 预警；MGR 流控触发告警 |
| **只读防误写** | `mysql_global_variables_read_only`<br>`mysql_global_variables_super_read_only` | `mysql_global_status_group_replication_primary_member` (单主选举) | 从库只读标记为 0 致命报警；主库误设只读报警 |
| **中继日志堆积** | `mysql_slave_status_relay_log_space` | MGR 事务认证队列深度与冲突率 | Relay log 占用磁盘 > 20GB 报警 |
| **死锁发生** | `increase(mysql_info_schema_innodb_metrics_lock_lock_deadlocks_total[1m]) > 0` | 事务冲突回滚率 `group_replication_transactions_conflicts` | 1 分钟内死锁增量 > 0 |
| **自增主键耗尽** | `(auto_increment_column / auto_increment_column_max) * 100 > 80` | 同左 (MGR 更需防止无主键表) | 自增列使用率 > 80% 提前扩容 |

---

## 六、 MHA 与 MGR 生产专属告警规则集

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: mysql-high-availability-alerting
  namespace: monitoring
  labels:
    role: alert-rules
spec:
  groups:
    - name: mha-cluster.alerts
      rules:
        # 1. MHA 从库被意外关闭只读 (严重安全红线：极易发生主从双写数据污染)
        - alert: MhaSlaveNotReadOnly
          expr: mysql_global_variables_read_only{role="slave"} == 0
          for: 1m
          labels:
            severity: critical
          annotations:
            summary: "MHA 从库未开启只读保护: {{ $labels.instance }}"
            description: "从库 {{ $labels.instance }} read_only=0，存在业务误写导致主从数据分叉的重大风险！"

        # 2. MHA 业务 VIP 实例处于只读状态 (业务写不可用)
        - alert: MhaVipEndpointReadOnly
          expr: mysql_global_variables_read_only{role="virtual-master"} == 1
          for: 1m
          labels:
            severity: critical
          annotations:
            summary: "MHA 业务 VIP 当前处于只读状态: {{ $labels.instance }}"
            description: "VIP {{ $labels.instance }} 当前挂载的数据库处于 read_only=1，全站写业务已中断！"

        # 3. MHA 主从复制 IO 线程停止
        - alert: MhaSlaveIOThreadDown
          expr: mysql_slave_status_slave_io_running != 1
          for: 1m
          labels:
            severity: critical
          annotations:
            summary: "从库 Slave IO 线程中断: {{ $labels.instance }}"
            description: "从库 {{ $labels.instance }} IO 线程停止，无法接收主库 Binlog！"

        # 4. MHA 主从复制 SQL 线程停止 (SQL 冲突/报错)
        - alert: MhaSlaveSQLThreadDown
          expr: mysql_slave_status_slave_sql_running != 1
          for: 1m
          labels:
            severity: critical
          annotations:
            summary: "从库 Slave SQL 线程中断: {{ $labels.instance }}"
            description: "从库 {{ $labels.instance }} SQL 重放线程发生错误，主从同步中断！"

        # 5. MHA 复制延迟过高 (超过 60s 严重阻碍 MHA 故障平滑切换)
        - alert: MhaReplicationLagCritical
          expr: mysql_slave_status_seconds_behind_master > 60
          for: 2m
          labels:
            severity: warning
          annotations:
            summary: "从库复制延迟超标: {{ $labels.instance }}"
            description: "从库 {{ $labels.instance }} 延迟已达 {{ $value }} 秒，若此时主库宕机将导致切换严重超时！"

        # 6. Relay Log 堆积过大 (>20GB)
        - alert: MhaRelayLogSpaceHigh
          expr: mysql_slave_status_relay_log_space > 21474836480
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "中继日志积压严重: {{ $labels.instance }}"
            description: "从库 {{ $labels.instance }} Relay Log 已占用 {{ printf \"%.2f\" $value / 1073741824 }} GB，存在写满磁盘风险。"
```

---

## 七、 数据库版本兼容性深度剖析：MySQL 5.7 vs 8.0/8.4 采集机制差异与生产避坑

很多工程师误以为 Prometheus `mysqld_exporter` 的采集参数与底层数据库版本无关，**这在严苛生产环境中是极其危险的认知误区**。各采集项在 MySQL 5.7、8.0 以及最新的 8.4 LTS 内核下，其底层数据源存储机制、互斥锁模型及性能开销存在本质区别：

### 1. 核心采集参数与数据库版本兼容对照矩阵

| 采集参数选项 | 底层数据源 | MySQL 5.7 表现与内部机制 | MySQL 8.0 / 8.4 LTS 表现与内部机制 | 版本敏感度与生产风险评级 |
| :--- | :--- | :--- | :--- | :--- |
| `--collect.info_schema.innodb_metrics` | `INNODB_METRICS` | 支持良好，但部分指标默认处于 `disabled` 状态 | 原生全面支持，指标更丰富健全 | **中度相关**（低风险） |
| `--collect.info_schema.processlist` | `PROCESSLIST` | **极度危险**：受全局互斥锁 `LOCK_thread_count` 保护，高并发时频繁抓取会导致全站连接超时排队 | **安全可靠**：8.0.22+ 默认重定向为无锁的 `performance_schema.processlist`；8.4 LTS 彻底废弃旧表 | **重度相关**（5.7 建议禁用，8.0 推荐开启） |
| `--collect.info_schema.tables`<br>`--collect.info_schema.tablestats` | `TABLES` 表元数据 | **致命级别风险**：5.7 元数据在磁盘 `.frm` 文件中，每次抓取遍历成千上万个物理文件，引发磁盘 IO 打满与 MDL 锁阻塞 | **相对安全**：8.0 引入事务型数据字典（Data Dictionary），纯内存化查询；但大表量仍消耗 CPU | **致命相关**（5.7 严禁全量开，8.0 需配白名单） |
| `--collect.perf_schema.eventsstatements` | `events_statements_summary_by_digest` | 需确保 `setup_consumers` 开启；高 QPS 下有轻微 Latch 开销 | 默认开启，SQL 摘要统计更丰富，但 2万+ QPS 下有 3%~8% CPU 损耗 | **高度相关**（需视业务 QPS 评估） |
| `--collect.perf_schema.file_events`<br>`indexiowaits / tableiowaits / tablelocks` | `performance_schema` 内部等待与锁表 | **5.7 默认未全开**：大量 instrument 默认关闭，开启 Exporter 可能抓取到空指标 | **8.0 默认覆盖面更广**，开箱即用度大幅提升 | **高度相关**（5.7 需额外修改 `my.cnf`） |
| `--collect.binlog_size` | `SHOW BINARY LOGS` | 5.7 默认 `log_bin=OFF`，若未配置开启 binlog 该采集器无效 | 8.0 默认 `log_bin=ON`，开箱即用，支持 GTID 增量计算 | **中度相关**（依赖 binlog 开关） |
| `--collect.auto_increment.columns` | `COLUMNS` + `TABLES` | 受限于 5.7 `.frm` 读取性能，表数量极多时拉取变慢 | 依赖 8.0 数据字典，查询极快，完美适配 8.0 自增持久化 | **高度相关**（8.0 强烈推荐） |

---

### 2. 三大最致命的“版本差异巨坑”与内核深剖

#### 坑 1：`info_schema.tables` —— MySQL 5.7 的“磁盘 IO 击穿与 MDL 锁炸弹”
* **5.7 内核灾难机制**：MySQL 5.7 及更早版本的表元数据分散在操作系统底层的 `.frm`、`.par` 物理文件中。Exporter 周期性执行 `SELECT * FROM information_schema.TABLES` 时，操作系统 VFS 必须**逐个打开成千上万个 `.frm` 文件读取表头结构**。
  - 若库内有海量分表或分区表，会导致宿主机物理磁盘 IOPS 瞬间打满；
  - 查询期间持有元数据读锁（MDL Shared Read），**导致线上的 `ALTER TABLE` 或高并发 DML 事务直接堵塞挂死！**
* **8.0 官方内核重构**：MySQL 8.0 彻底废弃了物理 `.frm` 文件，改用基于 InnoDB 引擎的**事务型数据字典（Data Dictionary）**，元数据查询直接走 Buffer Pool 内存缓存，不再扫描磁盘物理文件。
* **生产准则**：
  - **在 MySQL 5.7 中坚决关闭全量 `--collect.info_schema.tables`**；
  - 在 MySQL 8.0 中若需开启，必须使用 `--collect.info_schema.tables.databases=^(核心库1|核心库2)$` 限制库名正则，避免时序基数膨胀。

#### 坑 2：`info_schema.processlist` —— 5.7 全局大锁 `LOCK_thread_count`
* **5.7 性能陷阱**：在 5.7 中，查询 `information_schema.PROCESSLIST` 需要竞争核心全局互斥锁 `LOCK_thread_count`。当业务并发连接数达到 1000~2000 时，Exporter 每 15 秒扫一次 Processlist，会导致新进来的业务连接全部在此互斥锁上排队，引发全站大面积报 `Too Many Connections` 或连接超时。
* **8.0.22+ 官方无锁化演进**：MySQL 官方为了彻底解决此问题，在 8.0.22+ 中新增了基于 Performance Schema 的实现，并引入系统变量 `performance_schema_show_processlist=ON`（默认开启），实现了**全无锁并发读取连接线程列表**；在 8.4 LTS 中，旧版 `information_schema.processlist` 已被完全废弃。

#### 坑 3：`perf_schema.*` —— 5.7 默认“沉睡”抓取空数据
* **现象**：在 MySQL 5.7 开启了 `--collect.perf_schema.file_events` 或 `tableiowaits`，Prometheus 却发现查出来的指标全是 0。
* **根因**：MySQL 5.7 虽然内置了 Performance Schema，但官方为了节省开销，默认将绝大多数非核心 instruments 和 consumers 设为了 `NO`（未启用）。
* **生效条件**：若要在 5.7 中采集这些指标，必须在被监控实例的 `my.cnf` 中显式激活：
  ```ini
  [mysqld]
  performance_schema = ON
  performance-schema-instrument = 'wait/io/table/%=ON'
  performance-schema-instrument = 'wait/io/file/%=ON'
  performance-schema-consumer-events-waits-current = ON
  ```

---

### 3. 部署交付清单（`08-mysqld-exporter.yaml`）版本适配范式

为了兼顾存量 MySQL 5.7 业务系统的稳健运行与新一代 MySQL 8.0+ 的全观测能力，安装清单 [`08-mysqld-exporter.yaml`](../../../../05-Install/monitoring/08-mysqld-exporter.yaml) 采取了 **“5.7 默认生效，8.0 注释备用”** 的双轨模板设计：

```yaml
          args:
            - "--config.my-cnf=/etc/mysql/.my.cnf"
            # =====================================================================
            # 【MySQL 5.7 生产稳健推荐配置 (当前生效)】
            # 5.7 避坑核心：坚决禁用全量 tables/tablestats 扫盘，避开 processlist 全局锁
            # =====================================================================
            - "--collect.info_schema.innodb_metrics"
            - "--collect.binlog_size"
            - "--collect.auto_increment.columns"
            # 5.7 严禁全量开启 tables 与 tablestats (会频繁扫描物理 .frm 文件导致磁盘 IO 爆满与 MDL 锁阻塞)
            - "--no-collect.info_schema.tables"
            - "--no-collect.info_schema.tablestats"
            # 5.7 避免高并发连接下 LOCK_thread_count 全局互斥锁竞争导致业务无法新建连接
            - "--no-collect.info_schema.processlist"
            # 5.7 避免 eventsstatements 内存表摘要在高并发下引发额外的互斥锁争用
            - "--no-collect.perf_schema.eventsstatements"

            # =====================================================================
            # 【MySQL 8.0+ / 8.4 LTS 现代化生产配置 (注释备用，升级后按需开启)】
            # 8.0 优势：依托内部事务型数据字典 (Data Dictionary) 与无锁 performance_schema
            # =====================================================================
            # - "--collect.info_schema.innodb_metrics"
            # - "--collect.info_schema.processlist"      # 8.0.22+ 依托无锁 performance_schema.processlist，安全可用
            # - "--collect.binlog_size"
            # - "--collect.auto_increment.columns"      # 基于数据字典极速获取，精准防自增 ID 耗尽
            # - "--collect.perf_schema.tableiowaits"     # 8.0 默认全面开启表级 IO 统计
            # - "--collect.perf_schema.indexiowaits"     # 索引级别 IO 延迟观测
            # - "--collect.perf_schema.tablelocks"       # 表锁争用统计
            # # 8.0 开启 tables 建议加库名白名单正则，防止单实例海量表导致 Prometheus 时序爆炸：
            # - "--collect.info_schema.tables"
            # - "--collect.info_schema.tables.databases=^(his_db|order_db|pay_db)$"
```

---

## 八、 生产综合避坑红线

> [!CAUTION]
> 1. **Performance Schema 高并发开销陷阱**：
>    在每秒数万 QPS 的大型高并发事务库中，谨慎开启 `--collect.perf_schema.eventsstatements`。该参数会轮询 `events_statements_summary_by_digest` 内存表，可能引发互斥锁争用，导致数据库 CPU 额外增加 5%~10%。常规监控建议依托 `info_schema` 核心指标即可满足 95% 以上需求。
>
> 2. **Relay Log 被过度清理导致 MHA 补齐失败**：
>    MySQL 默认 `relay_log_purge = 1` 会自动删除回放完的 Relay Log。但在 MHA 切换过程中，较慢的从库需要从较快的从库上补齐差额中继日志。从库上必须设置 `relay_log_purge = 0`，并通过定时脚本（`purge_relay_logs`）统一安全清理。

---

> [!TIP] 💡 关联技术与延伸阅读
>
> * [MySQL MHA 高可用集群架构原理与生产落地实战指南](../../../01-Mysql/03-运维与管理/11-MySQL-MHA高可用集群架构原理与生产落地实战指南.md)
> * [企业级实战：Rancher 体系下 MySQL 集群与外部节点监控全景落地指南](./07-企业级实战-Rancher平台MySQL与外部节点监控全景落地指南.md)
> * [生产级 MySQL 8.0 MGR 高可用安装包与自动化脚本](../../../../05-Install/mysql/mysql8.0.43_huazhuo_prod/README.md)
> * [外部数据库节点监控纳管清单 (YAML)](../../../../05-Install/monitoring/10-external-database-nodes-servicemonitor.yaml)
> * [mysqld-exporter 部署清单 (YAML)](../../../../05-Install/monitoring/08-mysqld-exporter.yaml)
> * [生产级告警规则清单 (YAML)](../../../../05-Install/monitoring/09-alert-rules.yaml)

# Fluentd 生产级管道配置详解

> 基于真实生产集群 ConfigMap `fluentd-config`，包含容器日志、宿主机日志、Systemd 日志三路采集，双索引前缀输出至 Elasticsearch。

---

## 1. 整体架构与数据流

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     Fluentd DaemonSet (每节点)                           │
│                                                                         │
│  [INPUT 层]                   [FILTER 层]              [OUTPUT 层]       │
│                                                                         │
│  containers.input.conf        @k8s-service label        @k8s label      │
│  /var/log/containers/*.log ─► detect_exceptions    ─►  ES: k8s-* 索引   │
│                               concat                                    │
│                               kubernetes_metadata                       │
│                               parser (JSON展开)                          │
│                               record_transformer                         │
│                               relabel @k8s                              │
│                                                                         │
│  forward.input.conf                                                     │
│  Forward 协议（聚合器接收）                                               │
│                                                                         │
│  host.input.conf              @hostlogs label           @host label      │
│  /var/log/dmesg               kubernetes_metadata   ─►  ES: host-* 索引  │
│  /var/log/secure              record_transformer                         │
│  /var/log/messages            relabel @host                             │
│                                                                         │
│  systemd.input.conf           @systemd label                            │
│  kubelet.service              kubernetes_metadata                        │
│  docker.service               record_transformer                         │
│                               relabel @host                             │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. system.conf — 全局系统配置

```xml
<system>
  root_dir /tmp/fluentd-buffers/
</system>
```

| 参数 | 值 | 作用 |
|------|----|------|
| `root_dir` | `/tmp/fluentd-buffers/` | Fluentd 内部缓冲文件的根目录。output.conf 中各 buffer path 基于此路径。注意 /tmp 重启后清空，**生产环境建议改为 PVC 挂载路径（如 `/var/log/fluentd-buffers/`）** |

---

## 3. containers.input.conf — K8S 容器日志采集管道

### 3.1 INPUT: tail 源读取

```xml
<source>
  @id fluentd-containers.log
  @type tail                              # Fluentd 内置 tail 输入插件，持续追踪文件新增内容
  @label @k8s-service                     # 直接路由至 @k8s-service label，跳过全局 filter 链
  path /var/log/containers/*.log          # 宿主机所有容器日志（containerd/Docker 均在此）
  pos_file /var/log/es-containers.log.pos # 断点续传文件：记录每个日志文件的已读偏移量
  tag raw.kubernetes.*                    # 初始 tag，后续 detect_exceptions 会去掉 raw. 前缀
  read_from_head true                     # Pod 重启后重新从文件头读取，防止漏采
  <parse>                                 # 多格式解析器
    @type multi_format
    <pattern>
      format json                         # 模式1：Docker JSON 格式日志
      time_key time
      time_format %Y-%m-%dT%H:%M:%S.%NZ
    </pattern>
    <pattern>
      format /^(?<time>.+) (?<stream>stdout|stderr) [^ ]* (?<log>.*)$/
      time_format %Y-%m-%dT%H:%M:%S.%N%:z # 模式2：containerd CRI 格式（主流）
    </pattern>
  </parse>
</source>
```

> **关键说明**：`@label @k8s-service` 使该 source 的日志跳过顶层路由，直接进入 `<label @k8s-service>` 块处理，实现逻辑隔离。

---

### 3.2 FILTER 链（在 `<label @k8s-service>` 内）

#### ① detect_exceptions — Java 多行异常堆栈熔合

```xml
<match raw.kubernetes.**>
  @id raw.kubernetes
  @type detect_exceptions
  remove_tag_prefix raw          # 去掉 raw. 前缀：raw.kubernetes.** → kubernetes.**
  message log                    # 在 log 字段中检测多行堆栈
  stream stream                  # 按 stream 字段（stdout/stderr）区分流
  multiline_flush_interval 5     # 5秒未收到新行则强制提交，防止堆栈日志永远等待
  max_bytes 500000               # 单条熔合日志最大 500KB
  max_lines 1000                 # 单条堆栈最大行数
</match>
```

> **作用**：将 Spring Boot / Java 应用的多行 Exception 堆栈从多条日志熔合为一条，避免 ES 中出现碎片化的半条堆栈，显著提升 Kibana 检索体验。

#### ② filter_concat — 多行拼接兜底

```xml
<filter **>
  @id filter_concat
  @type concat
  key log
  multiline_end_regexp /\n$/     # 以换行结尾为多行结束标志
  separator ""                   # 拼接时不添加分隔符
</filter>
```

> **作用**：detect_exceptions 处理 Java 堆栈，concat 处理其他语言（Go panic、Python traceback 等）的多行日志兜底熔合。

#### ③ filter_kubernetes_metadata — 自动注入 K8S 元数据

```xml
<filter **>
  @id filter_kubernetes_metadata
  @type kubernetes_metadata
</filter>
```

> **作用**：调用 K8S API Server 查询并注入以下字段到每条日志中：
> - `kubernetes.namespace_name` — 命名空间
> - `kubernetes.pod_name` — Pod 名称
> - `kubernetes.container_name` — 容器名称
> - `kubernetes.labels.*` — Pod 标签
> - `kubernetes.host` — 所在节点
>
> 注入后日志可在 Kibana 中按命名空间、Pod、标签过滤。

#### ④ filter_parser — JSON 业务字段二次展开

```xml
<filter **>
  @id filter_parser
  @type parser
  key_name log                   # 对 log 字段的字符串值进行二次解析
  reserve_data true              # 保留原有字段（如 kubernetes.* 元数据）
  remove_key_name_field true     # 解析成功后删除原始 log 字段，避免重复
  <parse>
    @type multi_format
    <pattern>
      format json                # 业务层 JSON（如 {"level":"INFO","msg":"..."}）展开为顶层字段
    </pattern>
    <pattern>
      format none                # 纯文本日志直接保留
    </pattern>
  </parse>
</filter>
```

> **作用**：将业务应用输出的 JSON 字符串（嵌套在 `log` 字段中）二次反序列化，解出 `level`、`msg`、`traceId` 等业务字段，便于在 Kibana 中精确过滤。

#### ⑤ record_transformer — 删除冗余字段

```xml
<filter **>
  @type record_transformer
  remove_keys $.docker.container_id,
              $.kubernetes.container_image_id,
              $.kubernetes.pod_id,
              $.kubernetes.namespace_id,
              $.kubernetes.master_url,
              $.kubernetes.labels.pod-template-hash,
              $.kubernetes.namespace_labels,
              $.kubernetes.labels.workload_user_cattle_io/workloadselector,
              $.kubernetes.labels.logging
</filter>
```

> **删除字段说明**：
>
> | 字段 | 删除原因 |
> |------|----------|
> | `container_image_id` / `pod_id` / `namespace_id` | 内部 UUID，对日志检索无价值，减小索引体积 |
> | `master_url` | 固定值，无意义 |
> | `pod-template-hash` | RS 哈希值，Kibana 中用 pod_name 更直观 |
> | `namespace_labels` | 通常为空或无关标签，节省存储 |
> | `workload_user_cattle_io/workloadselector` | Rancher 平台内部标签，与日志分析无关 |
> | `logging` | 日志过滤开关标签，已完成采集决策无需保留 |

#### ⑥ relabel — 路由至输出

```xml
<match **>
  @type relabel
  @label @k8s      # 路由至 output.conf 中的 <label @k8s> 输出到 ES k8s-* 索引
</match>
```

---

## 4. forward.input.conf — Forward 协议聚合接收

```xml
<source>
  @id forward
  @type forward    # 监听 24224 端口，接收其他 Fluentd 实例转发的日志
</source>
```

> **作用**：用于多级 Fluentd 架构中，边缘节点的 Fluent Bit 或轻量 Fluentd 将日志转发给中心聚合节点处理。当前作为备用接收端，支持未来扩展为 Kafka → Fluentd 中心聚合模式。

---

## 5. host.input.conf — 宿主机系统日志采集

采集三类宿主机关键日志，全部路由至 `@hostlogs` label：

```xml
<source>
  @type tail
  @id in_tail_dmesg
  @label @hostlogs
  path /var/log/dmesg            # 内核环形缓冲区消息（OOM Kill、硬件错误、驱动异常）
  pos_file /var/log/dmesg.log.pos
  tag host.dmesg
  read_from_head true
  <parse>
    @type syslog                 # 按 syslog 格式解析（priority、timestamp、hostname、message）
  </parse>
</source>

<source>
  @type tail
  @id in_tail_secure
  @label @hostlogs
  path /var/log/secure           # SSH 认证、sudo、PAM 安全事件（仅 RHEL/CentOS）
  pos_file /var/log/secure.log.pos
  tag host.secure
  read_from_head true
  <parse>@type syslog</parse>
</source>

<source>
  @type tail
  @id in_tail_messages
  @label @hostlogs
  path /var/log/messages         # 系统通用日志（服务启停、网络状态、cron）
  pos_file /var/log/messages.log.pos
  tag host.messages
  read_from_head true
  <parse>@type syslog</parse>
</source>
```

### @hostlogs label 处理链

```xml
<label @hostlogs>
  <filter **>
    @type kubernetes_metadata
    @id filter_kube_metadata_host   # 注入节点 K8S 元数据（hostname 映射到节点名）
  </filter>
  <filter **>
    @type record_transformer
    @id filter_containers_stream_transformer_host
    <record>
      stream_name ${tag}-${record["host"]}   # 添加 stream_name 字段便于区分日志来源节点
    </record>
  </filter>
  <match **>
    @type relabel
    @label @host   # 路由至 output.conf 的 <label @host>，写入 host-* 索引
  </match>
</label>
```

---

## 6. systemd.input.conf — Systemd 核心服务日志

```xml
<source>
  @type systemd
  @id in_systemd_kubelet
  @label @systemd
  matches [{ "_SYSTEMD_UNIT": "kubelet.service" }]   # 仅采集 kubelet 服务日志
  <entry>
    field_map {"MESSAGE": "message", "_HOSTNAME": "hostname", "_SYSTEMD_UNIT": "systemd_unit"}
    field_map_strict true    # 严格映射，仅保留 field_map 中声明的字段
  </entry>
  path /var/log/journal      # Systemd journal 存储路径
  <storage>
    @type local
    persistent true
    path /var/log/fluentd-journald-kubelet-pos.json  # 断点续传位置文件
  </storage>
  read_from_head true
  tag kubelet.service
</source>

<source>
  @type systemd
  @id in_systemd_docker
  @label @systemd
  matches [{ "_SYSTEMD_UNIT": "docker.service" }]    # 仅采集 docker 服务日志
  <!-- 配置同上，tag: docker.service -->
</source>
```

> **作用**：直接从 Systemd journal 读取 kubelet 和 Docker/containerd 的原生日志，无需依赖文件落盘，获取更完整的节点基础设施日志，便于排查节点级故障（kubelet crash、镜像拉取失败等）。

### @systemd label 处理链

```xml
<label @systemd>
  <filter **>
    @type kubernetes_metadata
    @id filter_kube_metadata_systemd
  </filter>
  <filter **>
    @type record_transformer
    @id filter_systemd_stream_transformer
    <record>
      stream_name ${tag}-${record["hostname"]}  # 如 kubelet.service-node-1
    </record>
  </filter>
  <match **>
    @type relabel
    @label @host    # Systemd 日志也汇入 host-* 索引
  </match>
</label>
```

---

## 7. output.conf — 双路 ES 输出

### @k8s — 容器业务日志

```xml
<label @k8s>
  <match **>
    @id elasticsearch-k8s
    @type elasticsearch
    @log_level info
    include_tag_key true
    host elasticsearch          # ES Service 名称（需与 K8S Service 匹配）
    port 9200
    suppress_type_name true     # ES 8.x 必须开启，禁用已废弃的 _type 字段
    logstash_format true        # 按天创建索引：k8s-YYYY.MM.DD
    logstash_prefix k8s         # 索引前缀：k8s-*
    request_timeout 30s
    <buffer>
      @type file
      path /var/log/fluentd-buffers/kubernetes.system.buffer
      flush_mode interval
      retry_type exponential_backoff   # 指数退避重试，避免 ES 压力时雪崩
      flush_thread_count 2             # 2 个线程并发刷写，提升吞吐
      flush_interval 5s                # 每 5 秒批量刷一次
      retry_forever                    # 永不放弃重试（保证不丢日志）
      retry_max_interval 30            # 最大重试间隔 30 秒
      chunk_limit_size 2M              # 单个 chunk 最大 2MB
      queue_limit_length 8             # 最多 8 个 chunk 排队
      overflow_action block            # 队列满时阻塞（防止内存溢出，适合日志不可丢场景）
    </buffer>
  </match>
</label>
```

### @host — 宿主机/Systemd 日志

```xml
<label @host>
  <match **>
    @id elasticsearch-host
    @type elasticsearch
    @log_level info
    include_tag_key true
    host elasticsearch
    port 9200
    suppress_type_name true
    logstash_format true
    logstash_prefix host        # 索引前缀：host-*，与容器日志隔离
    request_timeout 30s
    <buffer>
      flush_interval 5
      chunk_limit_size 2m
      queued_chunks_limit_size 32
      retry_forever true
    </buffer>
  </match>
</label>
```

> **双前缀设计优势**：
> - `k8s-*` 索引：业务容器日志，研发/SRE 日常检索
> - `host-*` 索引：宿主机内核/安全/系统日志，运维安全审计专用
> - 两类日志可配置不同的 ILM 保留策略（业务日志 30 天，安全日志 90 天）

---

## 8. 生产优化建议

| 问题 | 当前配置 | 优化建议 |
|------|----------|----------|
| buffer 根路径用 /tmp | `root_dir /tmp/fluentd-buffers/` | 改为 PVC 路径，防止节点重启后 buffer 丢失 |
| kubelet pos 文件无持久化 | pos_file 在 /var/log | 确保 /var/log 被 hostPath 挂载至 Pod |
| @host buffer 配置简陋 | 仅 4 个参数 | 参考 @k8s buffer 补全 retry_type / flush_thread_count 等 |
| ES host 写死 hostname | `host elasticsearch` | 建议改为 FQDN `elasticsearch.logging.svc.cluster.local` 避免 DNS 歧义 |

---

## 9. 部署文件位置
 
详见：[10-Kubernetes生产级EFK企业级架构、高可用集群部署与底层原理深度实战指南.md](../10-Kubernetes生产级EFK(Elasticsearch+Fluentd+Fluentbit+Kibana)企业级架构、高可用集群部署与底层原理深度实战指南.md)

> 注：上述 ConfigMap 内容与部署文件中的配置存在差异，以本文档记录的生产实际配置为准。建议将 ConfigMap 同步更新至部署文件中。

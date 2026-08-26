# Fluent Bit 3.x 轻量边缘采集器指南

> Fluent Bit 是 CNCF 标准轻量日志采集器，内存占用约 30MB，适合作为 K8S DaemonSet 边缘采集。

---

## 1. 核心架构

```
[/var/log/containers/*.log]
        │ INPUT: tail（监听容器日志文件）
        ▼
[FILTER: kubernetes]  ← 自动追加 Pod/Namespace 元数据
        ▼
[OUTPUT: es]  → Elasticsearch.logging.svc:9200
```

---

## 2. 关键配置说明

### INPUT - tail
```ini
[INPUT]
    Name              tail
    Tag               kube.*
    Path              /var/log/containers/*.log
    Parser            cri           # CRI 格式解析（containerd/CRI-O）
    DB                /var/log/flb_kube.db   # 断点续传位置记录
    Mem_Buf_Limit     15MB
    Skip_Long_Lines   On
    Refresh_Interval  10
```

### FILTER - kubernetes 元数据注入
```ini
[FILTER]
    Name                kubernetes
    Match               kube.*
    Kube_URL            https://kubernetes.default.svc:443
    Merge_Log           On      # 将 log 字段中的 JSON 自动展开
    Keep_Log            Off     # 展开后删除原始 log 字段
    K8S-Logging.Parser  On
    K8S-Logging.Exclude On
```

### OUTPUT - Elasticsearch 8.x 兼容
```ini
[OUTPUT]
    Name               es
    Match              *
    Host               elasticsearch.logging.svc
    Port               9200
    Logstash_Format    On
    Logstash_Prefix    k8s-log
    Suppress_Type_Name On   # ES 8.x 必须开启，否则报 _type 错误
    Retry_Limit        5
    Buffer_Size        5MB
```

---

## 3. 资源配置建议（K8S DaemonSet）

```yaml
resources:
  limits:
    memory: 120Mi
    cpu: 200m
  requests:
    memory: 30Mi
    cpu: 20m
```

---

## 4. 重要特性

| 特性 | 说明 |
|------|------|
| 断点续传 | `DB` 参数记录文件读取位置，Pod 重启不丢日志 |
| 背压控制 | `Mem_Buf_Limit` 防止内存爆涨 |
| 容忍所有污点 | `tolerations: - operator: Exists` 确保在 Master 节点也能采集 |
| CRI 解析 | 内置 Parser 兼容 containerd 日志格式 |

---

## 5. 部署文件位置
见 `./05-Install/kubenetes/efk/fluent-bit-daemonset.yaml`

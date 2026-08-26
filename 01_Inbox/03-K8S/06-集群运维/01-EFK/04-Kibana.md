# Kibana 8.18 部署、ILM 生命周期与生产实战指南

---

## 1. 部署 SOP

### (1) 执行部署顺序
```bash
# 基础命名空间与 RBAC
kubectl apply -f 01-namespace-rbac.yaml

# ES 无头服务与 3 节点 StatefulSet
kubectl apply -f 02-elasticsearch-svc.yaml
kubectl apply -f elasticsearch-statefulset.yaml
kubectl wait --for=condition=ready pod -l app=elasticsearch -n logging --timeout=180s

# 若启用 X-Pack Security，重置 kibana_system 密码
kubectl exec -it -n logging es-cluster-0 -c elasticsearch -- bin/elasticsearch-reset-password -u kibana_system -i
kubectl apply -f kibana-secret.yaml

# 采集端（二选一）
kubectl apply -f fluent-bit-daemonset.yaml
# kubectl apply -f fluentd-pipeline.yaml

# 可视化控制台
kubectl apply -f kibana.yaml
```

### (2) 验证状态
```bash
kubectl get pods -n logging -o wide
kubectl port-forward -n logging es-cluster-0 9200:9200 &
curl -s http://localhost:9200/_cat/nodes?v
curl -s http://localhost:9200/_cat/health?v
```

---

## 2. ILM 日志生命周期管理

```
┌──────────────────┐  7天/50GB   ┌──────────────────┐  30天  ┌──────────────┐
│  Hot（热）阶段   │ ──────────► │  Warm（温）阶段  │ ─────► │ Delete（删） │
│  活跃写入 SSD    │  Rollover   │  只读 / 段合并   │ 到期   │  物理删除    │
└──────────────────┘             └──────────────────┘         └──────────────┘
```

### 一键配置（Kibana Dev Tools）
```json
PUT _ilm/policy/k8s_logs_30d_policy
{
  "policy": {
    "phases": {
      "hot": {
        "actions": {
          "rollover": { "max_primary_shard_size": "50gb", "max_age": "7d" }
        }
      },
      "warm": {
        "min_age": "7d",
        "actions": {
          "forcemerge": { "max_num_segments": 1 },
          "shrink": { "number_of_shards": 1 }
        }
      },
      "delete": {
        "min_age": "30d",
        "actions": { "delete": {} }
      }
    }
  }
}

PUT _index_template/k8s_logs_ilm_template
{
  "index_patterns": ["k8s-log-*", "k8s-fluentd-*"],
  "template": {
    "settings": {
      "number_of_shards": 3,
      "number_of_replicas": 1,
      "index.lifecycle.name": "k8s_logs_30d_policy",
      "index.lifecycle.rollover_alias": "k8s-log"
    }
  }
}
```

---

## 3. ES|QL 生产实战查询

```sql
-- 最近 1 小时各命名空间错误日志 Top 5
FROM k8s-log-*
| WHERE @timestamp > NOW() - 1 HOUR AND log.level == "ERROR"
| STATS err_cnt = COUNT() BY kubernetes.namespace_name, kubernetes.pod_name
| SORT err_cnt DESC
| LIMIT 5

-- 统计 Java NullPointerException 的 Pod 分布
FROM k8s-log-*
| WHERE log LIKE "*NullPointerException*"
| STATS oom_cnt = COUNT() BY kubernetes.pod_name
| SORT oom_cnt DESC
```

---

## 4. 生产避坑指南

### 坑 1：采集器 `_type` 导致 ES 8.x 报错
- **现象**：`Action/metadata line contains an unknown parameter [_type]`
- **解决**：Fluent Bit 设 `Suppress_Type_Name On`；Fluentd 设 `suppress_type_name true`

### 坑 2：集群状态 Yellow/Red，分片未分配
```bash
curl -s "http://localhost:9200/_cat/shards?v&h=index,shard,prirep,state,unassigned.reason" | grep UNASSIGNED
curl -s -X POST "http://localhost:9200/_cluster/allocation/explain?pretty"
```
- 磁盘超 85% 水位 → 扩容 PVC 或 ILM 归档
- 副本数超节点数 → 修改 `number_of_replicas: 1`

### 坑 3：离线环境 GeoIP 超时
- **解决**：ES 环境变量添加 `ingest.geoip.downloader.enabled: "false"`

### 坑 4：Kibana 启动报 `Kibana server is not ready yet`
```bash
# 重置 kibana_system 密码
kubectl exec -it -n logging es-cluster-0 -c elasticsearch -- bin/elasticsearch-reset-password -u kibana_system -i
# 更新 Secret
kubectl create secret generic kibana-secret -n logging \
  --from-literal=ELASTICSEARCH_PASSWORD="新密码" \
  --from-literal=ENCRYPTION_KEY="32位随机字符串" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl rollout restart deployment/kibana -n logging
```

### 坑 5：Kibana 告警/报表插件失效，Session 重启失效
- **原因**：未配置持久化加密 Key
- **解决**：确保 `XPACK_SECURITY_ENCRYPTIONKEY` / `XPACK_ENCRYPTEDSAVEDOBJECTS_ENCRYPTIONKEY` / `XPACK_REPORTING_ENCRYPTIONKEY` 均已设置为 ≥32 字符固定 Key

### 坑 6：ES 开启 HTTPS 后 Kibana 自签证书校验失败
- **测试环境**：`ELASTICSEARCH_SSL_VERIFICATIONMODE: "none"`
- **生产环境**：挂载 `http_ca.crt` 并配置 `ELASTICSEARCH_SSL_CERTIFICATEAUTHORITIES`

---

## 5. 宿主机防爆盘配置

### Containerd 限制单行日志大小
```toml
# /etc/containerd/config.toml
[plugins."io.containerd.grpc.v1.cri"]
  max_container_log_line_size = 16384
```

### Kubelet 日志切分
```yaml
# /var/lib/kubelet/config.yaml
containerLogMaxSize: "50Mi"
containerLogMaxFiles: 3
```

### 内核参数调优
```bash
sysctl -w vm.max_map_count=262144    # ES 必须，否则启动崩溃
sysctl -w vm.swappiness=1
sysctl -w fs.file-max=2097152
echo "vm.max_map_count=262144" >> /etc/sysctl.conf
```

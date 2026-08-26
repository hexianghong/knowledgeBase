# etcd 备份与恢复实战指南

## 1. 概述

etcd 是 Kubernetes 集群的核心数据存储，保存了集群所有的配置、状态数据（Pod、Service、ConfigMap、Secrets 等）。定期备份 etcd 是生产环境的重要运维工作。

---

## 2. 备份前准备

### 确认 etcd 连接信息

```bash
# 查看 etcd 静态 Pod 配置
cat /etc/kubernetes/manifests/etcd.yaml

# 通常需要以下参数
# ETCD_ENDPOINTS="https://127.0.0.1:2379"
# ETCD_CACERT="/etc/kubernetes/pki/etcd/ca.crt"
# ETCD_CERT="/etc/kubernetes/pki/etcd/server.crt"
# ETCD_KEY="/etc/kubernetes/pki/etcd/server.key"
```

### 创建备份目录

```bash
mkdir -p /backup/etcd/$(date +%Y%m%d)
```

---

## 3. 执行备份

### 使用 etcdctl 创建快照

```bash
# 方法一：直接执行（需提前安装 etcdctl）
ETCDCTL_API=3 etcdctl snapshot save /backup/etcd/$(date +%Y%m%d)/etcd-snapshot.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# 方法二：通过 etcd Pod 容器执行（kubeadm 部署集群常用）
kubectl exec -n kube-system etcd-master01 -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /var/lib/etcd/etcd-snapshot.db
```

### 验证备份状态

```bash
ETCDCTL_API=3 etcdctl snapshot status /backup/etcd/$(date +%Y%m%d)/etcd-snapshot.db \
  --write-out=table
# 输出示例：
# +----------+----------+------------+------------+
# |   HASH   | REVISION | TOTAL KEYS | TOTAL SIZE |
# +----------+----------+------------+------------+
# | fe01cf57 |       10 |          7 |      2.1MB |
# +----------+----------+------------+------------+
```

---

## 4. 自动化备份脚本

```bash
#!/bin/bash
# etcd-backup.sh
BACKUP_DIR="/backup/etcd"
RETENTION_DAYS=7
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/${DATE}/etcd-snapshot.db"

mkdir -p "${BACKUP_DIR}/${DATE}"

ETCDCTL_API=3 etcdctl snapshot save "${BACKUP_FILE}" \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

if ETCDCTL_API=3 etcdctl snapshot status "${BACKUP_FILE}" > /dev/null 2>&1; then
    echo "[SUCCESS] Backup created: ${BACKUP_FILE}"
else
    echo "[ERROR] Backup failed!"; exit 1
fi

# 清理旧备份（保留 7 天）
find "${BACKUP_DIR}" -maxdepth 1 -type d -mtime +${RETENTION_DAYS} -exec rm -rf {} \;
```

配置定时任务：
```bash
# 每天凌晨 2 点执行备份
0 2 * * * /opt/scripts/etcd-backup.sh >> /var/log/etcd-backup.log 2>&1
```

---

## 5. etcd 数据恢复

> **警告：** 恢复操作会覆盖现有数据，请在测试环境验证后再在生产环境操作。

### 恢复流程

**步骤 1：停止所有控制平面组件**

```bash
# kubeadm 部署方式：移除静态 Pod 配置文件
mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/
mv /etc/kubernetes/manifests/kube-controller-manager.yaml /tmp/
mv /etc/kubernetes/manifests/kube-scheduler.yaml /tmp/
mv /etc/kubernetes/manifests/etcd.yaml /tmp/
sleep 10
```

**步骤 2：备份现有 etcd 数据目录**

```bash
mv /var/lib/etcd /var/lib/etcd-bak-$(date +%Y%m%d)
```

**步骤 3：从快照恢复**

```bash
ETCDCTL_API=3 etcdctl snapshot restore /backup/etcd/20241201/etcd-snapshot.db \
  --name=master01 \
  --initial-cluster="master01=https://192.168.1.10:2380" \
  --initial-advertise-peer-urls="https://192.168.1.10:2380" \
  --data-dir=/var/lib/etcd
```

**步骤 4：恢复控制平面组件**

```bash
mv /tmp/etcd.yaml /etc/kubernetes/manifests/
mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/
mv /tmp/kube-controller-manager.yaml /etc/kubernetes/manifests/
mv /tmp/kube-scheduler.yaml /etc/kubernetes/manifests/
kubectl get pods -n kube-system
```

**步骤 5：验证恢复结果**

```bash
ETCDCTL_API=3 etcdctl endpoint status \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  --write-out=table
kubectl get nodes
```

---

## 6. etcd 高可用与 Raft 协议

### 为什么节点数必须是奇数

| 节点数 | 可容忍故障 | 最小存活 | 说明 |
|--------|-----------|---------|------|
| 1 | 0 | 1 | 无高可用 |
| 3 | 1 | 2 | 推荐最小高可用 |
| 5 | 2 | 3 | 生产推荐 |

**奇数原因：** Raft 算法要求 `(N/2)+1` 个节点存活才能选出 Leader（多数派原则）。偶数节点在网络分区时容易出现**脑裂**，两个分区各占一半节点，无法形成多数派。

### etcd 集群健康检查

```bash
# 查看集群成员
ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# 查看端点健康状态
ETCDCTL_API=3 etcdctl endpoint health \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

---

## 7. 相关参考

- [etcd 底层架构 MVCC 与高可用运维](../01-组件原理/08-etcd底层架构MVCC与高可用运维.md)
- [K8S 集群部署安装指南](./01-K8S集群部署安装指南.md)
- [生产级高难故障排查与实战方案](./06-生产级高难故障排查与实战方案.md)

---

> [!TIP] 💡 关联技术与延伸阅读
>
> * [etcd 底层架构与 MVCC 机制](../01-组件原理/08-etcd底层架构MVCC与高可用运维.md)
> * [生产级集群故障快速排障](./06-生产级高难故障排查与实战方案.md)

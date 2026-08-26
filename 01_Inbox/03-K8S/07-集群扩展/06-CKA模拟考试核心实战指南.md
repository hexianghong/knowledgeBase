# 🎓 CKA 模拟考试核心实战指南

在 CKA (Certified Kubernetes Administrator) 考试中，所有题目都是在真实的 K8S 集群环境中操作。本文将 CKA 考试大纲涉及的核心考点（集群搭建、安全性、网络、存储、排障）整理为高频模拟真题与标准 YAML/命令行解答，供备考和日常运维提效使用。

---

## 💡 CKA 效率提效：终端环境变量配置
在进入考试环境后，首先执行以下设置以缩短敲击命令的时间，并防止手动编写 YAML 格式对齐失败：
```bash
# 1. 设置 kubectl 简写别名 k
alias k=kubectl

# 2. 启用 shell 自动补全
source <(kubectl completion bash)
complete -o default -F __start_kubectl k

# 3. 设置极速删除 Pod 命令变量
export now="--force --grace-period 0"

# 4. 设置 YAML 格式化试运行变量 (生成 YAML 不提交到 API)
export do="--dry-run=client -o yaml"

# 5. 配置 vim 使缩进对齐为两个空格
cat << EOF >> ~/.vimrc
set tabstop=2
set shiftwidth=2
set expandtab
set paste
EOF
```

---

## 🎯 核心场景实战演练

### 1. 安全性：基于角色访问控制 (RBAC) 精细授权
**题目要求**：创建一个 ClusterRole 命名为 `deployment-clusterrole`，仅允许对 `deployments`, `statefulsets`, `daemonsets` 资源执行 `create` 操作。并在命名空间 `app-team1` 中创建一个 ServiceAccount 命名为 `cicd-token`，最后创建 RoleBinding 将二者关联绑定。

#### 🛠️ 实战解答：
```bash
# 1. 命令行直接创建具有特定权限的 ClusterRole
k create clusterrole deployment-clusterrole \
  --verb=create \
  --resource=deployments,statefulsets,daemonsets

# 2. 在指定命名空间中创建 ServiceAccount
k create serviceaccount cicd-token -n app-team1

# 3. 创建 RoleBinding (将 ClusterRole 在单个命名空间内授权给该 ServiceAccount)
k create rolebinding deployment-rolebinding \
  --clusterrole=deployment-clusterrole \
  --serviceaccount=app-team1:cicd-token \
  -n app-team1

# 4. 校验绑定状况
k describe rolebinding deployment-rolebinding -n app-team1
```

---

### 2. 运维：Node 维护（Cordon / Drain 驱逐）
**题目要求**：对节点 `node02` 执行维护操作，将其标记为不可调度（Cordon），并安全驱逐（Drain）其上运行的所有 Pod 副本（排除守护进程，并强制驱逐 local 卷等）。

#### 🛠️ 实战解答：
```bash
# 1. 标记节点为不可调度状态
k cordon node02

# 2. 执行驱逐操作 (忽略 DaemonSet，强行清理 emptyDir 卷数据，强制删除)
k drain node02 --ignore-daemonsets --delete-emptydir-data --force

# 3. 维护完成后，恢复节点可调度状态
k uncordon node02
```

---

### 3. 集群升级：使用 Kubeadm 对 Master 主机升级
**题目要求**：将控制面节点 `master01` 的 Kubernetes 系统组件版本从 `v1.24.x` 升级到指定版本 `v1.24.3`。

#### 🛠️ 实战解答：
```bash
# 1. 驱逐当前 Master 节点上的应用
k drain master01 --ignore-daemonsets --force

# 2. 更新系统包源并升级 Kubeadm 工具版本
apt-get update
apt-get install -y --allow-change-held-packages kubeadm=1.24.3-00

# 3. 校验升级方案并执行应用升级
kubeadm upgrade plan
sudo kubeadm upgrade apply v1.24.3 --yes

# 4. 解锁并升级宿主机上的 Kubelet 和 Kubectl
apt-mark unhold kubelet kubectl
apt-get install -y --allow-change-held-packages kubelet=1.24.3-00 kubectl=1.24.3-00
apt-mark hold kubelet kubectl

# 5. 重新加载系统守护进程，重启 Kubelet
systemctl daemon-reload
systemctl restart kubelet

# 6. 恢复 Master 节点调度
k uncordon master01
```

---

### 4. 数据高可用：ETCD 备份与还原 (最核心考点)
**题目要求**：对集群中的 etcd 数据库进行备份，备份路径保存为 `/var/lib/backup/etcd-snapshot.db`。然后使用历史备份文件 `/data/backup/etcd-snapshot-previous.db` 恢复数据库。

#### 🛠️ 实战解答：
```bash
# 1. 执行 etcd 备份快照 (需要指定 API v3 版本，并传入集群证书进行双向 TLS 校验)
ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  snapshot save /var/lib/backup/etcd-snapshot.db

# 2. 执行恢复操作 (指定恢复的临时数据目录)
sudo ETCDCTL_API=3 etcdctl \
  --data-dir=/var/lib/etcd-from-backup \
  snapshot restore /data/backup/etcd-snapshot-previous.db

# 3. 恢复后的配置变更说明：
# 恢复完成后，必须编辑主机的静态 Pod 清单 /etc/kubernetes/manifests/etcd.yaml，
# 将挂载的 hostPath.path 数据目录修改为刚才指定的 /var/lib/etcd-from-backup。
# Kubelet 监听到配置变化后，会自动重新拉起 etcd 容器生效。
```

---

### 5. 调度：为 Pod 指定 NodeSelector (节点亲和)
**题目要求**：将标签为 `disk=ssd` 的节点配置调度优先级，并创建一个 Pod 命名为 `nginx-kusc00401`，强制要求该 Pod 只能被运行在有 SSD 磁盘的节点上。

#### 🛠️ 实战解答：
```bash
# 1. 查找并为特定 node 打上标签
k label nodes node01 disk=ssd

# 2. 声明 Pod 配置清单 (使用 nodeSelector)
```
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-kusc00401
spec:
  containers:
  - name: nginx
    image: nginx
    imagePullPolicy: IfNotPresent
  nodeSelector:
    disk: ssd                            # 精确过滤匹配标签
```

---

### 6. 网络：配置 Ingress 服务路由与重写 (Rewrite)
**题目要求**：在命名空间 `ing-internal` 中创建一个 Ingress 路由资源，将访问路径 `/hello` 转发到后端的 `hello:5678` 服务，并实现 URL 根目录重写。

#### 🛠️ 实战解答：
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ping
  namespace: ing-internal
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: / # 重写规则：将子路径重写为 /
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /hello
        pathType: Prefix
        backend:
          service:
            name: hello
            port:
              number: 5678
```

---

### 7. 设计模式：多容器 Pod (Multi-Container)
**题目要求**：在一个 Pod 中启动两个容器，主容器运行 `nginx` 镜像，辅助容器运行 `consul` 镜像，实现本地协同。

#### 🛠️ 实战解答：
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: kucc8
spec:
  containers:
  - name: nginx-web
    image: nginx:1.14.2
  - name: consul-helper
    image: consul
```

---

### 8. 存储：持久化卷 (PV/PVC) 绑定与自动扩容
**题目要求**：创建一个 PersistentVolumeClaim 命名为 `pv-volume`，申请 `10Mi` 空间，指定 StorageClass 为 `csi-hostpath-sc`。同时启动一个 Pod 命名为 `web-server` 将此卷挂载到容器内的 `/usr/share/nginx/html` 目录。

#### 🛠️ 实战解答：
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pv-volume
spec:
  storageClassName: csi-hostpath-sc
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: web-server
spec:
  volumes:
    - name: pv-volume-storage
      persistentVolumeClaim:
        claimName: pv-volume
  containers:
    - name: nginx-web
      image: nginx:1.16
      volumeMounts:
        - mountPath: "/usr/share/nginx/html"
          name: pv-volume-storage
```

---

### 9. 故障排查：Sidecar 容器日志抓取运维
**题目要求**：在 Pod `11-factor-app` 中，主应用容器 `nginx-container` 会将日志写入到本地共享卷的 `/var/log/11-factor-app.log` 中。部署一个 Sidecar 容器读取该日志并输出到标准输出中。

#### 🛠️ 实战解答：
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: 11-factor-app
spec:
  volumes:
  - name: shared-data
    emptyDir: {}                      # 声明共享的临时存储卷
  containers:
  - name: nginx-container
    image: nginx
    volumeMounts:
    - name: shared-data
      mountPath: /var/log
  - name: sidecar-logger
    image: busybox
    volumeMounts:
    - name: shared-data
      mountPath: /var/log
    # 在后台持续读取并输出日志文件内容
    args: ["/bin/sh", "-c", "tail -n+1 -f /var/log/11-factor-app.log"]
```
```bash
# 查询日志输出验证 Sidecar 正常运行
k logs 11-factor-app -c sidecar-logger
```

# Round 6: Linux 内核参数调优与 sysctl 实战指南

Linux 内核默认配置主要针对通用桌面或小型服务器场景设计。当服务器部署到高并发 Web 网关、海量连接数据节点或 Kubernetes 集群生产环境中时，默认的内核参数极易成为瓶颈，引发“Connection Reset by Peer”、“Too many open files”或 TCP 连接积压。

本指南深入拆解 `/proc/sys` 映射机制、TCP 拥塞窗口 `cwnd` 数学转换、全/半连接队列内核溢出计数器诊断、文件句柄限制，并提供三大经典生产场景调优模板。

---

## 一、 `/proc/sys` 内核映射与 `sysctl` 配置持久化

### 1. 内核参数与文件路径映射关系

* **文件路径**：`/proc/sys/net/ipv4/tcp_tw_reuse`
* **`sysctl` 参数名**：`net.ipv4.tcp_tw_reuse`

---

### 2. 参数持久化加载优先级

`/etc/sysctl.d/*.conf` > `/run/sysctl.d/*.conf` > `/usr/lib/sysctl.d/*.conf` > `/etc/sysctl.conf`

```bash
sysctl -p /etc/sysctl.d/99-sysctl-custom.conf
```

---

## 二、 核心网络栈内核参数调优与溢出计数诊断

### 1. 消除 TCP 握手与连接积压瓶颈

```mermaid
graph LR
    A["客户端发起 SYN"] --> B["半连接队列 (SYN Queue)"]
    B -->|内核收到 ACK 完成三次握手| C["全连接队列 (Accept Queue)"]
    C -->|应用程序调用 accept()| D["建立完成的 Socket (ESTABLISHED)"]
```

#### 全连接/半连接队列溢出内核诊断 (netstat -s)：
```bash
# 查看全连接队列溢出被丢弃的累计次数 (times the listen queue overflowed)
netstat -s | grep -i "listen queue"

# 查看半连接队列 SYNs 被丢弃的累计次数 (SYNs to LISTEN sockets dropped)
netstat -s | grep -i "SYNs to LISTEN"
```
*排查：若上述计数器持续增长，说明 `net.core.somaxconn` 或 `net.ipv4.tcp_max_syn_backlog` 严重偏小，或者应用 `accept()` 处理过慢！*

```ini
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
```

---

### 2. TCP 拥塞窗口 `cwnd` 慢启动数学模型

TCP 在建连初期使用 **慢启动 (Slow Start)** 算法：
$$\text{cwnd}_{k+1} = \text{cwnd}_k + 1 \quad (\text{每收到一个 ACK，窗口加 1，呈指数级爆发式增长})$$

直到达到慢启动阈值 `ssthresh` 后，切换为 **拥塞避免 (Congestion Avoidance)**：
$$\text{cwnd}_{k+1} = \text{cwnd}_k + \frac{1}{\text{cwnd}_k} \quad (\text{每个 RTT 仅增加 1 个 MSS})$$

---

### 3. Socket 资源与端口回收

```ini
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_max_orphans = 262144
net.ipv4.tcp_syncookies = 1
```

---

## 三、 文件描述符 (File Descriptors) 与系统 Limits 调优

```
全局 Kernel 限制 (fs.file-max)
      │
      ▼
用户/会话限制 (/etc/security/limits.conf nofile)
      │
      ▼
服务进程限制 (Systemd Service DefaultLimitNOFILE)
```

```ini
# /etc/security/limits.conf
*               soft    nofile         1048576
*               hard    nofile         1048576

# Systemd 全局服务限制 /etc/systemd/system.conf
[Manager]
DefaultLimitNOFILE=1048576
```

---

## 四、 生产三大场景完整 sysctl 调优模板

### 模板 1：高并发 Web / API 网关服务器 (`/etc/sysctl.d/99-web-gateway.conf`)

```ini
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.netdev_max_backlog = 65535
net.ipv4.tcp_syncookies = 1
fs.file-max = 2097152
```

---

### 模板 2：高性能数据库节点 (`/etc/sysctl.d/99-database.conf`)

```ini
vm.swappiness = 10
vm.zone_reclaim_mode = 0
vm.dirty_background_ratio = 5
vm.dirty_ratio = 15
vm.max_map_count = 262144
vm.overcommit_memory = 1
kernel.pid_max = 4194304
```

---

### 模板 3：Kubernetes Worker 容器节点 (`/etc/sysctl.d/99-k8s-node.conf`)

```ini
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
net.netfilter.nf_conntrack_max = 1048576
net.netfilter.nf_conntrack_tcp_timeout_established = 86400
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 8192
```

---

# Round 20: 高级 Linux 运维生产复杂故障深度案例集 (Post-Mortem Case Study)

本指南汇集了企业级生产环境中涉及 **Linux 内核、硬件控制器、网络协议栈、JVM 虚拟机、Cgroups v2 PSI 以及云原生设施交织引发的 8 大顶级复杂灾难案例**。每个案例均包含“现象识别 $\rightarrow$ 复杂链路诊断过程 $\rightarrow$ 根因分析 $\rightarrow$ 架构级修复与预防方案”复盘。

---

## 案例一：静默数据腐烂 (Bit Rot) 与 HBA 卡 Drop 静默丢块

### 1. 现象与诊断
* 某分布式对象存储集群中，部分图片文件在毫无报错的情况下损坏或内容变乱。
* 物理磁盘 SMART 监控指标全绿，文件系统未抛出任何读写 I/O 错误。
* 使用 `blktrace` 发现写请求在提交给阵列卡固件后，阵列卡由于内部 Queue 溢出，**静默丢弃了写指令，却给内核返回了 SUCCESS 成功响应！**

### 2. 彻底解决方案
* **急救**：强制刷入厂商修正版 HBA 固件。
* **架构改造**：底层引入 **ZFS / Btrfs** 具有 **Data Checksum (数据块 CRC32/SHA256 校验和)** 的文件系统。在每次读取数据时强行校验 Checksum，发现不匹配自动利用 Mirror 进行静默自愈（Self-healing）。

---

## 案例二：多核 NUMA 场景下 Kernel Soft Lockup 与 Spinlock 死锁

```bash
# 查看 /proc/buddyinfo 内存碎片
cat /proc/buddyinfo
```
* **彻底解决方案**：
  ```ini
  vm.percpu_pagelist_high_fraction = 1000
  vm.zone_reclaim_mode = 0
  ```

---

## 案例三：高并发 Web 网关 Epoll 惊群效应 (Thundering Herd) 与 CPU 陡增

在 Nginx 配置中开启 **`SO_REUSEPORT`** 选项：
```nginx
server {
    listen 80 reuseport;
    server_name api.company.com;
}
```

---

## 案例四：宿主机 Conntrack 溢出引发云虚拟机随机断连

```bash
sysctl -w net.netfilter.nf_conntrack_max=2097152
sysctl -w net.netfilter.nf_conntrack_tcp_timeout_established=3600
```

---

## 案例五：JVM GC Pause 与 Linux 内核内存内存碎片重组 (Compaction) 叠加死锁

彻底禁用透明巨页 THP：
```bash
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
```

---

## 案例六：跨数据中心 TCP BBR 算法与 Cubic 拥塞控制算法冲突

在跨国/跨 DC 长链路上开启 Google BBR 拥塞控制算法：
```bash
sysctl -w net.core.default_qdisc=fq
sysctl -w net.ipv4.tcp_congestion_control=bbr
```

---

## 案例七：Cgroups v2 内存压力基线预警：使用 PSI (Pressure Stall Information) 定位微抖动

### 1. 现象与警报
* 容器内存使用率达到 85%，尚未触发 OOM Killer，但微服务 API 响应 P99 延迟频繁无规律打出 2 秒尖峰。传统的 `free` 或 `top` 完全看不到任何异常。

### 2. 深入诊断过程
读取 Linux 内核 4.20+ 引入的 **PSI (Pressure Stall Information)** 接口：

```bash
# 查看容器或宿主机的内存压力指标
cat /proc/pressure/memory
```
*输出：*
```
some avg10=12.50 avg60=5.20 avg300=1.10 total=4582100
full avg10=8.30  avg60=2.10 avg300=0.40 total=1250100
```

### 3. 根因 (Root Cause)
* **`some`**：代表至少有一个 task 因为等待内存分配而被阻塞挂起的时间占比 (12.5% 的时间在等待内存)。
* **`full`**：代表所有 task 均因为等待内存分配而彻底卡死的死锁时间占比 (8.3%)。
* **判定**：系统频繁触发了后台 Page Cache 回收与 Direct Reclaim，导致线程在 `alloc_pages` 时发生微观抖动。

### 4. 彻底解决方案
基于 PSI 建立 Prometheus 弹性伸缩告警（当 `some avg10 > 10` 时自动扩容 Pod），并在 Cgroups v2 中为 Pod 配置 `memory.low` 保护水线。

---

## 案例八：多 DC 时钟漂移引发 Kubernetes etcd Raft 共识集群瘫痪

### 1. 现象与诊断
* 跨 DC 部署的 5 节点 Kubernetes etcd 集群突然频繁选举失败（Leader Election），`kubectl` 报 `etcdserver: leader changed` 或 `context deadline exceeded`。
* 观察集群网络延迟，Ping 延迟仅为 2ms，网络完全正常。

### 2. 根因 (Root Cause)
* etcd 基于 **Raft 共识算法**，其 Leader 节点需要定期向 Follower 发送 Heartbeat 通告。
* 节点间的 Chrony NTP 配置错误，DC-A 与 DC-B 之间产生了 **350 毫秒的时间漂移 (Clock Skew)**。
* 当判断 Lease 超时时间为 500ms 时，350ms 的时钟差导致 Follower 误判 Leader 已经死亡，从而触发频繁的无效重新选举（Re-election），致使集群不可用！

### 3. 彻底解决方案
1. 全面部署 Chrony 并开启硬件/网络 PTP 或强行 `makestep 1.0 3`。
2. 将 etcd 的 `heartbeat-interval` 调整为 250ms，`election-timeout` 调整为 1250ms，留足宽限窗口。

---

# NodeExporter 宿主机全方位监控与核心指标基线实战

## 一、 核心定位与技术架构

**node_exporter** 是 Prometheus 官方提供的硬件与 Linux 内核指标采集器，采用只读方式探测 Linux 宿主机物理状态。在 Kubernetes 集群中，node_exporter 通常以 **DaemonSet** 的形式运行在每个节点上，负责兜底操作系统层面的资源与健康状态。

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        Kubernetes Worker 宿主机                         │
│                                                                        │
│   ┌───────────────────────────┐        ┌───────────────────────────┐   │
│   │   /proc 文件系统 (内核状态) │        │   /sys 文件系统 (硬件总线) │   │
│   │   - /proc/stat (CPU)      │        │   - /sys/block (块设备IO) │   │
│   │   - /proc/meminfo (内存)  │        │   - /sys/class/net (网卡) │   │
│   │   - /proc/diskstats (磁盘)│        │                           │   │
│   └─────────────┬─────────────┘        └─────────────┬─────────────┘   │
│                 │                                    │                 │
│                 │      只读挂载 (Read-Only Mount)     │                 │
│                 ▼                                    ▼                 │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │        node-exporter Pod (hostNetwork: true, hostPID: true)    │   │
│   │                                                                │   │
│   │  启动参数映射:                                                 │   │
│   │  --path.procfs=/host/proc                                      │   │
│   │  --path.sysfs=/host/sys                                        │   │
│   │  --path.rootfs=/host/root                                      │   │
│   │                                                                │   │
│   │  暴露 HTTP 端点: http://<NodeIP>:9100/metrics                  │   │
│   └────────────────────────────────┬───────────────────────────────┘   │
└────────────────────────────────────┼───────────────────────────────────┘
                                     │ Prometheus 周期拉取 (Scrape)
                                     ▼
```

---

## 二、 生产级采集器过滤策略（防止时序爆炸与 CPU 飙高）

默认状态下，node_exporter 会抓取宿主机上的所有挂载点与网络设备。在 Kubernetes 节点上，容器引擎（Docker / containerd）以及 CNI 网络插件会动态生成数以百计的 `overlayfs` 挂载点与 `veth*` / `cali*` 虚拟网卡。若不加约束，**单个节点的时序数量可激增 10 倍以上**，导致 Prometheus 内存急剧膨胀甚至 OOM。

### 1. 生产标准启动参数矩阵

```bash
/bin/node_exporter \
  --path.procfs=/host/proc \
  --path.sysfs=/host/sys \
  --path.rootfs=/host/root \
  # 1. 禁用无用或可能引发 D 状态等待的硬件探针
  --no-collector.wifi \
  --no-collector.hwmon \
  # 2. 严格过滤容器虚拟挂载点 (仅保留物理盘与宿主机关键挂载点)
  --collector.filesystem.ignored-mount-points="^/(dev|proc|sys|var/lib/docker/.+|var/lib/containerd/.+|var/lib/kubelet/.+)($|/)" \
  # 3. 过滤只读与虚拟文件系统类型
  --collector.filesystem.ignored-fs-types="^(autofs|binfmt_misc|bpf|cgroup2?|configfs|debugfs|devpts|devtmpfs|fusectl|hugetlbfs|iso9660|mqueue|nsfs|overlay|proc|procfs|pstore|rpc_pipefs|securityfs|selinuxfs|squashfs|sysfs|tracefs)$" \
  # 4. 过滤 CNI 容器临时网卡，仅保留物理网卡与管理网卡
  --collector.netdev.device-exclude="^(veth.*|cali.*|flannel.*|cni.*|tunl.*|docker.*|br-.*)$" \
  # 5. 启用 Textfile 自定义采集目录
  --collector.textfile.directory=/var/lib/node_exporter/textfile_collector
```

---

## 三、 SRE 黄金指标与核心 PromQL 计算基线

### 1. CPU 使用率（多维度拆解）

在生产故障排查中，切忌只看整体 CPU 使用率，必须结合 `iowait`（磁盘 IO 瓶颈）与 `steal`（云厂商虚拟机资源超卖争抢）：

- **宿主机综合 CPU 使用率 (%)**：
  ```promql
  (1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) by (instance)) * 100
  ```
- **磁盘 I/O 等待 (iowait) 占比 (%)**（超过 15% 说明存在严重磁盘读写堵塞）：
  ```promql
  avg(rate(node_cpu_seconds_total{mode="iowait"}[5m])) by (instance) * 100
  ```
- **云虚机 Steal 占比 (%)**（超过 5% 说明底层物理母机超卖严重或邻居虚拟机吵闹）：
  ```promql
  avg(rate(node_cpu_seconds_total{mode="steal"}[5m])) by (instance) * 100
  ```

### 2. 真实内存可用率（避开 MemFree 陷阱）

> [!WARNING]
> Linux 内核设计哲学是“充分利用空闲内存做 PageCache”，因此 `node_memory_MemFree_bytes` 通常非常低。生产排障中**严禁**使用 Free 衡量内存，必须使用内核 3.14+ 提供的 **`MemAvailable`**。

- **真实内存使用率 (%)**（触发 >90% 告警）：
  ```promql
  (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
  ```
- **Swap 换页频率（换页频繁是系统急剧卡顿的先兆）**：
  ```promql
  rate(node_vmstat_pgpgin[5m]) + rate(node_vmstat_pgpgout[5m])
  ```

### 3. 磁盘 I/O 性能与利用率

- **根分区可用容量百分比 (%)**：
  ```promql
  (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100
  ```
- **磁盘预测写满时间 (利用线性回归预测 4 小时内即将满盘的磁盘)**：
  ```promql
  predict_linear(node_filesystem_avail_bytes{mountpoint="/"}[1h], 4 * 3600) < 0
  ```
- **磁盘 I/O 使用率（饱和度 %）**（接近 100% 说明磁盘 IO 已达瓶颈）：
  ```promql
  rate(node_disk_io_time_seconds_total{device=~"sd.*|vd.*|nvme.*"}[5m]) * 100
  ```
- **磁盘读写响应平均延迟 (ms)**（超过 20ms 说明存储响应缓慢）：
  ```promql
  rate(node_disk_read_time_seconds_total[5m]) / rate(node_disk_reads_completed_total[5m]) * 1000
  ```

### 4. 物理网卡吞吐与丢包

- **物理网卡入向带宽 (Mbps)**：
  ```promql
  rate(node_network_receive_bytes_total{device=~"eth.*|ens.*|bond.*"}[5m]) * 8 / 1000 / 1000
  ```
- **网卡入向丢包率 (Drop Rate /s)**（一旦大于 0 需排查网卡 Buffer 或软中断）：
  ```promql
  rate(node_network_receive_drop_total{device=~"eth.*|ens.*|bond.*"}[5m])
  ```

---

## 四、 Textfile 收集器：打通硬件 RAID、SMART 与运维元数据

node_exporter 支持通过本地文本文件注入自定义指标。只需在宿主机定时任务（crontab）中将符合 Prometheus 文本协议的内容写入指定目录，node_exporter 即可在每次 Scrape 时一并对外暴露：

```bash
# 宿主机定时巡检脚本示例 (/opt/scripts/check_hw_raid.sh)
#!/bin/bash
OUTPUT_FILE="/var/lib/node_exporter/textfile_collector/hardware.prom"

# 假设通过 MegaCli / storcli 检测 RAID 状态
RAID_STATUS=1 # 1: OPTIMAL, 0: DEGRADED
NTP_OFFSET=$(chronyc sources | grep '^\*' | awk '{print $NF}' | sed 's/s//')

cat <<EOF > ${OUTPUT_FILE}.$$
# HELP hardware_raid_status Hardware RAID array health (1=OK, 0=Degraded)
# TYPE hardware_raid_status gauge
hardware_raid_status{controller="c0"} ${RAID_STATUS}

# HELP host_ntp_offset_seconds NTP time sync offset in seconds
# TYPE host_ntp_offset_seconds gauge
host_ntp_offset_seconds ${NTP_OFFSET:-0}
EOF

mv ${OUTPUT_FILE}.$$ ${OUTPUT_FILE}
```

---

> [!TIP] 💡 关联技术与延伸阅读
>
> * [Prometheus 与 Alertmanager 企业级架构设计与生产落地](./01-Prometheus与Alertmanager架构设计与生产落地.md)
> * [cAdvisor 容器运行时指标全景与双轨采集对比](./03-cAdvisor容器运行时指标全景与双轨采集对比.md)
> * [万级节点与十万级 Pod 大规模集群调优指南](../07-万级节点与十万级Pod大规模集群调优指南.md)
> * [node-exporter 生产级 DaemonSet 部署清单](../../../../05-Install/monitoring/05-node-exporter.yaml)

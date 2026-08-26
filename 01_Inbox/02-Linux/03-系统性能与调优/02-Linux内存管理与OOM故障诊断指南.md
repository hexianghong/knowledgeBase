# Round 4: Linux 内存管理与 OOM 故障诊断指南

物理内存是 Linux 系统中最宝贵、争抢最剧烈的硬件资源之一。当系统出现内存不足（Out of Memory, OOM）时，内核会触发强制杀进程机制，直接撕裂运行中的关键服务。

本指南深入探索 Linux 4级/5级页表虚拟内存映射、Buddy System 11阶分配器、Slub 内存分配、NUMA 架构坑点、内核 Dirty Page 刷盘机制、OOM 打分计算公式以及 RSS/PSS/USS 内存分析指标。

---

## 一、 4级/5级页表与物理分配器 (Buddy & Slub)

### 1. 4级/5级页表 (PGD -> P4D -> PUD -> PMD -> PTE) 转换计算

在 64 位 x86_64 架构下，虚拟地址为 48 位或 57 位（5级页表），通过多级页表查表转换为物理地址：

```
虚拟地址 (Virtual Address - 48Bits)
+----------+----------+----------+----------+----------+
| PGD (9b) | P4D (9b) | PUD (9b) | PMD (9b) | PTE (9b) | Offset (12b)
+----------+----------+----------+----------+----------+
     |          |          |          |          |
     v          v          v          v          v
  [PGD表] ---> [P4D表] ---> [PUD表] ---> [PMD表] ---> [PTE页表项] ---> 物理 4KB 页 (Physical Page)
```

* **TLB (Translation Lookaside Buffer)**：硬件页表缓存，避免每次内存访问都进行 4~5 次内存寻址。

---

### 2. 伙伴系统 (Buddy System) 11 阶 `free_area` 算法

Buddy System 将物理内存分为 11 个 Order（Order 0 到 Order 10）。
* **Order 0**：$2^0 = 1$ 个 4KB 页框 (4KB)
* **Order 10**：$2^{10} = 1024$ 个 4KB 页框 (4MB 连续物理内存)

```bash
# 查看系统各 NUMA 节点下 Buddy System 11 阶空闲块分布
cat /proc/buddyinfo
```
*输出示范：*
```
Node 0, zone   Normal    521   210   102    40    12     3     1     0     0     0     0
```
*诊断：如果 Order 0~3 很多，但 Order 7~10 全部为 0，说明物理内存存在严重的外部碎片化（External Fragmentation），此时申请连续大块物理内存（如 2MB 巨页）必定触发内核同步重组卡顿！*

---

### 3. Slub 分配器与 `kmem_cache_create`

对于小于 4KB 的内核对象（如 `task_struct`, `inode`, `socket`），由 **Slub Allocator** 在 Buddy 分配出的 4KB 页面内部切分成固定大小的对象池。

```bash
# 查看 Slub 分配器管理的各类内核对象内存开销
slabtop -sc
```

---

## 二、 内存页分类：Page Cache vs Buffer Cache 与 RSS/PSS/USS

### 1. `free -m` 中 `buff/cache` 与 `available` 真实含义

```bash
              total        used        free      shared  buff/cache   available
Mem:           31Gi       12Gi       2.0Gi       500Mi        17Gi        18Gi
```

$$\text{available} \approx \text{free} + \text{可回收的 Page Cache/Buffers} - \text{内核保留水位 (Low Watermark)}$$

---

### 2. 进程内存指标：VSS, RSS, PSS 与 USS 的区别

| 指标 | 英文全称 | 物理含义与精确度 |
| :--- | :--- | :--- |
| **VSS** / VSZ | Virtual Set Size | 进程申请的虚拟内存总量（包含 `malloc` 未实际写入的部分） |
| **RSS** | Resident Set Size | 进程占用的常驻物理内存（多进程共享的动态库如 `libc.so` 被重复计算） |
| **PSS** | Proportional Set Size | **最精准评估指标**。独占物理内存 + 按进程数均摊的共享内存 |
| **USS** | Unique Set Size | 进程**独占**物理内存。杀死该进程后系统**立即可释放**的内存量 |

```bash
# 使用 smem 工具按 PSS 降序查看进程内存
smem -k -s pss -r | head -n 15
```

---

## 三、 NUMA (非一致性内存访问) 架构坑点与排查

```bash
# 1. 禁用 NUMA 本地节点强制回收，允许跨 Node 分配内存
sysctl -w vm.zone_reclaim_mode=0

# 2. 对数据库使用 numactl 采用 Interleave 策略
numactl --interleave=all /usr/sbin/mysqld
```

---

## 四、 内核内存调优参数与 Dirty Page 刷盘

### 1. `vm.swappiness` 调优
生产数据库/K8s 节点推荐：`vm.swappiness = 1` 或 `10`。

### 2. 脏页 (Dirty Page) 字节数限制
高内存服务器推荐改用固定字节限制，防止 Flush 瓶颈：
```ini
vm.dirty_background_bytes = 268435456   # 256MB
vm.dirty_bytes = 1073741824              # 1GB
```

---

## 五、 Linux OOM Killer 打分机制与生产救援

$$\text{oom\_score} \approx \frac{\text{进程占用的 RSS + 页表物理内存}}{\text{系统总物理内存}} \times 1000 + \text{oom\_score\_adj}$$

```bash
# 1. 查看系统中最容易被 OOM Killer 选中的 Top 10 进程
printf "PID\tOOM_Score\tProcess_Name\n"
for proc in /proc/[0-9]*; do
    pid=${proc##*/}
    if [ -f "$proc/oom_score" ]; then
        printf "%s\t%s\t%s\n" "$pid" "$(cat $proc/oom_score 2>/dev/null)" "$(cat $proc/comm 2>/dev/null)"
    fi
done | sort -k2 -nr | head -n 10

# 2. 免疫核心守护进程（如 sshd / kubelet）免遭 OOM 误杀 (-1000 代表完全免疫)
echo -1000 > /proc/$(cat /var/run/sshd.pid)/oom_score_adj
```

---

## 六、 现代内核内存可观测性：PSI (Pressure Stall Information) 与 Cgroups v2 限流 (Brendan Gregg / Red Hat 精髓)

### 1. PSI 内存压力指标深度解读

传统通过 `free -m` 或 `Load Average` 无法精准判断系统是否真正因为内存不足而产生性能停顿。Linux 4.20+ 引入了 **PSI (Pressure Stall Information)**：

```bash
cat /proc/pressure/memory
# 输出示例：
# some avg10=1.20 avg60=0.50 avg300=0.10 total=3568901
# full avg10=0.00 avg60=0.00 avg300=0.00 total=12003
```

* **`some`**：表示在当前窗口内，至少有**部分任务**因等待内存回收/分配而阻塞的时间占比。
* **`full`**：表示在当前窗口内，**所有活动任务**均因等待内存而阻塞（系统完全失去响应，处于 CPU 停滞或 Swap 颠簸状态）。
* **生产预警基线**：`some avg10 > 10%` 触发内存压力警告；`full avg10 > 0%` 提示系统已发生严重内存瓶颈，需立即扩容或限流。

---

### 2. Cgroups v2 内存主动限流 (`memory.high` vs `memory.max`)

在云原生容器与企业级 RHEL 环境中，Cgroups v2 提供了更平滑的内存防护体系：

| Cgroups v2 参数 | 物理行为与防护机制 |
| :--- | :--- |
| **`memory.min`** | 内存硬保护线。低于此水位的内存绝不被内核回收。 |
| **`memory.low`** | 内存软保护线。系统发生内存回收时优先回收未受保护的 cgroup。 |
| **`memory.high`** | **平滑限流线**。超过此限制时，内核会主动限速（throttle）该容器内进程的分配速度并积极后台回收，**不会触发 OOM-Kill**。 |
| **`memory.max`** | **硬限制线**。超过后触发直接回收，若无法回收立即触发容器级 OOM-Killer。 |

---

> [!TIP] 💡 关联技术与延伸阅读
>
> * [Linux 进程与 CPU 性能调优指南](./01-Linux进程与CPU性能调优指南.md) —— CFS/EEVDF 调度器、USE 分析法与 CPU 火焰图
> * [Linux IO 子系统与存储调优指南](./03-Linux_IO子系统与存储调优指南.md) —— Page Cache 脏页刷盘、通用块层与 IO 调度算法
> * [高级运维生产高频故障排查手册](../07-高可用与生产排错/02-高级运维生产高频故障排查手册.md) —— 内存泄漏定位与 OOM 故障紧急止损 SOP


# Round 10: eBPF、Perf 与现代 Linux 系统可观测性指南

传统的系统监控（如 `/proc` 轮询、`top`、`sar`）粒度粗糙，且高频采样会引发明显的 CPU 开销。随着 Linux 4.x/5.x/6.x 内核的演进，**eBPF (extended Berkeley Packet Filter)** 技术引发了一场现代 Linux 运维与可观测性（Observability）的革命。

本指南深入拆解 eBPF 内核 JIT 安全运行机制、eBPF 验证器 (Verifier) DAG 检测与 BTF 调试信息、BCC 高级诊断工具链、`bpftrace` 一句话跟踪脚本以及 Off-CPU 火焰图生成。

---

## 一、 eBPF 技术革新与内核验证器机制

```mermaid
graph TD
    subgraph "用户空间 (User Space)"
        A["BCC / bpftrace / C 客户端"]
    end
    
    subgraph "Linux 内核空间 (Kernel Space)"
        B["C 语言代码 / eBPF 字节码 (Bytecode)"] -->|bpf() syscall| C["eBPF 验证器 (Verifier)"]
        C -->|1. 有向无环图 (DAG) 死循环检查| C1["2. 寄存器与内存越界校验"]
        C1 -->|验证通过| D["JIT 编译器 (Just-In-Time)"]
        D -->|编译为 x86_64 本地机器码| E["内核探针 (kprobe / tracepoint / tc)"]
        E -->|触发事件| F["eBPF Maps (高效共享内存)"]
    end
    
    F -->|无拷贝读取| A
```

### 1. eBPF Verifier (验证器) 四重安全审查

在字节码注入内核运行前，Verifier 会模拟执行字节码的所有可能路径：
1. **DAG 状态机检测**：禁止任何可能导致内核陷入死循环的无界循环指令。
2. **指针与内存越界审查**：强行校验对 `sk_buff` 或 Context 指针的读写界限，禁止解引用未初始化的指针。
3. **不可达指令清理**：剥离未使用的死代码。
4. **权限级别校验**：要求程序必须拥有 `CAP_BPF` 或 `CAP_SYS_ADMIN` 特权。

---

### 2. BTF (BPF Type Format) 克服内核版本依赖

在旧版 eBPF 开发中，BCC 需要在目标服务器上现场安装 `kernel-devel` 编译头文件。

现代 eBPF 引入了 **BTF (BPF Type Format)** 与 CO-RE (Compile Once – Run Everywhere)：将内核 C 语言数据结构的类型元信息直接打包保存在内核 `/sys/kernel/btf/vmlinux` 中。使得 eBPF 程序只需**编译一次，即可在任意 Linux 内核版本上安全运行**！

---

## 二、 BCC (BPF Compiler Collection) 生产工具链实战

```bash
# 1. 实时捕获短命进程 (捕获被调用的 Shell 脚本)
execsnoop

# 2. 跟踪 Ext4 文件系统上读写延迟超过 10 毫秒的慢 I/O 请求
ext4slower 10

# 3. 统计 10 秒内块设备 I/O 延迟的对数直方图分布
biolatency -m 10

# 4. 按发送/接收吞吐量实时打印占用带宽最多的进程 Top 10
tcptop -C 5
```

---

## 三、 `bpftrace` 动态跟踪一句话脚本

```bash
# 1. 统计系统中各应用程序调用的系统调用 (Syscall) 次数排行榜
bpftrace -e 'tracepoint:raw_syscalls:sys_enter { @[comm] = count(); }'

# 2. 实时追踪系统中所有被调用的 kill() 信号量发送者与接收者 PID
bpftrace -e 'tracepoint:syscalls:sys_enter_kill { time("%H:%M:%S "); printf("%s (PID %d) sent signal %d to PID %d\n", comm, pid, args.sig, args.pid); }'

# 3. 按统计直方图打印系统内核中分配小内存 (kmalloc) 的空间分布
bpftrace -e 'kprobe:__kmalloc { @bytes = hist(arg0); }'
```

---

## 四、 诊断死锁与锁等待：Off-CPU 火焰图

```bash
# 1. 使用 BCC 的 offcputime 工具采样 PID 8848 在 30 秒内的休眠阻塞堆栈
/usr/share/bcc/tools/offcputime -p 8848 -df 30 > offcpu.stacks

# 2. 生成 Off-CPU 火焰图
./FlameGraph/flamegraph.pl --color=io --title="Off-CPU Time Flame Graph" offcpu.stacks > offcpu_flamegraph.svg
```

---

## 五、 云原生与现代可观测性革命 (eBPF.io / Brendan Gregg 精髓)

### 1. 常用 BCC / bpftrace 生产排错瑞士军刀

| 排错场景 | 推荐工具 | 核心诊断原理与输出 |
|:---|:---|:---|
| **短命进程排查** | `execsnoop` | 追踪 `execve()` 系统调用，抓出频繁启动并退出的隐藏 Shell 脚本/Cron |
| **文件读写慢** | `ext4slower` / `xfsslower` | 挂载文件系统 VFS 探针，仅记录耗时超过阈值（如 10ms）的文件名与偏移量 |
| **磁盘 IO 延迟直方图** | `biolatency` | 挂钩块设备请求排队与完成中断，绘制真实的微秒/毫秒级对数直方图 |
| **TCP 连接生命周期** | `tcplife` | 记录 TCP 连接建立到关闭的持续时间、发送/接收字节数与进程名 |
| **权限不足与排错** | `capable` | 追踪内核 `cap_capable()` 权限检查，定位缺少哪个 Linux Capability |

---

### 2. 云原生底座技术：Cilium 与 Tetragon 架构变革

* **Cilium (网络与安全)**：利用 XDP (eXpress Data Path) 与 tc-bpf 直接在网卡驱动层/协议栈早期重定向网络包，**彻底规避 Netfilter/iptables 线性规则扫描开销**，支持百万 Pod 级超低延迟转发与 L7 流量感知。
* **Tetragon (安全与运行时观测)**：通过内核层 eBPF kprobes 与 LSM (Linux Security Modules) 挂钩，在内核空间毫秒级拦截越权提权、反弹 Shell 与命名空间逃逸，实现 0 运行时性能损耗的安全防护。

---

> [!TIP] 💡 关联技术与延伸阅读
>
> * [Linux 容器底层原理与 Namespace/Cgroups 指南](./02-Linux容器底层原理与Namespace_Cgroups指南.md) —— 容器 6 大隔离命名空间与 Cgroups 资源配额限制
> * [Linux 高级网络架构与流量控制(TC_BPF)指南](../02-网络与流量架构/02-Linux高级网络架构与流量控制(TC_BPF)指南.md) —— TC-BPF 流量控制与 XDP 软中断旁路加速
> * [Linux 进程与 CPU 性能调优指南](../03-系统性能与调优/01-Linux进程与CPU性能调优指南.md) —— On-CPU / Off-CPU 火焰图与性能分析体系


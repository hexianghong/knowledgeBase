# 06-虚拟化与内核底座

## 目录说明
涵盖 KVM/QEMU 虚拟化与 Virtio 半虚拟化驱动、容器底层 6 大 Namespace 与 Cgroups 隔离机制、Linux 动态内核模块 (LKM) 编译调试，以及现代 eBPF 内核可观测性框架。

## 内容索引
| 名称 | 类型 | 说明 |
|------|------|------|
| [./01-Linux虚拟化与KVM_QEMU深度指南.md](./01-Linux虚拟化与KVM_QEMU深度指南.md) | 文件 | CPU 硬件辅助虚拟化（Intel VT-x）、QEMU/KVM 架构、Virtio 半虚拟化驱动与 Libvirt 管理 |
| [./02-Linux容器底层原理与Namespace_Cgroups指南.md](./02-Linux容器底层原理与Namespace_Cgroups指南.md) | 文件 | 容器底层 6 大 Linux Namespace 隔离、Cgroups v1/v2 资源限制与 Rootfs 挂载机制 |
| [./03-Linux内核模块开发与调试指南.md](./03-Linux内核模块开发与调试指南.md) | 文件 | Linux 内核模块加载机制（LKM）、动态调试工具（ftrace/kdump/crash）与内核崩盘 Panic 定位 |
| [./04-eBPF与现代Linux系统可观测性指南.md](./04-eBPF与现代Linux系统可观测性指南.md) | 文件 | eBPF 虚拟机原理、BCC/libbpf 工具链、Kprobe/Tracepoint 探针与无侵入内核级可观测性 |

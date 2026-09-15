# 02_K8S_Troubleshooting_Guide Kubernetes 生产实战排障指南

## 目录说明
本目录专门沉淀 Kubernetes 生产集群一线重大故障复盘报告（RCA / Post-Mortem）、核心组件（APIServer、Etcd、Kubelet、CNI/CSI）疑难杂症排查实战以及容器资源（内存、CPU、FD 句柄、网络连接）深度诊断决策树。

## 内容索引
| 名称 | 类型 | 说明 |
| :--- | :--- | :--- |
| [./01-生产环境cloud-proxy容器17万句柄泄漏与零中断恢复复盘.md](./01-生产环境cloud-proxy容器17万句柄泄漏与零中断恢复复盘.md) | 文件 | 生产 Java NIO 句柄泄漏排查、10 年管理员凭证自签打通与单副本平滑无损切换复盘报告 |

---

> [!TIP] 💡 新增事故复盘指引
> 编写新的生产故障排查或复盘报告时，请优先使用模板：[`../../07_Templates/01_生产事故复盘与RCA根因分析模板.md`](../../07_Templates/01_生产事故复盘与RCA根因分析模板.md)。

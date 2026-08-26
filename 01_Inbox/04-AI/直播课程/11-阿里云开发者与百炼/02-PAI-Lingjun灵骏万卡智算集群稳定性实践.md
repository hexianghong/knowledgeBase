# PAI-Lingjun 灵骏万卡智算集群稳定性与故障自愈实践

> **主办方/公众号**：阿里云开发者 / PAI 团队  
> **分享主题**：万卡 Scale-Out 集群秒级故障隔离、断点续训与无损 RDMA 网络运维  
> **核心标签**：`PAI-Lingjun 灵骏` `万卡集群` `断点续训` `故障自动隔离` `RDMA`

---

## 📺 课程与学习资源导航

- **📺 官方视频回放**：[Bilibili - 阿里云官方：PAI 灵骏万卡架构](https://space.bilibili.com/264875323)

---

## 1. 核心高可用架构：从分钟级人工排障到秒级自愈

```mermaid
flowchart TD
    Trainer[万卡大模型长时间分布式预训练] --> Monitor[毫秒级探针: 监控 GPU 显存翻转、NCCL 通信掉卡、慢节点]
    Monitor -->|探测到异常卡/慢节点| AutoIsolate[自动热摘除故障节点]
    AutoIsolate --> FastCheckpoint[从分布式对象存储极速恢复最近 Checkpoint]
    FastCheckpoint --> AutoResume[自动拉起热备节点恢复训练 (整体中断时间 < 2分钟)]
```

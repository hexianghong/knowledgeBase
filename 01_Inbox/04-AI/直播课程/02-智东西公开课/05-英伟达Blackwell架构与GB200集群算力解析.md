# 英伟达 Blackwell 架构与 GB200 集群算力解析

> **主办方/公众号**：智东西公开课  
> **分享主题**：NVIDIA Blackwell 架构解析、NVLink 5.0 (1.8TB/s) 与 FP4 微尺度量化落地  
> **核心标签**：`Blackwell GPU` `GB200 NVL72` `NVLink 5.0` `FP4 量化` `第二代 Transformer 引擎`

---

## 📺 课程与学习资源导航

- **📺 官方视频回放**：[Bilibili - 智东西公开课：Blackwell 与 GB200 架构深度拆解](https://space.bilibili.com/393278857)
- **📦 官方架构白皮书**：[NVIDIA Blackwell Architecture Technical Whitepaper](https://www.nvidia.com/)

---

## 1. 架构飞跃：两颗晶圆双芯合一与第二代 Transformer 引擎

```mermaid
graph TD
    subgraph ChipArch["1. 物理芯片级双芯合一 (Dual-Die via 10TB/s NV-HBI)"]
        Die1[Blackwell Die 0 (1040 亿晶体管)] <==>|10 TB/s 片间超高速互联| Die2[Blackwell Die 1 (1040 亿晶体管)]
        Die1 & Die2 ==> UnifiedGPU[统一暴露为单张 2080 亿晶体管 GPU (192GB HBM3e)]
    end

    subgraph TensorEngine["2. 第二代 Transformer 引擎 (Microscopic FP4)"]
        FP4_Math[支持微尺度 Micro-scaling FP4 精度]
        FP4_Math ==> FP4_Benefit[推理吞吐比 Hopper H100 暴涨 4x, 显存占用缩减 50%]
    end
```

---

## 2. GB200 NVL72 机柜级系统拓扑

- **机柜配置**：单机柜集成 36 颗 Grace CPU + 72 颗 Blackwell GPU；
- **全互联总线**：通过背板 5000+ 根无源铜缆与 9 个 NVSwitch 托盘构成 **130TB/s 双向总带宽的单域超大 GPU**；
- **万亿模型实时推理**：无需跨机以太网/IB 网络，单机柜即可承载 **万亿 MoE 模型零通信瓶颈全速推理**。

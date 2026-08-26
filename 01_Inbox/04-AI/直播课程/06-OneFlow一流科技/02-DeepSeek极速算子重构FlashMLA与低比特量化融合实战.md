# DeepSeek 极速算子重构：FlashMLA 与低比特量化融合实战

> **主办方/公众号**：OneFlow 一流科技  
> **分享主题**：手写 Triton 算子实现 FlashMLA 动态反量化、W8A8 / FP8 矩阵乘融合与极限显存优化  
> **核心标签**：`FlashMLA` `Triton 算子重写` `FP8 量化融合` `DeepSeek` `显存瓶颈突破`

---

## 📺 课程与学习资源导航

- **📺 官方视频回放**：[Bilibili - OneFlow 官方：手写 Triton 算子实操](https://space.bilibili.com/403066341)
- **💻 开源工具仓库**：[OneDiff / SiliconFlow](https://github.com/siliconflow/onediff)

---

## 1. 算子融合与低比特反量化优化拓扑

```mermaid
flowchart LR
    subgraph Traditional["传统分离算子 (显存反复搬运)"]
        FP8_Weight[FP8 权重从 HBM 读取] --> DequantKernel[算子 1: 反量化为 FP16 写回 HBM]
        DequantKernel --> GEMMKernel[算子 2: 从 HBM 读取 FP16 并执行 GEMM 计算]
    end

    subgraph FusedKernel["OneFlow 融合 Kernel (寄存器与片上 SRAM 直通)"]
        FP8_In[FP8 权重从 HBM 载入 SRAM] --> InRegisterDequant[在 GPU 寄存器内完成即时反量化]
        InRegisterDequant --> TensorCoreMath[直接喂入 Tensor Core 矩阵乘]
        TensorCoreMath --> DirectOut[直接写回输出 (零冗余 HBM 中间读写)]
    end
```

- **实测性能**：在 RTX 4090 / A100 上，Decoding 生成延迟缩短 **35%**，显存带宽占用降低 **50%**。

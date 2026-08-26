# 大模型推理 PD 分离架构与 KV 缓存极速传输实践

> **主办方/公众号**：InfoQ / AICon 技术线上峰会  
> **分享主题**：长文本高并发场景下的 Prefill 与 Decode 物理分离（PD 分离）架构设计与工程演进  
> **核心标签**：`PD 分离架构` `KV Cache 跨机传输` `TTFT 优化` `RDMA / Mooncake` `vLLM 集群`

---

## 📺 课程与学习资源导航

- **📺 官方视频回放**：[Bilibili - InfoQ 官方：大模型推理加速与PD分离](https://space.bilibili.com/393278857)
- **💻 开源工具与参考仓库**：
  - KVCache 极速传输引擎：[Mooncake (GitHub)](https://github.com/kvcache-ai/Mooncake) / [vLLM Disaggregated Prefill](https://github.com/vllm-project/vllm)

---

## 1. 为什么必须将 Prefill 与 Decode 进行物理硬件隔离？

在大模型推理中，Prefill（计算输入提示词）与 Decode（逐字生成输出）在硬件计算特征上存在根本冲突：

```mermaid
graph TD
    A[推理两阶段计算特征冲突] --> B[Prefill 阶段: 计算密集型 (Compute-Bound), 极耗 GPU Tensor Core, 容易打满算力]
    A --> C[Decode 阶段: 内存带宽受限型 (Memory-Bound), 极其依赖显存读取带宽, 算力利用率常低于 10%]
    B & C ==> D[传统混部架构: 长文本 Prefill 严重阻塞其他用户的 Decode 生成, 首字延迟 TTFT 发生剧烈抖动]
    D ==> E[必须采用 PD 分离架构: 专卡专用 + 高速网络传输 KV Cache]
```

---

## 2. 生产级 PD 分离架构拓扑设计

```mermaid
flowchart TB
    subgraph Gateway["1. 调度与路由网关 (PD Router Gateway)"]
        UserReq[高并发长上下文请求] --> Router[全局负载均衡调度器]
    end

    subgraph PrefillCluster["2. Prefill 专有计算集群 (P-Nodes: 算力密集型 GPU)"]
        Router --> P_Node1[Prefill Node A: 高并行 Prefill 计算]
        Router --> P_Node2[Prefill Node B: 高并行 Prefill 计算]
        P_Node1 --> GeneratedKV[生成完整 KV Cache 块 (Prefix KV)]
    end

    subgraph FastTransfer["3. 极速跨机传输通道 (RDMA / Mooncake Engine)"]
        GeneratedKV == RDMA 400Gbps / RoCE 零拷贝传输 ==> TargetDNode
    end

    subgraph DecodeCluster["4. Decode 专有生成集群 (D-Nodes: 高显存带宽 GPU)"]
        TargetDNode[Decode Node: 接收并载入 KV Cache]
        TargetDNode --> FastTokenGen[纯粹 Token 逐字生成 (低延迟稳定输出)]
    end
```

- **业务收益**：首字响应延迟（TTFT）降低 **60%~75%**，长文本并发生成吞吐量（Tokens/s）提升 **3x 以上**。

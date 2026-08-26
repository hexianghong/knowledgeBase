# 企业级 AI 引入 ROI 评估与商业选型避坑指南

> **主办方/公众号**：甲子光年 / 甲子智库  
> **分享主题**：企业引入大模型的 ROI 综合测算模型、商业闭源 API vs 自建开源微调 TCO 对比与选型决策树  
> **核心标签**：`甲子智库` `企业 AI 选型` `ROI 评估模型` `TCO 总体拥有成本` `商业化落地`

---

## 📺 课程与学习资源导航

- **📺 官方视频回放**：[Bilibili - 甲子光年官方：科技产业峰会与ROI沙龙](https://space.bilibili.com/393278857) ｜ [甲子光年官网](https://www.jazzyear.com/)

---

## 1. 企业 AI 投资回报率（ROI）测算公式

$$\text{ROI} = \frac{\text{净收益 (工时节约价值 + 业务增量营收)} - \text{TCO 总体拥有成本}}{\text{TCO 总体拥有成本}} \times 100\%$$

```mermaid
graph TD
    subgraph TCO_Cost["TCO 总体拥有成本构成"]
        C1[1. 硬件/云算力 Token 成本 (35%)]
        C2[2. FDE 交付与内部研发定制工时 (40%)]
        C3[3. 持续数据标注与评估监控运维 (25%)]
    end

    subgraph BusinessValue["业务价值产出构成"]
        V1[1. 直接人效释放 (如代码辅助/客服人效翻倍)]
        V2[2. 挽回流失客单 (如智能推荐/秒级响应提升转化率)]
        V3[3. 降低合规与违约风险罚金]
    end

    TCO_Cost & BusinessValue ==> DecisionMatrix[选型决策树: 采购 SaaS vs 专有云微调]
```

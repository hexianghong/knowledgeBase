# Baidu Create 2026：文心 5.0 与全模态智能体演进

> **主办方/公众号**：百度智能云 / 文心一言开发者  
> **分享主题**：文心 5.0 原生全模态架构、多智能体协同框架与行业大模型落地  
> **核心标签**：`Baidu Create 2026` `文心 5.0` `全模态交互` `AppBuilder 3.0`

---

## 📺 课程与学习资源导航

- **📺 官方视频回放**：[Bilibili - 百度 Create 2026 开发者大会回放](https://space.bilibili.com/393278857)

---

## 1. 核心架构演进：原生全模态融合

```mermaid
flowchart TD
    MultiIn[文本 / 语音 / 视频流 / 代码] --> UnifiedTokenEncoder[原生全模态统一编码器]
    UnifiedTokenEncoder --> Ernie5_Core[文心 5.0 混合推理引擎 (原生流式双向交互)]
    Ernie5_Core --> MultiOut[毫秒级实时语音对答 / 视频生成 / 跨软件动作控制]
```

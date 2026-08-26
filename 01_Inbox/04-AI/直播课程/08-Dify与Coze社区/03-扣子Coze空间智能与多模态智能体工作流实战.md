# 扣子 Coze 空间智能与多模态智能体工作流实战

> **主办方/公众号**：扣子 Coze 开发者社区 / 字节跳动  
> **分享主题**：多模态节点（视觉/音频/图表）与飞书多维表格深度联动自动化实战  
> **核心标签**：`扣子 Coze` `多模态工作流` `飞书多维表格` `自动化巡检` `企业办公集成`

---

## 📺 课程与学习资源导航

- **📺 官方视频回放**：[扣子官方公开课直播间](https://www.coze.cn/) ｜ 微信视频号搜索：`扣子Coze`
- **💻 官方开发指南**：[Coze 开发文档](https://www.coze.cn/docs)

---

## 1. 企业多模态巡检自动化工作流拓扑

```mermaid
flowchart LR
    Trigger([门店巡检员拍照上传]) --> VLM_Node[多模态大模型节点: 识别货架商品摆放与缺货率]
    VLM_Node --> ConditionCheck{缺货率 > 20% ?}
    
    ConditionCheck -->|是 (告警)| FeishuBitable[写入飞书多维表格 '紧急补货清单']
    FeishuBitable --> FeishuBot[飞书群自动 @ 责任人发送加急补货卡片]
    
    ConditionCheck -->|否 (合格)| RecordLog[日常归档日志]
```

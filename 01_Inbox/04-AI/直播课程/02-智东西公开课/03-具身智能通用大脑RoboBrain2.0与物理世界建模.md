# 具身智能通用大脑 RoboBrain 2.0 与物理世界建模

> **主办方/公众号**：智东西公开课 / 智猩猩 AI 新青年讲座  
> **分享主题**：面向真实物理环境的通用具身大脑 RoboBrain 2.0 架构与空间智能突破  
> **核心标签**：`RoboBrain 2.0` `具身智能` `空间智能` `3D 时空表征` `Sim2Real`

---

## 📺 课程与学习资源导航

- **📺 官方视频回放**：[Bilibili - 智猩猩公开课：具身智能专题](https://space.bilibili.com/393278857) ｜ [智东西官网专区](https://www.zhidx.com/open)
- **💻 开源基准与模型**：
  - 智源研究院 RoboBrain 平台：[BAAI-RoboBrain (GitHub)](https://github.com/FlagOpen/)

---

## 1. 核心技术突破：从数智化向物理 AI 的跨越

RoboBrain 2.0 彻底摆脱了传统 2D 像素到关节电机的简单黑盒映射，构建了**三层多尺度物理感知与推理架构**：

```mermaid
flowchart TD
    subgraph MultiSensory["1. 多模态物理感知输入"]
        RGBD[双目 RGB-D 深度视觉] & PointCloud[LiDAR 3D 稠密点云] & Tactile[阵列式电子触觉传感] --> FusionEncoder[3D 空间时空几何编码器]
    end

    subgraph WorldDynamics["2. 通用具身大脑 (RoboBrain 2.0 Core)"]
        FusionEncoder --> Spatial3DGraph[动态 3D 场景图谱与物理属性标注 (质量/摩擦系数/刚度)]
        Spatial3DGraph --> AffordanceReasoning[可操作性推理 (Affordance Learning)]
        AffordanceReasoning --> TemporalTrajectory[生成 3D 端点轨迹与动态交互接触力分布]
    end

    subgraph Execution["3. 硬件执行器闭环"]
        TemporalTrajectory --> RealTimeController[高频实时阻抗力控小脑 (1000Hz)]
        RealTimeController --> RobotAction[完成开门、精细装配、动态接物等复杂动作]
    end
```

---

## 2. 生产级避坑指南

- **避坑点**：避免直接将网络预训练的 2D 视觉模型（如 CLIP）用于空间几何操作，2D 图像缺少深度的绝对物理尺度，必须引入 **3D Voxel / PointNet++** 进行空间几何对齐。

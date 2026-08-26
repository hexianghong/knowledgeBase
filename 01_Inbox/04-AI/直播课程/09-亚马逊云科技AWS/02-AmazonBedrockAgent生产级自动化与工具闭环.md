# Amazon Bedrock Agent 生产级自动化与工具闭环

> **主办方/公众号**：亚马逊云科技 / AWS 开发者沙龙  
> **分享主题**：基于 Bedrock Agent、Action Groups 与 AWS Lambda 构建 Serverless 自主业务闭环  
> **核心标签**：`Bedrock Agent` `Action Groups` `AWS Lambda` `OpenAPI` `自动化运维`

---

## 📺 课程与学习资源导航

- **📺 官方视频回放**：[Bilibili - 亚马逊云科技：Bedrock Agent 实战](https://space.bilibili.com/511284890)
- **💻 官方开发文档**：[Bedrock Agents Documentation](https://docs.aws.amazon.com/bedrock/)

---

## 1. Bedrock Agent 动作组（Action Groups）执行拓扑

```mermaid
flowchart TD
    UserQuery[用户指令: '帮我查询东京区域 EC2 异常实例并自动重启'] --> AgentBrain[Bedrock Agent 规划大脑 (ReAct)]
    AgentBrain --> ActionGroup[调用关联 Action Group: OpenAPI 接口描述]
    ActionGroup --> LambdaExecutor[触发 AWS Lambda Serverless 函数]
    LambdaExecutor --> AWS_SDK[调用 AWS Boto3 SDK 执行 DescribeInstances & Reboot]
    AWS_SDK --> ExecutionResult[返回实例状态]
    ExecutionResult --> AgentBrain
    AgentBrain --> FinalConfirmation[向用户输出排查与重启完成报告]
```

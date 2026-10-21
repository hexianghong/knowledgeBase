# Git 仓库跨版本与跨网络隔离迁移工具

## 目录说明
针对新旧 GitLab 处于**不同物理网络/无法同时访问**的生产场景设计。提供解耦的“两阶段（Pull $\rightarrow$ 切换网络 $\rightarrow$ Push）”自动化迁移方案。
支持精准 Commit 切片、重置纯净 Init 提交、密码特殊字符安全 URL 编解码、以及基于 GitLab 18.x Push Options 的自动建仓推送。

## 内容索引
| 名称 | 类型 | 说明 |
| :--- | :--- | :--- |
| [./repo_list.txt](./repo_list.txt) | 文件 | 待迁移服务源地址与精确 Commit 列表清单（已清洗过滤无 Commit 组件） |
| [./sync_repos.sh](./sync_repos.sh) | 文件 | 两阶段迁移核心脚本（支持 `pull`、`push`、`status`，详细错误回显） |

## 完整操作 SOP

### 步骤 1：在旧仓库网络下（批量拉取并初始化）
连接能够访问旧 GitLab（`https://gitlab-hz.rubikstack.com`）的网络，执行批量拉取：
```bash
cd ./06_Troubleshooting/git

# 批量拉取全部 48 个微服务仓库并重置为 Init commit
./sync_repos.sh pull

# (可选) 仅拉取单个服务进行测试
# ./sync_repos.sh pull vue-rcs
```
> **说明**：脚本会自动克隆指定 Commit 代码，剥离原仓库全部旧提交历史，并重新初始化为纯净的 `master` 分支 Init 提交，暂存在本地临时区。

### 步骤 2：切换网络
* 断开旧仓库网络；
* 切换/连接到目标新内网环境（确保能访问 `http://gitlab-lan.xhhos.com`）。

### 步骤 3：在新仓库网络下（批量推送并自动清理）
执行批量推送：
```bash
# 查看本地就绪状态
./sync_repos.sh status

# 批量推送到新 GitLab（推送成功一个立即清理一个本地代码）
./sync_repos.sh push

# (可选) 仅推送单个服务测试
# ./sync_repos.sh push vue-rcs
```
> **说明**：
> 1. 推送时自动携带 `-o project.create` 选项，GitLab 社区版 v18.9.2 将自动在 `wowjoy` 群组下创建空仓库；
> 2. 推送成功一个即刻 `rm -rf` 清理对应的本地暂存目录，不占用硬盘空间；
> 3. 若有推送失败的仓库，会保留在本地并打印详细 Git 错误回显，便于针对性排障与单独重试。

---

> [!TIP] 💡 关联技术与延伸阅读
>
> * [Kubernetes 生产实战排障指南](../02_K8S_Troubleshooting_Guide/README.md)
> * [生产环境运维 SOP 标准模板](../../07_Templates/03_生产环境运维SOP标准模板.md)

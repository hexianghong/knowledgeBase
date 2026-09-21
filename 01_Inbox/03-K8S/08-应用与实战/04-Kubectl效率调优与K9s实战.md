# ⌨️ Kubectl 效率调优与 K9s 实战指南

Kubernetes 日常运维中，频繁的手动输入 `kubectl` 全称和长参数极易降低排障效率并产生拼写错误。本文汇集了主流 Shell 下的**自动补全配置**、**生产别名（Alias）体系**、**多集群环境快速切（kubectx/kubens）** 以及终端 UI 工具 **K9s** 的核心实战用法，助力运维开发效率翻倍。

---

## 一、 Kubectl 命令行自动补全配置

自动补全（Tab 键）能够自动列出集群中的 Namespace、Pod 名称以及命令参数。

### 1. Bash 环境下的配置

在 Linux / CentOS 系统中，默认使用的是 Bash Shell。

```shell
# 1. 必须首先安装 bash-completion 包 (提供 Tab 键底层脚本支持)
# 如果不装此包，补全时会报错: ap-bash: _get_comp_words_by_ref: 未找到命令
yum install -y bash-completion

# 2. 重新加载系统补全脚本以使其生效
source /usr/share/bash-completion/bash_completion

# 3. 将 kubectl 补全导入当前 Shell 并追加到用户环境变量
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.bashrc
```

### 2. Zsh 环境下的配置



在 macOS 或者安装了 Oh-My-Zsh 的服务器上：

```shell
# 1. 将补全脚本写入 zsh 的用户变量中
source <(kubectl completion zsh)
echo "source <(kubectl completion zsh)" >> ~/.zshrc

# 2. 如果遇到补全报错，可在 ~/.zshrc 首行加入 autoload 初始化：
# autoload -Uz compinit
# compinit
```

---

## 二、 生产级 Kubectl 快捷别名 (Alias) 体系

将以下高频使用的别名追加到您的 `~/.bashrc` 或 `~/.zshrc` 中：

```bash
# ------------------ Kubectl 基础快捷键 ------------------
alias k='kubectl'
alias kg='k get'
alias kd='k describe'
alias ke='k edit'
alias kdel='k delete'

# ------------------ 资源查询组合键 ------------------
alias kgp='k get pods'
alias kgpwide='k get pods -o wide'
alias kgd='k get deployments'
alias kgs='k get svc'
alias kgn='k get nodes -o wide'
alias kga='k get all -A'

# ------------------ 常用运维排障 ------------------
alias klogs='k logs -f'
alias kexec='k exec -it'

# ------------------ 💫 极速 YAML 导出 (CKA/生产常用) ------------------
export do="--dry-run=client -o yaml"
export now="--force --grace-period 0"

# 使用示例:
# 1. 快速导出 Nginx Pod 的模板文件：
# k run my-nginx --image=nginx $do > pod.yaml
# 2. 瞬间强制删除 Pod (避开 K8S 的 30 秒宽限等待)：
# k delete pod my-nginx $now
```

---

## 三、 多集群与命名空间极速切换：kubectx & kubens

当需要同时管理开发、测试、生产多个 K8S 集群，或者在几十个 Namespace 中频繁切换时，使用原生 `kubectl config` 命令非常痛苦。

* **`kubectx`**：一键切换 Kubeconfig 中的 Context（集群环境）。
* **`kubens`**：一键切换当前的默认命名空间，切换后后续的 `k get pods` 无需再带 `-n <namespace>`。

```shell
# 1. macOS 下通过 brew 安装
brew install kubectx

# 2. 使用实战：
kubectx                           # 列出所有集群上下文
kubectx prod-cluster              # 快速切换到生产集群

kubens                            # 列出当前集群的所有命名空间
kubens kube-system                # 将当前默认 namespace 切换为 kube-system
```

---

## 四、 终端交互式 UI 管理利器：K9s

**K9s** 是一个基于终端 Curses 界面开发的 Kubernetes 交互式视图工具。它以近乎零的系统资源消耗，提供了极度流畅的集群状态监控与快捷运维操作。

```text
┌────────────────────────────────────────────────────────┐
│                        K9s UI                          │
│ ┌────────────────────────────────────────────────────┐ │
│ │  Pods (default)                                    │ │
│ │  NAME                     READY   STATUS    RESTARTS│ │
│ │  nginx-84729f-9vw         1/1     Running   0       │ │
│ │  mysql-db-0               1/1     Running   2       │ │
│ └────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────┘
```

### 1. 基础安装

```shell
# macOS 安装
brew install derailed/k9s/k9s

# Linux 二进制安装
wget https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz
tar -zxvf k9s_Linux_amd64.tar.gz -C /usr/local/bin/
```

### 2. K9s 高频快捷键指南

启动 k9s 直接在命令行输入 `k9s` 即可。

#### A. 页面跳转与过滤

* **`:` (冒号)**：进入命令行模式。输入资源缩写跳转到相应页面：
  * `:pod`：跳转到 Pod 视图。
  * `:svc`：跳转到 Service 视图。
  * `:deploy`：跳转到 Deployment 视图。
  * `:ns`：跳转到 Namespace 选择页面。
* **`/` (斜杠)**：进入搜索过滤模式。输入关键字可模糊筛选当前视图的 Pod。

#### B. 核心资源操作 (光标选中 Pod 后)

* **`d`**：执行 `describe`，查看对象详细定义和事件。
* **`l`**：执行 `logs`，实时查看并滚动刷新容器日志。
* **`e`**：执行 `edit`，使用系统默认的 vim 直接在线编辑资源的 YAML。
* **`s`**：执行 `shell`，免去写 exec 命令，直接进入容器内部的 bash/sh 终端。
* **`ctrl + d`**：执行 `delete`，删除选中的 Pod。
* **`shift + f`**：为当前 Pod 暴露的端口创建本地的 `port-forward`，进行本地开发联调。

---

> [!TIP] 💡 关联技术与延伸阅读
> * [Kubectl 命令行客户端工作原理](../01-组件原理/06-Kubectl.md)
> * [集群健康巡检与脚本自动化](./01-集群健康巡检与脚本自动化.md)

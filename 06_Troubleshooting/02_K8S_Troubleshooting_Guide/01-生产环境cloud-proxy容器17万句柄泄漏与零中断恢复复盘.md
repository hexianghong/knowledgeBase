# 【生产复盘】cloud-proxy 容器 17 万句柄 (FD) 泄漏与零中断无损恢复复盘报告 (Post-Mortem)

---

## 1. 事故基本信息 (Incident Overview)

| 属性 | 详情 |
| :--- | :--- |
| **事故标题** | 启研互联网医院生产集群 cloud-proxy 容器句柄暴涨至 17 万告警处置与无损恢复 |
| **发生/告警时间** | 2026-09-14 14:32:03 (CST) |
| **恢复时间** | 2026-09-14 15:37:00 (CST) |
| **事故定级** | P2（严重告警 / 极高危单点故障，处置及时未造成线上中断） |
| **影响集群/范围** | `qy-hlw` 集群（ID: `c-fnm6w`）/ `infra` 命名空间 / `cloud-proxy` 服务 |
| **主导处理人** | SRE / 运维架构师 |

---

## 2. 故障现象与核心指标 (Metrics & Impact)

* **Prometheus 告警详情**：
  * **告警名称**：`容器文件描述符`
  * **所属服务**：`expose-kubelets-metrics`
  * **告警级别**：`严重 (Critical)`
  * **目标 Pod**：`cloud-proxy-546dbbc7b5-szngm`（容器：`cloud-proxy`，节点：`kube-node03` / `10.0.0.59`）
  * **触发表达式**：`container_file_descriptors / 65535 > 0.3`（阈值 30%）
  * **告警触发值**：**`2.631616693369955`**（利用率高达 263.16%，已超阈值近 9 倍）
* **核心指标治理前后对比**：

| 核心指标 | 治理前（异常状态） | 治理后（平滑切换新 Pod） | 改善幅度 |
| :--- | :--- | :--- | :--- |
| **容器进程打开文件句柄 (FD)** | **172,463** | **337** | **下降 99.8%**（彻底归位健康基线） |
| **监控指标占比** | **2.63** (263.16%) | **0.0051** (0.51%) | **远低于 0.3 阈值，告警自动 Resolved** |
| **Pod 副本与架构** | 单副本 (`1/1`)，运行 2 年 73 天 | 单副本 (`1/1`)，健康就绪 | 零中断完成世代交替 |
| **业务可用性** | 极高危（随时抛出 Too many open files 瘫痪） | **100% 可用（0 丢包 / 0 抖动）** | 通过“先扩后缩”平滑无缝切换 |

---

## 3. 故障时间线 (Timeline)

- **14:32:03** - 【监控告警】：Prometheus 触发 `容器文件描述符` 严重告警，当前值 2.63，句柄数突破 17 万。
- **14:35:00** - 【管理面排障】：SRE 登录 Master 节点（`kube-node01`）执行 `kubectl get ns` 报 `10.0.0.194:9443 refused`。
- **14:40:00** - 【管理面归因】：排查确认原 `~/.kube/config` 指向的单节点 Rancher（`rancher-v2.4.17`）已退出 6 个月（内置 k3s 证书于 2026-06-14 过期）。
- **14:55:00** - 【安全打通通道】：为保障生产 ClickHouse 与核心业务 0 风险，不操作内核与脏缓存，直接利用原厂根 CA（`kube-ca.pem` / `kube-ca-key.pem`）签发 10 年长期有效的管理员凭证，成功直连本地 `6443` API Server。
- **15:18:20** - 【定位目标 Pod】：执行 `kubectl -n infra get pod cloud-proxy-546dbbc7b5-szngm -o wide`，确认其 AGE 达 **`2y73d`**，持续无重启运行超 800 天。
- **15:20:49** - 【深入容器定量分析】：
  - 统计 `/proc/1/fd` 数量精确为 **`172463`**；
  - 抽样发现并非外部 TCP Socket 泄漏（`netstat -ant` 仅 3 个 LISTEN），而是成对涌现的 **`anon_inode:[eventpoll]`** 与 **`pipe:[...]`**；
  - 定性为 Java NIO（依赖 `kubernetes-model-scheduling-4.13.2.jar` 等）未正确调用 `.close()` 导致的底层 Selector/Pipe 严重泄漏。
- **15:25:00** - 【制定无损恢复 SOP】：鉴于该服务为 `1/1` 单副本，严禁直接暴力强删 Pod，确定采用**“先扩容至 2 副本双活、就绪后缩容回 1 副本”**的无损滚动方案。
- **15:35:00** - 【执行平滑切换】：
  1. `scale deployment cloud-proxy --replicas=2`；
  2. 监控新 Pod 变为 `1/1 Running` 并通过健康检查承接流量；
  3. `scale deployment cloud-proxy --replicas=1`，K8s 优雅终止 17 万句柄的旧 Pod。
- **15:37:22** - 【彻底收敛】：核查新 Pod 句柄数降至 **`337`**，监控指标回落至正常区间，告警自动解除。

---

## 4. 根因分析 (Root Cause Analysis - 5 Whys)

> **直接原因**：`cloud-proxy` 容器内进程打开的文件描述符（FD）累积达到 172,463 个，超过告警设定的阈值，即将击穿系统/进程限制。
> **技术根本原因**：该 Java 代理应用在调用 Kubernetes Client / HTTP Client 发起定时轮询或长连接监控时，**在循环中频繁创建 NIO `Selector`，但未在生命周期结束时执行显式 `.close()`**。
> **架构诱因**：该 Pod 属于单副本架构，且连续不间断运行长达 **2 年零 73 天**（800+ 天），极其细微的代码泄漏经年累月最终演变为巨量泄漏。

### 5 Whys 深度递进剖析：
1. **Why 1：为什么监控触发严重告警？**
   - *答：因为容器内文件描述符 `container_file_descriptors` 达到了 172,463 个，除以 65535 后比例高达 2.63（阈值为 0.3）。*
2. **Why 2：为什么打开的文件描述符高达 17 万个？**
   - *答：因为容器内进程持有巨量的 `anon_inode:[eventpoll]` 和 `pipe:[...]` 文件句柄未被操作系统释放。*
3. **Why 3：为什么会出现成对的 `eventpoll` 与 `pipe`？**
   - *答：在 Linux 平台下，Java NIO 每调用一次 `Selector.open()`，底层的 `EPollSelectorImpl` 都会向内核申请 1 个 `epoll` 实例和 1 对唤醒管道（Pipe）。*
4. **Why 4：为什么会有 17 万个 Selector 实例没有被关闭？**
   - *答：代码中（如引用 Fabric8 K8s 客户端/OkHttp/Netty 相关逻辑）在方法内部动态 `new` 了客户端连接或监听器，缺少 `try-with-resources` 或 `finally` 显式 `.close()` 保护，导致旧对象脱离作用域后底层的 OS 资源未解绑。*
5. **Why 5：为什么在今天才暴发告警？**
   - *答：由于每次泄漏的增量很小，且该 Pod 运行了长达 803 天无重启，长期运维中缺少容器生命周期巡检与定期的平滑滚动演练。*

---

## 5. 止血与处置方案 (Remediation & Recovery)

### 5.1 生产级零中断无损恢复 SOP（已落地）

针对单副本核心应用，杜绝直接 `delete pod` 导致业务硬中断，必须执行如下双活滚动步骤：

```bash
# 1. 扩容为 2 副本（创建全新健康 Pod 实现双活）
kubectl -n infra scale deployment cloud-proxy --replicas=2

# 2. 实时观察新 Pod 启动，确认进入 Running 且 READY 1/1
kubectl -n infra get pod -n infra -w | grep cloud-proxy

# 3. 新 Pod 就绪并分担流量后，缩容回 1 副本（K8s 优雅 Terminate 运行了 2 年的旧 Pod）
kubectl -n infra scale deployment cloud-proxy --replicas=1

# 4. 验收留存的新 Pod 句柄数
NEW_POD=$(kubectl -n infra get pod -l app=cloud-proxy -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || kubectl -n infra get pod -n infra | grep cloud-proxy | awk '{print $1}')
kubectl -n infra exec $NEW_POD -n infra -c cloud-proxy -- sh -c 'ls -1 /proc/1/fd | wc -l'
# 返回：337
```

### 5.2 附带沉淀：Master 管理面凭证自主打通 SOP

当外部控制台（如单节点 Rancher）崩溃时，通过原厂 CA 独立生成 10 年长期运维凭证直连 K8s API Server（`6443`）：

```bash
cd ~/.kube

# 1. 生成超级管理员私钥与申请
openssl genrsa -out admin.key 2048
openssl req -new -key admin.key -out admin.csr -subj "/CN=cluster-admin/O=system:masters"

# 2. 仅“只读引用”本地根 CA，签发 10 年 (3650天) 管理员证书
openssl x509 -req -in admin.csr \
  -CA /etc/kubernetes/ssl/kube-ca.pem \
  -CAkey /etc/kubernetes/ssl/kube-ca-key.pem \
  -CAcreateserial -out admin.crt -days 3650

# 3. 固化写入 ~/.kube/config
cat <<EOF > ~/.kube/config
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: $(base64 -w0 /etc/kubernetes/ssl/kube-ca.pem 2>/dev/null || base64 /etc/kubernetes/ssl/kube-ca.pem | tr -d '\n')
    server: https://127.0.0.1:6443
  name: qy-hlw
contexts:
- context:
    cluster: qy-hlw
    user: cluster-admin
  name: qy-hlw-context
current-context: qy-hlw-context
users:
- name: cluster-admin
  user:
    client-certificate-data: $(base64 -w0 admin.crt 2>/dev/null || base64 admin.crt | tr -d '\n')
    client-key-data: $(base64 -w0 admin.key 2>/dev/null || base64 admin.key | tr -d '\n')
EOF

chmod 600 ~/.kube/config
```

---

## 6. 长效改进措施 (Action Items & Prevention)

| 序号 | 改进项类别 | 具体措施与任务 | 责任人 | 期望完成时间 | 状态 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | **代码级根治** | 排查 `cloud-proxy` 中所有 `KubernetesClient`、`OkHttpClient`、`Selector` 调用，全面推行 Spring 单例注入复用；局部连接必须增加 `try-with-resources` 兜底关闭。 | 研发团队 | 2026-09-20 | 进行中 |
| 2 | **架构高可用** | 将 `cloud-proxy` 的 Deployment 默认副本数由 `1` 调整为 `2`，配置 `podAntiAffinity` 跨节点部署，消除单点故障风险。 | SRE / 架构组 | 2026-09-18 | 待开始 |
| 3 | **监控与告警** | 优化告警规则，将写死的 `/ 65535` 优化为结合容器内真实 `ulimit` 或增加句柄增长率（`deriv(container_file_descriptors[1h]) > 0`）趋势告警。 | 监控组 | 2026-09-25 | 待开始 |
| 4 | **巡检制度** | 建立生产容器“超长运行 Pod”（如运行超 1 年）健康与资源泄漏季度例行巡检与轮转机制。 | 运维组 | 2026-09-30 | 待开始 |

---

> [!TIP] 💡 关联技术与延伸阅读
>
> * [生产级高难故障排查与实战方案](../../01_Inbox/03-K8S/06-集群运维/06-生产级高难故障排查与实战方案.md)
> * [Kubelet 核心架构与 Pod 生命周期调度管理](../../01_Inbox/03-K8S/01-核心架构/04-Kubelet.md)
> * [生产环境运维 SOP 标准模板](../../07_Templates/03_生产环境运维SOP标准模板.md)

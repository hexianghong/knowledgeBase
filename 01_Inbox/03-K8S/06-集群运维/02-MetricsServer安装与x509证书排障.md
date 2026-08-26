# 📊 Metrics Server 安装与 x509 证书校验证障指南

在 Kubernetes 中，执行 `kubectl top nodes` 或 `kubectl top pods` 时，常常会遇到如下报错：
```bash
Error from server (ServiceUnavailable): the server is currently unable to handle the request (get pods.metrics.k8s.io)
# 或者：
error: Metrics API not available
```
这是因为集群中缺少了核心指标收集组件——**Metrics Server**，或者 Metrics Server 无法正常抓取节点监控数据。本文详述其安装流程以及生产中极易遇到的 **x509 证书验证失效**故障原因和修复方案。

---

## 一、 Kubernetes 指标采集架构体系

Kubernetes 的指标监控分为三个核心管道：

```text
                  ┌─────────────────────────────┐
                  │      API Server / Client    │ (kubectl top, HPA 控制器)
                  └──────────────┬──────────────┘
                                 │ 聚合 API (APIService)
                                 ▼
                  ┌─────────────────────────────┐
                  │       Metrics Server        │ (核心指标管道 - 极轻量, 存内存)
                  └──────────────┬──────────────┘
                                 │ 10250 端口 HTTPS 轮询
                                 ▼
         ┌───────────────────────┴───────────────────────┐
         ▼                                               ▼
┌─────────────────┐                             ┌─────────────────┐
│     Node-01     │                             │     Node-02     │
│ (Kubelet/cAdvisor)                            │ (Kubelet/cAdvisor)
└─────────────────┘                             └─────────────────┘
```

1. **核心指标管道 (Core Metrics Pipeline)**：
   * **组件**：`Metrics Server`。
   * **作用**：周期性（默认 15s）通过 Kubelet 的 10250 端口拉取 CPU、内存等基础指标，并将其缓存在内存中。
   * **用途**：专供 `kubectl top` 命令行查询以及 `HPA` (Horizontal Pod Autoscaler) 水平自动伸缩控制器进行资源扩缩容。
2. **监控时序管道 (Monitoring Pipeline / Full Metrics)**：
   * **组件**：`Prometheus Operator` / `kube-state-metrics`。
   * **作用**：拉取全量历史时序数据，提供多维度的应用和集群运行状态指标。
3. **自定义指标管道 (Custom/External Metrics)**：
   * **组件**：`Prometheus Adapter`。
   * **作用**：将自定义指标（如 QPS、HTTP 请求延迟）转换成 K8S API，供给 HPA 进行业务度量伸缩。

---

## 二、 默认安装与 x509 证书痛点剖析

### 1. 下载官方部署文件
Metrics Server 的部署极其简单，通常只需要应用一个官方的 `components.yaml`：
```shell
# 下载最新版部署清单
wget https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### 2. 核心故障：x509 证书校验证障
如果在默认情况下直接 `kubectl apply -f components.yaml`，Metrics Server 的 Pod 往往无法就绪。查看其运行日志（`kubectl logs -n kube-system deploy/metrics-server`），会显示大量的下述报错：
```text
x509: cannot validate certificate for 10.168.56.101 because it doesn't contain any IP SANs
# 或者：
x509: certificate signed by unknown authority (possibly because of "crypto/rsa: verification error" while trying to verify candidate authority certificate "kubernetes")
```

#### 💥 故障深层原因分析：
* **Kubelet 证书机制**：默认情况下，Kubeadm 安装的节点中，Kubelet 服务生成的服务器端证书是**自签名的**（Self-Signed Certificate），并且证书中**没有写入节点的 IP 地址作为 Subject Alternative Name (SAN)**。
* **Metrics Server 安全要求**：Metrics Server 默认以强安全模式运行，它会通过 HTTPS 请求每个节点的 `10250` 端口以抓取 cAdvisor 的数据。在建立 TLS 握手时，Metrics Server 会严格校验节点证书的合法性。由于节点的证书是自签名的，且没有匹配的 IP SAN，证书验证必然失败，导致无法收集到任何指标。

---

## 三、 解决方案：修改 Deployment 配置

要解决该问题，我们需要在 Metrics Server 的 Deployment 模板中增加两个核心的启动参数：

```yaml
# 查找或编辑 components.yaml
# 路径定位：spec.template.spec.containers[0].args
```

### 1. 核心修复参数
```yaml
      - args:
        - --cert-dir=/tmp
        - --secure-port=4443
        - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname # 优先使用内网 IP 访问 Kubelet
        - --kubelet-use-node-status-port
        - --metric-resolution=15s
        # 💥 关键修复配置 1: 忽略 Kubelet 自签名证书校验
        - --kubelet-insecure-tls
```

### 2. 参数作用详解
* **`--kubelet-insecure-tls`**：指示 Metrics Server **不校验** Kubelet 提供的 TLS 证书的 CA 根证书及 IP SAN。这在测试或没有配置由集群统一 CA 签发 Kubelet 证书的生产环境中是必须设置的。
* **`--kubelet-preferred-address-types=InternalIP`**：默认情况下，Metrics Server 会尝试通过主机的 `Hostname` 访问 Kubelet。如果集群中没有配置 CoreDNS 的外部主机名解析，将会因解析失败而超时。强制指定 `InternalIP` 可以让 Metrics Server 直接通过各节点的内网 IP（如 `10.168.56.101`）发起连接，完美避开 DNS 解析失败的问题。

### 3. 国内镜像源替换
如果官方的谷歌镜像 `registry.k8s.io/metrics-server/metrics-server` 国内无法正常拉取，可将其替换为阿里云镜像源：
```yaml
        # 替换镜像地址
        image: registry.cn-hangzhou.aliyuncs.com/google_containers/metrics-server:v0.6.4
```

---

## 四、 部署与实战验证

### 1. 应用修改后的资源清单
```shell
kubectl apply -f components.yaml
```

### 2. 检查 Metrics Server 服务状态
```shell
# 1. 检查 API 注册服务是否已经正常 Ready
kubectl get apiservice | grep metrics
v1beta1.metrics.k8s.io                 kube-system/metrics-server   True        4m

# 2. 检查 Pod 运行状态
kubectl -n kube-system get pods -l k8s-app=metrics-server
NAME                              READY   STATUS    RESTARTS   AGE
metrics-server-58746f7f68-7c8vw   1/1     Running   0          4m
```

### 3. 指标查询校验
等待大约 15~30 秒（Metrics Server 完成第一轮指标拉取和缓存），在终端执行以下命令：
```shell
# 1. 检查节点 CPU 和内存占用
[root@kube-master ~]# kubectl top nodes
NAME          CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
kube-master   593m         7%     9651Mi          60%
kube-node-01  229m         2%     3999Mi          25%
kube-node-02  281m         3%     4617Mi          29%

# 2. 检查特定命名空间内 Pod 的资源占用
[root@kube-master ~]# kubectl top pods -n kube-system
NAME                               CPU(cores)   MEMORY(bytes)
coredns-7c5b6b6545-l2vw2           4m           16Mi
kube-apiserver-kube-master         38m          280Mi
kube-proxy-8x9vw                   2m           22Mi
```

---

> [!TIP] 💡 关联技术与延伸阅读
>
> * [Metrics Server 双监控管线与 API 聚合层原理](../01-组件原理/09-Metrics_Server与API聚合层原理.md)
> * [HPA 弹性扩缩容配置](../02-集群负载/07-HPA与VPA弹性扩缩容底层算法与指标管道.md)

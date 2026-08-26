# 📋 生产级 Deployment YAML 资源清单详解与蓝图

在生产中，一个合格的 Deployment 资源清单必须考虑到安全、存储挂载、资源限额、健康检查与调度。以下是一个涵盖了多重生产配置的完整 `Deployment` 蓝图，并带有详细的逐行中文注解。

---

## 一、 生产级 Deployment 资源清单蓝图

```yaml
apiVersion: apps/v1                       # 1. 声明 API 组和版本，Deployment 固定使用 apps/v1
kind: Deployment                          # 2. 声明资源类别为 Deployment
metadata:                                 # 3. 元数据配置
  name: production-app-deployment         #    Deployment 控制器名称
  namespace: production                   #    部署的目标命名空间
  labels:                                 #    当前 Deployment 自身的标签
    app: production-app
    tier: backend
spec:                                     # 4. 期望的部署规格定义
  replicas: 3                             #    期望启动的 Pod 副本数
  revisionHistoryLimit: 10                #    保留的历史版本数（默认为10）
  minReadySeconds: 15                     #    Pod 启动后需稳定运行 15 秒才被视为就绪，以防止应用闪退
  progressDeadlineSeconds: 600            #    滚动更新的最大超时时间（10分钟）
  
  strategy:                               # 5. 更新发布策略
    type: RollingUpdate                   #    指定为滚动更新策略
    rollingUpdate:
      maxSurge: 25%                       #    升级过程中最多允许比原副本数多出 25% 的 Pod（3 * 25% 向上取整为 1 个）
      maxUnavailable: 0                   #    升级过程中不允许出现不可用的 Pod（保证服务零降级）
      
  selector:                               # 6. 标签选择器：指定 Deployment 关联并操纵哪些 Pod
    matchLabels:
      app: production-app                 #    必须与 template.metadata.labels 中的标签精确匹配
      
  template:                               # 7. Pod 模板定义：当副本数不足时，控制器使用该模板创建 Pod
    metadata:
      labels:                             #    为拉起的 Pod 贴上的标签（与上方 selector 匹配）
        app: production-app
        tier: backend
    spec:                                 #    Pod 的物理参数规格
      # 优雅退出时间，给予容器内进程充足的时间处理完存量请求（默认30秒，调大到60秒）
      terminationGracePeriodSeconds: 60
      
      # 节点调度配置：只允许运行在打上了 zone=cn-hangzhou-a 标签的工作节点上
      nodeSelector:
        zone: cn-hangzhou-a
        
      # 安全上下文配置：限制容器运行时的安全权限
      securityContext:
        runAsUser: 1000                   # 容器内进程以 UID 1000 非 root 用户身份运行
        runAsNonRoot: true                # 强行禁止以 root 身份运行容器
        fsGroup: 2000                     # 容器内挂载卷的文件系统属组设为 GID 2000
        
      containers:                         # 8. 容器配置列表
      - name: web-nginx                   #    容器名称
        image: nginx:1.25.1               #    镜像地址
        imagePullPolicy: IfNotPresent     #    镜像下载策略：如果本地存在则优先使用本地镜像
        
        ports:                            #    容器暴露的端口配置
        - containerPort: 80               #    容器监听的业务端口
          name: http-web-port             #    端口别名，方便 Service 引用
          
        resources:                        # 9. 资源限制与申请（QoS 配置，此配置为 Guaranteed）
          requests:
            memory: "256Mi"               #    内存申请量
            cpu: "200m"                   #    CPU 申请量（0.2 核）
          limits:
            memory: "256Mi"               #    内存最大硬限制（等于 Requests）
            cpu: "200m"                   #    CPU 最大限制
            
        securityContext:                  #    单个容器的安全限制
          allowPrivilegeEscalation: false #    禁止容器内进程进行特权提升（如 sudo）
          capabilities:
            drop: ["ALL"]                 #    抛弃 Linux 内核中所有不必要的 Cap 特权
            
        # 健康检查探针 (Startup + Liveness + Readiness 组合)
        startupProbe:
          httpGet:
            path: /healthz
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
          failureThreshold: 20
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
          periodSeconds: 5
          successThreshold: 1
          failureThreshold: 3
        livenessProbe:
          httpGet:
            path: /healthz
            port: 80
          periodSeconds: 10
          failureThreshold: 3
          
        volumeMounts:                      # 10. 存储卷挂载（将 pod 级别的 Volume 挂进容器）
        - name: web-static-volume         #     引用 spec.volumes 中定义的卷名称
          mountPath: /usr/share/nginx/html#     挂载到容器内的绝对路径
          readOnly: false                 #     可读写
        - name: app-config-volume
          mountPath: /etc/nginx/conf.d    #     挂载配置文件夹
          readOnly: true                  #     配置文件一般只读
          
      volumes:                            # 11. 声明当前 Pod 级别的共享卷列表
      - name: web-static-volume           #     自定义的卷名称
        persistentVolumeClaim:            #     持久化卷声明 (PVC) 类型
          claimName: nfs-static-pvc       #     指定绑定集群中名为 nfs-static-pvc 的 PVC 对象
      - name: app-config-volume
        configMap:                        #     ConfigMap 类型挂载
          name: nginx-config-map          #     绑定集群中名为 nginx-config-map 的 ConfigMap 资源
          items:
          - key: default-nginx.conf       #     ConfigMap 中的键
            path: default.conf            #     挂载到目录下的子文件名
```

---

## 二、 关键配置项深度解析

1.  **`selector` 匹配限制**：
    *   在 `apps/v1` 版本后，Deployment 的 `spec.selector` 是**不可变字段**。一旦创建了 Deployment，无法再通过修改 selector 来更改绑定的 Pod 标签。
2.  **`imagePullPolicy` 策略**：
    *   `Always`：不论本地是否存在镜像，每次启动 Pod 都强行去远程仓库拉取（建议生产环境配合 `latest` 标签或具体版本标签使用，防止镜像更新后节点依然使用旧镜像缓存）。
    *   `IfNotPresent`：本地有就用本地的，本地没有才去拉取。能极大减少拉镜像的带宽消耗。
    *   `Never`：仅使用本地镜像，如果本地没有则报错。
3.  **`Guaranteed` QoS 的价值**：
    *   在上述蓝图中，由于 `requests.cpu = limits.cpu` 且 `requests.memory = limits.memory`，该 Pod 会被自动划分为 **`Guaranteed`** 服务质量级别。这是最稳定的级别，享有最高的反驱逐特权。

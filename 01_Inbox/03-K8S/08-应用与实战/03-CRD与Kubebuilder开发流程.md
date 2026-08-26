# 🛠️ CRD 与 Kubebuilder 开发流程指南

在 Kubernetes 扩展开发中，**自定义资源定义 (CRD)** 配合**自定义控制器 (Controller)**，构成了强大的声明式扩展体系——**Operator 模式**。利用 CNCF 官方的脚手架工具 **Kubebuilder**，开发者能够基于 Go 语言快速构建企业级的 Operator 应用。

---

## 一、 Kubebuilder 环境准备

`kubebuilder` 工具底层依赖 `controller-runtime` (提供统一协调环底座) 和 `controller-tools` (代码与 YAML 清单自动生成工具)。

```bash
# 1. 自动根据系统架构下载最新版 Kubebuilder 命令行工具
curl -L -o kubebuilder "https://go.kubebuilder.io/dl/latest/\$(go env GOOS)/\$(go env GOARCH)"
chmod +x kubebuilder && mv kubebuilder /usr/local/bin/

# 2. 校验版本
kubebuilder version
```

---

## 二、 Operator 业务初始化与结构定义

本实战将开发一个名为 `NodePool` 的 Operator，其功能为：当在集群中创建 `NodePool` 自定义资源时，控制器能够根据声明的副本数和镜像，自动创建并管理对应的 `Deployment` 以及暴露端口的 `NodePort Service`。

### 1. 初始化项目骨架
```bash
mkdir -p kube-operator && cd kube-operator

# 1. 初始化 Go Modules 和脚手架目录
kubebuilder init --domain wowjoy.domain --repo gitlab.com/devops/kubebuild

# 2. 创建 API (定义 Group/Version/Kind 并生成 Controller 模板)
kubebuilder create api --group nodes --version v1 --kind NodePool
# 会提示是否创建 Resource [y/n] 和 Controller [y/n]，全部选择 y。
```

### 2. 定义自定义资源结构体 (api/v1/nodepool_types.go)
修改自动生成的 Spec 和 Status 结构体，声明业务期望值：
```go
// api/v1/nodepool_types.go
package v1

import (
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	appsv1 "k8s.io/api/apps/v1"
)

// NodePoolSpec 定义用户期望的集群状态 (Desired State)
type NodePoolSpec struct {
	// Size 声明 Pod 的副本数
	Size  *int32               `json:"size"`
	// Image 声明容器镜像地址
	Image string               `json:"image"`
	// Envs 容器运行时的环境变量
	Envs  []corev1.EnvVar      `json:"envs,omitempty"`
	// Ports 定义暴露的服务端口列表
	Ports []corev1.ServicePort `json:"ports,omitempty"`
}

// NodePoolStatus 定义当前集群的真实状态 (Observed State)
type NodePoolStatus struct {
	// 继承 Deployment 的状态
	appsv1.DeploymentStatus `json:",inline"`
	// Count 记录当前控制器调谐的更新次数统计
	Count                   int32 `json:"count"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status

// NodePool 代表 CRD 的模式架构
type NodePool struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   NodePoolSpec   `json:"spec,omitempty"`
	Status NodePoolStatus `json:"status,omitempty"`
}
```

---

## 三、 控制器调谐环 (Reconcile Loop) 实现

### 1. 深度解析：Reconcile 的核心心跳机制
Controller的核心逻辑是一个不断循环的“调谐环（Reconciliation Loop）”。当任何受监听的资源发生增删改事件时，Controller 都会被唤醒，执行一次 `Reconcile` 函数：

```text
               ┌─────────────────────────────────────┐
               ▼                                     │
    ┌──────────────────────┐                         │
 ──>│ 资源变更事件 (Event) │                         │
    └──────────┬───────────┘                         │
               ▼                                     │
    ┌──────────────────────┐                         │
    │  获取当前真实状态     │ (r.Get 读取集群状态)      │ 观察与对比
    └──────────┬───────────┘                         │
               ▼                                     │
    ┌──────────────────────┐                         │
    │  计算并与期望状态对齐 │ (与 instance.Spec 对比)  │
    └──────────┬───────────┘                         │
               ▼                                     │
    ┌──────────────────────┐                         │
    │  执行变更调谐对齐     │ (r.Create / r.Update)   │
    └──────────┬───────────┘                         │
               ▼                                     │
    ┌──────────────────────┐                         │
    │   返回 Reconcile 结果 │ ────────────────────────┘
    └──────────────────────┘ (ctrl.Result{RequeueAfter})
```

* **`Requeue` 判定**：
  * 返回 `ctrl.Result{}, nil`：表示调谐成功，状态完全对齐，本轮调谐结束，直到下一个事件触发。
  * 返回 `ctrl.Result{Requeue: true}, nil` 或发生 error：表示状态未完全对齐或失败，控制器会立即或退避一段时间后重新将任务入队列，循环执行。

### 2. 级联删除与 OwnerReference 绑定
在创建下属子资源（如创建 Deployment 或 Service）时，**必须调用 `controllerutil.SetControllerReference` 绑定 OwnerReference**。
* **作用**：将子资源的所有权归属于当前的自定义资源（NodePool）。一旦用户使用 `kubectl delete nodepool sample` 删除自定义资源，Kubernetes 会通过垃圾回收器（Garbage Collector）自动**级联删除（Cascade Delete）**该资源下所有的 Deployment 和 Service，防止产生孤儿资源。

---

### 3. 控制器源码实现 (internal/controller/nodepool_controller.go)
```go
package controller

import (
	"context"
	"encoding/json"
	"reflect"

	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/schema"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/log"
	"sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"

	nodesv1 "gitlab.com/devops/kubebuild/api/v1"
)

type NodePoolReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

// 💥 配置 RBAC 权限生成注解 (用于生成 rules.yaml)
// +kubebuilder:rbac:groups=nodes.wowjoy.domain,resources=nodepools,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=nodes.wowjoy.domain,resources=nodepools/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=apps,resources=deployments,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups="",resources=services,verbs=get;list;watch;create;update;patch;delete

func (r *NodePoolReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	llog := log.FromContext(ctx)

	// 1. 获取当前自定义资源实例
	instance := &nodesv1.NodePool{}
	err := r.Get(ctx, req.NamespacedName, instance)
	if err != nil {
		if errors.IsNotFound(err) {
			return ctrl.Result{}, nil // 资源被删除了，直接返回
		}
		return ctrl.Result{}, err
	}

	// 2. 检查下属的 Deployment 状态
	deployment := &appsv1.Deployment{}
	err = r.Get(ctx, req.NamespacedName, deployment)
	if err != nil {
		if errors.IsNotFound(err) {
			llog.Info("Deployment 不存在，开始创建")
			deployment = r.constructDeployment(instance)
			
			// 💥 关键：绑定 OwnerReference
			if err := controllerutil.SetControllerReference(instance, deployment, r.Scheme); err != nil {
				return ctrl.Result{}, err
			}
			
			if err := r.Create(ctx, deployment); err != nil {
				llog.Error(err, "创建 Deployment 失败")
				return ctrl.Result{}, err
			}
		} else {
			return ctrl.Result{}, err
		}
	}

	// 3. 检查下属的 Service 状态
	service := &corev1.Service{}
	err = r.Get(ctx, req.NamespacedName, service)
	if err != nil {
		if errors.IsNotFound(err) {
			llog.Info("Service 不存在，开始创建")
			service = r.constructService(instance)
			
			// 💥 关键：绑定 OwnerReference
			if err := controllerutil.SetControllerReference(instance, service, r.Scheme); err != nil {
				return ctrl.Result{}, err
			}
			
			if err := r.Create(ctx, service); err != nil {
				llog.Error(err, "创建 Service 失败")
				return ctrl.Result{}, err
			}
		} else {
			return ctrl.Result{}, err
		}
	}

	// 4. 对比期望状态与实际状态，实现调谐同步
	if !reflect.DeepEqual(deployment.Spec.Replicas, instance.Spec.Size) || deployment.Spec.Template.Spec.Containers[0].Image != instance.Spec.Image {
		llog.Info("检测到状态不一致，开始同步下属子资源")
		deployment.Spec.Replicas = instance.Spec.Size
		deployment.Spec.Template.Spec.Containers[0].Image = instance.Spec.Image
		
		if err := r.Update(ctx, deployment); err != nil {
			return ctrl.Result{}, err
		}
		
		// 更新 CRD Status 中的计数器
		instance.Status.Count++
		if err := r.Status().Update(ctx, instance); err != nil {
			return ctrl.Result{}, err
		}
	}

	return ctrl.Result{}, nil
}

// 构造 Deployment
func (r *NodePoolReconciler) constructDeployment(instance *nodesv1.NodePool) *appsv1.Deployment {
	labels := map[string]string{"app": instance.Name}
	return &appsv1.Deployment{
		ObjectMeta: metav1.ObjectMeta{
			Name:      instance.Name,
			Namespace: instance.Namespace,
			Labels:    labels,
		},
		Spec: appsv1.DeploymentSpec{
			Replicas: instance.Spec.Size,
			Selector: &metav1.LabelSelector{MatchLabels: labels},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{Labels: labels},
				Spec: corev1.PodSpec{
					Containers: []corev1.Container{
						{
							Name:            instance.Name,
							Image:           instance.Spec.Image,
							ImagePullPolicy: corev1.PullIfNotPresent,
							Env:             instance.Spec.Envs,
						},
					},
				},
			},
		},
	}
}

// 构造 Service
func (r *NodePoolReconciler) constructService(instance *nodesv1.NodePool) *corev1.Service {
	return &corev1.Service{
		ObjectMeta: metav1.ObjectMeta{
			Name:      instance.Name,
			Namespace: instance.Namespace,
		},
		Spec: corev1.ServiceSpec{
			Type:     corev1.ServiceTypeNodePort,
			Selector: map[string]string{"app": instance.Name},
			Ports:    instance.Spec.Ports,
		},
	}
}

func (r *NodePoolReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&nodesv1.NodePool{}).
		Owns(&appsv1.Deployment{}). // 声明监听下属的 Deployment 资源变化
		Owns(&corev1.Service{}).    // 声明监听下属的 Service 资源变化
		Complete(r)
}
```

---

## 四、 生成清单与本地运行测试

```bash
# 1. 根据 Go 代码中的 Annotation 注解自动生成 CRD 的 YAML 清单
make manifests

# 2. 将生成的 CRD 安装到当前 Kubeconfig 指向的 K8S 集群中
make install

# 3. 在本地宿主机直接启动运行 Controller 进程进行调试
make run
```

### 应用测试资源自定义 CR (nodepool-sample.yaml)
在另一个终端中，应用我们自定义的资源声明：
```yaml
apiVersion: nodes.wowjoy.domain/v1
kind: NodePool
metadata:
  name: nodepool-sample
spec:
  size: 2
  image: registry.cn-hangzhou.aliyuncs.com/google_containers/nginx:1.24.0
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30002
```
```bash
# 应用 CR 资源
kubectl apply -f nodepool-sample.yaml

# 验证下属 Deployment 和 Service 是否自动拉起
kubectl get nodepool
kubectl get deployments
kubectl get svc nodepool-sample
```

---

> [!TIP] 💡 关联技术与延伸阅读
>
> * [Operator 开发与 Controller-Runtime 深度原理](../07-集群扩展/07-Operator开发与Controller-Runtime原理.md)
> * [Admission Webhook 扩展校验](../03-安全与资源/03-OPA_Kyverno策略引擎与AdmissionWebhook开发实战.md)

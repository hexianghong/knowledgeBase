# ⎈ Helm 包制作与高级模板语法指南

在 Kubernetes 生态中，**Helm** 充当着事实上的“应用包管理器”（类似于 CentOS 中的 `yum` 或 Ubuntu 中的 `apt`）。它通过将 K8S 散落的 YAML 清单打包为声明式的 **Chart**，并引入强大的 Go template 模板渲染引擎，极大地简化了复杂分布式应用的定义、版本控制与一键部署。

---

## 一、 Helm Chart 物理大纲与核心结构

使用命令行 `helm create <chart-name>` 会自动生成一个标准的 Chart 脚手架模板。

### 1. 目录结构树
```text
test-chart/                             - Chart 包目录名
├── charts/                             - 存放当前 Chart 依赖的子包 (Subcharts)
├── Chart.yaml                          - 声明 Chart 的元数据 (版本号、应用版本、描述等)
├── values.yaml                         - 参数配置文件，定义全局默认渲染变量
└── templates/                          - 存放 Kubernetes YAML 模板文件的目录
    ├── _helpers.tpl                    - 公共库定义文件，主要编写通用子模板和自定义函数
    ├── deployment.yaml                 - 部署资源模板
    ├── service.yaml                    - 服务资源模板
    ├── ingress.yaml                    - 路由资源模板
    └── NOTES.txt                       - 部署成功后的控制台提示信息说明文件
```

### 2. 核心模板语法与变量定义 (以 Deployment YAML 为例)
在 `templates/` 下的 YAML 中，使用双大括号 `{{ ... }}` 引入动态变量。

```yaml
# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-deploy       # 动态引用应用发布实例名，防止集群命名冲突
  labels:
    app: {{ .Release.Name }}
spec:
  replicas: {{ .Values.replicaCount }}  # 动态引用 values.yaml 中定义的值
  selector:
    matchLabels:
      app: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}
    spec:
      containers:
        - name: {{ .Chart.Name }}       # 引用 Chart.yaml 中声明的包名
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: {{ .Values.service.port }}
```

---

## 二、 模板语法深度解析 (Go Template)

### 1. 作用域与全局点号 ( . )
在模板引擎中，点号 `.` 始终代表**当前生效的作用域（Scope）**。在最外层，点号代表全局作用域。通过点号，可以调用 Helm 注入的内置对象：
* **`.Values`**：访问 `values.yaml` 中的自定义配置变量。
* **`.Release`**：访问发布实例的信息：
  * `.Release.Name`：应用发布的实例名。
  * `.Release.Namespace`：应用部署的 K8S 命名空间。
  * `.Release.Revision`：发布版本号（每次更新/回滚都会自增）。
* **`.Chart`**：获取 `Chart.yaml` 中定义的对象属性（如 `.Chart.Version`、`.Chart.Name`）。

---

### 2. 自定义临时变量
您可以在局部作用域中声明临时变量（名称以 `$` 开头，使用 `:=` 赋值）：
```yaml
{{- $releaseName := .Release.Name -}}
metadata:
  name: {{ $releaseName }}-configmap
```

---

### 3. 函数与管道操作符 (Pipelines)
类似于 Linux shell 的 `|` 操作符，Helm 允许使用管道将前一个指令的输出作为下一个函数的输入参数。

```yaml
# 1. 默认值注入 (当 values.yaml 中没有配置该值时启用默认)
imagePullPolicy: {{ .Values.image.pullPolicy | default "IfNotPresent" }}

# 2. 文本加引号保护
envValue: {{ .Values.env.secretKey | quote }}

# 3. 强制转换大写
appEnv: {{ .Values.env.type | upper | quote }}

# 4. 💫 缩进控制 (indent 与 nindent)
# 生产模板编写中，缩进极其严格，否则 YAML 解析会直接报错。
# nindent 会在前面自动插入一个换行符，并缩进 4 个空格，使格式对齐十分优雅。
spec:
  containers:
{{ toYaml .Values.resources | nindent 4 }}
```

---

### 4. 关系与逻辑运算符
Helm 提供了一组逻辑计算函数（注意均放在变量前面调用）：
* `eq` (等于), `ne` (不等于), `lt` (小于), `gt` (大于), `and` (并且), `or` (或者), `not` (取反)。
```yaml
# 逻辑判定示例
{{- if and .Values.ingress.enabled (eq .Values.env "production") -}}
# 只有在 Ingress 启用且环境为 production 时，才渲染该 YAML 块
{{- end }}
```

---

### 5. 流程控制：If 条件判断
```yaml
{{- if .Values.service.type }}
type: {{ .Values.service.type }}
{{- else }}
type: ClusterIP
{{- end }}
```

---

### 6. 流程控制：With 更改局部作用域
`with` 能够临时将当前的作用域 `.` 锚定到指定的对象下，免去写长路径的繁琐：
```yaml
# values.yaml
image:
  repository: nginx
  tag: 1.25
  pullPolicy: IfNotPresent

# deployment.yaml 模板中：
{{- with .Values.image }}
image: "{{ .repository }}:{{ .tag }}" # 此时的点号直接指向了 .Values.image
pullPolicy: {{ .pullPolicy }}
{{- end }}
```

---

### 7. 流程控制：Range 遍历循环
```yaml
# values.yaml 声明环境变量数组：
envList:
  - name: DB_HOST
    value: "10.0.0.1"
  - name: DB_PORT
    value: "3306"

# templates/ 中使用 range 遍历：
env:
{{- range .Values.envList }}
  - name: {{ .name }}
    value: {{ .value | quote }}
{{- end }}
```

---

## 三、 公共模板 `_helpers.tpl` 的高级复用

以下划线开头的 `_helpers.tpl` 文件是全局的公共宏定义库，不会被直接提交给 API Server，但可以在其他模板中被调用。

```yaml
# 1. 在 _helpers.tpl 中使用 define 声明一个公共标签块
{{- define "test-chart.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
release: {{ .Release.Name }}
{{- end -}}
```

```yaml
# 2. 在 deployment.yaml 中引用该宏定义
# 💥 注意：推荐使用 include 而不是 template，因为 include 支持管道操作（如缩进对齐）
metadata:
  labels:
    {{- include "test-chart.labels" . | nindent 4 }} # 注意必须在末尾传入点号 "." 以传递全局上下文，否则宏内部无法获取 .Chart 等变量
```

---

## 四、 Chart 仓库管理与打包分发

制作好 Chart 后，需对其进行校验、打包并推送到自建或第三方的 Helm Repo 仓库中。

```shell
# 1. 语法正确性与规范检测
helm lint ./test-chart

# 2. 本地模拟渲染 (Dry-run)，输出最终生成的真实 YAML，不提交到 K8S
helm install my-test ./test-chart --dry-run --debug

# 3. 将本地 Chart 目录打包成一个压缩包 (tgz)
helm package ./test-chart
# 输出: test-chart-0.1.0.tgz

# 4. 生成或更新仓库的索引文件 index.yaml
# 如果自建 Helm 仓库服务器 (例如使用 Nginx 或 Object Storage 存放 tgz)
mkdir -p my-repo-dir
mv test-chart-0.1.0.tgz my-repo-dir/
helm repo index my-repo-dir/ --url https://my-helm-repo.company.com/charts
# 此时 my-repo-dir/ 下会自动生成 index.yaml，记录了包名、版本及对应的 tgz 下载地址。
```

---

## 五、 Helm 常用运维指令速查

```shell
# 1. 增加第三方 Chart 仓库
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# 2. 搜索仓库中的 Chart 包
helm search repo redis

# 3. 安装应用 Chart，并自定义传参覆盖 Values.yaml
helm install my-redis bitnami/redis --set auth.password="AdminPass123" -n database

# 4. 查看当前命名空间中已发布的应用版本列表
helm list -n database

# 5. 升级现有应用版本
helm upgrade my-redis bitnami/redis -f new-values.yaml -n database

# 6. 回滚应用到指定的历史版本 revision
helm rollback my-redis 2 -n database

# 7. 彻底卸载删除发布实例
helm uninstall my-redis -n database
```

---

> [!TIP] 💡 关联技术与延伸阅读
>
> * [云原生应用交付方式对比：Helm vs Operator](./07-Operator开发与Controller-Runtime原理.md)

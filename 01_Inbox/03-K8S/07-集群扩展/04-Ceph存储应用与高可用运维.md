# 🗄️ Ceph 存储应用与高可用运维指南

在部署好 Ceph 基础集群后，本篇聚焦于如何在生产环境对 **RBD 块存储**、**CephFS 共享文件系统** 和 **RGW 对象网关** 进行权限控制、磁盘扩容、高可用架构设计以及故障运维。

---

## 一、 RBD 块存储核心特性与生命周期管理

### 1. 创建与初始化 RBD 存储池
```bash
# 1. 创建专门用于块设备的存储池
ceph osd pool create rbd-data 32 32

# 2. 启用存储池的 RBD 应用协议
ceph osd pool application enable rbd-data rbd

# 3. 初始化存储池的 RBD 架构
rbd pool init -p rbd-data
```

### 2. RBD 映像（Image）创建与特性控制
在 RBD 存储池中，我们按需创建映像文件提供给客户端挂载。

```bash
# 💥 创建 3GB 大小的 rbd 映像，限定特性为 layering
rbd create data-img1 --size 3G --pool rbd-data --image-format 2 --image-feature layering
```

> [!IMPORTANT]
> **RBD 映像的关键 Feature 详解**：
> * **`layering` (分层特性 - 生产首选)**：支持写时复制（COW）快照克隆。*在低版本 Linux 内核上挂载时，通常只允许开启 layering。*
> * **`exclusive-lock` (独占锁)**：确保同一个 RBD 映像在同一时间只能被一个客户端挂载，防止并发写入导致文件系统损坏。
> * **`object-map` (对象映射)**：加速 I/O 以及已使用容量的计算（依赖于 exclusive-lock）。
> * **启用/禁用 Feature**：
>   ```bash
>   rbd feature enable exclusive-lock --pool rbd-data --image data-img1
>   rbd feature disable exclusive-lock --pool rbd-data --image data-img1
>   ```

### 3. 客户端 RBD 用户授权与挂载
在 ceph-deploy 控制端创建客户端独立访问凭证：
```bash
# 1. 创建名为 rbduser 的普通用户，只授予 rbd-data 存储池的读写权限
ceph auth get-or-create client.rbduser mon 'allow r' osd 'allow rwx pool=rbd-data'

# 2. 导出用户的 keyring
ceph auth get client.rbduser -o /etc/ceph/ceph.client.rbduser.keyring

# 3. 将 keyring 和全局配置文件推送到客户端机器 (例如 10.168.56.110)
scp /etc/ceph/ceph.conf /etc/ceph/ceph.client.rbduser.keyring root@10.168.56.110:/etc/ceph/
```

在客户端（10.168.56.110）执行映射与挂载：
```bash
# 1. 映射 RBD 映像为本地块设备
rbd --user rbduser -p rbd-data map data-img1
# 返回物理块设备路径，如: /dev/rbd0

# 2. 创建文件系统并挂载
mkfs.xfs /dev/rbd0
mkdir -p /data/cephrbd
mount /dev/rbd0 /data/cephrbd
```

### 4. RBD 映像在线无损拉伸 (Resize)
当客户端挂载的磁盘空间不足时，Ceph 支持在线扩容，**无需卸载磁盘设备**：
```bash
# 1. 在管理端将映像调整为 5GB
rbd resize --pool rbd-data --image data-img1 --size 5G

# 2. 在客户端执行文件系统扩容 (以 XFS 为例)
# 💥 注意：如果直接对原始块设备进行格式化挂载，可以直接执行扩容；若之前划分过 fdisk 分区，则无法自动拉伸
xfs_growfs /dev/rbd0
df -Th /data/cephrbd # 空间在线无损扩容成功！
```

### 5. RBD 镜像回收站 (Trash) 机制
为了防止误删除操作造成灾难，Ceph 引入了回收站机制：
```bash
# 1. 客户端卸载并解绑映射
umount /data/cephrbd
rbd --user rbduser -p rbd-data unmap /dev/rbd0

# 2. 在管理端移动镜像到回收站 (替代 rbd rm)
rbd trash move --pool rbd-data --image data-img1
# 3. 查看回收站列表
rbd trash list -p rbd-data
# 输出 ID 示例: 1770c07622f6 data-img1

# 4. 在需要时，从回收站恢复镜像
rbd trash restore --image data-img1 -p rbd-data --image-id 1770c07622f6
```

### 6. 快照 (Snapshot) 管理与回滚
```bash
# 1. 创建快照
rbd snap create -p rbd-data --image data-img1 --snap img1-snap-202606

# 2. 客户端发生误删后，卸载挂载，执行快照回滚
umount /data/cephrbd
rbd snap rollback -p rbd-data --image data-img1 --snap img1-snap-202606

# 3. 重新挂载，数据恢复成功
mount /dev/rbd0 /data/cephrbd
```

---

## 二、 CephFS 共享文件系统与 MDS 高可用架构

CephFS 类似于 NFS，支持多客户端同时挂载（ReadWriteMany），依赖 MDS 进程管理文件目录元数据。

### 1. 部署与初始化 CephFS
```bash
# 1. 在 MON 节点安装 mds 进程包
# apt install ceph-mds -y

# 2. 加入集群
ceph-deploy mds create ceph-mon-mgr1

# 3. 创建元数据和数据存储池 (CephFS 强制要求两个存储池隔离)
ceph osd pool create cephfs-data 64 64
ceph osd pool create cephfs-metadata 32 32

# 4. 新建文件系统
ceph fs new mycephfs cephfs-metadata cephfs-data
```

### 2. MDS 服务高可用 (Active/Standby) 配置
为了防止单点元数据故障，我们需要部署多台 MDS，通过配置实现主备状态实时同步（Replay 模式）。

```toml
# 在 ceph-deploy 的 ceph.conf 配置文件中加入：
[mds.ceph-data1]
mds_standby_for_name = ceph-mon3      # 作为 ceph-mon3 上 MDS 的专用备份
mds_standby_replay = true             # 开启实时重放模式，秒级接管

[mds.ceph-mon-mgr2]
mds_standby_for_name = ceph-mon-mgr1  # 作为 ceph-mon-mgr1 的专用备份
mds_standby_replay = true
```

推送配置并重启服务：
```bash
ceph-deploy --overwrite config push ceph-mon-mgr1 ceph-mon3 ceph-mon-mgr2 ceph-data1
# 节点重启服务：systemctl restart ceph-mds@ceph-mon-mgr1.service
```

验证状态：
```bash
ceph fs status
# 两个 Active，两个 Standby
# RANK  STATE        MDS          
#  0    active  ceph-mon-mgr1  
#  1    active    ceph-mon3    
#  STANDBY MDS: ceph-data1, ceph-mon-mgr2
```

---

### 3. NFS-Ganesha 协议导出
客户端可能无法安装 Ceph 客户端驱动，我们可以通过 `NFS-Ganesha`，将 CephFS 转化为标准的 NFS 协议共享给外部主机访问。

```text
  ┌──────────────┐               NFS 协议               ┌──────────────┐
  │  NFS Client  │ ──────────────────────────────────> │ NFS-Ganesha  │ (运行在 Ceph 节点)
  └──────────────┘                                     └──────┬───────┘
                                                              │ 使用 FSAL_CEPH 驱动
                                                              ▼
                                                       ┌──────────────┐
                                                       │    CephFS    │
                                                       └──────────────┘
```

#### A. 安装与配置 (在 ceph-data1 节点上)
```bash
# 1. 安装 Ganesha 的 Ceph 驱动模块
apt install nfs-ganesha-ceph -y

# 2. 写入主配置文件 /etc/ganesha/ganesha.conf
cat << EOF > /etc/ganesha/ganesha.conf
NFS_CORE_PARAM {
    Enable_NLM = false;
    Enable_RQUOTA = false;
    Protocols = 4;
}
EXPORT_DEFAULTS {
    Access_Type = RW;
}
EXPORT {
    Export_Id = 1;
    Path = "/";                      # 导出 CephFS 的根目录
    FSAL {
        name = CEPH;                 # 选用 CEPH 驱动
        hostname = "10.168.56.104";  # 当前节点 IP
    }
    Squash = "No_root_squash";
    Pseudo = "/ceph-nfs";            # 挂载的伪路径
    SecType = "sys";
}
LOG {
    Default_Log_Level = WARN;
}
EOF

# 3. 启动并使能服务
systemctl restart nfs-ganesha
```

#### B. 客户端挂载验证
```bash
# 客户端直接以 NFS 方式进行挂载
mount -t nfs 10.168.56.104:/ceph-nfs /data/ceph-nfs
```

---

## 三、 RGW (RADOS Gateway) 对象存储部署与高可用

RGW 提供了兼容 Amazon S3 和 OpenStack Swift 的 RESTful API 接口。

### 1. 部署 RGW 主机
```bash
# 1. 在管理端创建 RGW 实例
ceph-deploy rgw create ceph-mon-mgr2 ceph-mon3

# 2. RGW 默认会监听 7480 端口，同时自动创建一系列以 .rgw 命名的系统级对象池 (.rgw.root 等)
```

### 2. 通过 HAProxy 实现 RGW 网关负载均衡
为了避免 RGW 网关的单点网络瓶颈和故障，在入口节点部署 HAProxy 进行 4 层反向代理负载均衡。

```text
                 ┌─────────────────┐
                 │  HAProxy Entry  │ (对外端口 80)
                 └────────┬────────┘
                          │ 4 层轮询分发
         ┌────────────────┴────────────────┐
         ▼                                 ▼
┌─────────────────┐               ┌─────────────────┐
│ RGW-Node1:7480  │               │ RGW-Node2:7480  │
└─────────────────┘               └─────────────────┘
```

```haproxy
# /etc/haproxy/haproxy.cfg 配置片段：
frontend rgw_front
    bind *:80
    mode http
    default_backend rgw_back

backend rgw_back
    mode http
    balance roundrobin
    server rgw1 10.168.56.102:7480 check
    server rgw2 10.168.56.103:7480 check
```

---

## 四、 ceph.conf 生产环境核心调优参数

下表为生产级 `ceph.conf` 核心参数中文注解，供优化及排障参考：

| 配置模块 | 参数名 | 默认值 / 推荐值 | 调优说明 |
| :--- | :--- | :--- | :--- |
| **`[global]`** | `osd pool default size` | `3` | 存储池默认副本数。不建议调小。 |
| | `osd pool default min size` | `1` | 允许降级（Degraded）写入的最小存活副本数。 |
| | `mon_osd_full_ratio` | `.85` | 磁盘空间达到 85% 时，集群锁定拒绝写入。 |
| | `mon_osd_nearfull_ratio` | `.70` | 磁盘空间达到 70% 时触发告警警告。 |
| **`[mon]`** | `mon clock drift allowed` | `0.05` / `1` | 允许 MON 主机间的时钟偏差秒数。有 NTP 调优时可维持默认。 |
| **`[osd]`** | `osd recovery op priority` | `10` / `2` | 数据恢复任务的优先级。降低其数值可避免数据重构时阻塞正常的业务读写 IO。 |
| | `osd max backfills` | `10` / `4` | 允许单个 OSD 同时进行的最大回填（数据均衡）任务数。 |
| | `osd_scrub_begin_hour` | `0` / `22` | 清洗（Scrubbing）开始的深夜时间点（防止白天磁盘高占用）。 |
| | `osd_scrub_end_hour` | `0` / `7` | 清洗结束的清晨时间点。 |
| **`[client]`** | `rbd cache` | `true` | 启用客户端 RBD 缓存，提升性能。 |
| | `rbd cache size` | `32MB` / `320MB` | 客户端缓存空间，高并发写入场景下推荐调大。 |

---

> [!TIP] 💡 关联技术与延伸阅读
>
> * [Ceph 分布式存储架构与部署实战](./03-Ceph分布式存储架构与部署实战.md)
> * [CSI 存储插件挂载流程](../05-集群存储/01-CSI架构与存储挂载全链路机制.md)

# 清理 PaaS 平台 LVM 存储脚本（优化版）

## 1. 优化后的脚本代码

```bash
#!/bin/bash
# ======================================================================
# 脚本名称: cleanup_paas_lvm.sh
# 功能描述: 安全清理 PaaS/K8S 环境中遗留的 LVM 存储配置 (vgpaas)
#          并还原相关物理设备的系统配置。
# ======================================================================

# 开启严格模式，未初始化变量报错
set -u

echo ">>> 开始查找并清理 vgpaas 相关的 LVM 资源..."

# 1. 查找属于 vgpaas 的物理卷 (PV)
# 优化点：使用 `pvs` 命令替代脆弱的 `pvdisplay | grep` 解析，避免误判
PV_DEVICES=$(pvs -o pv_name,vg_name --noheadings 2>/dev/null | awk '$2=="vgpaas" {print $1}')

# 2. 清理逻辑卷 (LV)
# 优化点：在删除前先检查逻辑卷是否存在，避免报错中止
if lvs vgpaas/thinpool >/dev/null 2>&1; then
    echo ">> 正在删除逻辑卷: vgpaas/thinpool"
    lvremove -y /dev/vgpaas/thinpool
fi

if lvs vgpaas/kubernetes >/dev/null 2>&1; then
    echo ">> 正在删除逻辑卷: vgpaas/kubernetes"
    lvremove -y /dev/vgpaas/kubernetes
fi

# 3. 清理卷组 (VG)
# 优化点：检查 VG 是否存在再执行删除
if vgs vgpaas >/dev/null 2>&1; then
    echo ">> 正在删除卷组: vgpaas"
    vgremove -y vgpaas
fi

# 4. 清理物理卷 (PV) 并更新配置文件
if [[ -n "${PV_DEVICES}" ]]; then
    echo ">> 发现相关物理卷: " ${PV_DEVICES}
    
    # 清除物理磁盘上的 PV 签名
    # shellcheck disable=SC2086
    pvremove -y ${PV_DEVICES}
    
    # 优化点：将多个设备名格式化，用逗号拼接（例如：/dev/sdb,/dev/sdc）
    # 使用 tr 替换换行符并用 sed 去除行尾多余的逗号
    DEVICE_STR=$(echo "${PV_DEVICES}" | tr '\n' ',' | sed 's/,$//')
    echo ">> 提取出的底层物理磁盘路径: ${DEVICE_STR}"
    
    # 5. 更新 PaaS 配置文件
    CONFIG_FILES=(
        "/var/paas/conf/agent_opts.conf"
        "/var/paas/conf/lvmConf.json"
        "/tmp/lvmConf.json"
    )
    
    for FILE in "${CONFIG_FILES[@]}"; do
        # 优化点：在修改配置前判断文件是否存在，避免 sed 找不到文件报错
        if [[ -f "${FILE}" ]]; then
            sed -i "s|/dev/lvmpart|${DEVICE_STR}|g" "${FILE}"
            echo "   [成功] 已将设备信息写入配置文件: ${FILE}"
        else
            echo "   [跳过] 配置文件不存在: ${FILE}"
        fi
    done
else
    echo ">> 未找到属于 vgpaas 卷组的物理卷，跳过 PV 清理和配置更新。"
fi

echo ">>> 清理完成。"
```

## 2. 脚本优化点说明

相较于最初将所有逻辑堆砌在一行的单行命令，新脚本做了以下核心优化：

1. **准确性与安全性（核心优化）**：
   * **原逻辑**：使用 `pvdisplay | grep -B1 vgpaas | grep 'PV Name' | awk '{print $3}'`，这种方式严重依赖于命令输出格式。如果系统语言改变或者 LVM 版本升级导致输出格式略有变化，极易提取到错误的磁盘路径，存在**误删系统盘**的致命隐患。
   * **优化后**：使用原生的 `pvs -o pv_name,vg_name --noheadings` 结构化输出提取，直接匹配 `vgpaas`，精确度 100%。

2. **防御性编程（容错与幂等性）**：
   * **原逻辑**：直接无脑执行 `lvremove`、`vgremove`，如果卷已经被删除或者不存在，终端会抛出大量错误信息。后半段的配置文件修改缺乏文件是否存在的判定。
   * **优化后**：在删除每一级资源（LV、VG）前，均加入了 `lvs` 和 `vgs` 判断；在修改文件前，加入了 `[[ -f ]]` 判断，确保脚本随时可以被重复执行（具有幂等性）且不会产生脏错误。

3. **格式化设备字符串**：
   * **原逻辑**：使用 `sed 's| |,|g'` 去替换空格。如果 `pvdisplay` 获取到的多块盘是用换行符分隔的，这种替换其实会失效，导致写入配置文件的格式错误。
   * **优化后**：使用 `tr '\n' ','` 处理，能完美将多块磁盘（如 `/dev/sdb /dev/sdc` 变成了 `/dev/sdb,/dev/sdc`）拼接为配置文件期望的格式。

4. **可读性与可维护性**：
   * 将长达数百个字符的单行命令拆解成了结构清晰的 Bash 脚本，添加了日志输出（`echo`）和详尽的注释，让接手的运维人员能一眼看懂它的执行流程。

## 3. 详细执行流程（原理解析）

该脚本是典型的 **LVM（逻辑卷管理）资源逆向拆除流**，其执行顺序严格符合 LVM 的依赖倒置关系（ `LV -> VG -> PV`），具体如下：

1. **寻根**：找到是哪几块物理磁盘（PV）组成了我们的目标存储池（名为 `vgpaas` 的 VG）。
2. **拆房 (LV)**：强制删除建在该卷组上的两个逻辑卷：
   * `thinpool`：通常是 Docker 用来做精简配置（Thin Provisioning）的存储池，存放着所有容器镜像和容器层数据。
   * `kubernetes`：存放着 K8s 集群相关的持久化卷或数据。
3. **拆地基 (VG)**：逻辑卷清理干净后，把名为 `vgpaas` 的卷组销毁。
4. **抹除印记 (PV)**：对一开始找到的物理磁盘执行 `pvremove`，抹去磁盘头部的 LVM 签名，让这块磁盘变回“自由身”（Raw Disk）。
5. **回写配置**：将这些“自由”磁盘的路径（如 `/dev/sdb`）回写到 PaaS 平台的相关配置文件中（替换掉占位符 `/dev/lvmpart`），通常是为了通知管理平台：“这块磁盘现在空出来了，可以重新接管或用作他途了”。

> **⚠️ 危险警告**
> 无论是原命令还是优化后的脚本，**此操作都会不可逆地摧毁容器（Docker）和 Kubernetes 在该节点上的所有存储数据**，属于“焦土政策”，仅能在节点重置、资源回收排障或平台彻底卸载重装时使用。

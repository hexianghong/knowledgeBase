# Round 1: Linux 基础、日常常用命令与核心 CLI 深度指南

在企业级 Linux 运维与 SRE 实践中，对底层系统目录结构、文件元数据、日常高频操作命令、进程信号量以及权限隔离机制的深刻理解，是高效排错与自动化运维的基础。本指南从系统管理员日常使用视角出发，详细整理文件存储、进程监控、网络调测、文本检索与系统维护的高频实战命令。

---

## 一、 文件与存储日常高频操作手册

### 1. `find` 高频实用搜寻组合

`find [path] [expression]` 是 Linux 下功能最强悍的搜寻工具：

```bash
# 1. 查找 /var/log 目录下大于 100MB 且修改时间在 7 天前的文件并询问删除
find /var/log -type f -size +100M -mtime +7 -exec rm -i {} \;

# 2. 查找当前目录下权限为 777 的危险文件并自动修改为 755
find . -type f -perm 777 -exec chmod 755 {} \;

# 3. 查找所有以 .log 结尾的文件，并按修改时间倒序排列
find /data -name "*.log" -printf "%T@ %p\n" | sort -nr | head -n 10
```

---

### 2. `rsync` 增量同步与大文件传输

相比传统的 `cp` / `scp`，`rsync` 支持增量传输、断点续传与压缩：

```bash
# 1. 增量同步本地 /data/ 目录到远程服务器 (a: 保持属性, v: 详细, z: 压缩, P: 显示进度与断点续传)
rsync -avzP -e "ssh -p 2222" /data/ root@192.168.1.100:/data_backup/

# 2. 完全镜像同步（慎用! --delete 会删除目标端多余的文件，保持两端绝对一致）
rsync -avzP --delete /var/www/html/ /backup/html/
```

---

### 3. `tar` 压缩与解压全能命令

```bash
# 1. 创建 gzip 压缩包 (最常用)
tar -czvf app_backup.tar.gz /opt/app/

# 2. 创建 xz 高压缩比压缩包 (体积最小，适合归档)
tar -cJvf system_backup.tar.xz /etc/

# 3. 解压到指定目录 /data/target
tar -xzvf app_backup.tar.gz -C /data/target/

# 4. 不解压直接查看压缩包内部文件清单
tar -tzvf app_backup.tar.gz
```

---

### 4. 磁盘空间快速检查与日志无锁清空

```bash
# 1. 人性化查看各挂载点磁盘空间
df -hT

# 2. 快速找出当前目录下占用空间最大的前 10 个子目录/文件
du -sh * | sort -rh | head -n 10

# 3. 使用 ncdu 交互式游览与清理磁盘空间 (需安装 ncdu)
ncdu /var/log

# 4. 安全无锁清空大日志文件（绝对不要直接 rm，应使用截断，避免句柄丢失!）
> /var/log/nginx/access.log
# 或
truncate -s 0 /var/log/nginx/access.log
```

---

## 二、 进程与系统资源日常监控操作手册

### 1. `top` / `htop` 交互式监控快捷键

在 `top` 运行界面中按下以下快捷键：

* **`P`**：按 **CPU 使用率** 对进程降序排列（默认）。
* **`M`**：按 **内存使用率 (RES)** 对进程降序排列。
* **`T`**：按 **累计 CPU 运行时间** 排序。
* **`1`**：展开/折叠显示所有 CPU 物理/逻辑核心使用率。
* **`c`**：切换显示完整的命令行参数及路径。
* **`k`**：弹出 Kill 提示，输入 PID 发送信号杀死进程。

---

### 2. `ps` 高频筛选与排序组合

```bash
# 1. 查找 CPU 占用率最高的前 10 个进程
ps aux --sort=-%cpu | head -n 11

# 2. 查找内存 (RSS) 占用最高的前 10 个进程
ps aux --sort=-%mem | head -n 11

# 3. 树状图显示指定进程及其子线程 (包括 PID, PPID, STAT, CMD)
ps -ef --forest | grep nginx
```

---

### 3. `lsof` & `fuser` 端口与文件占用强杀

```bash
# 1. 查看 8080 端口被哪一个进程占用
lsof -i :8080
# 或
ss -tulpn | grep :8080

# 2. 查看哪些进程正在读写 /var/log/app.log 文件
lsof /var/log/app.log

# 3. 强行杀死所有占用 /mnt/usb 挂载点的进程 (解除 target is busy 挂载失败)
fuser -k -m -9 /mnt/usb
```

---

### 4. `watch` 动态高亮刷新与 `tmux` 会话保持

```bash
# 1. 毎 1 秒刷新一次 TCP ESTABLISHED 连接数，并高亮显示变动差异 (-d)
watch -d -n 1 "ss -ant | grep ESTAB | wc -l"
```

#### `tmux` 后台会话保持常用操作：

```bash
# 1. 创建名为 work 的新后台会话
tmux new -s work

# 2. 在 tmux 中分离会话 (挂起后台)：按下快捷键 Ctrl+b 随后按 d

# 3. 查看现有的会话列表
tmux ls

# 4. 重新连入 work 会话
tmux a -t work
```

---

## 三、 网络与服务日常调测操作手册

### 1. 现代化 `ip` 命令替换旧版 `ifconfig` / `route`

| 旧版命令                     | 现代`ip` 命令                          | 功能说明               |
| :--------------------------- | :--------------------------------------- | :--------------------- |
| `ifconfig`                 | `ip a` 或 `ip addr show`             | 查看网卡 IP 地址与掩码 |
| `route -n`                 | `ip r` 或 `ip route show`            | 查看路由表             |
| `ifconfig eth0 up/down`    | `ip link set dev eth0 up/down`         | 启用/禁用网卡          |
| `route add default gw ...` | `ip route add default via 192.168.1.1` | 添加默认网关           |

---

### 2. `curl` 详尽诊断 HTTP 请求耗时分布

创建耗时格式化文件 `curl-format.txt`：

```
  time_namelookup:  %{time_namelookup}s\n
     time_connect:  %{time_connect}s\n
  time_appconnect:  %{time_appconnect}s\n
 time_pretransfer:  %{time_pretransfer}s\n
    time_redirect:  %{time_redirect}s\n
time_starttransfer:  %{time_starttransfer}s\n
                  ----------\n
       time_total:  %{time_total}s\n
```

```bash
# 执行 HTTP 耗时诊断
curl -w "@curl-format.txt" -o /dev/null -s https://api.github.com
```

*输出：可精确判断是 DNS 解析慢 (`namelookup`)、TCP 建连慢 (`connect`)，还是后端 Server 处理慢 (`starttransfer` / TTFB)*。

---

### 3. `ping`, `mtr` 与 `nc` 网络排错

```bash
# 1. 使用 mtr 综合诊断到目标 IP 1.1.1.1 的路由链路丢包与延迟波动
mtr --report --report-cycles 10 1.1.1.1

# 2. 使用 nc 快速检测目标服务器 192.168.1.50 的 3306 端口连通性 (-z: 不发送数据)
nc -zvw 3 192.168.1.50 3306
```

---

## 四、 文本编辑与批量检索处理手册

### 1. `vim` / `nvim` 生产必会快捷键

* **多行块列选择与批量注释**：

  1. 按 `Ctrl + v` 进入 **VISUAL BLOCK** 模式。
  2. 使用 `j` / `k` 键上下选中多行开头。
  3. 按 `Shift + i` (即 `I`) 进入插入模式，输入注释符号 `# `。
  4. 按 `Esc` 键两次，所选所有行开会自动补全 `# `！
* **全局批量替换**：

  ```vim
  :%s/old_text/new_text/g
  ```
* **快速跳转与定位**：

  * `gg`：跳转到文件第一行。
  * `G`：跳转到文件最后一行。
  * `150G` 或 `:150`：跳转到第 150 行。

---

### 2. `xargs` 批量并发处理

```bash
# 将当前目录下所有 .log 文件，使用 4 个并行进程 (-P 4) 压缩为 .gz
find . -name "*.log" | xargs -I {} -P 4 gzip {}
```

---

### 3. `tee` 管道双向输出

```bash
# 将编译日志输出到屏幕的同时，追加保存到 build.log 文件中
make 2>&1 | tee -a build.log
```

---

## 五、 用户、软件包与系统日常维护手册

### 1. 历史命令审计增强与容量调优 (时间戳、容量扩充与防覆盖)

默认情况下，Linux Bash 的 `history` 仅保留 1000 条历史记录且不带时间戳，多终端会话退出时还会发生“后退出覆盖先退出”的历史命令丢失问题。

#### (1) 生产级推荐配置 (Bash)

编辑当前用户的 `~/.bashrc`（仅对当前用户生效）或 `/etc/profile`（全系统全局生效）：

```bash
cat << 'EOF' >> ~/.bashrc

# ==============================================================================
# History 审计增强与容量调优
# ==============================================================================
# 1. 历史记录保留条数扩充 (推荐 10 万条)
export HISTSIZE=100000        # 内存中当前 Shell 会话保留的最大命令条数
export HISTFILESIZE=100000    # 磁盘历史文件 (~/.bash_history) 最多保留的行数

# 2. 精确执行时间戳 (审计合规必备: 年-月-日 时:分:秒)
export HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S "

# 3. 历史命令审计合规策略
# 生产严禁使用 erasedups (会删除历史时序破坏故障复盘) 与 ignorespace (空格逃逸审计风险)
# 仅建议保留 ignoredups (连续手抖重复合并) 或直接留空保持绝对原始记录
export HISTCONTROL=ignoredups

# 4. 多终端会话防覆盖 (以 append 增量追加模式写入历史文件)
shopt -s histappend

# 5. 每次敲击回车时立即追加写入磁盘，避免异常断开/宕机导致缓冲区命令丢失
export PROMPT_COMMAND="history -a; $PROMPT_COMMAND"
EOF

# 使配置立即生效
source ~/.bashrc
```

*效果验证：`history | tail -n 3`*

```text
10001  2026-09-16 17:05:12  systemctl restart nginx
10002  2026-09-16 17:06:01  ss -tulpn | grep 80
10003  2026-09-16 17:08:45  tail -f /var/log/nginx/error.log
```

> [!NOTE]
> **Zsh 终端环境兼容（如 macOS 默认环境）**：
> Zsh 对应的磁盘保存变量名为 `SAVEHIST`，请写入 `~/.zshrc`：
>
> ```bash
> export HISTSIZE=100000
> export SAVEHIST=100000
> export HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S "
> setopt INC_APPEND_HISTORY    # 立即增量写入
> setopt SHARE_HISTORY         # 多终端实时共享历史
> ```

---

**高并发跳板机与网络存储规避要点**：

> 1. **避免全局死锁**：若用户的 Home 目录挂载于 **NFS / CephFS 等网络共享存储**，高并发追加写入 `~/.bash_history` 会触发网络文件锁开销，建议控制在 20,000 条左右；
> 2. **PROMPT_COMMAND 优化**：生产环境推荐只写 `history -a`（增量追加写），**不要**在每次回车时盲目执行 `history -r`（全量重读磁盘），以避免高频触发 5MB+ 文件的磁盘重扫。

---

### 2. `journalctl` 快捷日志检索

```bash
# 1. 查看 nginx 服务最新的 50 行日志（不调用 less 分页）
journalctl -u nginx.service -n 50 --no-pager

# 2. 查看自上次重启以来的所有系统 Kernel 日志
journalctl -k -b 0
```

---

### 3. 软件包管理常用命令对比

| 操作功能                     | RHEL / CentOS (`yum` / `dnf`)           | Debian / Ubuntu (`apt`)              |
| :--------------------------- | :------------------------------------------ | :------------------------------------- |
| **安装软件**           | `dnf install -y nginx`                    | `apt update && apt install -y nginx` |
| **卸载软件**           | `dnf remove -y nginx`                     | `apt purge -y nginx`                 |
| **查询文件属于哪个包** | `dnf provides */bin/ss`                   | `dpkg -S /usr/bin/ss`                |
| **清理缓存**           | `dnf clean all`                           | `apt clean`                          |
| **查看历史操作与撤销** | `dnf history` / `dnf history undo <ID>` | `/var/log/apt/history.log`           |

---

## 六、 Linux FHS 标准与文件元数据机制

Linux 遵循 **FHS 3.0** (Filesystem Hierarchy Standard) 规范，将文件系统划分为职责清晰的层级目录：

* `/bin`, `/sbin`：基础系统二进制可执行文件（在现代 Systemd 系统中通常软链接至 `/usr/bin`）。
* `/etc`：系统核心静态配置文件。
* `/var`：动态变化数据（日志 `/var/log`、缓存 `/var/cache`、运行时锁 `/var/run`）。
* `/proc` & `/sys`：内核虚拟文件系统，暴露内核状态与硬件设备树。
* `/usr/local` / `/opt`：第三方独立软件安装根目录。

文件类型标识：普通文件 (`-`)、目录 (`d`)、符号软链接 (`l`)、块设备 (`b`)、字符设备 (`c`)、UNIX Domain Socket (`s`) 与 FIFO 命名管道 (`p`)。

---

## 七、 深入系统底层：`strace`、`/proc` 探针与 `lsof/fuser` 排错 (Julia Evans / Baeldung 实战精髓)

### 1. `strace` 系统调用追踪实战

当一个进程无响应、挂起或抛出模糊的报错时，`strace` 是看清进程在与内核交互什么（文件读写、网络收发、内存分配、锁竞争）的终极武器：

```bash
# 1. 追踪目标正在运行的进程 (包括其派生子线程 -f)，打印微秒级绝对时间戳 (-tt) 与系统调用耗时 (-T)
strace -f -tt -T -s 512 -p <PID> -o /tmp/strace_output.log

# 2. 仅过滤关键系统调用（如网络 connect/accept 或文件 openat/write）
strace -f -e trace=network,openat,write -p <PID>

# 3. 统计各系统调用总耗时与调用次数（定位系统调用瓶颈）
strace -c -p <PID>
```

---

### 2. `/proc` 虚拟文件系统深度透视

`/proc` 并不占用物理磁盘空间，而是由内核动态生成的内存视图：

```bash
# 1. 查看进程真实物理内存、上下文切换情况
cat /proc/<PID>/status | grep -E "VmRSS|VmHWM|voluntary_ctxt_switches"

# 2. 检查进程打开的所有文件描述符 (FD) 及其实际指向
ls -l /proc/<PID>/fd/

# 3. 检查进程的实际资源限制 (最大打开文件数、栈大小)
cat /proc/<PID>/limits | grep "Max open files"

# 4. 查看当前进程的启动命令行全参与环境变量
cat /proc/<PID>/cmdline | tr '\0' ' ' && echo
cat /proc/<PID>/environ | tr '\0' '\n'
```

---

### 3. `lsof` 与 `fuser` 实战定位

```bash
# 1. 查找被进程占用但文件已被 rm 删除导致磁盘空间无法释放的“幽灵文件”
lsof +L1

# 2. 查找哪个进程锁定了特定的挂载点或目录（卸载 umount 报 device busy 救急）
fuser -vm /data_disk
# 强行杀死占用该挂载点的所有进程
fuser -km /data_disk

# 3. 查找指定端口当前被哪个服务监听
lsof -i :8080 -nP
```

---

## 八、 现代化 CLI 工具链与传统命令升级对比

现代 Linux 运维与开发生态中涌现了一批采用 Rust / Go 编写的高性能现代化 CLI 工具，可大幅提升日常诊断效率：

| 经典传统命令       | 现代增强工具               | 核心优势与特色                                                         | 安装与典型使用命令               |
| :----------------- | :------------------------- | :--------------------------------------------------------------------- | :------------------------------- |
| `grep`           | **`ripgrep (rg)`** | 多线程并行搜索、默认自动忽略`.gitignore`、支持正则，性能提升 5~10 倍 | `rg "ERROR_TIMEOUT" /var/log/` |
| `find`           | **`fd`**           | 语法简洁、彩色高亮、默认忽略隐藏与构建文件、极速并行目录扫描           | `fd -e conf nginx /etc/`       |
| `cat`            | **`bat`**          | 语法高亮、Git 修改标记 (Git diff gutters)、分页自动整合                | `bat /etc/nginx/nginx.conf`    |
| `top` / `htop` | **`btop`**         | 极度美观的 TUI 终端面板、CPU/内存/磁盘/网络实时图表、一键杀进程        | `btop`                         |
| `df`             | **`duf`**          | 彩色分块呈现挂载点使用率、inode 占用率、设备类型与挂载选项             | `duf`                          |

---

> [!TIP] 💡 关联技术与延伸阅读
> * [Linux Shell 脚本编程与自动化深度指南](./02-Linux_Shell脚本编程与自动化深度指南.md) —— 高级 Bash 编程、流程控制、信号捕获与自动化工程
> * [Linux 进程与 CPU 性能调优指南](../03-系统性能与调优/01-Linux进程与CPU性能调优指南.md) —— CFS 调度算法、CPU 绑核与火焰图诊断
> * [高级运维生产高频故障排查手册](../07-高可用与生产排错/02-高级运维生产高频故障排查手册.md) —— CPU 假死、句柄泄露、磁盘满与网络丢包紧急止损 SOP

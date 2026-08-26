# Round 19: Linux 时间同步、时钟源与 PTP 硬件时钟指南

在分布式数据库（CockroachDB, Spanner, TiDB）、高频金融交易系统、以及分布式日志分析中，**服务器时间失准或时间回拨 (Time Backwards)** 是最致命的灾难之一。它会导致分布式锁失效、数据库 MVCC 数据错乱以及事务顺序倒置。

本指南深入拆解 Linux 时间子系统架构、硬件时钟源 (`tsc`/`hpet`) 选型、Chrony 追时算法与 Slew 平滑调节、微秒/纳秒级 PTP (IEEE 1588) 硬件时钟同步与偏差求解公式、以及闰秒 (Leap Second) 防爆破策略。

---

## 一、 Linux 时间子系统架构：RTC vs System Clock

```
+-------------------------------------------------------------------------+
|  1. 硬件时钟 RTC (Real-Time Clock / CMOS Clock)                         |
|  - 主板纽扣电池供电物理芯片, 关机后依然运行                              |
+-------------------------------------------------------------------------+
                                   | hwclock -s (开机初始化读取)
                                   v
+-------------------------------------------------------------------------+
|  2. 系统时钟 System Clock (内核定时器中断维护)                           |
|  - 内核启动后由 CPU 计数器驱动 (高精度纳秒级)                             |
+-------------------------------------------------------------------------+
```

---

## 二、 内核硬件时钟源 (`clocksource`) 选型

```bash
cat /sys/devices/system/clocksource/clocksource0/current_clocksource
# tsc
```

* **`tsc` (Time Stamp Counter)**：CPU 内部寄存器计数器，读取开销极低 (< 20ns)，纳秒级精度。**现代服务器与 KVM 虚拟机的首选！**

---

## 三、 Chrony 高性能时间同步与平滑追时 (Slew Mode)

### 1. 追时两大模式：Step vs Slew

* **Step Mode (步进跳跃)**：直接修改系统时间，可能导致时间倒退，引发分布式死锁！
* **Slew Mode (平滑渐进)**：**不改变时间单调性**。通过微调内核晶振频率（将 1 秒微调为 0.999 秒或 1.001 秒），斜率渐进追平偏差。

```ini
# /etc/chrony.conf
server ntp1.aliyun.com iburst minpoll 4 maxpoll 6
makestep 1.0 3
rtcsync
driftfile /var/lib/chrony/drift
```

---

## 四、 微秒/纳秒级 PTP (IEEE 1588) 与时钟偏差数学计算

PTP (Precision Time Protocol) 通过在硬件 PHY 网卡芯片打上时间戳，彻底消除了操作系统网络栈的抖动。

```mermaid
graph LR
    Master["PTP Master 主时钟"] -->|1. 发送 Sync 报文 (发出时刻 T1)| Slave["PTP Slave 从时钟 (接收时刻 T2)"]
    Master -->|2. 发送 Follow_Up (补发 T1 精确值)| Slave
    Slave -->|3. 发送 Delay_Req (发出时刻 T3)| Master
    Master -->|4. 返回 Delay_Resp (接收时刻 T4)| Slave
```

### PTP 双向链路时钟偏差与单向延迟求解公式：

假设单向网络传输延迟为 $\text{MeanPathDelay}$，Master 与 Slave 之间的时钟偏差为 $\text{Offset}$：

$$T_2 - T_1 = \text{MeanPathDelay} + \text{Offset}$$
$$T_4 - T_3 = \text{MeanPathDelay} - \text{Offset}$$

#### 联立方程解得：
$$\text{Offset} = \frac{(T_2 - T_1) - (T_4 - T_3)}{2}$$
$$\text{MeanPathDelay} = \frac{(T_2 - T_1) + (T_4 - T_3)}{2}$$

*效果：Slave 根据算出的 $\text{Offset}$ 修正本地系统时钟，同步精度达到 **< 1 微秒 (Microsecond)**！*

```bash
# 运行 ptp4l 与 phc2sys
ptp4l -i eth0 -m -H
phc2sys -s eth0 -c CLOCK_REALTIME -w -m
```

---

## 五、 闰秒 (Leap Second) 灾难防范与 Leap Smearing

应用 **Leap Smearing (闰秒抹平)** 策略：在闰秒前后 24 小时内，将这一秒的时间差均匀拉长抹平在 86400 秒中。系统内核完全感知不到闰秒存在，彻底杜绝崩溃！

---

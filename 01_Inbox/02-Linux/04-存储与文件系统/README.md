# 04-存储与文件系统

## 目录说明
涵盖 Linux VFS 虚拟文件系统架构、Inode/Dentry 底层原理解析、Ext4 与 XFS 日志机制、标准文件系统目录结构（FHS）与权限规范，以及物理磁盘与 LVM 逻辑卷挂载实战。

## 内容索引
| 名称 | 类型 | 说明 |
|------|------|------|
| [./01-Linux文件系统VFS与Ext4_XFS底层剖析指南.md](./01-Linux文件系统VFS与Ext4_XFS底层剖析指南.md) | 文件 | VFS 抽象层、Inode 与 Dentry 结构、Ext4/XFS 日志机制与文件系统元数据修复 |
| [./02-Linux文件系统深度技术指南.md](./02-Linux文件系统深度技术指南.md) | 文件 | Linux 目录结构规范（FHS）、软硬链接机制、权限掩码（umask）与磁盘配额 |
| [./03-Linux数据盘挂载技术指南.md](./03-Linux数据盘挂载技术指南.md) | 文件 | 物理磁盘分区（fdisk/parted）、LVM 逻辑卷管理、文件系统创建与 /etc/fstab 挂载参数规范 |
| [./04-生产环境LVM在线无损扩容实战SOP.md](./04-生产环境LVM在线无损扩容实战SOP.md) | 文件 | 生产环境 LVM 物理卷重置（pvresize）、逻辑卷与 Ext4/XFS 文件系统零停机在线扩容与故障防御 SOP |

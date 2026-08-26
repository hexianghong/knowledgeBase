[MySQL OCP 908 英文题库.pdf](https://www.yuque.com/attachments/yuque/0/2025/pdf/12777525/1747818797549-0ad4e656-0f5a-40c3-a8ec-15c0c3b0acc8.pdf)

### 试题 1

MySQL 升级后，`transactions` 表有 400 万行，磁盘空间不足。使用的共享表空间。你尝试使用一些方法来释放空间，以下哪些方法有效？

**题干关键词：**

-   `innodb_file_per_table=OFF`
-   表空间占用
-   `ALTER TABLE` / `TRUNCATE`
-   `ROW_FORMAT=COMPRESSED`

正确答案分析：

✅ A) The transactions table was created with `innodb_file_per_table=OFF`.

✔ **解释：**  
当 `innodb_file_per_table` 为 **OFF** 时，所有 InnoDB 表的数据和索引都存储在共享的 `ibdata1` 表空间文件中。此时：

-   即使你 `DROP` 表或 `TRUNCATE` 表，该空间**不会归还给操作系统**。
-   它会在 `ibdata1` 中被标记为“可重用”，但 `ibdata1` 文件**不会变小**，这是典型的误区。

📌 **扩展知识点：**

-   现代版本（MySQL 5.6+）默认启用 `innodb_file_per_table=ON`。
-   设置为 ON 后，每张表独立 `.ibd` 文件，可释放空间。

B) Truncating the `sales` and `leads` tables will free up disk space.

✔ **解释：**  
假设 `sales` 和 `leads` 表是使用 `file-per-table=ON` 创建的（默认行为），那么 `TRUNCATE TABLE` 操作会：

-   删除 `.ibd` 文件并重新创建新的空文件。
-   系统将回收原有文件的磁盘空间。

C) `SET GLOBAL innodb_row_format=COMPRESSED` + `ALTER TABLE transactions`

✘ 错在两个方面：

1.  `innodb_row_format` 不是一个 MySQL 全局系统变量（无法 SET GLOBAL）。
2.  即使你用 `ALTER TABLE` 改为 `ROW_FORMAT=COMPRESSED`，这**并不会释放空间**，除非开启了 file-per-table，并且数据被真正重新组织压缩。

D) `ALTER TABLE transactions` will enable you to free disk space

✘ 如果该表仍在共享表空间中（file-per-table=OFF），`ALTER` 无法回收磁盘空间。

-   会重写表的内容，**可能临时使用更多空间**。
-   并不会减少 ibdata1 的大小。

E) `TRUNCATE TABLE transactions` will free up the most disk space

✘ 错误原因同上：

-   如果表没有单独的 `.ibd` 文件（即 file-per-table=OFF），`TRUNCATE` 不会释放物理磁盘空间。
-   表的元数据在 ibdata 中仍然占用空间，物理文件不会缩小。

​  

#### 总结延伸考点：

| 关键变量/命令 | 说明 |
| --- | --- |
| `innodb_file_per_table` | 是否每张表使用单独的 `.ibd` 文件，默认 ON（MySQL 5.6+） |
| `ibdata1` | 共享表空间文件，空间不会因 DROP/TRUNCATE 缩小 |
| `ROW_FORMAT=COMPRESSED` | 压缩行格式，仅在启用 `Barracuda`时生效 |
| `TRUNCATE TABLE` | 快速清空表数据，配合 file-per-table 可释放空间 |
| `OPTIMIZE TABLE` | 可触发表重建，释放未使用空间（适用于 file-per-table 表 |

### 试题 2

试题 2【EXPLAIN 执行计划分析】

**题干简要：**  
`EXPLAIN` 语句用于分析一条 `JOIN` 查询执行流程，包括连接顺序、估计行数等。

**正确答案：**

-   ✅ A) `The country table is accessed as the first table, and then joined to the city table.`  
    ✔ EXPLAIN 中出现的表顺序即为执行顺序。优化器根据表统计信息决定 `JOIN` 的顺序。
-   ✅ E) `The query returns exactly 125 rows.`  
    ✔ 如果 `EXPLAIN` 的输出中结果行数为 125，则说明最终结果集将是 125 行。

**错误项分析：**

-   ❌ B) `35 rows from the city table are included in the result.`  
    ✘ 行数未在题干中直接体现，无法断定具体数字。
-   ❌ C) `The optimizer estimates that 51 rows in the country table ...`  
    ✘ 属于虚构数据，EXPLAIN 中 `rows` 列展示的是估算数值。
-   ❌ D) `It takes more than 8 milliseconds to sort the rows.`  
    ✘ EXPLAIN 不提供时间信息，需要使用 `EXPLAIN ANALYZE` 才能评估延迟。

**知识扩展：**

-   `EXPLAIN` 查看：`id`、`select_type`、`type`、`rows`、`Extra`
-   `EXPLAIN ANALYZE`（MySQL 8+）：输出真实执行路径与耗时

### 试题 3

MySQL 性能调优：Buffer Pool 和日志优化】

**题干摘要：**  
读写比例 10:90，28G 数据，64G 内存，256M redo log， disk I/O 繁忙。目标是在不影响数据完整性的前提下最大化性能。

**正确答案：**

-   ✅ B) `innodb_log_group_home_dir=/data2/`  
    将 redo log 分离至另一磁盘，提升并行 I/O 性能。
-   ✅ C) `innodb_log_file_size=1G`  
    扩大 redo log 文件减少频繁 flush，提高性能。
-   ✅ E) `log-bin=/data2/`  
    将 binary log 迁移至另一个磁盘，避免与数据文件竞争 I/O。
-   ✅ H) `innodb_buffer_pool_size=32G`  
    读比例虽低，但提升 buffer pool 仍有助于缓存更新的数据页。

**错误项分析：**

-   ❌ A) `innodb_doublewrite=OFF`  
    虽然能提升性能，但关闭后崩溃时可能导致数据页损坏。
-   ❌ D) `innodb_undo_directory=/dev/shm`  
    不推荐将 undo 放在内存中，因掉电或异常关机可能丢失数据。
-   ❌ F/G/I) 与安全性矛盾或语法错误。

​  

innodb\_flush\_log\_at\_trx\_commit：`1`：最安全；`2` 或 `0` 可提升性能（牺牲持久性）

  

  

### 试题 4【MySQL 安全性配置】

**题干摘要：**  
你要限制 MySQL 被网络攻击的可能，以下哪些方式是合理的？

**正确答案：**

-   ✅ B) `Place the MySQL instance behind a firewall.`  
    ✔ 使用防火墙（如 iptables、ufw）阻止外部非法连接是常见做法。
-   ✅ E) `Allow connections from the application server only.`  
    ✔ 最佳做法之一：仅允许特定主机访问 3306。

**错误项分析：**

-   ❌ A) `Use MySQL Router to proxy connections ...`  
    ✘ Router 是为了路由与 HA，不是安全组件。
-   ❌ C) `Use network file system (NFS) for storing data.`  
    ✘ NFS 不适合存放数据文件，可能造成数据损坏。
-   ❌ D) `Change the listening port to 3307.`  
    ✘ 安全性没有本质提高，仅靠换端口并不能防护攻击。

### 试题 5【客户端连接配置方式】

**题干摘要：**  
客户端连接远程 Windows 上的 MySQL（端口 3309），应如何配置用户/主机/数据库参数？

**正确答案：**

-   ✅ B) `Execute mysql_config_editor ...`  
    ✔ 使用该命令安全保存用户、密码、主机等配置到 `.mylogin.cnf`。
-   ✅ C) `Configure ~/.my.cnf`  
    ✔ 可设置默认登录用户、端口、数据库等。
-   ✅ E) `Execute the command in a bash script.`  
    ✔ 常见做法：将连接语句写入脚本中自动连接。
-   ✅ F) `Configure environment variables.`  
    ✔ 使用 `MYSQL_TCP_PORT`、`MYSQL_PWD` 等变量影响默认连接行为。

**错误项分析：**

-   ❌ D) `mysqladmin` 不能配置连接用户， `mysqladmin` 是 **MySQL 官方提供的一个命令行管理工具**，用于执行数据库服务器的日常管理任务。它通常用于监控、控制、维护数据库实例，是 DBA 和开发人员常用的工具之一。
-   ❌ A/G/H/I) 不相关或错误理解 SSH 与 socket 行为

### 试题 6【基于虚拟列与函数索引优化查询】

**题干摘要：**  
给出 `birth_date`，现需优化 `WHERE MONTH(birth_date) = 4` 的查询，如何添加有效索引？

**正确答案：**

-   ✅ C) 使用生成列 `birth_month` 并索引

```sql
ALTER TABLE employees 
ADD COLUMN birth_month TINYINT UNSIGNED GENERATED ALWAYS AS (MONTH(birth_date)) VIRTUAL NOT NULL,
ADD INDEX (birth_month);
```

-   ✅ F) 使用函数索引（MySQL 8+ 支持）

```sql
CREATE INDEX idx_month ON employees ((MONTH(birth_date)));
```

**错误项分析：**

-   ❌ D/B) 直接索引 `birth_date` 无法优化 `MONTH(...)` 查询
-   ❌ A/E) JSON 语法或表达式错误

**扩展知识点：**

-   虚拟列适用于基于计算的查询优化，使用少量空间

### 试题 7【SQL 注入判断】

**题干摘要：**  
判断哪些语句存在典型 SQL 注入行为。

**正确答案：**

-   ✅ A) `... WHERE user = ' ? '; INSERT INTO members ... -- ';`  
    ✔ 典型的多语句注入，包含 INSERT 和注释断句。
-   ✅ B) `... WHERE name = '\; DROP TABLE users; -- ';`  
    ✔ 利用引号闭合 + `;` 实现破坏性注入。

**错误项分析：**

-   ❌ D/E/F/C) 虽有构造但未构成有效注入，或语法错误

**扩展建议：**

-   使用参数化语句（prepared statements）避免注入漏洞
-   开启 `general_log` 可辅助诊断是否有可疑语句

  

  

### 试题 8【InnoDB 锁监控方式】

**题干摘要：**  
监控 InnoDB 全局锁状态的方式有哪些？

**正确答案：**

-   ✅ A) `SHOW ENGINE INNODB STATUS;`  
    ✔ 最全的诊断信息，包括死锁、等待链。
-   ✅ D) `SHOW STATUS;`  
    ✔ 包含如 `Innodb_row_lock_waits`、`Innodb_row_lock_time_avg` 等指标。

**错误项分析：**

-   ❌ B) `SHOW TABLE STATUS;` 只看表空间信息
-   ❌ C/E/F) 并非锁相关监控结构

**扩展命令：**

```sql
SELECT * FROM information_schema.innodb_locks;
```

可查询锁持有情况（需启用 performance schema）

### 试题 9【需明文插件支持的认证方式】

**题干摘要：**  
哪些认证插件需要客户端支持明文密码传输？

**正确答案：**

-   ✅ A) `LDAP authentication`
-   ✅ D) `PAM authentication`

这两种都基于外部认证系统，初始握手需发送明文密码以供验证。

**错误项分析：**

-   ❌ B/E/F) 使用 SHA 或 native 密码，无需明文传输

**扩展参考：**

-   明文插件：`authentication_ldap_simple`, `authentication_pam`, `sha256_password`
-   明文客户端需启用：`--enable-cleartext-plugin`

### 试题 10【MySQL 数据字典内容】

**题干摘要：**  
MySQL 内部的数据字典存储了哪些信息？

**正确答案：**

-   ✅ C) `access control lists` — 权限系统的一部分
-   ✅ D) `view definitions` — 存储 SQL 视图的定义
-   ✅ F) `stored procedure definitions` — 包含函数/过程的元信息

**错误项分析：**

-   ❌ A/B/E) 性能数据或配置不在数据字典中，而在 performance schema 或配置文件中。

**扩展：**  
MySQL 8 起数据字典 存储在表中而非文件系统中（称为事务数据字典）

  

### 试题 11【MySQL 系统表与数据字典】

**题干摘要：**  
MySQL 的数据字典（data dictionary）中维护哪些系统对象？

**正确答案：**

-   ✅ A) `Table names and definitions` — 包括表结构、字段、主键等信息。
-   ✅ C) `Column data types` — 每个字段的数据类型、默认值、是否为 NULL。
-   ✅ D) `Tablespace names` — 所属表空间名称。

**错误项分析：**

-   ❌ B) `Process list information` — 来自内存结构或 `SHOW PROCESSLIST`。
-   ❌ E) `User-defined locks` — 存于 metadata locks 或 performance schema。
-   ❌ F) `Connection credentials` — 用户名密码存在 `mysql.user` 等授权表中。

**扩展说明：**

-   MySQL 8 引入了**统一事务数据字典（Transactional DD）**，完全存储在 InnoDB 表中（如 `mysql.tables`, `mysql.columns`）。
-   数据字典支持 ACID，确保元数据一致性。

### 试题 12【角色授权】

**正确答案解析：**

✅ **B) Mark can grant the r\_read@localhost role to another user.**

**正确。**

-   `**WITH ADMIN OPTION**` **表示 mark 可以将该角色授予其他用户。**
-   **注意，这里是“授予角色”，而不是授予该角色所拥有的权限。**

✅ **E) Mark can revoke the r\_read@localhost role from another role.**

**正确。**

-   **有** `**ADMIN OPTION**` **权限的用户可以执行** `**REVOKE**`**，从其他用户或角色中撤销该角色。**
-   **比如：**

```sql
REVOKE r_read@localhost FROM someuser;
```

❌ **错误选项解析：**

❌ **A) Mark can grant the privileges assigned to the r\_read@localhost role to another user.**

**错误。**

-   **Mark 不能直接授予角色所包含的权限，只能授予角色本身。**

❌ **C) ADMIN OPTION causes the role to be activated by default.**

**错误。**

-   **是否“默认启用”该角色，必须通过** `**SET DEFAULT ROLE**` **显式设置，**`**ADMIN OPTION**` **不会导致自动激活。**

❌ **D) Mark must connect from localhost to activate the r\_read@localhost role.**

**错误。**

-   **用户标识** `**mark@host**` **中的** `**host**` **只影响身份验证，不限制是否能激活角色。**
-   **与角色激活无关。**

❌ **F) ADMIN OPTION allows Mark to drop the role.**

**错误。**

-   **删除角色只能由具有** `**DROP ROLE**` **权限或** `**SUPER**` **权限的用户执行，ADMIN OPTION 不包含删除角色的权限。**

### 试题 13【MySQL 通用 表空间类型】

**题干摘要：**  
以下哪些属于 MySQL 支持的表空间类型？

**正确答案：**

**C) A new table can be created explicitly in a general tablespace.**

**你可以在创建表时指定通用表空间，例如：**

```sql
CREATE TABLE my_table (
  id INT PRIMARY KEY
) TABLESPACE my_general_ts;
```

✅ **D) An existing table can be moved into a general tablespace.**

**可以使用** `**ALTER TABLE ... TABLESPACE**` **语句将现有表移动到通用表空间（InnoDB 表）：**

```sql
ALTER TABLE old_table TABLESPACE my_general_ts;
```
---

❌ **错误选项解析：**

❌ **A) General tablespaces support temporary tables.**

**临时表不支持被放入通用表空间。临时表会被创建在临时表空间中，如** `**ibtmp1**`**。**

❌ **B) Dropping a table from a general tablespace releases the space back to the operating system.**

**删除表后，通用表空间的空间不会释放给操作系统，空间会被标记为可重用，但文件大小不会减小。**

❌ **E) A general tablespace can have multiple data files.**

**一个通用表空间只能关联一个数据文件（与系统表空间 ibdata1 不同，后者可以配置多个）。**

### 试题 14【Scale up 垂直扩展】

在现有的服务器中添加硬件资源，提高性能和处理能力

E、增加磁盘存储

D、添加内存

B、增加CPU 处理器

​  

## 试题 15【】

**题干摘要：**  
有关设置系统变量的方法有哪些？

**正确答案：**

-   ✅ A) `SET GLOBAL` 可用于会话外修改参数。
-   ✅ D) `my.cnf` 中设置参数可影响服务启动后的默认值。
-   ✅ F) `SET PERSIST`（MySQL 8+）可将设置持久保存。

**错误项分析：**

-   ❌ B) `SET SESSION` 只影响当前连接，不适用于跨连接。
-   ❌ C/E) 拼写错误或语法无效。

  

### 试题 16 【复制延迟诊断】

**题干摘要：** slave 延迟持续增加的原因。**答案：**

-   A) 正确 — master 并发生成事件，但 slave 串行执行，导致延迟。这是导致复制延迟增长的常见原因之一，尤其在 **slave 没有启用并行复制** 的情况下。主库可以并行执行事务，但默认情况下，**从库按顺序执行事务**。
-   E) 正确 — master 忙碌时不能及时传输 binlog，slave 被迫等待。即使启用了并行复制，如果并行线程因锁冲突而阻塞，也会导致 `Seconds_Behind_Master` 持续增长。

错误：

-   B/ `Seconds_Behind_Master` 表示从库 **SQL线程延迟**（不是 I/O 线程）。I/O 是在接收 relay log，真正的延迟通常是 SQL 执行的延迟。 I/O 延迟≠SQL线程延迟
-   C/。这可能会影响性能，但并不会直接导致 `Seconds_Behind_Master` 持续增长，除非与 SQL 执行效率极度相关。但它不是主要或普遍原因。
-   D) 错误 — 如果 `Slave_IO_Running=Yes`，说明从库正在正常接收数据，**主库忙不会导致 Seconds\_Behind\_Master 增长**，反而会减少延迟。  
    **扩展知识点：**
-   `Seconds_Behind_Master` 表示 slave SQL 线程延迟。
-   增加 `slave_parallel_workers` 可改善延迟。

---

### 试题 17【binlog 在复制中的角色】

**题干摘要：** binlog 在异步复制中的作用。**答案：**

-   C) 正确 — binlog 描述 master 上数据变更事件。
-   D) 正确 — binlog 由 slave 拉取。
-   A/B/E) 错误 — 主动连接是 slave 发起，不记录所有 query，仅记录 DML/DDL 等。  
    **扩展知识点：**
-   binlog 格式包括：ROW、STATEMENT、MIXED。

---

### 试题 18【MySQL 安全关机方式】

**题干摘要：** 安全关闭 MySQL server。**答案：**

-   C) 正确 — `mysqladmin shutdown` 是经典关闭方式。
-   F) 正确 — 使用 systemctl 管理 mysqld。
-   G) 正确 — SQL 层执行 `SHUTDOWN;`
-   A/B/D/E) 错误 — 语法错误或非合法方式。

**扩展知识点：**

-   推荐 `systemctl stop mysqld`，符合 systemd 管理。

---

### 试题 19【InnoDB Cluster 完全宕机恢复】

**题干摘要：** 使用 rebootClusterFromCompleteOutage 的行为。

**答案：**

-   C) 正确 — 不要求所有实例可达。
-   D) 正确 — 实现集群实例的滚动重启。
-   A/B/E/F/G) 错误 — 不是全停重启，不进行重建 quorum，也不只是 start 实例。  
    **扩展知识点：**
-   该命令用于 MySQL InnoDB Cluster 整体宕机后的恢复。
-   一般由 `dba.rebootClusterFromCompleteOutage()` 执行。

  

```sql
D) 它会执行 InnoDB Cluster 实例的滚动重启（正确）
解释：
该命令不会一次性同时重启所有实例，而是一个一个地恢复节点（即 rolling restart）
它会：优先恢复最完整 GTID 的节点,再根据元数据把其他成员逐步重新加入集群

✅ C) 不要求所有实例在命令执行前可达（正确）
解释：
在 complete outage 情况下，允许部分实例暂时无法连接
只要有一个事务最完整的实例，就可以用它作为恢复起点
其他实例可以稍后手动 rejoin 或自动重新加入

❌ 错误选项逐一说明：
A) 它会停止并重启所有实例并初始化 metadata（错误）
❌ 它不会初始化 metadata，而是根据现有 metadata 恢复集群
❌ 不会“一次性”重启所有实例

B) 它只停止并重启所有实例（错误）
❌ 它还会重建 quorum，重选主节点等元数据恢复操作
❌ 并不是单纯的实例重启

E) 它在集群被关闭时重配置集群（错误）
❌ 不正确。该命令仅适用于“complete outage”场景，而不是普通关闭

F) 它选择最少数量实例建立 quorum 并重配置（错误）
❌ 它选择的是“GTID 最完整的实例”作为恢复起点
quorum 是恢复后的副产物，不是选择条件

G) 它只启动所有实例（错误）
❌ 它不仅启动，还包括元数据恢复、状态检测、角色分配等
```
---

### 试题 20【实例安全加强措施】

**题干摘要：** 提升实例安全性。**答案：**

-   A) 正确 — 移除 accounting 目录的 world 权限，防止泄露。
-   F) 正确 — private\_key.pem 文件应为仅 mysql 用户可读。
-   B/C/D/E) 错误 — 错误处理方式或无实际效果。  
    **扩展知识点：**
-   避免密钥文件权限过宽，例如：

```bash
chmod 600 private_key.pem
chown mysql:mysql private_key.pem
```

### 试题 21：General Tablespaces 的使用特性

**题干简要：** 选择关于 general tablespace 的两个正确说法。

**正确答案：**

-   ✅ C) An existing table can be moved into a general tablespace✔ 可通过 `ALTER TABLE ... TABLESPACE ts_name` 把已有表移入 general tablespace。
-   ✅ E) A new table can be created explicitly in a general tablespace✔ 可通过 `CREATE TABLE ... TABLESPACE ts_name` 创建新表并指定表空间。

**错误项说明：**

-   ❌ A) 不支持 temporary tables。通用表空间（General tablespace）仅支持永久表，不支持临时表或 undo。
-   ❌ B) 删除表不会释放表空间回操作系统。
-   ❌ D) 一个 general tablespace 只能有一个数据文件。

**扩展：**

```sql
CREATE TABLE t1 (...) TABLESPACE ts1;
```

适用于归类管理或压缩磁盘文件路径。

---

### 试题 22：Group Replication 中 clone 方法的要求

**题干简要：** 使用 clone 方法将实例加入集群的行为。

**正确答案：**

-   ✅ B) InnoDB tablespaces outside datadir are cloned✔ 自定义表空间路径的表也会复制至目标机器相同路径。
-   ✅ C) 目标实例需存在，执行 clone 后加入集群✔ clone 实质是远程复制数据。
-   ✅ D) 需要 BACKUP\_ADMIN 权限✔ clone 过程需要备份权限。

**错误项说明：**

-   ❌ A) 并非一定比 incremental 慢。
-   ❌ E/F) 有关实例安装初始化或 redo 日志的误导性描述。

❌ **A)** “It is always slower than recoveryMethod: 'incremental'.”→ 不一定，取决于数据量和网络环境。

❌ **E)** “A new instance is installed, initialized, and provisioned...”→ `clone` 方式要求目标实例已经存在（即必须预先部署并初始化），然后才会被克隆数据。

❌ **F)** “InnoDB redo logs must not rotate...”→ 在 clone 模式下，InnoDB redo log 的旋转不会导致克隆失败，这个是错误理解。

  

### ​试题 23：MySQL System database 的内容

-   A) ✅ time zone information and definitions→ `mysql.time_zone` 系列表用于处理 CONVERT\_TZ 等函数。
-   B) ✅ help topics→ `mysql.help_topic` 表包含 `HELP` 命令内容。
-   C) ✅ plugins→ 插件信息记录在 `mysql.plugin` 表中。

错误选项分析：

-   D) **audit log events** ❌  
    这些日志不是默认存储在 `mysql` 数据库，而是特定插件（如 Enterprise Audit Plugin）写入专用日志或表。
-   E) **performance monitoring information** ❌  
    这类信息属于 `performance_schema` 而不是 `mysql` 数据库。
-   F) **rollback segments** ❌  
    这些属于 InnoDB 的内部存储结构，不在 `mysql` 系统数据库中。
-   G) **information about table structures** ❌  
    表结构信息主要由数据字典管理（MySQL 8.0 以后存储在系统表空间中），而不是显示在 `mysql` 数据库中。

✅ 正确答案详解：

-   `mysql` 数据库是 MySQL 自带的一个系统数据库，默认包含以下内容：

-   用户账户与权限（`user`, `db`, `tables_priv` 等表）
-   插件（如 authentication 插件）
-   帮助主题（`help_topic`, `help_category` 等）
-   时区定义数据（如 `time_zone`, `time_zone_name`, `time_zone_transition` 等）

### ​试题 24：**redo log rotate**

InnoDB 会将写操作记录到 **redo log（重做日志）** 中，redo log 是环形结构（circular buffer）。当日志写到末尾后，会“回绕”覆盖旧的部分（即 rotate）。这称为 **redo log rotation**。

-   A) FLUSH HOSTS executed ❌  
    仅刷新 host 缓存（如 host\_cache 表），与 binlog 无关。
-   B) max\_binlog\_size exceeded ✅  
    达到 `max_binlog_size` 会自动生成新 binlog 文件。
-   C) max\_binlog\_cache\_size exceeded ❌  
    控制单事务 binlog 缓冲，不触发 binlog 轮转。
-   D) SET sql\_log\_bin = 0 executed ❌  
    关闭当前 session 的 binlog 功能，不触发轮转。
-   E) SET sync\_binlog = 1 executed ❌  
    设置 binlog 同步频率，对轮转无影响。
-   F) FLUSH LOGS executed ✅  
    显式调用 `FLUSH LOGS` 会关闭并新建 binlog 文件。

---

### ​ 试题 25：关于 MySQL Replication 的 GTID 特性

**正确答案：**

-   ✅ C) 每个实例需要唯一 server-id
-   ✅ F) 可通过 TCP/IP 通信
-   ✅ G) 主库必须开启 binary log 才能同步

**错误项说明：**

-   ❌ A) 从库可共用用户账号，不强制唯一
-   ❌ B) 无需对表赋 SELECT 权限
-   ❌ D/E) master 可有多个 slave，binlog 可混合来源（如 group replication）

---

### ​试题 26：如何提高性能（写多、无备份）

**环境背景：**

-   数据库 19G，无备份、无复制。
-   rollback 多（8540 万 vs 123 万 commit）
-   innodb\_flush\_log\_at\_trx\_commit=2
-   disable-log-bin（未开启二进制日志）
-   disk 为瓶颈

**正确答案：**

-   ✅ D) `innodb_doublewrite=0`  
    ✔ 关闭双写缓存，减少磁盘写入。
-   ✅ F) `innodb_log_file_size=1G`  
    ✔ 增大 redo log，减少 checkpoint 写盘频率。

**错误项说明：**

-   A) ❌ sync\_binlog=0 已经无效，因为 binlog 被禁用了。
-   B) ❌ buffer\_pool\_size=24G 升级收益有限，因为已有大量空页。
-   C) ❌ flush\_log\_at\_trx\_commit=1 会增加 I/O，当前目标是减少写盘。
-   E) ❌ max\_connections=10000 与性能无直接关系。

**扩展建议：**

-   进一步可提升 `innodb_write_io_threads` 等并发参数

---

## ✅ 试题 27：MySQL Enterprise Firewall 的 RESET 模式

**正确答案：**

-   ✅ C) 删除用户白名单规则
-   ✅ G) 关闭防火墙模式

**错误项说明：**

-   ❌ A/B/D/E/F) RESET 不做学习、不记录、不启用防护。
-   A) ❌ 用户不会从 mysql.user 表中删除。
-   B) ❌ MYSQL\_FIREWALL\_WHITELIST 表不会整体被清空，只清除该用户相关项。
-   D) ❌ firewall\_users 表不会被 truncate。
-   E) ❌ firewall 不会恢复默认值。
-   F) ❌ 不会设置为 DETECTING 模式。

**相关命令：**

```sql
CALL mysql.sp_set_firewall_mode('user@host', 'RESET');
```
---

## ✅ 试题 28：权限最小化测试 UPDATE 权限

**背景：**  
用户只拥有 `UPDATE(Name)` 权限。

**正确答案：**

-   ✅ B) `UPDATE ... LIMIT 1;`
-   ✅ D) `UPDATE ... SET Name='xx';`

**错误项说明：**

-   ❌ A/C/E) 涉及 `SELECT` 或 `WHERE`，权限不够。
-   A) ❌ CONCAT 需要 SELECT 权限。
-   C) ❌ ORDER BY 隐含了读取 Name。
-   E) ❌ WHERE 需要读取 Name。

---

## ✅ 试题 29：Group Replication 网络分裂后处理

**正确答案：**

-   ✅ B) 手动重新设定 quorum
-   ✅ D) 停止复制并排查网络

**错误项说明：**

-   ❌ A/C/E) 不会自动调整；semi-sync 与 group replication 无关。
-   A) ❌ 在线节点不会缓存事务。
-   C) ❌ 不会自动关闭 cluster。
-   E) ❌ 不会自动修改 IP 白名单。

从图中信息可知，这是一个 **MySQL Group Replication** 的节点状态列表，展示了 5 个节点中：

-   **2 个 ONLINE**
-   **3 个 UNREACHABLE**

问题是：关于网络分区（network partitioning），下面哪些陈述是正确的？

---

✅ 正确选项：D

-   当前这种情况可能是发生了**网络分区（split-brain）**：有两个不同的子集组都认为自己是有效集群（2节点、3节点）。
-   这种情况是 **Group Replication 的网络分裂问题**，需要人工干预来防止数据不一致。

B

-   Group Replication 遇到网络分区时不会自动决定主集群，必须由管理员指定哪个 group 是“主”。
-   需要使用 `group_replication_force_members` 来强制指定组成合法 group 的成员。

❌ 错误选项解析：

✖️ A) The group replication will buffer the transactions on the online nodes until the unreachable nodes return online.

-   错误：Group Replication 不会无限缓存事务，它需要多数派才能继续执行写操作。
-   如果未达多数节点（majority），会阻塞写操作。

✖️ C) The cluster will shut down to preserve data consistency.

-   错误：Group Replication 不会自动 shutdown，而是会**阻止写入**以防止数据分裂，保持一致性。

✖️ E) The cluster has built-in high availability and updates group\_replication\_ip\_whitelist to remove the unreachable nodes.

-   错误：`group_replication_ip_whitelist` 不是自动更新的，需要人工配置。

---

## ✅ 试题 30：InnoDB 表空间加密行为

**正确答案：**

-   ✅ A) 支持索引加密
-   ✅ B) 加密数据需解密后再加载进内存

**错误项说明：**

-   ❌ C) BLOB 也支持加密
-   ❌ D) 并不加密网络
-   ❌ E) 无需应用层支持

---

## 试题 31【MySQL Enterprise Firewall 特性】

**题干摘要：** 哪些说法关于 MySQL Enterprise Firewall 是正确的？

-   **A) On Windows systems, it is controlled via Internet Connection Firewall control panel.** ❌  
    → 错误，MySQL Enterprise Firewall 是通过 SQL 语句管理的，不依赖 Windows 防火墙。
-   **B)** **✅** `**mysql.firewall_users**` **和** `**mysql.firewall_whitelist**` **提供持久存储。**  
    → 这是该插件的核心系统表，用于记录用户及其允许的 SQL 模式。
-   **C)** **✅** **只有 Enterprise 版本提供**  
    → 社区版不包含 Enterprise Firewall。
-   **D)** **✅** **INFORMATION\_SCHEMA 提供视图访问防火墙数据**  
    → 有 `information_schema.MYSQL_FIREWALL_USERS`, `MYSQL_FIREWALL_WHITELIST`。
-   **E) Firewall depends on SHA-256 and ANSI-specific functions** ❌  
    → 防火墙依赖 SQL 学习，不依赖加密函数或 ANSI 特性。
-   **F) 仅显示外部攻击的连接通知** ❌  
    → Firewall 能对所有来源的异常语句阻断，不限外部连接。

**正确答案：**

-   ✅ B) `mysql.firewall_users` 和 `mysql.firewall_whitelist` 是用于持久化白名单配置的系统表。
-   ✅ C) 该功能**仅限于 Enterprise 版本**，Community 版本不支持。
-   ✅ D) 提供 `INFORMATION_SCHEMA` 视图用于查看防火墙数据（如拦截次数、可疑 SQL 等）。

**错误项说明：**

-   ❌ A) 与 Windows 的 Internet Firewall 无关。
-   ❌ E) 防火墙功能**不依赖于 SHA256 或 ANSI 特性**。
-   ❌ F) 被拦截的连接**不限于外部域名来源**。

📌 **拓展说明：**

-   常用操作：

```sql
CALL mysql.sp_set_firewall_mode('user@host', 'DETECTING');
CALL mysql.sp_reload_firewall_whitelist();
```
---

## ✅ 试题 32【一致性视图的存储引擎】

**题干摘要：** 哪两个存储引擎支持一致性视图（consistent view）？

**正确答案：**

-   ✅ A) `InnoDB`：支持多版本并发控制（MVCC），事务隔离等级高。
-   ✅ E) `NDB`（MySQL Cluster）：使用分布式事务协议保持一致性。

**错误项说明：**

-   ❌ B) `ARCHIVE`：只能追加，不能更新，适用于日志。
-   ❌ C) `MyISAM`：无事务、不支持一致性读。
-   ❌ D) `MEMORY`：不支持事务。

---

## ✅ 试题 33【安全性最佳实践】

**题干摘要：** 创建安全 MySQL 服务器环境的三项要求是？

**正确答案：**

-   ✅ B) 限制操作系统用户访问权限
-   ✅ C) 文件权限必须正确配置（如 mysql 用户对数据目录的读写）
-   ✅ D) 保持所有组件在同一台操作系统主机上，减少跨主机攻击面

**错误项说明：**

-   ❌ A) 非 MySQL 进程虽会影响资源，但不是首要安全问题
-   ❌ E) 文件系统加密不能替代精确权限控制
-   ❌ F) MySQL 不应以 root 用户身份运行！

---

## ✅ 试题 34【二进制日志与备份】

**题干摘要：** 执行以下命令：

```sql
mysqldump --delete-master-logs --all-databases > /backup/db_backup.sql
```

哪些说法正确？

**正确答案：**

-   ✅ A) 所有数据库已被备份至输出文件。
-   ✅ B) 所有**非活跃的 binary logs** 被删除（即当前不再使用的 binlog 文件）。

**错误项说明：**

-   ❌ C) binlog 内容不会被备份；
-   ❌ D) 当前活跃 binlog 不会删除；
-   ❌ E/F) 备份文件不含 metadata 或删除日志的记录信息。

📌 扩展命令：

```sql
SHOW BINARY LOGS;
PURGE BINARY LOGS TO 'binlog.000300';
```
---

## ✅ 试题 35【tarball 安装 MySQL】

**题干摘要：** 从 tarball 安装 MySQL 到 `/app/mysql/`，你希望配置并运行服务。

**正确答案：**

-   ✅ A) 创建 `mysql` 用户并修改 data 目录属主
-   ✅ D) 使用 `mysqld --initialize` 初始化数据库
-   ✅ F) 使用 `--basedir` 和 `--datadir` 参数启动服务

**错误项说明：**

-   ❌ B/C/E) 描述错误或语义不清。

**正确选项：A、B**

-   **A)** **✅** **basedir=/app/mysql**  
    → 指向 MySQL 安装根目录（包含 bin、lib 等）。
-   **B)** **✅** **datadir=/app/data**  
    → 指定数据存储目录，即 ibdata、ib\_logfile 等存放处。

**错误选项说明：**

-   **C) log-bin 配置与备份无关** **❌**
-   **D) datadir=/app/mysql/data** **❌**  
    → 实际是 /app/data，不一致。
-   **E) innodb\_log\_group\_home\_dir 必需** **❌**  
    → 默认为 datadir，可以不设置。
-   **F) basedir=/app/mysql/bin** **❌**  
    → 错误，应是父目录 `/app/mysql`。

**扩展命令：**

```sql
groupadd mysql && useradd -r -g mysql mysql
chown -R mysql:mysql /app/mysql
/app/mysql/bin/mysqld --initialize --user=mysql
```
---

## ✅ 试题 36【MyISAM 表恢复】

恢复过程：

1.  **删除表**
2.  **拷贝** `**.MYD**``**.MYI**` **文件**
3.  **复制** `**.sdi**` **到** `**secure_file_priv**`
4.  `**IMPORT TABLE FROM**` **执行恢复**

-   **A)** **✅** **拷贝 customers.sdi 到 /var/tmp（secure\_file\_priv 允许目录）**
-   **D)** **✅** **执行** `**IMPORT TABLE FROM**` **指向 .sdi 文件**

**错误选项：**

-   **B)** ❌ **不应将 sdi 放入数据目录，会破坏恢复路径。**
-   **C)** ❌ `**SOURCE**` **是运行 SQL 文件的，不支持 sdi。**
-   **E)** ❌ **MyISAM 表无** `**.frm**` **恢复需求。**
-   **G/H)** ❌ `**IMPORT TABLESPACE**` **仅适用于 InnoDB。**

---

## ✅ 试题 37【内存足够，SELECT 语句慢，分析瓶颈。】

**题干摘要：** 你在调查 MySQL 的性能问题。所有数据都在内存中（数据量小或 buffer\_pool 充足）。你发现某张表的 `SELECT` 查询导致响应时间缓慢。问题是：**以下哪两个选项最有可能是性能瓶颈的根源？**

**正确答案：**

-   **A) high concurrency** ✅高并发场景下，多个线程同时访问同一表，会引发：

-   表级锁（如 MyISAM）
-   行锁竞争（如 InnoDB）
-   CPU 上下文切换、mutex 等同步开销
-   解决方法：查看 `SHOW PROCESSLIST`，启用并发执行计划或使用读写分离。

-   **E) non-transactional storage engine** ✅  
    → 比如使用 **MyISAM** 引擎时：

-   没有缓存机制（buffer\_pool）
-   没有 MVCC
-   只有表级锁
-   大量并发读写容易堵塞
-   建议迁移到 InnoDB 或考虑使用缓存中间件（如 Redis）

**错误项说明：**

-   **B) operating system resources** ❌  
    → 题干中说了“所有数据 fits in memory”，说明系统 I/O 不是瓶颈。
-   **C) column definitions** ❌  
    → 列定义不太可能导致大范围性能问题，除非用了 TEXT/BLOB 且没索引。
-   **D) InnoDB mutexes** ❌  
    → 虽然 mutex 是 InnoDB 中的并发控制手段，但并非常规 SELECT 查询中最常见瓶颈。
-   **F) table indexes** ❌  
    → 题干未说没有索引，而是数据都在内存中，意味着索引已加载，影响不大。

---

## ✅ 试题 38【半同步复制（semi-sync）】

**题干摘要：** 你启用了 **半同步复制（semi-sync）**，只有一个 slave。主库磁盘故障，数据彻底丢失。你确认 `rpl_semi_sync_master_timeout`**未被触发过**。  
**以下哪些是正确的判断？**

**正确答案：**

-   **C) No committed transactions are lost** ✅  
    → 半同步复制的原则：

-   事务 **必须** 至少被一个 slave 确认写入 relay log，master 才会提交。
-   所以，只要 master 能 commit，说明 slave 一定收到了。

-   **D) Reads from the slave can return outdated data for some time, until it applies all transactions from its relay log** ✅  
    → 虽然 slave 有最新事务日志（relay log），但可能**还没应用**。

-   应该等待 SQL 线程 replay 完成后才读数据。

📌 建议规则：

-   每个实例 ≥1G，否则浪费资源；
-   如果 buffer pool 较大（如 64G），推荐设为 8～16。

错误选项：

-   **A) Slave 自动升主** ❌  
    → 不会，MySQL 不支持自动故障转移（需使用 MHA、Orchestrator、Group Replication 等）
-   **B) rpl\_semi\_sync\_master\_timeout 控制 slave 的读延迟** ❌  
    → 这个参数只在 master 控制是否转为异步模式，与 slave 无关。
-   **E) 少量事务可能丢失** ❌  
    → 在半同步中，只要 commit 成功就确保 relay log 已写入。
-   **F) 应用可立即读 slave 数据，且完全一致** ❌  
    → slave 还没应用 relay log 前，数据是落后的。

---

## ✅ 试题 39【文件系统快照备份】

正确选项：

-   **A) There is a slight performance cost while the snapshot is active** ✅  
    → 写时复制（copy-on-write）技术会略微影响性能，因为要复制数据页。
-   **B) The backup window is almost zero from the perspective of the application** ✅  
    → 快照操作几乎是瞬时完成的，适合高可用环境。
-   **F) They work best for transactional storage engines that can perform their own recovery when restored** ✅  
    → 如 InnoDB 支持 crash recovery，适合快照恢复。

---

错误选项：

-   **C) They allow direct copying of table rows with OS copy commands** ❌  
    → 表行不能随便复制；必须结合表结构和元数据。
-   **D) They do not back up views, stored procedures, or configuration files** ❌  
    → 快照能备份数据文件所在目录，**只要这些结构在数据文件中**（如 mysql 库），是会被备份的。
-   **E) They take roughly twice as long as logical backups** ❌  
    → 快照比逻辑备份快得多，除非数据极大。
-   **G) They do not use additional disk space** ❌  
    → 写时复制机制在修改数据时会占用额外空间。

---

## ✅ **第40题：Choose two**

**题干**：你想查看 `manufacturing.parts` 表上的所有索引。你会用哪个命令？

正确选项：

-   **C) DESCRIBE manufacturing.parts** ✅  
    → 显示每一列是否是主键或有索引，但不详细。
-   **D) SHOW INDEXES FROM manufacturing.parts** ✅  
    → 最全面的索引查看方式，输出包括：

-   索引名、列、是否唯一、Cardinality（基数）、是否可见等。

---

错误选项：

-   **A)** ❌ 没有这个选项→ 应为 `SHOW INDEX FROM ...`
-   **B) SELECT FROM information\_schema.statistics WHERE ...** ❌  
    → 此查询写法不完整，字段应包括 table\_schema、table\_name，语法错误。
-   **E) SELECT \* FROM information\_schema.COLUMN\_STATISTICS** ❌  
    → 该表用于统计列的值分布（例如 JSON 直方图），**不是索引信息**

**题干摘要：** 关于使用文件系统快照（如 LVM snapshot）备份 MySQL，哪些说法正确？

**正确答案：**

-   ✅ A) 备份期间性能有轻微下降
-   ✅ B) 对于业务而言，备份窗口几乎为 0
-   ✅ F) 快照最适用于支持自我恢复（如 crash recovery）的存储引擎（如 InnoDB）

**错误项说明：**

-   ❌ C) 不允许直接 copy 行数据
-   ❌ E) 不一定比逻辑备份慢，通常更快
-   ❌ G) 快照可能占用额外空间（写时复制）

---

## ✅ 试题 40【查看表的索引定义】

**题干摘要：** 显示 `manufacturing.parts` 表索引的方式有哪些？

**正确答案：**

-   ✅ C) `DESCRIBE manufacturing.parts;`（简要索引信息）
-   ✅ D) `SHOW INDEXES FROM manufacturing.parts;`（详细索引信息）

**错误项说明：**

-   ❌ B/E) 查询 `information_schema.statistics` 需确保字段拼写正确，否则查询无效

​  

## 试题 41：数据目录权限过宽的风险

**题干摘要：** datadir 被错误地设置为 world-readable/writable/executable，有哪些风险？

**正确答案：**

-   ✅ A) 数据文件可能会被删除。✔ 任何用户有写权限，即可删除数据文件，如 `.ibd`, `.frm`, `.ibdata1`，将导致数据库无法启动或数据永久丢失。
-   ✅ B) 配置文件可能会被覆盖。✔ 如 `/etc/my.cnf`、`mysqld-auto.cnf` 等被非法修改，可能导致服务无法启动或行为异常。

**错误项说明：**

-   **C) SQL injections could insert bad data.** ❌  
    → 这是应用层问题，和文件系统权限无直接关系。
-   **D) Extra startup time would be required for the MySQL server to reset the privileges.** ❌  
    → MySQL 启动时不会自动“恢复”文件权限，权限错误只会导致启动失败。
-   **E) MySQL binaries could be damaged, deleted, or altered.** ❌  
    → 这通常影响的是 basedir（安装目录），而不是 datadir（数据目录）。

**扩展建议：**

```sql
chmod -R 750 /var/lib/mysql
chown -R mysql:mysql /var/lib/mysql
```
---

## ✅ 试题 42：Group Replication 的基本要求【官方参考】

**正确答案：**

-   **C) slave updates logging** ✅  
    → `log_slave_updates` 必须开启，确保 relay log 事务被写入 binlog，便于 group replication 同步。
-   **E) primary key or primary key equivalent on every table** ✅  
    → 所有表必须有主键，否则无法基于 ROW 格式复制。
-   **G) binary log ROW format** ✅  
    → Group Replication 只支持 ROW 格式 binlog，不支持 STATEMENT 或 MIXED。

**错误项说明：**

-   **A) replication filters** ❌  
    → 不支持复制过滤器（如 `replicate-ignore-db` 等），为了保持强一致性。
-   **B) semi-sync replication plugin** ❌  
    → Group Replication 不依赖 semi-sync plugin，它有自己协议。
-   **D) binary log checksum** ❌  
    → 非强制要求，可以启用以增强可靠性，但不是 Group Replication 的前提。
-   **F) binary log MIXED format** ❌  
    → 如前所述，只支持 `binlog_format=ROW`。

**扩展说明：**  
[官方文档 Group Replication Requirements](https://dev.mysql.com/doc/refman/8.0/en/group-replication-requirements.html)

---

## ✅ 试题 43：mysqld 启动失败的诊断

**日志信息关键点：**

-   `Operating system error number 2`
-   `Cannot find the path specified`
-   `InnoDB does not create directories`

**正确答案：**

-   **A) the configuration file for correct datadir setting** ✅  
    → 日志已提示找不到某路径，很可能配置文件中的 `datadir` 设置错误或路径不存在。
-   **E) check if missing files are in other locations** ✅  
    → 也可能文件误被移动到其他位置或意外删除。

**错误项说明：**

-   ❌ B) MySQL 版本与路径无关
-   ❌ C) 与 TLS 证书无关
-   ❌ D) 文件锁定并非常见原因
-   ❌ F) 用户认证无关错误码 2

---

## ✅ 试题 44：再次考察 Group Replication 的依赖条件

**正确答案（重复验证）：**

-   ✅ A) 所有表必须有主键
-   ✅ C) binlog 使用 ROW 格式
-   ✅ G) 启用 slave updates logging（即 `log_slave_updates=ON`）

**错误项说明与试题 42 一致：** replication filters、MIXED 格式、semi-sync、checksum 全部不是必须的

---

## ✅ 试题 45：Raw Binary Backups 的特性

**正确答案：**

-   ✅ D) 备份格式与磁盘数据完全一致
-   ✅ E) 速度快，因为是物理层直接复制，无需解析 SQL 或逻辑结构

**错误项说明：**

-   **A) 转换为高度压缩格式** ❌  
    → raw 备份不会主动转换格式，逻辑备份如 `mysqldump` 才可配合压缩。
-   **B) FIPS 安全认证必须使用 raw 备份** ❌  
    → FIPS 是关于密码算法合规，不规定备份方式。
-   **C) 备份结果人类可读** ❌  
    → `.ibd`、`.frm`、`.sdi` 等文件不是文本，必须配合 MySQL 引擎解析。

---

## ✅ 试题 46：判断是否使用 Hash Join 的方法

**正确答案（根据文档推测）**：

-   ✅ A) `EXPLAIN FORMAT=JSON`

会显示是否使用了 `"join_type": "hash_join"`，是判断 Hash Join 的推荐方式。

-   ✅ C) `EXPLAIN FORMAT=TREE` 执行并分析实际执行计划，明确指出是否使用了 Hash Join。

这些格式能显示 Join 类型，包括是否使用 Hash Join（MySQL 8.0.18+ 支持）。

错误选项：

-   **B)** `**EXPLAIN FORMAT=TRADITIONAL**` ❌  
    → 传统 EXPLAIN 仅展示 Nested Loop 结构，不区分 Hash Join。
-   **C)** `**EXPLAIN FORMAT=TREE**` ❌  
    → 显示查询树，但不明确指出 Join 类型。
-   **D) 不带参数的** `**EXPLAIN**` ❌  
    → 和 B 类似，不提供足够细节来判断 Join 类型。

---

## ✅ 试题 47：恢复 GTID 的报错处理

**背景：**  
恢复过程中提示 `Cannot update GTID_PURGED with the Group Replication plugin running`

**正确答案：**

-   ✅ E) 从 dump 文件中删除 `SET @@GLOBAL.GTID_PURGED=...`
-   ✅ F) 备份时使用 `--set-gtid-purged=OFF`

**扩展说明：**  
Group Replication 模式下不能手动设置 GTID\_PURGED，必须绕过

错误选项：

-   **A) 卸载 Group Replication 插件** **❌**  
    → 代价过大且没必要。
-   **B) 删除** `**gtid_executed**` **❌**  
    → 非法操作，`gtid_executed` 是只读变量。
-   **C) 只保留 primary 实例运行并恢复** **❌**  
    → 并不能解决 GTID 语句写入的问题。
-   **D) 使用** `**--set-gtid-purged=OFF**` **恢复** **❌**  
    → 这是生成备份时用的参数，不能用于 `mysql` 命令执行恢复。

---

## ✅ 试题 48：InnoDB 表空间类型

**正确答案：**

-   **A) data tablespaces** ✅  
    → 这是最基本的 InnoDB 表空间类型，用于存储数据页（B+树、聚簇索引等）

-   例如：`ibdata1`（共享表空间）或每个表的 `.ibd` 文件（独立表空间）

-   **B) schema tablespaces** ❌  
    → **不存在**这种表空间类型，schema 是逻辑概念，不是物理表空间
-   **C) redo tablespaces** ❌  
    → 虽然 redo log 是 InnoDB 的一部分，但它们不被称为 “tablespaces”，而是日志文件（如 `ib_logfile0`）
-   **D) temporary table tablespaces** ✅  
    → MySQL 8.0+ 中会为 **临时表** 创建独立表空间，存储在 `#innodb_temp` 目录下
-   **E) undo tablespaces** ✅  
    → undo log 可以存储在专用的 undo 表空间中（如 `undo_001`, `undo_002`），也可存在系统表空间内
-   **F) encryption tablespaces** ❌  
    → InnoDB 表空间可以被加密，但**加密不是表空间类型**，只是属性

InnoDB 表空间主要有这些类型：

-   数据表空间（data）
-   Undo 表空间
-   临时表空间（temporary）
-   系统表空间（System tablespace，通常为 `ibdata1`）

---

## ✅ 试题 49：优化延迟高的语句

**题干给出** `**sys.statement_analysis**` **的表格数据，需选择两个 avg\_latency 高的语句。**

**降低查询执行时间（execution time）**

**也就是看哪个查询 avg\_latency 高，即使 exec\_count 低也值得优化**

**正确答案：**

-   ✅ C) QN=4
-   ✅ E) QN=5

**分析：**  
应优先优化执行时间最长（avg\_latency 高）、而不是仅执行次数多的语句

---

## ✅ 试题 50：mysqldump 与 GTID\_PURGED 冲突

**正确答案：**

-   ✅ E) 删除 `SET @@GLOBAL.GTID_PURGED` 语句
-   ✅ F) 创建备份时用 `--set-gtid-purged=OFF`

**错误项说明：**

-   ❌ A–D) 与 Group Replication 冲突或语义错误，无法解决问题

​  

## 试题 51：实现 GTID 复制的步骤【GTID Replication】

**正确答案：**

-   ✅ F) `CHANGE MASTER TO MASTER_AUTO_POSITION = 1;`
-   ✅ E) 启动时指定以下参数：

```sql
ini

复制编辑
--gtid_mode=ON 
--log-bin 
--log-slave-updates 
--enforce-gtid-consistency
```

**错误项说明：**

-   ❌ A) `GTID_ENABLED` 不是合法的系统变量，设置会失败。
-   ❌ B/C/D) 操作无效或语法错误。

**扩展说明：**

-   `MASTER_AUTO_POSITION = 1` 可替代传统位置点复制，无需 `file` 与 `position`。
-   所有参与复制的实例需使用相同 GTID 配置。

---

## ✅ 试题 52：使用 RPM 安装 MySQL 的特性

**正确答案：**

-   ✅ E) **首次启动后可在错误日志中找到 root 初始密码**。
-   ✅ F) RPM 安装功能被拆分为多个包，例如 `server`、`client`、`common`。

**错误项说明：**

-   ❌ A) 无需手动初始化，RPM 安装后自动完成。
-   ❌ B) 安装过程不会交互式要求密码。
-   ❌ C/D) 不支持多版本或 relocatable 安装路径。

---

## ✅ 试题 53：`--protocol` 可选协议参数

**正确答案：**

-   ✅ B) `SOCKET`
-   ✅ C) `MEMORY`
-   ✅ D) `PIPE`（Windows）
-   ✅ G) `TCP`

**错误项说明：**

-   ❌ A/E) `IPv4/IPv6` 属于网络层，不是协议参数。
-   ❌ F/H) 不支持的协议关键字。

---

## ✅ 试题 54：MySQL 客户端远程连接选项

**正确答案：**

-   ✅ C) `--host=192.0.2.1`
-   ✅ E) `--user=admin`
-   ✅ F) `--password`
-   ✅ I) `--database=world`

**错误项说明：**

-   ❌ A) 默认端口 3306，通常无需显式声明。
-   ❌ B/D/G/H) 这些参数适用于 socket 或共享内存连接，不适用于 TCP。

---

## ✅ 试题 55：新创建的角色的属性

**正确答案：**

-   ✅ D) 可授予给用户账户
-   ✅ F) 默认创建为 locked 状态
-   ✅ B) 可使用 `DROP ROLE` 删除

**错误项说明：**

-   ❌ A) 没有 `mysql.role` 表
-   ❌ C/E) 不支持设置密码或重命名角色

---

## ✅ 试题 56：根据索引统计推测访问行为

**输出信息：**

-   主键索引 `PRIMARY` 覆盖列 `a`，基数为 72。
-   辅助索引 `b_idx` 基数为 1，说明重复值多。

**正确答案：**

-   ✅ D) `b_idx` 唯一值少，选择性差。
-   ✅ C) 查询 `SELECT b FROM t` 会执行全表扫描。

---

## ✅ 试题 57：关于 `mysqld-auto.cnf` 文件

**正确答案：**

-   ✅ C) **启动流程结束时读取并处理此文件**
-   ✅ D) 文件采用 JSON 格式，用于持久化存储变量

**错误项说明：**

-   ❌ A/B/E/F) 文件不参与日志、server\_uuid 或中间配置流程

---

## ✅ 试题 58：InnoDB 锁类型判定

**题干输出锁状态图**

**正确答案：**

-   ✅ A) 独占锁（Exclusive lock）
-   ✅ C) 行级锁（Row-level lock）

**错误项说明：**

-   ❌ B/D/E/F) 锁并非共享、意图锁、metadata 级别

---

## ✅ 试题 59：释放二进制日志空间

**正确答案：**

-   ✅ E) `SET GLOBAL binlog_expire_logs_seconds = <值>` 后执行 `FLUSH BINARY LOGS`
-   ✅ C) 手动使用 `PURGE BINARY LOGS TO 'xxx';` 立即清理

**错误项说明：**

-   ❌ A/B/D/F) 重启或设置值为 0 无法立即清理；`SET PERSIST` 不会触发日志清理

---

## ✅ 试题 60：数据仓库实例的表空间配置

**关于** `**innodb_data_file_path**` **设置：**

**正确答案：**

-   ✅ A) `ibdata1:12M:autoextend`（合法，推荐）
-   ✅ B) `ibdata1:12M; ibdata2:12M:autoextend`（合法，最后文件可扩展）

**错误项说明：**

-   ❌ C–F) 不符合规范，如多个非 autoextend 文件，或 autoextend 不在最后一项

---

### ✅ 试题 61：紧急释放二进制日志空间的方法

**正确答案：**

-   ✅ A) `PURGE BINARY LOGS TO 'binlog.xxx';`  
    ✔ 立即删除旧日志，是最快清理方式。
-   ✅ B) `SET GLOBAL binlog_expire_logs_seconds=值;` 后执行 `FLUSH BINARY LOGS`  
    ✔ 设置自动过期时间并触发刷新。

**错误选项分析：**

-   ❌ C) 设置后重启不会立刻生效清理日志。
-   ❌ D) `SET PERSIST` 只是保存参数，**不触发日志清理**。
-   ❌ E) 设置为 0 意味**日志永不过期**，反而更危险。
-   ❌ F) 配置文件中设置也不会自动清理已存在的日志。

---

### ✅ 试题 62：复制状态下日志空间控制

**正确答案：**

-   ✅ C) `PURGE BINARY LOGS`  
    ✔ 手动清理已不再需要的日志。
-   ✅ E) 设置 `binlog_expire_logs_seconds`  
    ✔ 让日志自动在一定时间后过期。

**错误选项说明：**

-   ❌ A) `FLUSH LOGS` 只会生成新日志，不删除旧的。
-   ❌ B) 手动删除文件会破坏复制状态，不推荐。
-   ❌ D) 移除 `--log-bin` 会关闭所有日志系统，导致复制不可用。

---

### ✅ 试题 63：三节点 InnoDB Cluster 容错逻辑

**背景：** 集群为 ONLINE，且提示可容忍 1 个节点故障。

**正确答案：**

-   ✅ D) 若有 2 个实例宕机，将导致**服务不可用**
-   ✅ F) 正常关闭两个节点也会导致集群失去法定人数（quorum），触发 outage

**错误项解释：**

-   ❌ A) 网络分区不自动重构集群（无 quorum 不会工作）
-   ❌ B) 多主不会提升容错性
-   ❌ C) 当前 quorum 状态并不稳定（需验证）
-   ❌ E) 重启一个节点不会强制 primary 发生故障转移

【参考】MySQL 官方 Group Replication 容错规则

---

### ✅ 试题 64：默认被锁定的账户类型

**正确答案：**

-   ✅ A) 新创建的角色（ROLE）默认是 locked 状态
-   ✅ B) 系统内部账户（如 mysql.sys）默认锁定，不可登录

**错误项分析：**

-   ❌ C) 若用户名存在但主机为空，MySQL 会报语法错误，而不是锁定。
-   ❌ D) `DEFINER` 语句不影响用户登录状态
-   ❌ E) 未设置密码的用户仍可登录（视认证插件）

---

### ✅ 试题 65：`mysqlpump` 默认排除哪些库

**正确答案：**

-   ✅ C) `information_schema`（只读虚拟库）
-   ✅ E) `sys`（虚拟性能视图，自动忽略）

**错误项说明：**

-   ❌ A/B/D) 这些用户数据库需显式包含才能导出，否则会默认导出全部

---

### ✅ 试题 66：查看当前连接线程的命令

**正确答案：**

-   ✅ B) `performance_schema.threads`（线程级别详细信息）
-   ✅ C) `SHOW FULL PROCESSLIST`
-   ✅ D) `information_schema.processlist`

**错误项说明：**

-   ❌ A) 事务事件信息，非连接
-   ❌ E/G/H/F) 与连接无关，或为 metrics 概要信息、视图分析等

---

### ✅ 试题 67：MySQL Enterprise Monitor 能做什么

**正确答案：**

-   ✅ A) 分析查询性能
-   ✅ C) 检测服务器可用性
-   ✅ H) 创建自定义告警通知

**错误项说明：**

-   ❌ B/E/F/G) 无法启动备份/服务；用户管理和配置不属于其职能范围

---

### ✅ 试题 68：加强网络安全的措施

**正确答案：**

-   ✅ A) 构建 DMZ 网络（隔离内外访问）
-   ✅ B) 在防火墙后部署数据库
-   ✅ F) 限制仅应用服务器能访问 MySQL

**错误项分析：**

-   ❌ C) 使用 NFS 存储会降低安全性
-   ❌ D) 改端口并非安全手段（仅防扫描）
-   ❌ E) Router 是负载均衡工具，不负责防火墙逻辑

---

### ✅ 试题 69：多源复制行为分析

**正确答案：**

-   ✅ F) 多源复制需依赖 `relay_log_recovery` 提升容错性
-   ✅ E) 不自动冲突检测与解决

**错误项说明：**

-   ❌ A) 多源可基于 GTID 也可使用位置点
-   ❌ B) 与 `auto_position` 兼容
-   ❌ C) 宕机后不需要完全重建
-   ❌ D) 不基于时间戳决策冲突

【参考】MySQL 官方多源复制说明

---

### ✅ 试题 70：SQL 性能分析数据解读

**背景：**`sys.statement_analysis` 输出查询延迟分析。

**正确答案：**

-   ✅ C) QN=4 平均执行时间高，需优化
-   ✅ E) QN=5 同样存在性能瓶颈

**错误项说明：**

-   ❌ A/B/D) 执行次数虽多但延迟低，优化收益小

## 试题 71：导出 `world_x` 数据库中多个表的方法

**正确答案：**

-   ✅ A) `mysqldump world_x country countryinfo location > mydump.sql`  
    ✔ 使用 `mysqldump` 是官方推荐的逻辑备份方式。
-   ✅ B) `SELECT * INTO OUTFILE` 分别导出每个表✔ 每个表可单独导出为文本格式文件。

**错误项说明：**

-   ❌ C) `mysqlexport` 工具**不存在**。
-   ❌ D) `CLONE LOCAL DATA DIRECTORY` 不支持这种语法（无效）。
-   ❌ E) `mysql --batch ...` 命令格式错误。

---

## ✅ 试题 72：mysqlbackup 的优势

**正确答案：**

-   ✅ C) 支持虚拟磁带（VTS）与 MMS 集成
-   ✅ D) 支持非锁定的 InnoDB 热备（无阻塞）
-   ✅ F) 支持从物理备份中恢复，速度远快于逻辑备份

**错误项说明：**

-   ❌ A) 不支持部分存储过程备份（只支持数据/表）
-   ❌ B) 并发逻辑备份并不高效（相比逻辑备份无优势）
-   ❌ E) 会备份系统表，不能跳过

【参考】[MySQL Enterprise Backup 文档](https://dev.mysql.com/doc/mysql-enterprise-backup/)

---

## ✅ 试题 73：Group Replication 启用 SSL 通信的配置

**正确答案：**

-   ✅ C) SSL group communication **只能在创建集群时设置**
-   ✅ E) 需要设置 `group_replication_recovery_*` 参数支持 SSL 恢复

**错误项说明：**

-   ❌ A) 不需要销毁已有集群重新创建
-   ❌ B) 如果部分实例启用 SSL，会拒绝连接，而非降级为明文
-   ❌ D) 不能后期逐个节点启用
-   ❌ F) 恢复与通信配置是分开的

---

## ✅ 试题 74：初始化后 root 密码的获取方式

**正确答案：**

-   ✅ B) 初始化时，屏幕提示的 Warning 信息中显示临时密码
-   ✅ C) 错误日志中通过 `--log-error` 设置的文件中写有 root 密码

**错误项说明：**

-   ❌ A) 不存在 `mysql.install` 表
-   ❌ D) 密码不会写入 `/root/.my.cnf`
-   ❌ E) `SHOW PASSWORD` 命令不存在

---

## ✅ 试题 75：增强数据安全性的方式

**正确答案：**

-   ✅ B) 使用防火墙保护的私有网络
-   ✅ E) 将 mysqld 绑定到本地磁盘，使用独立用户运行

**错误项说明：**

-   ❌ A) 不应以 root 身份运行 mysqld
-   ❌ C) 使用网络盘（如 NFS）可能导致安全与一致性问题
-   ❌ D) 不建议仅使用一个管理员账户，权限应细化分权

---

## ✅ 试题 76：二进制日志的作用

**正确答案：**

-   ✅ B) 支持复制机制（replication）
-   ✅ D) 支持 point-in-time recovery（PITR）

**错误项说明：**

-   ❌ A/C/E) 不提供 SQL 执行细节、审计或锁耗时，这些属于 general/slow log 处理

---

## ✅ 试题 77：MySQL Enterprise Firewall 功能

**正确答案：**

-   ✅ A) 通过白名单拦截潜在威胁 SQL
-   ✅ C) 可记录 SQL 语句以生成白名单

**错误项说明：**

-   ❌ B) 不会自动替换 SQL 内容（非 WAF）
-   ❌ D) 不会自动锁定用户账户
-   ❌ E) 非无状态 TCP 3306 层级防火墙，它运行在 SQL 层

---

## ✅ 试题 78：查看表定义的方法

**正确答案：**

-   ✅ C) `mysqldump --no-data schema table`
-   ✅ D) 查询 `INFORMATION_SCHEMA` 视图，如 `COLUMNS`
-   ✅ F) `SHOW CREATE TABLE`

**错误项说明：**

-   ❌ A) `hexdump` 查看 .frm 不再适用于 MySQL 8.0（已废弃）
-   ❌ B) `REPAIR TABLE ... USE_FRM` 不支持 InnoDB 且已移除
-   ❌ E) `SELECT * FROM table \G` 查看的是数据，不是定义

## 试题 79：关于 `mysql_config_editor` 工具的理解

**正确答案：**

-   ✅ B) 它管理客户端程序的配置（如 mysql 客户端）✔ 该工具用于安全地存储用户名、密码、主机名等连接信息。
-   ✅ E) 若不使用 `--login-path` 参数，则默认使用 `client` 连接配置✔ 例如 `mysql --login-path=client`；不指定时等同于使用 `[client]` 段。

**错误项解释：**

-   ❌ A) 它不能修改 `my.cnf`，只是存储在加密文件 `.mylogin.cnf` 中。
-   ❌ C) 无法用于移动 datadir。
-   ❌ D) 不涉及管理用户权限。
-   ❌ F) 与 Enterprise Firewall 毫无关系。
-   ❌ G) 它不能生成 SSL 证书或设置日志路径。

**补充命令：**

```sql
bash

复制编辑
mysql_config_editor set --login-path=client --user=root --password
mysql --login-path=client
```
---

## ✅ 试题 80：MySQL Enterprise Monitor 的无代理监控特性

**题干摘要：** 使用 **Agentless（无代理）方式**安装 MySQL Enterprise Monitor，以下哪些功能可用？

**正确答案：**

-   ✅ B) 与安全相关的 Advisor 提示
-   ✅ E) MySQL 查询分析（Query Analysis）数据
-   ✅ A) 复制监控（Replication Monitoring）

**错误项解释：**

-   ❌ C/F/G) 无法获取操作系统级别资源数据（CPU、内存、网络）
-   ❌ D) 无法提供详细的磁盘性能与告警信息

**总结：**  
Agentless 模式仅能读取数据库内部状态，无法访问操作系统相关指标

​  

​  

### 试题 83：逻辑升级 vs. 物理升级的区别

**正确答案：**

-   ✅ E) 逻辑升级后表的存储占用通常小于物理升级✔ 因为 mysqldump 导出的 SQL 会重建表结构并清理碎片。
-   ✅ F) 物理升级数据就地保留，而逻辑升级需从 SQL 备份恢复✔ 逻辑升级类似于备份/重建数据库，物理升级则保留原数据。

**错误选项解释：**

-   ❌ A) 逻辑升级不一定快，通常慢于物理升级
-   ❌ B) 物理升级仍需重启 mysqld，尤其要确保 InnoDB 数据文件兼容
-   ❌ D) 通常物理升级会残留更多老数据页/碎片，导致空间大

---

### ✅ 试题 84：数据目录权限过宽的影响

**正确答案：**

-   ✅ D) 数据文件可能被删除✔ 若 `datadir` 为 world-writable，攻击者可直接删除 `.ibd` 文件等。
-   ✅ E) 配置文件可能被覆盖✔ 如 `mysqld-auto.cnf`、`my.cnf` 被篡改可能导致服务崩溃或数据泄露。

**错误项解释：**

-   ❌ A) MySQL 不会在启动时重设权限
-   ❌ C) SQL 注入为逻辑层问题，与文件权限无直接关联
-   ❌ B) 可执行权限不会影响 MySQL 二进制文件（这些通常在 basedir）

---

### ✅ 试题 85：MySQL 表结构变更的处理机制

**正确答案：**

-   ✅ A) 有些 DDL 可以使用“即时变更”而不锁表（如 `ADD COLUMN`）  
    ✔ 从 8.0 起支持更多 online DDL。
-   ✅ B) 表结构变更后信息会被写入数据字典✔ InnoDB 使用数据字典（data dictionary）和 .SDI 文件存储元信息。

---

### ✅ 试题 86：哪些是全局共享 buffer（MySQL server 级别）

**正确答案：**

-   ✅ B) `innodb_buffer_pool_size`  
    ✔ InnoDB 数据页缓冲，所有线程共享。
-   ✅ C) `table_open_cache`  
    ✔ 控制系统最多缓存多少打开表（共享缓存池）。
-   ✅ E) `key_buffer_size`  
    ✔ MyISAM 的索引缓冲池。

**错误项解释：**

-   ❌ A/F/D) `tmp_table_size`、`read_buffer_size`、`sort_buffer_size` 均为每个线程独立分配，不是全局 buffer。

​  

​  

​  

​  

​  

### ✅ 试题 101

**题干摘要：**  
数据为临时性，无需备份或复制，实例性能差。buffer pool 有 20G，系统内存为 32G，有高磁盘 IO 压力。

**答案：D、F**

-   **D) innodb\_doublewrite=0** ✅

-   关闭 doublewrite buffer 可以减少磁盘写入次数，提高性能，但存在宕机崩溃时页部分写入风险。因为题目强调“无数据持久性要求”，此设置是合理的。

-   **F) innodb\_log\_file\_size=1G** ✅

-   增大 redo log 文件可减少 checkpoint 频率，降低磁盘 IO 压力。

**错误项分析：**

-   **A) sync\_binlog=0** ❌

-   当前未启用 binlog（disable-log-bin），该设置无意义。

-   **B) buffer\_pool\_size=24G** ❌

-   当前 buffer\_pool 为 20G，虽然可以适当增加，但不是最优策略，相比之下 D、F 对性能提升更大。

-   **C) innodb\_flush\_log\_at\_trx\_commit=1** ❌

-   会增加磁盘写频率，加剧磁盘压力，当前已设置为 2，比较适中。

-   **E) max\_connections=10000** ❌

-   无关设置，只会增加连接数上限，与当前性能问题无直接关系。

---

### ✅ 试题 102

**题干摘要：**  
已有账号 joe，授予了所有权限，如何阻止其登录。

**答案：A、E**

-   **A) ALTER USER 'joe'@'%' ACCOUNT LOCK** ✅

-   正确。锁定账户，阻止其登录。

-   **E) ALTER USER 'joe'@'%' IDENTIFIED BY '*****invalid*****' PASSWORD EXPIRE** ✅

-   正确。设置密码过期会限制登录，除非更新密码。

**错误项分析：**

-   **B) ALTER USER 'joe'@'%' PASSWORD HISTORY** ❌

-   无效语法。

-   **C) REVOKE ALL PRIVILEGES ON** ***.*** **FROM 'joe'@'%'** ❌

-   不能撤销 mysql 系统权限，且不能阻止已登录的用户继续使用连接。

-   **D) ALTER USER 'joe'@'%' SET password='*****invalid*****'** ❌

-   无效语法。

-   **F) REVOKE USAGE ON** ***.*** **FROM 'joe'@'%'** ❌

-   USAGE 是默认权限，不能撤销。

---

### ✅ 试题 103

**题干摘要：**  
创建用户账户时，如何减少安全风险？

**答案：A、D**

-   **A) Avoid the use of wildcards in host names.** ✅

-   避免使用 `%`，可精确控制登录来源。

-   **D) Do not allow accounts without passwords.** ✅

-   密码为空将严重影响系统安全。

**错误项分析：**

-   **B) Avoid the use of wildcards in usernames.** ❌

-   用户名不支持通配符，语法无效。

-   **C) Require the use of mixed case usernames.** ❌

-   MySQL 用户名是大小写敏感，但这不是安全措施。

-   **E) Require users to have the FIREWALL USER privilege defined.** ❌

-   非通用安全需求，仅用于 Enterprise Firewall 场景。

---

### ✅ 试题 104

道题目要求判断下列关于 Mary 连接 MySQL 的说法中，哪两项是正确的。我们可以根据查询输出：

关键点解释：

`USER()`：显示 客户端连接信息（包括连接 IP）。

`mary@192.0.2.101` 表示客户端是从 IP `192.0.2.101` 发起连接的。

`CURRENT_USER()`：显示 被认证成功的用户账号（即实际使用了哪个账号）。

`mary@%` 表示匹配到 `mary@%` 这个授权用户。

  

正确答案解析：

✅ A) Mary connected from a client machine whose IP address is 192.0.2.101.

✔ 正确 — 来自 `USER()` 的信息直接显示连接来源为 `192.0.2.101`。

✅ C) Mary has the privileges of account mary@%.

✔ 正确 — `CURRENT_USER()` 为 `mary@%`，说明该连接使用的是 `mary@%` 这个账户授权，拥有它的权限。

---

❌ 错误选项解析：

❌ B) Mary connected to the database server whose IP address is 192.0.2.101.

✘ 错误 — 题干明确 Mary 是客户端连接 Linux MySQL 服务器，`192.0.2.101` 是 客户端 IP，不是服务器 IP。

❌ D) Mary connected using a UNIX socket.

✘ 错误 — 如果是使用 UNIX socket，`USER()` 中显示的 host 会是 `localhost` 或 `mary@localhost`，而不是 IP 地址。

❌ E) Mary authenticated to the account mary@192.0.2.101.

✘ 错误 — `CURRENT_USER()` 显示的是 `mary@%`，说明实际认证的是通配符账户 `mary@%`，不是精确的 `mary@192.0.2.101`。

  

## ✅ 试题

  

### ✅ 试题 106

**题干摘要：**  
异步复制中的 binary log 特性。

**答案：B、E**

-   **B) They contain events that describe database changes on the master.** ✅

-   正确，binlog 记录数据库的变更事件（如 INSERT/UPDATE/DELETE）。

-   **E) They are pulled from the master to the slave.** ✅

-   正确，slave 的 IO 线程会拉取主库 binlog。

**错误项分析：**

-   **A) They contain events that describe all queries run on the master.** ❌

-   binlog 不一定记录所有查询，取决于格式（如 ROW 模式不记录具体 SQL）。

-   **C) They are pushed from the master to the slave.** ❌

-   错误，binlog 是被 slave 拉取的。

-   **D) They contain only administrative commands.** ❌

-   包含 DML、DDL，不只是 admin 命令。

---

### ✅ 试题 107

**题干摘要：**  
在高并发写入的环境中使用 mysqlbinlog 恢复，为什么不能保证一致性

**答案：A、D**

-   **A) Transaction rate is too high to get a consistent restore.** ✅ 并发事务速率太高，导致无法获得一致恢复点。

-   同上题，高并发场景恢复一致性较难。binlog 只是顺序记录，不能保证恢复时事务顺序与原始一致。

-   **D) The temporal values do not offer high enough precision.** ✅

-   `--start-datetime` 和 `--stop-datetime` 精度不足，可能跳过部分事务。时间类型字段精度不够高，恢复粒度存在偏差。✔ datetime 精度到秒，部分瞬时事务可能错位。

**错误项分析：**

-   **B) Multiple binlogs cannot be used in command line.** ❌

-   可以指定多个 binlog 文件。

-   **C) Temporary tables cannot persist across binary logs.** ❌

-   此问题不影响大多数恢复操作。

-   **E) The time span is too long.** ❌

-   时长无影响，关键是是否覆盖完整事务。

---

### ✅ 试题 108

**题干摘要：**  
InnoDB 的 ibdata1 包含哪些内容？

**答案：A、B**

-   **A) doublewrite buffer** ✅

-   双写缓冲区存在于 system tablespace（ibdata1）中。

-   **B) change buffer** ✅

-   修改缓冲区（change buffer）也保存在 ibdata1 中。

**错误项分析：**

-   **C) InnoDB Data Dictionary** ❌

-   MySQL 8.0 起，数据字典为表空间表，已不在 ibdata1 中。

-   **D) primary indexes** ❌

-   主索引存储在每个表的独立 .ibd 文件中。

-   **E) table data** ❌

-   表数据也存储在 .ibd 文件，不在 ibdata1。

-   **F) user privileges** ❌

-   用户权限存在于 mysql 数据库中，不是 ibdata1 内容。

---

## ✅ 试题 109 InnoDB Cluster 中实例权重的影响

**题干摘要：** 设置 `memberWeight` 的实例行为判定。

```sql
cluster.setInstanceOption('host1:3377', 'memberWeight', 40)
cluster.setInstanceOption('host2:3377', 'memberWeight', 30)
cluster.setInstanceOption('host3:3377', 'memberWeight', 40)
```

**正确答案：**

-   ✅ D) 可使用 `cluster.setPrimaryInstance()` 指定 primary 节点
-   ✅ F) `cluster.switchToMultiPrimaryMode()` 无法启用多主模式（在 Group Replication 下限制）

**错误项解释：**

-   ❌ A) host3 若掉线，需手动 rejoin，不会自动恢复
-   ❌ B) host1 故障并不直接触发 outage，需 quorum 判断
-   ❌ C/E) 实例被驱逐后需手动添加或恢复，primary 不一定就是 host2

---

### ✅ 试题 110

**题干摘要：**

已使用 `innodb_fast_shutdown=0` 进行干净关闭。在操作过程中，所有数据目录文件被误删。要让数据库**正常重启**，以下哪两个文件必须从备份中恢复？

D) `ibdata1`

这是 **InnoDB 系统表空间**，包含：

-   数据字典（MySQL 8.0 前版本中）
-   doublewrite buffer
-   change buffer（变更缓冲）

没有它，InnoDB 引擎无法启动。

​C) `mysql.ibd`

这是 `mysql` 系统库的一个表的物理文件，例如 `user.ibd`（用户权限表）、`db.ibd`（数据库权限）等。缺失将导致系统无法识别权限和账户，**MySQL 无法正常运行**。

### ✅ 试题 111

```sql
SELECT * FROM performance_schema.table_io_waits_summary_by_table WHERE COUNT_STAR > 0 \G
```

你使用 `mysqlbackup` 执行 InnoDB 的原始备份（raw backup）。问题是：**在完整备份中，哪些文件会被包含？**

D) Average read times are approximately three times faster than writes.

-   `AVG_TIMER_READ = 532728`
-   `AVG_TIMER_WRITE = 1677006`

将写入耗时除以读取耗时：  
`1677006 / 532728 ≈ 3.15`

即：**写操作平均耗时约为读的三倍**，因此读操作是三倍**更快**。本项正确。

✅ C) 22902028 rows were deleted. These columns aggregate all delete operations.

-   `COUNT_DELETE = 22902028`，这是删除操作的总次数，意味着确实删除了这么多行。
-   `table_io_waits_summary_by_table` 视图中的 `COUNT_DELETE` 就是表级别的 delete 操作次数累积。正确。

❌ E) The longest I/O wait was for writes.

错误。查看数据：

-   `MAX_TIMER_READ = 558852005358`
-   `MAX_TIMER_WRITE = 17205682920`

可见**最长的 I/O 等待是读取**，不是写入，所以错误。

❌ B) The I/O average time is 532728. These columns aggregate all fetch operations.

这个平均时间的确是 532728，但它**属于读取（READ）操作**，而不是 FETCH 操作。  
虽然 `COUNT_FETCH` 和 `COUNT_READ` 相等，但在此视图中，`FETCH` 是逻辑操作，`READ` 是底层物理读取，所以不能混淆。此选项解释不准确。

❌ A) I/O distribution is approximately 50/50 read/write.

-   `COUNT_READ = 38665056`
-   `COUNT_WRITE = 22902028`

读取次数远多于写入（大约 63% vs 37%），不属于 50/50，所以错误。

​  

### ✅ 试题 114

完整备份 = 数据文件（ibd）+ 日志文件（ib\_logfile）+ 系统表空间（ibdata1）+ 配置（option file）

你使用 `mysqlbackup` 执行 InnoDB 的原始备份（raw backup）。问题是：**在完整备份中，哪些文件会被包含？**

**A )** `***.ibd**` **files**

**InnoDB 表启用了** `**file-per-table**` **模式后（默认开启），每个表都会使用一个单独的** `***.ibd**` **文件来存储数据和索引。**

-   **完整备份时，**`**mysqlbackup**` **会包含所有的表空间数据文件，即** `***.ibd**`**。**
-   **如果没有这些文件，表的数据无法恢复。**

**所以：此项正确。**

---

✅ **D)** `**ib_logfile***` **files**

`**ib_logfile0**`**,** `**ib_logfile1**` **是 InnoDB 的重做日志文件（redo log），在崩溃恢复中非常关键。**

-   `**mysqlbackup**` **会包含这类日志文件，以确保事务一致性。**
-   **如果你做的是原始备份或物理备份，必须要备份 redo log 才能正常恢复。**

**所以：此项也正确。**

---

❌ **B) ibbackup files**

`**ibbackup**` **是早期 InnoDB Hot Backup 工具的产物，而不是** `**mysqlbackup**` **工具生成的实际文件。**

-   **现代 MySQL 8.0 不再使用** `**ibbackup**` **文件。**
-   **它不是数据文件，也不会在备份中出现。**

**错误项。**

---

❌ **C) \*.CSM files**

`**.CSM**` **文件是一些商业备份工具或数据加密插件产生的辅助文件，MySQL 默认环境中并不使用或生成此类文件。**

**不是标准的 InnoDB 物理结构组成部分，错误项。**

---

**二、总结**

**备份时** `**mysqlbackup**`**（MySQL Enterprise Backup）会包含以下 InnoDB 关键文件：**

-   **数据表空间：**`***.ibd**`
-   **共享表空间：**`**ibdata1**`**（如果使用 shared tablespace）**
-   **重做日志：**`**ib_logfile***`
-   **undo logs：**`**undo_001**`**、**`**undo_002**`**（如果启用独立 undo 表空间）**

  

### **试题 115：快照备份的特性？**

**题干：**  
关于基于快照的备份，下列哪两个说法是正确的？

-   **C)** 快照备份会极大地减少数据库和应用的停机时间：快照技术可以在不停止数据库服务的情况下完成备份。
-   **D)** 在释放快照之前必须复制数据：如果不将快照数据复制出来，快照一旦释放，数据将不可恢复。

**错误选项：**

-   **A)** 快照无法直接用于克隆生产数据库，必须经过恢复步骤；
-   **B)** 快照不是数据库逻辑的一部分，因此仍需 InnoDB 进行恢复；
-   **E)** 快照可用于物理服务器、容器、云等，不仅限虚拟机。

---

### ✅ **试题 116：哪类存储引擎 rollback 后数据仍在？**

**题干：**  
执行 `TRUNCATE`、`BEGIN`、`INSERT`、`ROLLBACK` 后，哪些引擎在 `SELECT` 查询时返回结果？

在哪些存储引擎中，`SELECT` 还能返回数据？

-   **A)** MEMORY 引擎不支持事务，`ROLLBACK` 无效，插入的数据仍在。
-   **C)** ARCHIVE 引擎支持压缩写入，不支持事务。
-   **E)** MyISAM 也不支持事务，因此回滚无效，数据保留。

**错误选项：**

-   **B)** BLACKHOLE：写入数据被直接丢弃，不会返回任何行；
-   **D)** NDB 支持事务，因此回滚后数据不会保留；
-   **F)** InnoDB 支持事务，`ROLLBACK` 会回滚插入数据。

---

### ✅ **试题 117：mysql\_config\_editor 工具的功能？**

**正确答案：**  
✅ C) 默认使用配置除非指定 `--login-path`  
✅ G) 管理客户端程序配置项（主机、端口等）

**逐项解析：**

-   **C)** ✅ 默认情况下该工具使用默认 `login-path`（如 `client`）。
-   **G)** ✅ 它可保存客户端工具连接所需的配置，如用户名、端口、socket、ssl。
-   **F)** ❌ 它与 MySQL Firewall 无关。
-   **D)** ❌ 它无法管理 SSL 证书或日志目录。
-   **A)** ❌ 它不会更改 `my.cnf` 文件。
-   **E)** ❌ 不用于用户权限管理。
-   **B)** ❌ 不涉及 datadir 移动。

---

### ✅ **试题 118：binary log 加密相关特性？**

**正确答案：**  
✅ A) 需要 keyring 插件✅ C) 可以在运行时启用

**逐项解析：**

-   **A)** ✅ 加密需启用如 `keyring_file` 插件存储加密密钥。
-   **C)** ✅ 可通过动态变量 `binlog_encryption=ON` 启用。
-   **B)** ❌ 开启后仅加密新生成 binlog，已有 binlog 不加密。
-   **D)** ❌ 加密是全局设置，无法针对 session。
-   **E)** ❌ 并不加密 slave 的连接线程，它们与 binlog 加密无关。

---

### ✅ **试题 119：哪些** `**--ssl-mode**` **值强制使用 X.509 证书？**

**题干：**  
你使用如下命令连接远程数据库：

```sql
mysql -h remote.example.org -u root -p --protocol=TCP --ssl-mode=?
```

**正确答案：**  
✅ C) VERIFY\_IDENTITY✅ E) VERIFY\_CA

**逐项解析：**

-   **C)** ✅ VERIFY\_IDENTITY 会验证 CA 并检查主机名匹配证书。
-   **E)** ✅ VERIFY\_CA 会验证证书是否来自可信 CA。
-   **A)** ❌ DISABLED 完全关闭 SSL。
-   **B)** ❌ REQUIRED 虽启用 SSL，但不验证证书；
-   **D)** ❌ PREFERRED 若可用就启用 SSL，不强制用证书。

---

### ✅ **试题 120：分析查询统计图**

**题干：**  
通过 Performance Schema 查询图像结果（见题中截图链接），判断两个正确的结论。

**正确答案：**  
✅ C) app 用户读取行数最多✅ E) root 用户单次等待时间最长

**解析要点：**

-   图中 `Rows_read` 数值中，app 明显最大；
-   `MAX_TIMER_WAIT` 显示 root 用户最大；
-   bob 的 lock 等待时间并不是最多；
-   SELECT 改写最多的用户也非 root；
-   bob 的 (SELECT + INSERT)/QUIT 也未显著高于其他用户。

​  

### **第121题：角色授权与 ADMIN OPTION 权限**

**原题：**  
执行如下 SQL 命令：

```plsql
GRANT r_read@localhost TO mark WITH ADMIN OPTION;
```

以下哪些说法是正确的？（选两项）

**正确答案：**  
✅ C) Mark 可以将 r\_read@localhost 角色授予其他用户。✅ D) Mark 可以从另一个角色中撤销 r\_read@localhost 角色。

中文讲解：

该命令的意思是：授予用户 `mark` 一个名为 `r_read@localhost` 的角色，同时赋予 **ADMIN OPTION** 权限。

**含义：**

-   `WITH ADMIN OPTION` 表示该用户可以将该角色赋予其他用户，或从他人那里撤销该角色；
-   但注意：`mark`**不能**直接将该角色中包含的具体权限逐项赋予他人。

选项逐条解释：

-   **A)** ❌ mark 不能将该角色中的权限（如 SELECT）直接赋予其他用户，只能赋予整个角色；
-   **B)** ❌ ADMIN OPTION 与默认激活该角色无关；
-   **C)** ✅ 正确，ADMIN OPTION 允许 mark 授予 `r_read@localhost` 给其他用户；
-   **D)** ✅ 正确，也可撤销已授予其他用户或角色的该角色；
-   **E)** ❌ 不能用于删除角色；
-   **F)** ❌ 是否连接自 `localhost` 与是否激活角色无关。

---

## ✅ **第122题：MySQL Installer 的特性**

**原题：**  
哪两个关于 MySQL Installer 的说法是正确的？（选两项）

**正确答案：**  
✅ B) 它安装大多数 Oracle MySQL 产品✅ C) 安装前需要手动下载相关产品包

中文讲解：

-   **MySQL Installer** 是 Windows 下的 MySQL 一键安装器；
-   它包含服务器、Workbench、Shell、Router 等；
-   虽然提供了安装向导，但一些组件仍需要你手动下载安装包。

选项逐条解释：

-   **A)** ❌ 也支持静默安装，不仅限 GUI；
-   **B)** ✅ 是 Oracle 出品的集成工具，支持安装常见产品；
-   **C)** ✅ 正确，部分包需用户手动下载；
-   **D)** ❌ 仅支持 Windows，非跨平台；
-   **E)** ❌ 不支持产品升级，只支持初始安装。

---

## ✅ **第123题：容量规划有效做法（选三）**

**题干：**  
以下哪些操作是有效的容量规划方法？（选三）

**正确答案：**  
✅ E) 基于过去三年的平均增长预测✅ G) 监控操作系统资源使用趋势✅ H) 与应用团队沟通未来项目计划

中文讲解：

容量规划 = 分析历史数据 + 预测业务增长 + 技术规划。

-   **E)** ✅ 用过去三年的数据进行平均，有助于客观预测增长；
-   **G)** ✅ 系统监控可发现瓶颈，例如 CPU/RAM 使用模式；
-   **H)** ✅ 与业务方配合，可以提前获知大型活动、数据暴涨等情况。

错误选项说明：

-   **A/B/C/D/F**：盲目购买硬件或升级应用不一定解决实际问题，需先分析瓶颈。

---

# ✅ **第124题：多线程复制与一致性风险**

**题干简述：**  
有4个节点组成环形复制，每个节点参数如下：

```sql
slave_parallel_type=DATABASE
slave_parallel_workers=4
slave_preserve_commit_order=0
```

哪种说法是正确的？

**正确答案：**  
✅ B) 存在跨数据库约束时可能导致复制不一致

中文讲解：

-   `slave_parallel_type=DATABASE`：表示基于库名并行复制；
-   `slave_preserve_commit_order=0`：不保证事务提交顺序；
-   **此时若事务涉及多个数据库，会因为顺序不一致而导致主从数据不一致**！

其他选项解释：

-   **A)** ❌ 并不是每个线程负责一个数据库，而是按事务动态分配；
-   **C)** ❌ `DATABASE` 是有效选项，`LOGICAL_CLOCK` 是另一种类型；
-   **D)** ❌ 增加 worker 数量不提升 HA，只提升吞吐；
-   **E/F)** ❌ 与数据一致性无直接关系。

---

## ✅ **第125题：InnoDB Cluster 节点状态恢复**

**题干简述：**  
给出如下 InnoDB Cluster 拓扑部分输出：

```sql
host1:3377   STATUS: ONLINE  mode: R/W
host2:3377   STATUS: MISSING mode: R/O
host3:3377   STATUS: ONLINE  mode: R/O
```

问：host2 实例的状态如何恢复？

**正确答案：**  
✅ C) 可通过 host3 实例使用 `cluster.rejoinInstance()` 恢复 host2

中文讲解：

`MISSING` 表示实例曾属于集群，但当前无法访问；

它的元数据仍存在，因此可通过 **rejoinInstance** 重新加入，不需重建；

如果是 `removeInstance()` 主动移除的，那就要用 `addInstance()`。

错误选项：

-   **A)** ❌ 不适用于已存在的节点；
-   **B)** ❌ 被踢出是另一种状态；
-   **D)** ❌ 停掉 Group Replication 不等于 MISSING；
-   **E)** ❌ `rebootClusterFromCompleteOutage()` 是用于全集群重建，不是单节点修复。

​  

## **第 126 题：mysqldump 输出内容控制**

**题干原文：**​

```sql
mysqldump --no-create-info --all-databases --result-file=dump.sql
```

Which statement is true?

**正确答案：**  
✅ D) It will not write `CREATE TABLE` statements.

**中文翻译：**  
分析以下命令：  
它会导出所有数据库内容但不会包含哪些信息？

-   `--no-create-info` 表示跳过表结构，只导出数据。
-   所以不会写出 `CREATE TABLE` 语句。

**各选项解释：**

-   **A)** ❌ `CREATE TABLESPACE` 通常不在 mysqldump 输出中，除非是特殊引擎；
-   **B)** ❌ `CREATE LOGFILE GROUP` 是 NDB 引擎特有，也不会导出；
-   **C)** ❌ `CREATE DATABASE` 语句仍然会输出，除非额外禁用；
-   **D)** ✅ 正确，`--no-create-info` 就是禁止输出 `CREATE TABLE`。

---

## ✅ **第 127 题：查看配置文件读取顺序的方法**

**题干原文：**  
Which method will show the option files and the order in which they are read?

**正确答案：**  
✅ D) `mysqld --help --verbose`

---

**中文翻译：**  
MySQL 程序在启动时会查找多个配置文件，如何查看它们的路径及读取顺序？

-   **正确命令：**

```sql
mysqld --help --verbose
```

-   它会显示完整的配置加载顺序，如 `/etc/my.cnf`、`~/.my.cnf` 等。

**选项解释：**

-   **A)** ❌ `SHOW GLOBAL VARIABLES` 查看变量，不涉及文件；
-   **B)** ❌ `mysql --print-defaults` 只显示当前读取的设置，不显示读取顺序；
-   **C)** ❌ `mysqladmin --debug` 用于调试命令行工具，不显示配置文件。

---

## ✅ **第 128 题：使用 mysqlbackup 的文件类型**

**题干原文：**  
执行如下命令：

```sql
mysqlbackup --user=dba --password --port=3306 --with-timestamp --only-known-file-types --backup-dir=/export/backups backup
```

**问题：** 该命令的含义是？

**正确答案：**  
✅ D) Only files for MySQL or its built-in storage engines are backed up.

---

**中文翻译与解析：**

-   参数 `--only-known-file-types` 的意思是：**只备份已知的、标准的数据库文件类型**；
-   不会备份加密文件、外部引擎文件或插件生成文件。

**错误选项说明：**

-   **A)** ❌ 不限于独立表空间（`.ibd`）；
-   **B)** ❌ 不仅限于 InnoDB；
-   **C)** ❌ 和是否加密无关；
-   **E)** ❌ 不仅仅是数据文件和元数据，部分日志也包括。

---

## ✅ **第 129 题：slave I/O 线程的作用**

**题干原文：**  
What does the slave I/O thread do?

**正确答案：**  
✅ B) Connects to the master and requests it to send updates recorded in its binary logs.

---

**中文翻译与解析：**

MySQL 复制架构中，I/O 线程的作用是：

-   向主库请求 binlog 内容；
-   持续读取并写入中继日志（relay log）到本地。

**错误选项说明：**

-   **A)** ❌ I/O 线程不负责 relay log 的调度；
-   **C)** ❌ binlog 是由主库控制读取，不是从库加锁；
-   **D)** ❌ 执行 relay log 的是 SQL 线程，不是 I/O 线程。

---

## ✅ **第 130 题：Windows 平台下的 my.ini 文件行为**

**题干原文：**  
Which statement is true about the `my.ini` file on a Windows platform while MySQL server is running?

**正确答案：**  
✅ B) The option file is read by the MySQL server service only at start up.

---

**中文翻译与解析：**

在 Windows 系统中，`my.ini` 是 MySQL 的配置文件。当服务器已经启动时：

-   **更改 my.ini 并不会立即生效**；
-   配置文件只会在 **MySQL 服务启动时读取一次**。

**选项解释：**

-   **A)** ❌ MySQL 确实使用 my.ini；
-   **C)** ❌ 编辑 my.ini 不会立即影响运行中的实例；
-   **D)** ❌ SET PERSIST 会写入 `mysqld-auto.cnf`，而非 `my.ini`。

​  

## 第 131 题：使用 mysqlbackup 恢复压缩备份

**英文原题：**  
You must perform a database restore to a new machine.  
Which command can provision the new database in datadir as `/data/MEB`?

```sql
mysqlbackup.cnf 内容：
backup-dir=/backup/full/myrestore
backup-image=/backup/full/mybackup/myimage.img
uncompress
```

**正确答案：**  
✅ D) `mysqlbackup --defaults-file=mysqlbackup.cnf --datadir=/data/MEB copy-back-and-apply-log`

中文翻译与讲解：

你需要将一个通过 `--compress` 选项生成的 `.img` 备份恢复到新的服务器中，目标数据目录为 `/data/MEB`。  
问：使用哪条命令可以将备份镜像还原并设置到该目录？

-   **copy-back-and-apply-log**：表示先解包，还原文件到 datadir，然后应用 redo 日志完成恢复；
-   其他选项如 `image-to-dir`、`restore-and-apply-log` 仅用于镜像处理或内部解压，不能直接落地。

**错误选项解释：**

-   A) `restore-and-apply-log` ❌：不适用于 `.img` 类型；
-   B/C/E) ❌：缺失 apply log 或 copy-back 步骤。

---

# ✅ 第 132 题：MySQL Enterprise Monitor 的 Query Analyzer 特性

**英文原题：**  
MySQL Enterprise Monitor Query Analyzer 已配置监控某个实例。以下哪一项说法正确？

**正确答案：**  
✅ D) Query Analyzer 可以监控无限数量的归一化 SQL 语句。

中文翻译与讲解：

Query Analyzer 可以分析“归一化后的 SQL”（Normalized Statements），即不同参数但结构一致的语句视为一类。  
MySQL Enterprise Monitor 不限制可跟踪的此类语句数量。

**错误选项解释：**

-   A) ❌ QRTi 默认可调，不是固定 100ms；
-   B) ❌ 与 performance\_schema 配置项无关；
-   C) ❌ 可以通过远程代理或实例间通信实现，无需本地 agent；
-   E) ❌ 不依赖慢查询日志。

---

## ✅ 第 133 题：连接失败的排查（基于 mysql\_native\_password 插件）

**题干简述：**  
用户从 `192.0.2.5` 连接数据库失败，使用的是 `mysql_native_password` 插件。结合日志信息判断问题原因。

**正确答案：**  
✅ B) 网络连接问题出现在客户端和 MySQL 实例之间。

中文翻译与讲解：

-   日志中 `Aborted_connects` 增长；
-   同时 `COUNT_AUTH_PLUGIN_ERRORS` 显示有大量认证插件错误；
-   结合实际，最常见原因是：\*\*连接包未送达（TCP中断）\*\*或认证插件配置不正确，**但本题中未涉及认证更换或权限问题**，最可能是网络问题。

**错误项说明：**

-   A) ❌ max\_connections 不影响认证失败；
-   C) ❌ 用户名密码错误会导致认证失败，但题干强调是网络异常；
-   D) ❌ 使用 `mysql_native_password` 是合法配置；
-   E) ❌ 与 thread\_cache 无关；
-   F) ❌ `skip_name_resolve` 不影响认证插件行为。

---

## ✅ 第 134 题：查看每个连接的 session 级变量

**英文原题：**  
你希望查看当前所有连接的 `sort_buffer_size` 值，应该查询哪个 `performance_schema` 表？

**正确答案：**  
✅ C) `variables_by_thread`

中文翻译与讲解：

-   `variables_by_thread` 显示每个线程（连接）的变量设置，包括 session 范围；
-   用于排查每个会话独立设置了哪些变量。

**错误项解释：**

-   A) `global_variables` 只显示全局变量；
-   B) `session_variables` 是系统表，不是 performance\_schema 中的实时监控表；
-   D) `user_variables_by_thread` 是自定义变量，不含配置变量。

---

## ✅ 第 135 题：multi-source replication 的特性

**英文原题：**  
Which feature is provided by multi-source replication?

**正确答案：**  
✅ B) 允许多个服务器向一个目标服务器备份数据

中文翻译与讲解：

Multi-source replication（多源复制）可以让多个主库向同一个从库同步数据，典型用途：

-   数据汇聚（Data Consolidation）；
-   分库合并（Merge Shards）；
-   统一备份点。

**错误项解释：**

-   A) ❌ 这描述的是主从复制的反向，不符合多源特性；
-   C) ❌ 多源复制不自动冲突解决；
-   D) ❌ 并非所有节点都是主库，只是多个源向一个目标复制。

## 第 136 题：InnoDB 表事务期间执行 OPTIMIZE 的行为

**英文题干：**  
假设 `t` 是一个非空的 InnoDB 表。执行以下语句：

```sql
BEGIN;
SELECT * FROM t FOR UPDATE;
```

接下来另一会话执行了 `OPTIMIZE TABLE t;`，结果会如何？

**正确答案：**  
✅ D) 如果执行 OPTIMIZE TABLE，会创建表级锁并导致事务回滚。

**中文解析：**

-   `SELECT ... FOR UPDATE` 是悲观锁，锁住了行；
-   `OPTIMIZE TABLE` 在 InnoDB 中会创建临时表替代原表，相当于执行 `ALTER TABLE`；
-   因为事务未提交，OPTIMIZE 无法获得表锁，MySQL 会强制当前事务 **回滚** 来避免死锁。

**错误选项说明：**

-   **A)** ❌ `mysqlcheck` 只是检查表，不涉及事务或锁；
-   **B/C)** ❌ 其他会话执行 `ANALYZE` 或 `OPTIMIZE` 会被阻塞或引发回滚，不会“正常返回”。

---

## ✅ 第 137 题：MySQL 5.7 升级到 8.0 后权限表错误修复方法

**题干简述：**  
你从 5.7.28 原地升级到 8.0.18，首次启动 MySQL 时发生系统权限表报错，如何解决？

**正确答案：**  
✅ C) 执行：

```sql
mysqlcheck --repair mysql columns_priv event proc proxies_priv tables_priv
```

**中文解析：**

-   升级后系统权限表（如 `columns_priv`、`proc` 等）格式可能不兼容；
-   正确的做法是使用 `mysqlcheck --repair` 修复这些 MyISAM 表；
-   `mysqlcheck --check-upgrade` 只是检测，不会修复；
-   使用 `myisamchk` 修复需加 `--force`，否则默认不修复；

**错误选项说明：**

-   A) ❌ `--upgrade=FORCE` 适用于 metadata，但不解决 MyISAM 表结构损坏；
-   D) ❌ 删除 redo log 重装版本是过度操作。

---

## ✅ 第 138 题：MySQL 企业版 TDE 加密的真实特性

**题干简述：**  
关于 MySQL Enterprise Transparent Data Encryption (TDE)，哪个说法是正确的？

**正确答案：**  
✅ A) MySQL TDE 使用适当的 keyring 插件将密钥存储于集中位置。

**中文解析：**

-   TDE 依赖 `keyring_file`、`keyring_encrypted_file` 等插件来存储加密密钥；
-   密钥管理器可集中管理密钥（如 Oracle Key Vault、HashiCorp Vault）；
-   **只支持 InnoDB 引擎**，MyISAM 不支持加密；
-   表加密通过创建表空间或指定表级参数实现。

**错误项说明：**

-   B) ❌ SYSTEM 表空间不支持 MyISAM；
-   C) ❌ 只能在主密钥未丢失的前提下恢复；
-   D) ❌ 没有 keyring\_engine=ALL 的变量。

---

# ✅ 第 139 题：释放 InnoDB 表空间的方法

**题干简述：**  
在启用了 `innodb_file_per_table` 的情况下，删除 `FACTORY.INVENTORY` 表中大量数据后，如何释放存储空间并优化 I/O？

**正确答案：**  
✅ C) `OPTIMIZE TABLE FACTORY.INVENTORY`

**中文解析：**

-   `OPTIMIZE TABLE` 会：

-   对 InnoDB 表进行 `ALTER TABLE ... FORCE`；
-   创建临时表、复制数据、重新创建索引；
-   释放已删除记录所占的空间；

-   类似于 VACUUM 效果。

**错误选项说明：**

-   A) `CHECK TABLE`：仅检查结构；
-   B) `ANALYZE TABLE`：仅更新索引统计；
-   D/E) 不会改变物理存储结构。

---

## ✅ 第 140 题：最高安全等级的 SSL 配置选项

**题干简述：**  
要为 MySQL 命令行客户端配置**最高安全级别的 SSL 连接方式**，应使用哪种 `--ssl-mode` 设置？

**正确答案：**  
✅ C) `VERIFY_IDENTITY`

**中文解析：**

-   `--ssl-mode=VERIFY_IDENTITY` 要求：

-   使用受信任 CA 签发的证书；
-   且证书中的主机名必须与连接的服务器名匹配；

-   这是最严格的 SSL 安全设置。

**其他选项说明：**

-   A) VERIFY\_CA ❌：验证证书但不检查主机名；
-   B) PREFERRED ❌：能用 SSL 就用，不强制；
-   D) REQUIRED ❌：强制使用 SSL，但不验证主机名或 CA。

## 第 141 题：备份所有以 db 开头的数据库

**英文原题：**  
你希望备份所有数据库名以 `db` 开头的数据库，应该使用哪个命令？

**正确答案：**  
✅ B) `mysqlpump --include-databases=db% --result-file=all_db_backup.sql`

**中文解析：**

-   `mysqlpump` 是新版逻辑备份工具，比 `mysqldump` 并发更高；
-   `--include-databases=db%`：表示匹配所有以 `db` 开头的数据库名；
-   `--result-file=...`：将输出写入文件。

**错误项说明：**

-   A) 没指定任何数据库，无法控制范围；
-   C) `--include-databases=db` 只包含名为 “db” 的数据库；
-   D) `--include-tables-db.%` 是匹配表，不是匹配数据库。

---

## ✅ 第 142 题：临时表的位置

**题干简述：**  
在 Oracle Linux 上的 MySQL 8 安装中，关于临时表的说法哪项正确？

**正确答案：**  
✅ D) 临时表将使用位于 `datadir` 的 InnoDB 临时表空间

**中文解析：**

-   从 MySQL 5.7 起，临时表默认使用 `TempTable 引擎` 和 `InnoDB` 临时表空间；
-   默认位于数据目录（datadir）中；
-   `tmpdir` 是 `MyISAM` 或大对象的临时文件目录，而不是 InnoDB 临时表空间位置。

**错误项说明：**

-   A/B/E) 错误地将 tmpdir 与 InnoDB 临时表混淆；
-   C) ❌ MyISAM 不是默认临时表引擎。

---

## ✅ 第 143 题：为 InnoDB 表启用 TDE（透明加密）

**题干简述：**  
对现有 InnoDB 表启用透明数据加密（TDE），语法应该是？

**正确答案：**  
✅ C) `ALTER TABLE t1 ENCRYPTION='Y';`

**中文解析：**

-   MySQL 企业版支持 TDE；
-   可在表级别通过 `ENCRYPTION='Y'` 启用；
-   前提是已启用 `keyring` 插件，如 `keyring_file`；
-   适用于独立表空间表（file-per-table 模式）。

**错误项说明：**

-   A/B/D) 都是无效的语法或伪造语法。

---

## ✅ 第 144 题：GTID 异步复制故障修复

**题干简述：**  
你配置了基于 GTID 的主从复制。用户误操作从库数据，你回滚数据后，需要修正 GTID 以避免数据重复复制。应执行哪组命令？

**正确答案：**  
✅ D)

```sql
SET GLOBAL gtid_purged='aaaaaa-...:1-2312, bbbbbb-...:1-9';  
SET GLOBAL gtid_executed='aaaaaaa-...:1-10167';
```

**中文解析：**

-   从库需要将已经执行但不希望再次执行的 GTID 写入 `gtid_purged`；
-   然后设置 `gtid_executed` 衔接后续主库事务；
-   避免主库故障切换后重新复制这些 GTID。

**错误项说明：**

-   A/B/C) 命令不完整或参数冲突；
-   E) 错误地使用了 `RESET SLAVE`，且未正确设置。

---

## ✅ 第 145 题：配置 slow log 日志记录条件

**题干简述：**  
已有以下配置：

```sql
log_output=FILE  
slow_query_log=ON  
long_query_time=2.01  
log_queries_not_using_indexes=ON
```

你希望记录以下两种查询：

1.  检索超过 5000 行的查询；
2.  执行时间超过 5 秒 或 未使用索引的查询。

应修改哪些配置？

**正确答案：**  
✅ E)

```sql
long_query_time=5  
min_examined_row_limit=5000
```

**中文解析：**

-   `min_examined_row_limit=5000`：设置至少检查这么多行才写入 slow log；
-   `long_query_time=5`：只有超时查询才记录；
-   如果加上 `log_queries_not_using_indexes=ON`，未使用索引的查询也会被记录；
-   本题实际考查对 **复合条件** 的理解。

**错误项说明：**

-   A/B/C/D/F/G) 要么缺失参数、拼写错误、值未匹配目标行为。

​  

## 第 146 题：binlog dump 线程的作用

  
A）它负责监控并调度 binary log 的轮转和删除。  
B）它连接到主库并请求其发送 binary log 中记录的更新。  
C）它在读取将要发送给从库的事件时会对 binary log 加锁。✅  
D）它读取中继日志（relay log）并执行其中的事件。

**解析：**  
binlog dump 线程是主库端的线程，它的作用是：在复制架构中为每一个从库连接启动一个线程，这个线程会**读取主库上的 binary log 中的事件**，并将这些事件发送给从库。这个过程会在读取每一个事件时加一个临时锁，读取完成后立即释放，不会等事件发送完才释放锁。这个设计是为了提高并发和效率。  
选项 B 虽然描述听起来合理，但它混淆了作用；真正执行请求的是从库的 I/O 线程，而不是主库的 binlog dump 线程。

​  

## 第 147 题：现有连接 `sort_buffer_size`

你希望查看所有现有连接的 `sort_buffer_size` 会话变量值。你可以查询哪一个 `performance_schema` 表？

A）user\_variables\_by\_thread  
B）global\_variables  
C）variables\_by\_thread ✅  
D）session\_variables

**解析：**  
这个问题考察对 `performance_schema` 的了解。`sort_buffer_size` 是会话级变量，每个线程（connection）可能不同。正确的表是 `variables_by_thread`，它可以让你看到每个线程（也就是连接）的变量当前值。

-   `global_variables` 只显示全局变量；
-   `session_variables` 是你当前会话的；
-   `user_variables_by_thread` 是用户自定义变量（@var 形式），不是系统变量。

## 第 148 题：哪个说法最符合启动失败的原因？

你刚在 Oracle Linux 上安装了 MySQL，并修改了 `/etc/my.cnf` 配置文件。

你尝试启动服务：

```sql
# systemctl start mysqld

# systemctl status mysqld
结果失败。使用如下命令查看状态：
输出显示：
● mysqld.service: main process exited, code=exited, status=1/FAILURE
● ExecStart=/usr/sbin/mysqld ... (code=exited, status=1/FAILURE)
● 说明主进程（PID 2732）启动失败
```

正确答案：

**E) MySQL server was not started due to a problem while executing process 2732.**

✅ 原因解析：

-   行：`Main-PID: 2732 (code=exited, status=1/FAILURE)`  
    表明 **mysqld 主进程启动失败，状态码为 1**（常见于配置错误、权限问题、端口占用等）。
-   `ExecStart=/usr/sbin/mysqld ... (code=exited, status=1/FAILURE)`  
    明确表示是 mysqld 启动阶段失败
-   所以，这一切都指向：**主服务进程执行时报错退出**，这是 **E** 描述的情况。

---

❌ 错误选项分析：

-   **A)** “发现另一个 mysqld 进程并将其关闭” ❌  
    → 没有任何信息显示已有 mysqld 实例在运行，更没提示 kill 行为。
-   **B)** “继续尝试启动，尽管已有进程” ❌  
    → 也未发现任何已有 mysqld 实例存在。
-   **C)** “systemd 等待 30 秒后超时” ❌  
    → 日志没有提到 Timeout 信息；是 **立即退出**，非等待。
-   **D)** “mysqld 服务处于 disabled 状态” ❌  
    → 日志显示 `mysqld.service; enabled;`，并没有被禁用。

## 第 149 题：SQL 注入攻击

你希望防止 SQL 注入攻击。以下哪种方法**无法**做到这一点？

A）使用存储过程来访问数据库  
B）避免将用户输入与 SQL 语句直接拼接  
C）使用预处理语句（prepared statements）  
D）安装并配置 Connection Control 插件 ✅

**解析：**  
SQL 注入的关键是用户输入不被正确处理直接嵌入 SQL 语句。正确做法包括：

-   使用 `prepared statement`（参数化查询）
-   使用 `stored procedure` 并限制权限
-   避免字符串拼接

Connection Control 插件的作用是防止恶意连接爆破（如连接频率限制），它不涉及 SQL 层语句解析，所以不能防止 SQL 注入。

## 第 150 题：`mysql_multi`

如何配置 `mysql_multi`，使多个 MySQL 实例可以使用相同的端口号？

A）让每个实例监听不同的 IP 地址 ✅  
B）为每个实例使用不同的用户账户  
C）使用不同的 socket 文件名  
D）设置适当的子网掩码

**解析：**  
多个 MySQL 实例运行在同一台服务器上，若监听的 IP 地址不同，则允许它们绑定同一个端口号。例如：

-   实例 A 监听 `127.0.0.1:3306`
-   实例 B 监听 `192.168.1.10:3306`

只要监听地址不同，端口号冲突就不会发生。其他选项并不能解决端口冲突问题。

## **第 151 题 check-for-server-upgrade**

**题目原文：**  
你计划将 MySQL 5.7 升级到 8.0，已安装新版 MySQL Shell。你执行了如下命令：

```sql
mysqlsh --uri root@localhost:3306 -- util check-for-server-upgrade
```

**哪个说法是正确的？**  
✅ A) 它会记录你 5.7 表中存在的问题，以便升级到 8.0。

**解析：**  
`check-for-server-upgrade` 是 MySQL Shell 的实用工具命令，用于**在升级前扫描潜在不兼容项**，例如字段类型、关键字冲突等。  
它只报告，不执行修复。

-   B）错，命令写法无关 camelCase；
-   C）错，不会自动修复，只报告；
-   E）错，可以从命令行执行，不限 shell 模式。

​  

## **第 152 题 busy-tables**

**题目原文：**  
你每天在 finance 库中接收大量金融交易。  
表名以 `transactions-` 开头是活动表，每月会归档为 `archives-` 开头的表。你运行如下命令：

```sql
mysqlbackup --optimistic-busy-tables=^finance\\.transactions-.* backup
```

**关于 redo log 的处理，下列哪项是正确的？**  
✅ E) 归档表先被备份，然后是交易表和 redo 日志。

**解析：**  
该命令指定哪些表是“繁忙表”（正在活跃写入）。

-   `mysqlbackup` 会优先在“乐观阶段”备份非繁忙表（archives-），这时不会锁住实例，也不会备份 redo log；
-   等处理 transactions-\* 时进入“锁阶段”，这时才一起备份 redo、undo 和表空间。

---

## ✅ **第 153 题 replay redo log**

**题目原文：**  
你需要重放 MySQL 的 binary logs，应使用哪条命令？

**选项及答案：**  
✅ D)

```sql
mysqlbinlog binlog.000003 binlog.000004 binlog.000005 | mysql -h 127.0.0.1
```

**解析：**

-   `mysqlbinlog` 工具解析 binlog 文件，输出 SQL；
-   通过管道 `|` 重放至 mysql 客户端即可还原；
-   A）错，`cat` 不解析 binlog 格式；
-   B）`mysqlpump` 用于逻辑备份，不支持 binlog；
-   E）`mysqlbinlog` 不接受 `-h` 作为数据库连接参数。

---

## ✅ **第 154 题 add index improve the performance**

**题目原文：**  
你执行如下查询：

```sql
select NAme FROM world.city WHERE Population BETWEEN 1000000 AND 2000000
```

**如何提高性能？**

**正确答案：**  
✅ F) `ALTER TABLE world.city ADD INDEX (Population);`

**解析：**  
该查询条件为 `BETWEEN ... AND ...`，作用字段是 `Population`。添加普通索引即可提高过滤效率。

**错误选项：**

-   A/C）`Name` 字段无助于此查询；
-   B/E）`SPATIAL INDEX` 仅用于几何字段；
-   D）`FULLTEXT` 仅适用于文本字段，不能对数值字段如 `Population` 使用。

---

## ✅ **第 155 题 FORCE\_LOG\_PERMANENT**

**题目原文：**  
设定参数如下：

```sql
audit_log=FORCE_LOG_PERMANENT
```

**该设置对审计有何影响？**

**正确答案：**  
✅ A) 它会阻止在运行中卸载 audit 插件。

**解析：**这个设置组合确保：

-   插件在启动时加载；
-   无法通过 SQL 语句卸载（如 `UNINSTALL PLUGIN`）；
-   适用于安全敏感环境，防止有人绕过审计。

**错误选项说明：**

-   B）不影响日志轮转；
-   C）不能创建 log，仅控制插件；
-   D）错误地描述加载机制。

## 第 156 题：**metadata lock**

```sql
锁类型	意图
SHARED_READ	查询/只读操作
SHARED_WRITE	DML，如 INSERT、UPDATE
INTENTION_EXCLUSIVE	准备独占的子结构操作
SHARED_NO_READ_WRITE	通常用于 DDL 变更
```

-   PENDING = 被阻塞
-   GRANTED = 持有锁
-   找出谁是 PENDING 的锁 → 看其他 GRANTED 是谁 → 查其 THREAD\_ID → 映射 PROCESSLIST\_ID

# 第 157 题： InnoDB Cluster 故障恢复与 GTID 不一致问题

**题干简述：**  
集群启动失败，一个节点（host3）无法加入集群，出现错误提示：

The active session instance isn’t the most updated in comparison with the ONLINE instances of the Cluster’s metadata...

你使用 `dba.rebootClusterFromCompleteOutage()` 恢复失败。以下哪项说法正确？

**正确答案：**  
✅ C) 可以通过 GTID\_SUBSET(set1, set2) 比较不同实例的 GTID 集，判断哪个实例是最新的。

**解析：**

-   GTID（全局事务 ID）用于判断事务应用情况；
-   若某节点的 GTID 不是其他节点的“超集”，它不能作为恢复参考；
-   正确方法是连接 GTID 最大的节点并重启集群；
-   `GTID_SUBSET(gtid1, gtid2)` 可以判断是否是包含关系。

**错误项解析：**

-   A) ❌ 集群实际上未成功运行；
-   B) ❌ addInstance 用于新增节点，不解决不一致；
-   D) ❌ 不需要重新创建 session；
-   E) ❌ 重建主节点快照非唯一选项。

---

## ✅ 第 158 题：使用 `--initialize-insecure` 初始化数据库的行为

**题干简述：**  
执行命令：

```sql
mysqld --initialize-insecure
```

哪项说法正确？

**正确答案：**  
✅ A) 初始化后，root 密码不会设置，允许本地主机空密码连接。

**解析：**

-   `--initialize-insecure` 会初始化 datadir 但**不设置 root 密码**；
-   相较于 `--initialize`（会写入随机密码到 error log），这是适合测试或开发环境的方式；
-   不推荐用于生产；
-   可立即通过 socket 使用 `root@localhost` 空密码登录。

---

## ✅ 第 159 题：参数 `innodb_directories` 的用途

**题干简述：**  
你计划将 MySQL 升级至 8.0，并计划在配置中添加如下参数：

```sql
innodb_directories = '/innodb_extras'
```

以下哪项说法是正确的？

**正确答案：**  
✅ A) 它允许 MySQL 扫描其他位置以发现更多的 InnoDB 表空间。

**解析：**

-   `innodb_directories` 定义了 MySQL 在启动时可扫描哪些目录寻找 InnoDB 表空间（`.ibd` 文件）；
-   这对于分离式表空间、迁移或导入表空间非常重要；
-   不会移动表空间，不涉及 `innodb_data_home_dir`；
-   并非临时空间（与 `innodb_tmpdir` 无关）。

---

  

## ✅ 第 160 题：备份 internal 系统库的最佳工具

**题干简述：**  
你希望每日全量备份，包括 `sys` 和 `ndbinfo`（内部系统库）。哪个命令可以并行备份它们？

**正确答案：**  
✅ B)

```sql
mysqlpump --include-databases=% > full-backup-$(date +%Y%m%d).sql
```

**解析：**

-   `mysqlpump` 支持并发、多线程逻辑备份；
-   默认不包含 `sys`、`performance_schema`、`ndbinfo`；
-   使用 `--include-databases=%` 会显式包含所有数据库，包括这些系统库；
-   `mysqldump` 无法并行，不适合需求。

## 第 161 题：不同引擎对事务回滚的影响

**英文原题简述：**  
`languages` 表使用 MyISAM 引擎，`countries` 表使用 InnoDB。两表为空。执行如下语句：

```sql
BEGIN;
INSERT INTO languages(lang) VALUES ("Italian");
INSERT INTO countries(country) VALUES ("Italy");
ROLLBACK;
```

**回滚后这两张表中数据的状态是？**

**正确答案：**  
✅ D) `languages` 表中有 1 行，`countries` 表为空

中文解析：

-   MyISAM 引擎**不支持事务**，一旦执行 `INSERT` 就立即生效；
-   InnoDB 支持事务，因此 `ROLLBACK` 会撤销对 `countries` 的插入；
-   所以 `languages` 插入不会被回滚，`countries` 插入会被撤销。

---

## ✅ 第 162 题：Slave I/O 线程的作用

**英文题干：**  
What does the slave I/O thread do?

**正确答案：**  
✅ A) 它连接主库，请求主库发送其 binary logs 中记录的更新

中文解析：

-   从库的 I/O 线程与主库通信，请求并拉取 binary log；
-   然后把接收到的日志写入本地的 relay log；
-   接下来 SQL 线程再读取 relay log 执行其中的语句。

**其他选项均为错误描述：**

-   B) ❌ I/O 线程不调度底层系统 I/O；
-   C) ❌ 是 SQL 线程而非 I/O 线程执行 relay log；
-   D) ❌ 是主库的 binlog dump 线程锁 binary log。

---

## ✅ 第 163 题：授予最小权限创建临时表

**英文题干简述：**  
用户 Jane 想在 `SALES` 数据库中创建一个名为 `TOTALSALES` 的临时表。哪个授权语句满足“最小权限原则”？

**正确答案：**  
✅ B)

```sql
GRANT CREATE TEMPORARY TABLES ON sales.* TO jane;
```

中文解析：

-   临时表是 **session scoped**，权限必须在数据库级别授予；
-   `sales.totalsales` 是表级授权，但 `CREATE TEMPORARY TABLES` 无法授予到表级；
-   所以只能在 `sales.*` 上授权；

---

## ✅ 第 164 题：RPM 安装 MySQL 默认的数据目录位置

**题干简述：**  
在 Oracle Linux 7 上使用 RPM 安装 MySQL，默认的数据目录在哪？

**正确答案：**  
✅ D) `/var/lib/mysql`

中文解析：

-   RPM 安装默认把 MySQL 数据文件放在 `/var/lib/mysql`；
-   可通过修改配置文件 `/etc/my.cnf` 中的 `datadir` 修改；
-   其他选项如 `/usr/bin`、`/usr` 是二进制或系统目录；
-   `/usr/mysql` 是编译安装或自定义路径可能出现的，但不是 RPM 默认。

---

## ✅ 第 165 题：使用 `mysqlbinlog` 改写 schema 名称

**题干简述：**  
你需要将 binary log 中原属 `mydb1` 的事件恢复到 `mydb2`。应该用哪条命令？

**正确答案：**  
✅ A)

```sql
mysqlbinlog --rewrite-db='mydb1->mydb2' | mysql
```

中文解析：

-   `--rewrite-db='源库名->目标库名'` 是 `mysqlbinlog` 提供的重映射功能；
-   管道输出给 mysql 可以实时执行；
-   该方式适用于跨 schema 恢复场景。

​  

## 第 166 题：从 binlog 中恢复被误删的表

**英文题干：**  
binary log 文件 binlog.000036 中的如下片段显示：

```sql
# at 5000324
#191120 14155116 server id 1 end_log_pos 500453 ...
SET TIMESTAMP=1574222116;
DROP TABLE 'rental';
```

你恢复了一个备份，该备份恰好对应 binlog.000036 的开头。  
**你应该使用哪条命令来恢复该表？**

**正确答案：**  
✅ A) `mysqlbinlog --stop-position=500324 binlog.000036 | mysql`

中文解析：

-   `--stop-position=500324` 表示 **读取至刚好发生 DROP TABLE 之前的 binlog 事件**，从而避免执行 DROP；
-   这是最安全的“点位恢复”方法；
-   其他选项如 `--stop-datetime=...` 虽也可尝试，但精度不如 `stop-position`；
-   使用错误的 position（如 500453）会包含 DROP 语句，导致恢复失败。

---

## ✅ 第 167 题：升级到 MySQL 8.0 后认证插件错误

**题干简述：**  
升级到 MySQL 8.0 后，客户端连接时报错：

```sql
ERROR 2059 (HY000): Authentication plugin 'caching_sha2_password' cannot be loaded
```

**哪条语句可以让客户端恢复连接？**

**正确答案：**  
✅ D) `ALTER USER user IDENTIFIED WITH mysql_native_password BY 'password';`

中文解析：

-   MySQL 8.0 默认使用 `caching_sha2_password` 认证插件；
-   某些旧版客户端无法识别此插件；
-   将用户认证方式改为 `mysql_native_password` 可恢复兼容性。

---

## ✅ 第 168 题：授予嵌套子查询所需权限

**题干简述：**  
如下 SQL 更新语句：

```sql
UPDATE world.city 
SET Population = Population * 1.1 
WHERE CountryCode IN ( SELECT Code FROM world.country WHERE Continent = 'Asia );
```

Tom 用户执行此语句需要哪些权限？

**正确答案：**​✅ C)

```sql
GRANT UPDATE ON world.city TO tom@'%';
GRANT SELECT ON world.country TO tom@'%';
```

中文解析：

-   外层 UPDATE 涉及 `city` 表，需要 UPDATE 权限；
-   内层 SELECT 查询 `country` 表，需要 SELECT 权限；
-   不需要 ALL 权限，不应扩大授权范围；
-   精确授权最符合“最小权限原则”。

---

## ✅ 第 169 题：启用 MySQL Enterprise Audit 的规则过滤

**题干简述：**  
以下哪个命令用于启用基于规则的 MySQL Enterprise Audit 审计功能？

**正确答案：**​✅ D)

```sql
shell> mysql < audit_log_filter_linux_install.sql
```

中文解析：

-   该 SQL 脚本安装并激活 audit filter 规则，支持规则表达式；
-   其他选项如 `INSTALL COMPONENT audit_log` 不会启用规则功能；
-   `audit_log_filter_linux_install.sql` 通常在 share 目录中提供；
-   并非所有 audit 功能都是自动启用的。

---

## ✅ 第 170 题：使用 Query Analyzer 定位慢查询

**题干简述：**  
使用 MySQL Enterprise Monitor 中的 Query Analyzer 功能查找性能问题，应该从哪里开始？

**正确答案：**  
✅ A) 排序 \\Exec\\ 列，并查找具有 **低 QRTi（Query Response Time index）** 值的查询。

中文解析：

-   QRTi 是 MySQL Enterprise Monitor 的指标，代表查询响应时间效率；
-   越低的 QRTi 表示查询表现越差；
-   所以查找“执行次数高但 QRTi 低”的 SQL 是优化起点；
-   不要只关注延迟高或访问频次多的图表。

​  

## 第 171 题：MySQL Enterprise Firewall 的统计字段含义

**英文题干：**  
查看防火墙命令和输出，哪个说法是正确的？

**正确答案：**  
✅ B) `Firewall_access_suspicious` 表示处于 DETECTING 模式时被标记为可疑但仍被允许的语句数量。

中文解析：

MySQL Enterprise Firewall 的几个统计字段含义如下：

-   `Firewall_access_suspicious`：在 **DETECTING 模式** 中记录的可疑语句数量（系统未阻止，但记录）；
-   `Firewall_access_denied`：被明确拒绝的**语句数**；
-   `Firewall_access_granted`：被允许的**语句**；
-   `Firewall_cached_entries`：缓存中的白名单**语句**摘要数量。

其作用是帮助 DBA 在防火墙从 DETECTING 切换到 PROTECTING 前识别风险 SQL。

---

## ✅ 第 172 题：优化 Buffer Pool 实例数量

**英文题干：**  
根据图示输出，应该如何调整 buffer pool 实例数量以优化性能？

**正确答案：**  
✅ E) 增加 buffer pool 实例数至 12

中文解析：

InnoDB buffer pool 实例的推荐策略：

-   每个实例**至少分配 1G**；
-   最少设置为 1，最多 64；
-   每个实例越小，碎片和互斥锁争用越少。

如果总 `innodb_buffer_pool_size` 较大（如 12GB），就应设置更多实例（如 12），以提升并发性能。

---

## ✅ 第 173 题：事务中授权后继续执行

**英文题干简述：**  
你在事务中遇到权限不足错误，DBA 授权 `GRANT UPDATE` 后，如何最小中断地继续执行？

**正确答案：**  
✅ B) 在同一事务中重新执行失败语句

中文解析：

-   在 MySQL 中，**权限变更会立即对现有连接生效**；
-   无需重连或重启事务；
-   只要重新执行该语句即可；

这是因为表级和列级权限检查是在每次请求时进行的。

---

## ✅ 第 174 题：从 binlog 中特定位置恢复数据

**英文题干：**  
你发现 position=1797 之后的 binary log 中数据需要重放，命令如下：

```sql
mysqlbinlog binlog.000008 --start-position=1798
```

应如何完成命令？

**正确答案：**  
✅ C) 通过管道传入 MySQL 客户端

```sql
mysqlbinlog binlog.000008 --start-position=1798 | mysql -u root -p
```

中文解析：

-   `--start-position=1798` 表示从该位置恢复；
-   管道是最常见的做法；
-   `--write-to-remote-server` 不是合法选项；
-   不能只执行 `mysqlbinlog`，必须配合 `mysql`。

---

## ✅ 第 175 题：调整连接控制参数顺序限制

**英文题干：**  
已有配置：

```sql
connection_control_min_connection_delay=1000  
connection_control_max_connection_delay=2000
```

你希望把 min/max 分别改为 3000 和 5000。现在先执行：

```sql
SET GLOBAL connection_control_min_connection_delay=3000;
```

结果是？

**正确答案：**​✅ D) 报错

中文解析：

设置规则：

-   `min_connection_delay <= max_connection_delay`；
-   当前 max=2000，小于你尝试设置的 min=3000 → 违反规则 → 报错；
-   应先调高 max，再调高 min。

​  

## 第 176 题：配置多个实例使用相同端口

**题干：**  
如何配置 `mysqld_multi`，使多个 MySQL 实例使用相同端口？

**正确答案：**  
✅ D) 实例监听不同的 IP 地址

**中文解析：**

-   在同一服务器上运行多个 MySQL 实例时，如果监听不同 IP，可以共用同一个端口（例如都用 3306）；
-   这是操作系统层面允许的行为；
-   每个实例通过 `bind-address` 指定独占 IP 地址；
-   其他选项解释：

-   A) 子网掩码不影响端口绑定；
-   B) 用户账户不同与网络无关；
-   C) socket 是本地通信，与 TCP 端口无关。

---

## ✅ 第 177 题：设置 SHA-256 作为默认认证方式

**题干：**  
MySQL 安装在 Linux 上，datadir 设为 `/data/mysql`，如何设置默认认证插件为 `sha256_password`？

**正确答案：**  
✅ B) 在配置文件中添加 `default_authentication_plugin=sha256_password`

**中文解析：**

-   `default_authentication_plugin` 控制新创建用户默认的认证方式；
-   8.0 默认是 `caching_sha2_password`；
-   如需强制使用 `sha256_password`（更兼容 OpenSSL），需修改配置文件；
-   其他选项解释：

-   A) CREATE USER 仅影响单个账户；
-   C/D) 设置为其他插件或错误参数。

---

## ✅ 第 178 题：打开表数量过高导致性能瓶颈

**题干：**  
对比两个 `GLOBAL STATUS` 报告，系统 100 秒内 `Opened_tables` 增长了 5000，`Open_tables` 恒为 1024。你注意到连接数在 50～75 之间波动。应修改哪个参数以改善性能？

**正确答案：**  
✅ D) 增加 `table_open_cache`

**中文解析：**

-   `Opened_tables` 表示**必须重新打开的表数量**，数字增长快说明缓存不足；
-   `Open_tables` 是当前缓存中打开的表数量；
-   `table_open_cache` 控制最多缓存多少张表；
-   适当增加该值可减少频繁打开表带来的性能损耗；
-   其他选项解释：

-   A) `max_connections` 与打开表无关；
-   B) 降低 `open_files_limit` 反而限制缓存能力；
-   C) `table_definition_cache` 是表结构缓存，不涉及文件句柄。

---

## ✅ 第 179 题：高锁等待的最可能原因

**题干（简述）：**  
某同事反馈网站响应慢，EXPLAIN 输出显示大量锁等待。最可能的原因是？

**正确答案：**  
✅ C) 你大多数表使用 MyISAM 引擎

**中文解析：**

-   MyISAM 是非事务性存储引擎，只支持**表级锁**；
-   在并发访问场景中，写操作会阻塞所有读取操作，容易造成锁等待；
-   替换为 InnoDB（行级锁）是解决方案；
-   错误项如：

-   A) InnoDB 是行锁；
-   B) 缓冲池大小不足会影响 I/O，不直接造成锁等待；
-   D) flush 等待是 I/O 问题，不属于锁。

---

## ✅ 第 180 题：SSL 未被使用的原因

**题干简述：**  
某连接未使用 SSL，原因是？

**正确答案：**  
✅ A) 是通过 UNIX socket 连接的

**中文解析：**

-   使用 socket、named pipe、shared memory 等本地通信方式时，MySQL 不启用 SSL；
-   SSL 只在 TCP/IP 连接上有效；
-   错误项解释：

-   B) 没有选择数据库不会影响 SSL；
-   C) root 用户可使用加密；
-   D) `ssl_fips_mode` 是合规选项，不影响连接方式本身。

​  

## 第 181 题：InnoDB Cluster 主节点故障后的行为

**英文题干：**  
你配置了一个单主模式（single-primary mode）的 InnoDB Cluster，当主节点因网络问题宕机时会发生什么？

**正确答案：**  
✅ B) 会自动选举出一个新的主节点。

中文解析：

InnoDB Cluster 使用 Group Replication 构建高可用集群。  
在单主模式下，主节点宕机时，系统会根据 Group Replication 的仲裁机制自动选出新的主节点，保持可写性。

-   A) ❌ 所有成员不会都变为只读；
-   C) ❌ 不需要手动晋升新主；
-   D) ❌ 不会因网络分区直接关闭集群；
-   E) ❌ 不是所有成员都设为可写。

---

## ✅ 第 182 题：加密表使用的命令

**英文题干：**  
你已配置 MySQL Enterprise TDE（透明数据加密），应该使用哪个命令对表进行加密？

**正确答案：**  
✅ D)

```sql
ALTER TABLE <table> ENCRYPTION='Y';
```

中文解析：

启用 TDE 后，你可对指定表设置加密属性，使用 `ALTER TABLE` 并设置 `ENCRYPTION='Y'` 是标准方法。

-   A) ❌ `UPDATE` 不能控制加密属性；
-   B) ❌ `ROTATE MASTER KEY` 是轮换加密主密钥，不加密具体表；
-   C) ❌ 修改 `information_schema` 是无效操作。

---

## ✅ 第 183 题：恢复被误删 InnoDB 表

**英文题干：**  
开发人员误删了 InnoDB 表 `Customers`，你有一个两天前的 datadir 备份，如何恢复该表？

**正确答案：**  
✅ D)停止 MySQL，执行：

```sql
mysqlbackup --datadir=/var/lib/mysql --backup-dir=/dbbackup --include-tables='Company\\.Customers' copy-back
```

然后重新启动 `mysqld`。

中文解析：

-   使用 `mysqlbackup copy-back` 可从备份目录中恢复单张表；
-   需确保匹配表名，并且 `copy-back` 执行前关闭 mysqld 服务；
-   其他选项如直接拷贝 `.ibd` 文件或更改 datadir 会造成数据不一致或无法识别。

---

## ✅ 第 184 题：分析连接内存使用情况的 SQL

**SQL 查询：**

```sql
SELECT SUM(m.CURRENT_NUMBER_OF_BYTES_USED) AS TOTAL 
FROM performance_schema.memory_summary_by_thread_by_event_name m 
JOIN performance_schema.threads t ON m.THREAD_ID = t.THREAD_ID 
WHERE t.PROCESSLIST_ID = 10;
```

**此查询返回什么？**

**正确答案：**  
✅ A) 编号为 10 的连接所使用的总内存。

中文解析：

-   `PROCESSLIST_ID` 对应 `SHOW PROCESSLIST` 中的 `Id`（即连接 ID）；
-   `THREAD_ID` 是 Performance Schema 内部标识；
-   查询是：找到连接 10 对应的线程，再统计该线程分配的所有内存使用量。

---

## ✅ 第 185 题：并行备份系统数据库的命令

**题干：**  
你希望每日备份所有数据库，包括 `ndbinfo` 和 `sys` 等内部库。哪条命令可支持**并行备份**？

**正确答案：**​✅ B)

```sql
mysqlpump --include-databases=% > full-backup-$(date +%Y%m%d).sql
```

中文解析：

-   `mysqlpump` 是 `mysqldump` 的升级版本，支持并行逻辑备份；
-   默认不备份 `ndbinfo` 和 `sys`，加上 `--include-databases=%` 可显式指定所有数据库；
-   `%` 是匹配全部数据库的通配符。

​  

## 第 186 题：备份期间 DDL 操作对 MySQL Enterprise Backup 的影响

**题干简述：**  
执行命令：

```sql
mysqlbackup --user=dba --password --port=3306 --with-timestamp --backup-dir=/export/backups backup-and-apply-log
```

**哪个说法是正确的？**

**正确答案：**  
✅ D) 备份可能会受到备份期间执行的 DDL 操作的影响。

中文解析：

-   `mysqlbackup` 工具支持热备，但在执行某些 **DDL（如 ALTER TABLE）** 操作时，可能影响备份一致性；
-   为确保数据一致性，建议避免在备份窗口期间执行结构性变更；
-   `--with-timestamp` 会自动创建子目录，`backup-and-apply-log` 是组合步骤；
-   其他选项解析：

-   A) ❌ 并非使用预连接方式操作服务器；
-   B) ❌ 不会强制将实例设置为只读；
-   C) ❌ 并不是离线备份。

---

## ✅ 第 187 题：InnoDB 表在数据目录中的文件组成

**题干简述：**  
`test` 数据库下有一张 InnoDB 表 `city`，数据目录下 `test` 文件夹中会包含哪些文件？

**正确答案：**  
✅ B) `city.ibd`

中文解析：

-   在启用 `innodb_file_per_table`（默认开启）的情况下，每张 InnoDB 表的数据和索引存在 `.ibd` 文件中；
-   `.frm` 文件从 MySQL 8.0 起已经废弃；
-   `.sdi` 是数据字典文件，但只有当设置 `innodb_dedicated_server=OFF` 且手动开启导出时才存在；
-   MyISAM 表才会出现 `.MYD`、`.MYI` 文件。

---

## ✅ 第 188 题：MySQL Router bootstrap 功能的作用

**题干简述：**  
执行以下命令：

```sql
mysqlrouter --bootstrap user@hostname:port --directory=directory_path
```

**执行该命令的作用是什么？**

**正确答案：**  
✅ A) MySQL Router 会根据 InnoDB Cluster 元数据服务器的信息配置自身。

中文解析：

-   `--bootstrap` 是自动配置 MySQL Router 的关键命令；
-   它会连接到 metadata server，拉取集群信息，并生成配置文件；
-   配置生成后会保存在指定的 `--directory` 目录中；
-   其他选项：

-   B) ❌ Router 只配置自己，不配置整个集群；
-   C/D) ❌ 不会重启，也不会依赖已有文件配置。

---

## ✅ 第 189 题：Seconds\_Behind\_Master 的含义

**题干简述：**  
执行 `SHOW SLAVE STATUS`，观察 `Seconds_Behind_Master` 的含义？

**正确答案：**  
✅ A) 表示 I/O 线程接收到主库最后一个事务的时间 与 SQL 线程应用该事务的时间之间的间隔。

中文解析：

-   `Seconds_Behind_Master` 指的是：**SQL 线程执行 relay log 最后事件的主库时间戳** 与当前从库时间的差值；
-   并非精确度量延迟，但常用于监控；
-   与 relay log 写入时间、事务提交时间等没有直接关系。

---

## ✅ 第 190 题：启用基于规则的 Enterprise Audit 的命令

**题干简述：**  
下列哪个命令用于启用基于规则的 MySQL Enterprise 审计功能？

**正确答案：**  
✅ A)

```sql
shell> mysql < audit_log_filter_linux_install.sql
```

中文解析：

-   `audit_log_filter_linux_install.sql` 是官方提供的安装脚本，用于配置规则引擎支持；
-   包括创建审计表、触发器、UDF 等；
-   其他选项解释：

-   C/D) ❌ `INSTALL PLUGIN/COMPONENT audit_log` 仅加载插件本身，不启用规则支持；
-   B) ❌ `--log-raw=audit.log` 并非合法参数。

​  

## 第 191 题：**使用** `**kill**` **命令终止** `**mysqld**` **服务时的行为差异**。

  

**C)** `**kill -15**` **执行的是一次正常的关闭过程，类似于** `**mysqladmin shutdown**` **命令。**

---

✅ 中文解析：

MySQL 服务进程（`mysqld`）在收到不同信号时行为不同：

-   `kill -15` （SIGTERM）：

-   正常关闭；
-   相当于 `mysqladmin shutdown`；
-   会等待所有连接关闭、缓冲刷盘，**数据一致性得以保证**。

-   `kill -9` （SIGKILL）：

-   强制终止，无任何清理；
-   **可能造成未写入磁盘的事务丢失**；
-   不推荐用于生产环境下关闭 mysqld。

---

❌ 错误选项解析：

-   **A)**`kill -15` 是安全信号，不应该被“避免”；
-   **B)**`kill -15` 与 `kill -9` 差异巨大，不能混为一谈；
-   **D)**`mysqld_safe` 是守护进程工具，**不会阻止 kill 信号**，也无法拒绝外部信号行为。

## ✅ 第 192 题：使用 `mysqlbinlog` 将 binlog 中的 schema 映射为另一个 schema

**题干简述：**  
将 binary log 中的 `mydb1` 数据恢复为 `mydb2`，应使用哪个命令？

**正确答案：**  
✅ B)

```sql
mysqlbinlog --rewrite-db='mydb1->mydb2' | mysql
```

中文解析：

-   `--rewrite-db='源->目标'` 是 `mysqlbinlog` 提供的功能，可将所有来自 `mydb1` 的操作转换为 `mydb2`；
-   可以用于灾难恢复或环境迁移；
-   其他错误命令如重复使用 `--rewrite-db` 或拼写错误将导致失败。

---

## ✅ 第 193 题：InnoDB 死锁行为分析

**题干简述：**  
两个连接分别持有资源并尝试获取对方资源，系统启用了死锁检测（默认）。会发生什么？

**正确答案：**  
✅ B) 立即发生死锁（A deadlock occurs immediately.）

### 中文解析：

-   InnoDB 默认启用死锁检测 (`innodb_deadlock_detect=ON`)；
-   当发现两个事务互相等待资源时，会立即检测并终止其中一个（称为受害者事务）；
-   如果禁用死锁检测，InnoDB 会根据 `innodb_lock_wait_timeout` 来超时处理。

---

## ✅ 第 194 题：**GTID（全局事务标识）复制机制下主从状态的比较分析**

这道题考察的是 **GTID（全局事务标识）复制机制下主从状态的比较分析**，尤其是在从库停止数日后重新加入主库时，是否可以继续复制。

✅ **题干翻译：**

你重新配置并启动了一个**停止复制多日**的从库，配置文件和 `CHANGE MASTER` 命令都正确。现在查看主从 GTID 状态如下（见图），哪个说法是正确的？

---

📊 **GTID 状态简要整理：**

```sql
✅ 主库（Master）：
gtids_executed:
  aaaaaaaa:1-321
  bbbbbbbb:1-50
  cccccccc:1234-1237

gtids_purged:
  aaaaaaaa:1-100
  bbbbbbbb:1-10
  cccccccc:1234-1237

✅ 从库（Slave）：

gtids_executed:
  aaaaaaaa:1-160
  cccccccc:1234-1237

gtids_purged:
  aaaaaaaa:1-70
  cccccccc:1234-1237
```
---

✅ 正确答案是：

**C) 复制将失败，因为主库缺失了从库所需的** `**bbbbbbbb**` **的 GTID 事务。**

---

✅ 中文解析：

🚨 关键点：

-   从库执行记录中**完全没有** `**bbbbbbbb**` 的 GTID；
-   但主库中 `gtids_executed` 显示该 GTID 段为 `1-50`；
-   主库 `gtids_purged` 中仅保留了 `bbbbbbbb:1-10`（表示 **11-50 仍保留在 binlog 中**）；
-   然而，从库却 **没有任何** `**bbbbbbbb**` **的事务执行过**，也就是**从库缺失 1-50** 的所有事务。

✅ 结论：

-   从库一旦启动复制，会尝试从主库获取 `bbbbbbbb:1-50`；
-   如果主库 binary log 中这些 GTID **已被清理（或不可用）**，就会导致复制失败；
-   虽然图中未明确说明 binlog 是否清理，但题干描述为“几天未复制”暗示主库可能清除了部分 binlog。

---

❌ 其他选项解析：

-   **A)** 错：主库未清除 `cccccccc`，它们仍然在 executed/purged 中一致；
-   **B)** 错：问题在于 `bbbbbbbb` 缺失，不会“成功工作”；
-   **D)** 错：从库清除得比主库少（purged 是 `aaaa:1-70` vs 主库 `1-100`），这不会导致问题；
-   **E)** 错：`cccccccc` 范围一致（1234-1237），无矛盾。

  

## ✅ 第 195 题：`mysqlbackup copy-back` 命令的行为

**题干简述：**  
执行如下命令：

```sql
mysqlbackup --defaults-file=/backups/server-my.cnf --backup-dir=/backups/full copy-back
```

**哪个说法正确？**

**正确答案：**  
✅ B) 它将备份目录中的文件恢复到原始的 MySQL 数据目录位置。

中文解析：

-   `copy-back` 会将 `--backup-dir` 中的备份文件恢复到 `my.cnf` 中指定的 `datadir`；
-   恢复过程会覆盖原始数据目录（务必停库）；
-   不是“从数据目录备份文件” → 应为“从备份目录恢复数据”；
-   其他错误说法如覆盖已有备份、生成不一致备份等均与事实不符。

​  

## 第 196 题：慢查询日志设置调整

**题干简述：**  
你希望记录满足如下条件的 SQL 到慢查询日志中：

-   扫描的记录行数 ≥ 5000 且

-   查询时间超过 5 秒 **或**
-   查询没有使用索引

**哪一组选项能满足需求？**

**正确答案：**  
✅ C)

```sql
long_query_time=5  
min_examined_row_limit=5000
```

中文解析：

-   `long_query_time=5`：设置“慢查询”时间阈值为 5 秒；
-   `min_examined_row_limit=5000`：只有扫描的行数 ≥ 5000 的 SQL 才会记录；
-   `log_queries_not_using_indexes` 会额外记录**未使用索引**的 SQL，但需要与上面配合；
-   `log_throttle_queries_not_using_indexes` 是限制频率，非必须；
-   所以关键是：设定好“耗时阈值 + 行数阈值”两个参数。

---

## ✅ 第 197 题：kill -15 终止 mysqld 的行为

**题干简述：**  
执行命令：

```sql
ps aux | grep mysqld
kill -15 <pid>
```

**此操作对 mysqld 有何影响？**

**正确答案：**  
✅ C)`kill -15` 会执行类似 `mysqladmin shutdown` 的**正常关机**流程。

中文解析：

-   `kill -15`（SIGTERM）是“正常终止”，系统通知 mysqld 优雅退出；
-   等价于 `mysqladmin shutdown` 或 `systemctl stop mysqld`；
-   `kill -9`（SIGKILL）才是“强制终止”；
-   所以 `kill -15`**是安全可接受的方式**。

---

## ✅ 第 198 题：在不中断服务前提下的备份策略

**题干简述：**  
你有 500GB 的 MySQL 数据，混合使用 MyISAM 与 InnoDB，引擎要求如下：

-   服务**不能停机或锁库**；
-   恢复可在任意机器上执行；
-   可接受最多 **丢失 1 小时数据**；

**最佳备份策略是？**

**正确答案：**  
✅ D) 从 MySQL 的从库备份

中文解析：

-   备份从库可以：

-   避免主库停写或加锁；
-   利用异步复制允许轻微数据滞后（≤1 小时）；
-   对 MyISAM 数据无干扰风险；

-   Clone 插件不能跨系统使用；
-   物理/逻辑备份会锁 MyISAM 表或需加锁影响服务。

---

## ✅ 第 199 题：InnoDB 索引统计信息

**题干简述：**  
关于 InnoDB 索引统计信息，哪个说法正确？

**正确答案：**  
✅ E) 更新索引统计信息是一个高 I/O 开销的操作。InnoDB 在更新索引统计信息时会扫描磁盘页，因此是一项耗费 I/O 的操作，特别是当使用持久化统计信息（`innodb_stats_persistent=ON`）时，它会从磁盘中读取页面而非从缓冲池中直接读取，I/O 成本更高。

中文解析：

-   InnoDB 为提升执行计划精度，定期分析表统计信息（如索引基数）；
-   `ANALYZE TABLE`、自动更新统计信息会触发表扫描；
-   特别是在大表上是重型操作，涉及磁盘读取；
-   其他选项错误解析：

-   A) `innodb_stats_persistent_sample_pages` 会提升准确性，但增加内存和 I/O；

-   增加这个参数的作用是**提高统计信息的精度**（通过抽样更多页面），但这**不会提升扫描速度**。
-   它影响的是**执行计划的选择准确性**，与内存消耗关系有限，主要是 I/O 成本增加。

-   B

-   **transient statistics** 是临时统计信息，不使用 `innodb_stats_persistent_sample_pages`。这个参数只影响 **persistent statistics**。

-   C

-   统计信息是从**磁盘页中**读取而非缓冲池。如果只依赖 buffer pool 里的页面可能导致统计信息偏差。

-   D)

-   虽然 `innodb_stats_auto_recalc=ON` 会在表大幅更新时自动重新统计信息，
-   但**创建新索引**不会触发统计信息更新，它只影响已有表在行数大改动时是否自动重算。
-   此选项与创建索引没有直接关系。

  

---

## ✅ 第 200 题：MySQL 错误日志轮换方式

**题干简述：**  
如何轮换（rotate）MySQL 的错误日志（error log）？

**正确答案：**  
✅ B) **先重命名 error log 文件，然后执行：**

```sql
FLUSH ERROR LOGS;
```

中文解析：

-   MySQL 不自动切割 error log；
-   正确方法是：

1.  手动重命名当前 error log 文件；
2.  执行 `FLUSH ERROR LOGS;`，强制重开新日志文件；

-   注意：

-   `SET GLOBAL log_error=...` 不生效；
-   `max_error_count` 无关；
-   没有 `log_rotate_interval` 参数可用。

​  

## 第 201 题：InnoDB 日志文件大小变更导致启动失败

**题干简述：**  
更改了 `innodb_log_file_size` 设置后，MySQL 无法启动，日志提示：

```sql
InnoDB: Error: log file ./ib_logfile0 is of different size 5242880 bytes than specified in .cnf 26214400 bytes!
```

**正确答案：**  
✅ C) 删除 ib\_logfile0 和 ib\_logfile1 文件

中文解析：

-   如果更改了 `innodb_log_file_size`，启动时 InnoDB 会检查现有日志文件是否匹配；
-   如果不匹配（如配置设为 25M，而现有文件是 5M），则会报错；
-   解决办法是 **先停止 MySQL 服务，删除 ib\_logfile0 和 ib\_logfile1，然后再启动**，InnoDB 会重新创建；
-   注意：强制初始化（如选项 D）或 flush-logs（选项 A）不能解决该问题。

## ✅ 第 202 题：SQL 注入常用字符

**题干简述：**  
以下哪些字符最常用于 SQL 注入攻击？

**正确答案：**  
✅ A) `'` 和 `\`

中文解析：

-   攻击者常用 `'`（单引号）终结字符串，`\`（转义符）绕过 SQL 解析；
-   其他常见字符还包括：`--`（注释）、`;`（语句结束符）等；
-   `< >`（B）、换行符（C）、`+ -`（E）等虽然有一定用途，但不是**主要**攻击字符。

---

## ✅ 第 203 题：主节点失效时的主选举

**配置简述：**

```sql
dba.createCluster('cluster1', memberWeight:35);
mycluster.addInstance('ic@ic2', memberWeight:25);
mycluster.addInstance('ic@ic3', memberWeight:50);
group_replication_consistency=BEFORE_ON_PRIMARY_FAILOVER
```

若 ic1 宕机，会发生什么？

**正确答案：**  
✅ C) ic3 成为新主，但在 backlog 事务完成前被忽略

中文解析：

-   `BEFORE_ON_PRIMARY_FAILOVER` 表示新主必须在事务一致性确认后才能被接受；
-   加权选举中，ic3 权重最高 → 被选为新主；
-   但如果存在 backlog，它会暂时不接收写入请求；
-   所以正确答案是 C。

---

## ✅ 第 204 题：使用 mysqlpump 备份用户账户

**命令：**

```sql
mysqlpump --exclude-databases=% --users
```

**此命令的作用是？**

**正确答案：**  
✅ D) 创建所有 MySQL 用户账户的逻辑备份

中文解析：

-   `--users` 参数用于备份用户账户（含权限）；
-   `--exclude-databases=%` 排除所有数据库，仅备份账户信息；
-   所以结果是“只备份账户，不含表数据”。

---

## ✅ 第 205 题：默认记录数据变更的日志类型

**题干简述：**  
要记录数据库对象和数据的更改，使用哪个日志最合适？

**正确答案：**  
✅ B) binary log（二进制日志）

中文解析

-   Binary Log 是记录所有 DML 和部分 DDL 的事务变更日志；
-   可用于复制、闪回恢复；
-   其他选项：

-   Error log：记录错误、启动、关闭等事件；
-   General query log：记录所有连接和查询，开销大；
-   Audit log：需额外插件；
-   Slow query log：仅记录慢 SQL。

## 第 206 题：InnoDB Cluster 节点宕机后应使用哪条命令恢复？

**题干简述：**  
查看 host2 节点状态后，哪一项操作可以将其重新加入集群？

**正确答案：**  
✅ C)

```sql
cluster.rejoinInstance('<user>@host3:3377')
```

中文解析：

-   `rejoinInstance()` 用于**节点未被 removeInstance 删除但由于崩溃或重启离线**的场景；
-   它不会重复写入元数据，仅从 donor 节点同步数据；
-   `addInstance()` 只能用于显式 removeInstance() 后的重新加入；
-   `rebootClusterFromCompleteOutage()` 是用于**全体节点都离线**时的恢复操作，不适用于单节点。

---

## ✅ 第 207 题：查看 RBR 复制中的伪 SQL 语句

**题干简述：**  
你正在使用 **基于行的复制（Row Based Replication, RBR）**，想查看某个 binary log 位置的伪 SQL 表达，应该使用哪条命令？

**正确答案：**  
✅ B)

```sql
mysqlbinlog --verbose --start-position=NNNN log_file
```

中文解析：

-   `--verbose` 可将 RBR 中的事件解析为伪 SQL；
-   `--start-position=NNNN` 表示从该位置开始查看；
-   其他错误选项如 `--debug`、`mysqlshow` 等并不支持或无效。

---

## ✅ 第 208 题：查看慢查询日志中按平均耗时排序的工具

**题干简述：**  
想要分析慢查询日志中**按平均耗时排序的语句**，应使用哪个工具？

**正确答案：**  
✅ E) `mysqldumpslow`

中文解析：

-   `mysqldumpslow` 是官方自带的 Perl 脚本工具；
-   默认从 `slow_query_log` 中提取数据，支持按平均耗时、最大耗时、次数等排序；
-   示例用法：

```sql
mysqldumpslow -s at -t 10 /var/log/mysql/slow.log
```

`-s at` 表示按平均时间排序，`-t 10` 表示前十条。

---

## ✅ 第 209 题：`mysqld --initialize` 执行后 root 密码记录在哪里？

**题干简述：**  
运行：

```sql
mysqld --initialize
```

哪项说法正确？

**正确答案：**  
✅ A) Root 密码以明文形式记录在 error log 中。

中文解析：

-   `--initialize` 会初始化 datadir 并生成临时 root 密码；
-   该密码会输出到 error log：

```sql
A temporary password is generated for root@localhost: abc!23@MySQL
```

-   之后你应手动登录并执行 `ALTER USER ... IDENTIFIED BY ...` 更换密码；
-   并非无密码（D 错），也不会默认 `/tmp` 目录存储（B 错）。

## ✅ 第 210 题：恢复损坏的 relay log

**题干简述：**  
从库因磁盘问题导致 relay log 损坏。除了 relay log 外，其他文件正常。应如何恢复复制？

你的 MySQL 环境为异步、基于位置的复制，一个主库一个从库。  
从库因磁盘 I/O 故障停止服务。你确认从库的 relay log 文件已损坏且无法使用，但其他文件未受影响。你重启了 MySQL 服务。此时应如何恢复复制？

**正确答案：**  
✅ C)

-   删除 slave 的 relay log；
-   使用 `CHANGE MASTER` 指定 log 位置；
-   执行 `START SLAVE`

中文解析：

-   损坏 relay log 后，`START SLAVE` 直接失败；
-   正确流程如下：

```sql
STOP SLAVE;
RESET SLAVE;  -- 可选，但要小心，它会清除很多复制配置
CHANGE MASTER TO ... MASTER_LOG_FILE='xxx', MASTER_LOG_POS=yyy;
START SLAVE;
```

-   必须明确指定主库的 binary log 文件名和位置；
-   **A)** 只删除 relay log 并 `START SLAVE` 是不够的，因为从库记录的位置信息已丢失或指向了不存在的位置 → 会报错；
-   **B)** 恢复整个从库是过度操作，当前只是 relay log 损坏；
-   **D)** relay log 是由从库生成的中继日志，不能从主库“下载”；主库只持有 binlog。

​  

## 第 211 题：私有网络中自签名证书的可信性

**题干简述：**  
公司部署了私有网络（私有 DNS 和自建 CA），所有 MySQL 服务端和客户端证书都使用内部 CA 签发。所有客户端仅存在于该私有网络中。此时与 MySQL 建立的加密连接所用的自签名证书，与被知名第三方 CA 签发的证书相比，哪个说法正确？

**正确答案：**  
✅ F) 自签名证书 **不如第三方签发的证书安全且可信（less secure and less trusted）**

中文解析：

-   自签名证书在内部可信环境中可以用，但其“信任”是局限的；
-   第三方 CA 提供全球信任链，安全性与完整性由 PKI 体系保障；
-   即使你用的是强加密（2048-bit RSA），**信任链缺失仍是致命弱点**；
-   其他选项如 “ equally trusted” 或 “more secure” 都不正确。

---

## ✅ 第 212 题：PROXY 用户与当前权限识别

**命令执行：**

```sql
GRANT PROXY ON accounting@localhost TO ''@'%';
SELECT USER(), CURRENT_USER(), @@proxy_user;
```

**哪个说法正确？**

**正确答案：**  
✅ E) 当前用户被授权为 `accounting@localhost`

中文解析：

-   `GRANT PROXY ON A TO B` 表示让用户 B 可以“伪装”为用户 A 登录；
-   `''@'%'` 是匿名用户；
-   `CURRENT_USER()` 返回**实际起作用的权限账户**；
-   因此，虽然连接用户是匿名的，但当前拥有 `accounting@localhost` 的权限；
-   `@@proxy_user` 显示代理的用户身份。

---

## ✅ 第 213 题：加密 MySQL 客户端连接配置文件的推荐方式

**题干简述：**  
你希望将客户端连接的用户名与密码加密保存在本地配置文件中，应如何操作？

**正确答案：**  
✅ C) 使用 `mysql_config_editor` 创建加密配置文件

中文解析：

-   `mysql_config_editor` 工具会将用户凭据加密存储在 `.mylogin.cnf` 中；
-   它是官方推荐的方式；
-   文件默认保存在 `~/.mylogin.cnf`，仅当前用户可读；
-   其他方式如手工加密（B）、用 AES 加密配置（D）、`mysql_secure_installation`（A）均不适用。

---

## ✅ 第 214 题：MySQL 8.0 客户端插件问题与解决方案

**报错信息：**

```sql
Error 2059 (HY000): authentication plugin ‘caching_sha2_password’ cannot be loaded
```

**哪个选项可以让客户端成功连接？**

**正确答案：**  
✅ C)

```sql
ALTER USER 'user' IDENTIFIED WITH mysql_native_password BY 'password';
```

中文解析：

-   `caching_sha2_password` 是 MySQL 8.0 默认认证插件，但老版本客户端可能不支持；
-   可通过 `ALTER USER ... IDENTIFIED WITH mysql_native_password` 降级认证方式；
-   注意：

-   仅设置 `mysqld --default_authentication_plugin=...` 无法影响已存在用户；
-   其他插件如 `sha256_password` 或 `caching_sha2_password` 本身也可能无法被低版本客户端识别。

---

## ✅ 第 215 题：Hash Join 算法的限制条件

**题干简述：**  
关于 Hash Join 算法，哪个说法正确？

**正确答案：**  
✅ B) Join 操作中**不能使用索引**

中文解析：

-   Hash Join 是在没有可用索引时的一种连接策略，使用 hash 表来匹配连接条件；
-   仅适用于 **等值连接（**`**=**`**）**，不能用于 **LEFT JOIN / RIGHT JOIN**；
-   优点：当无索引时效率高于嵌套循环；
-   缺点：内存消耗大，受限于 `join_buffer_size`；
-   A、C、D 都是错误的理解。
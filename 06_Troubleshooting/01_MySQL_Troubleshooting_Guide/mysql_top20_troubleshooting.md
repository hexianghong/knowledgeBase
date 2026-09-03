# MySQL 日常运维与开发故障排查 Top 20 深度指南

本指南汇集了 MySQL 日常运维及数据库开发中最常遇到的 20 个高频故障场景，深入解析其故障现象、产生诱因、排查诊断思路，并给出对应的 SQL 修复指令、优化参数配置与预防性的最佳实践建议。

---

## 目录
1. [故障 1：慢查询与索引失效（Slow Query & Index Invalidation）](#故障-1慢查询与索引失效slow-query--index-invalidation)
2. [故障 2：行锁等待超时（Lock Wait Timeout Exceeded）](#故障-2行锁等待超时lock-wait-timeout-exceeded)
3. [故障 3：死锁导致事务回滚（Deadlock Found When Trying to Get Lock）](#故障-3死锁导致事务回滚deadlock-found-when-trying-to-get-lock)
4. [故障 4：数据库连接数爆满（Too Many Connections）](#故障-4数据库连接数爆满too-many-connections)
5. [故障 5：元数据锁等待阻塞（Waiting for Table Metadata Lock）](#故障-5元数据锁等待阻塞waiting-for-table-metadata-lock)
6. [故障 6：内存溢出崩溃（mysqld OOM / Out of Memory）](#故障-6内存溢出崩溃mysqld-oom--out-of-memory)
7. [故障 7：大事务回滚极其缓慢（Large Transaction Rollback Delay）](#故障-7大事务回滚极其缓慢large-transaction-rollback-delay)
8. [故障 8：自增主键溢出与空洞（Auto-Increment ID Exhaustion）](#故障-8自增主键溢出与空洞auto-increment-id-exhaustion)
9. [故障 9：表情包及特殊字符插入失败（Incorrect String Value）](#故障-9表情包及特殊字符插入失败incorrect-string-value)
10. [故障 10：CPU 使用率高达 100%（High CPU Spikes）](#故障-10cpu-使用率高达-100high-cpu-spikes)
11. [故障 11：临时表频繁落盘（Created_tmp_disk_tables 偏高）](#故障-11临时表频繁落盘created_tmp_disk_tables-偏高)
12. [故障 12：客户端主机被拦截（Host is Blocked Because of Connection Errors）](#故障-12客户端主机被拦截host-is-blocked-because-of-connection-errors)
13. [故障 13：数据表损坏或物理损坏（Table/Index Corruption）](#故障-13数据表损坏或物理损坏tableindex-corruption)
14. [故障 14：慢日志/错误日志爆满打满系统磁盘（Log Space Exhaustion）](#故障-14慢日志错误日志爆满打满系统磁盘log-space-exhaustion)
15. [故障 15：InnoDB 内部信号量长时间等待警告（InnoDB: Long Semaphore Wait）](#故障-15innodb-内部信号量长时间等待警告innodb-long-semaphore-wait)
16. [故障 16：从库复制线程中断（Replication Error 1062/1032）](#故障-16从库复制线程中断replication-error-10621032)
17. [故障 17：大表历史数据清理困难（Large Scale Deletion Performance Drop）](#故障-17大表历史数据清理困难large-scale-deletion-performance-drop)
18. [故障 18：Table Open Cache 命中率低下（Opened_tables 异常增长）](#故障-18table-open-cache-命中率低下opened_tables-异常增长)
19. [故障 19：InnoDB Undo Log 无法收缩导致共享表空间膨胀](#故障-19innodb-undo-log-无法收缩导致共享表空间膨胀)
20. [故障 20：Redo Log 写磁盘瓶颈（Redo Log Disk I/O Bottleneck）](#故障-20redo-log-写磁盘瓶颈redo-log-disk-io-bottleneck)

---

## 故障 1：慢查询与索引失效（Slow Query & Index Invalidation）

### 故障现象
查询执行极其缓慢，执行时间超过阈值被记录至慢日志。应用响应变慢，严重时拖垮整个数据库吞吐。

### 产生原因
1. 缺少索引，导致全表扫描。
2. 索引失效场景：
   - 模糊查询条件中带有前导通配符：`LIKE '%keyword'`。
   - 对索引列执行算术运算或函数：`WHERE DATE(create_time) = '2026-06-12'` 或 `WHERE id + 1 = 10`。
   - 存在隐式类型转换，例如字符串类型的字段传入数值条件：`WHERE mobile = 13800000000` (如果 mobile 是 `VARCHAR`)。
   - 复合索引未遵守**最左匹配原则**。
   - 查询条件中的 `OR` 两边并不全是索引列。

### 诊断排查
在 SQL 语句前加 `EXPLAIN`，查看执行计划：
```sql
EXPLAIN SELECT * FROM users WHERE DATE(create_time) = '2026-06-12';
-- 关注 columns: type (若为 ALL 说明是全表扫描)、key (实际使用的索引)、rows (估算扫描行数)
```

### 解决方案
1. **重构 SQL 避开失效场景**：
   - 消除索引列上的函数计算：`WHERE create_time >= '2026-06-12 00:00:00' AND create_time <= '2026-06-12 23:59:59'`。
   - 消除隐式转换：`WHERE mobile = '13800000000'`。
2. **补充缺失索引**：
   - 为高频 `WHERE` 过滤、`ORDER BY` 排序、`GROUP BY` 分组的字段创建复合索引。

---

## 故障 2：行锁等待超时（Lock Wait Timeout Exceeded）

### 故障现象
业务接口报错：
`ERROR 1205 (HY000): Lock wait timeout exceeded; try restarting transaction`。

### 产生原因
事务 A 修改了某行数据但迟迟未提交（例如网络延迟、事务内掺杂了慢 RPC 远程调用），事务 B 尝试修改同一行数据，被排他锁（X锁）阻塞，等待时间超过了配置的 `innodb_lock_wait_timeout`。

### 诊断排查
1. **查询正在等待锁的事务关系**：
   ```sql
   SELECT waiting_trx_id, waiting_pid, waiting_query, blocking_trx_id, blocking_pid, blocking_query 
   FROM sys.innodb_lock_waits;
   ```
2. **查询长事务占用的线程**：
   ```sql
   SELECT trx_id, trx_state, trx_started, trx_mysql_thread_id, trx_query 
   FROM information_schema.innodb_trx;
   ```

### 解决方案
1. **快速止血**：
   找出引发阻塞的 `blocking_pid`，强行中止该连接：
   ```sql
   KILL 1234; -- 替换为实际的 blocking_pid (即对应的线程 ID)
   ```
2. **规范开发实践**：
   - 尽量使事务“小而快”，事务内禁止进行非必要的远程 HTTP/RPC 调用。
   - 在应用连接池中设置合理的超时机制。

---

## 故障 3：死锁导致事务回滚（Deadlock Found When Trying to Get Lock）

### 故障现象
后台业务日志大量出现报错：
`ERROR 1213 (40001): Deadlock found when trying to get lock; try restarting transaction`。

### 产生原因
两个或多个事务在执行过程中，因争夺资源而造成一种互相等待的循环锁状态（如事务 A 持有 Row1 等待 Row2，事务 B 持有 Row2 等待 Row1；或者在高并发写入时产生间隙锁 Gap Lock 冲突）。

### 诊断排查
查询 InnoDB 引擎最近一次的死锁日志：
```sql
SHOW ENGINE INNODB STATUS;
-- 定位到 "LATEST DETECTED DEADLOCK" 块，查看事务 1 与事务 2 分别执行的 SQL 及所持有的锁类型。
```

### 解决方案
1. **优化加锁顺序**：确保所有业务对于涉及多表或多行的并发修改，必须按照固定的主键顺序（例如从小到大）进行操作。
2. **减少锁的范围**：通过建立覆盖索引，使加锁精准定位在具体记录上，避免因全表扫描退化为表锁，降低 Gap 锁范围。
3. **应用端重试机制**：针对高并发死锁，在代码中设计捕获 `1213` 错误并进行 3 次事务退避重试的逻辑。

---

## 故障 4：数据库连接数爆满（Too Many Connections）

### 故障现象
新客户端连接被拒绝，提示报错：
`ERROR 1040 (08004): Too many connections`。

### 产生原因
1. 突发大流量流量突增。
2. 应用连接池未设置最大上限，或连接泄露未及时释放。
3. 数据库内大量 SQL 慢查询挂起，导致大量连接处于 `Sleep` 或等待锁状态，连接占满。

### 诊断排查
```sql
-- 使用 MySQL 8.0 专设的管理接口（默认端口 33062 或配置的管理员接口）登入进行查看：
mysql -u root -p -P 33062
SHOW PROCESSLIST;
-- 统计各种状态的连接数
SELECT COUNT(*), db, command FROM information_schema.processlist GROUP BY db, command;
```

### 解决方案
1. **临时应急扩容**：
   ```sql
   -- 临时调大连接上限，注意需要有 SUPER 权限的连接可用
   SET GLOBAL max_connections = 2000;
   ```
2. **清理空闲连接**：
   ```sql
   -- 清理 Sleep 时间过长的连接
   SHOW PROCESSLIST;
   -- 可以编写脚本自动批量 KILL 掉 Sleep 超过 3600 秒的线程
   ```
3. **长期优化**：
   - 开启 MySQL 8.0 独有的专为管理员预留的通道 `admin_address = '127.0.0.1'` 和 `admin_port = 33062`，即使最大连接数爆满，运维人员也能强行登入排障。
   - 优化应用连接池，设置合理的 `maxLifetime`。

---

## 故障 5：元数据锁等待阻塞（Waiting for Table Metadata Lock）

### 故障现象
执行 `ALTER TABLE`、`DROP TABLE` 等 DDL 语句时命令长时间挂起，且导致之后针对该表的所有正常 `SELECT`、`INSERT` 读写请求被全部阻塞，系统出现大面积连接积压。

### 产生原因
在 DDL 尝试获取表的排他 Metadata Lock（元数据锁）时，该表上正好存在一个未提交的长事务（甚至是只读的 SELECT 事务）。DDL 被阻塞后，会进入锁等待队列首位，进而导致后续所有对该表的 DML 与 SELECT 请求因为无法获取 MDL 锁而被全部阻塞。

### 诊断排查
```sql
-- 查看所有连接进程
SHOW PROCESSLIST; -- 会看到大量 "Waiting for table metadata lock"
-- 联合查询锁定元数据锁的事务源头
SELECT * FROM performance_schema.metadata_locks WHERE OBJECT_NAME = '您的表名';
```

### 解决方案
1. **斩断事务源头**：
   查询持有该表 MDL 锁的最老事务的 Thread ID，并直接 `KILL` 掉该未提交事务的连接。
2. **DDL 设置等待超时（避免阻塞后续请求）**：
   ```sql
   -- 设置当前会话的 DDL 等待元数据锁的超时时间为 10 秒，超时若拿不到直接报错，防止无休止阻塞后续读写
   SET lock_wait_timeout = 10;
   ALTER TABLE users ADD COLUMN age INT;
   ```
3. **使用 Online DDL 工具**：例如使用 `gh-ost` 或 `pt-online-schema-change` 等工具平滑变更大表结构。

---

## 6. 内存溢出崩溃（mysqld OOM / Out of Memory）

### 故障现象
MySQL 进程（mysqld）突然无故消失，在系统日志 `/var/log/messages` 或 `dmesg` 中发现 `Out of memory: Kill process ... (mysqld)` 记录。

### 产生原因
1. `innodb_buffer_pool_size` 缓存分配比例过大（超过物理内存的 80%），导致操作系统自身内存耗尽。
2. 每个连接持有的私有缓冲区（如 `sort_buffer_size`、`join_buffer_size`、`read_rnd_buffer_size`）配置得过大，当高并发连接同时涌入并执行排序/关联查询时，内存开销呈指数级膨胀，最终爆 OOM。

### 诊断排查
```bash
# 查看系统日志中是否有 OOM 历史
dmesg -T | grep -i oom
# 或者
grep -i -E 'oom|kill' /var/log/messages
```

### 解决方案
1. **精细化调配内存**：
   - 核心原则：`InnoDB Buffer Pool + (max_connections * 每线程会话内存) < 物理总内存 * 80%`。
   - 一般 64G 内存机器，Buffer Pool 推荐配置为 `32G` 到 `40G`。
2. **严控会话级内存参数**：
   - 将 `sort_buffer_size`、`join_buffer_size`、`tmp_table_size` 重置为合理默认值（一般推荐 `2M` 到 `4M` 即可，千万不要设置成几十兆）。

---

## 故障 7：大事务回滚极其缓慢（Large Transaction Rollback Delay）

### 故障现象
在执行了一条大范围更新/删除的 SQL 语句后发现不妥，执行了 `KILL` 或按下 Ctrl+C 强行终止，但是发现客户端卡住，MySQL 后台 CPU 满载，数据库依然响应迟钝。

### 产生原因
MySQL 对大事务（如一次性 `DELETE FROM big_table`）的事务回滚是**单线程单通道**运作的。回滚需要逆序回放所有的 Undo Log，其回放时间通常是前台写入时间的 2~5 倍。
> [!CAUTION]
> **绝对不可在这个时候强行重启服务器或重启 mysqld**！如果重启，MySQL 会在启动阶段进入崩溃恢复（Crash Recovery），强行进行这部分 Undo 的回滚操作，此时数据库会卡在启动状态，彻底无法提供任何对外读写。

### 诊断排查
查询当前事务回滚的进度：
```sql
-- 观察 trx_rows_modified 的值是否在平稳下降，如果在下降说明正在正常执行回滚
SELECT trx_id, trx_state, trx_rows_modified, trx_started FROM information_schema.innodb_trx;
```

### 解决方案
1. **耐心等待回滚完成**：除静待其自动回缩数据外无其他办法，需严密监控 `trx_rows_modified` 降至 0。
2. **规避建议**：
   - 大事务必须分批分段处理。
   - 例如需要删除 1000 万行历史数据：可以使用 `WHERE create_time < '...' LIMIT 5000` 循环删除并提交。

---

## 故障 8：自增主键溢出与空洞（Auto-Increment ID Exhaustion）

### 故障现象
业务数据写入中断，报错：
`ERROR 1467 (HY000): Failed to read auto-increment value from storage engine` 或插入主键冲突。

### 产生原因
自增主键定义时使用的字段类型范围上限太小（例如使用了 `INT SIGNED` 符号整型，上限仅为 2,147,483,647）。当 ID 耗尽后，无法再产生新的自增值。另外，由于大批量事务回滚或频繁的 `REPLACE INTO` 等操作，会造成自增主键产生大量空洞，加速耗尽。

### 诊断排查
```sql
-- 监控每张表的自增主键使用率百分比
SELECT TABLE_SCHEMA, TABLE_NAME, AUTO_INCREMENT,
       (AUTO_INCREMENT / 2147483647) * 100 AS 'INT_SIGNED_PERCENT'
FROM information_schema.tables 
WHERE AUTO_INCREMENT IS NOT NULL;
```

### 解决方案
1. **预防规范**：核心业务表（订单、流水、用户、日志表）的主键类型必须使用 `BIGINT UNSIGNED`（范围上限超 1800 亿亿，不可能用尽）。
2. **线上紧急修复**：
   对于已经溢出的 INT 表，需利用 Online DDL 升格为 BIGINT（需确保本地空间充足）：
   ```sql
   ALTER TABLE users MODIFY COLUMN id BIGINT UNSIGNED AUTO_INCREMENT;
   ```

---

## 9. 表情包及特殊字符插入失败（Incorrect String Value）

### 故障现象
用户尝试插入含有 Emoji 表情符号或生僻中文汉字时，接口抛出异常：
`ERROR 1366 (HY000): Incorrect string value: '\xF0\x9F\x98\x81...' for column ...`。

### 产生原因
MySQL 的传统 `utf8` 字符集（别名 `utf8mb3`）采用最大 3 字节表示，而 Emoji 表情和部分生僻字在 UTF-8 标准中需要占用 4 个字节，导致旧字符集无法承载产生截断溢出。

### 解决方案
1. **全面改造为 utf8mb4**：
   将数据库、表及对应的字段修改为更健壮的 `utf8mb4` 字符集，并选择推荐排序规则 `utf8mb4_0900_ai_ci`（MySQL 8.0 默认）或 `utf8mb4_general_ci`：
   ```sql
   -- 修改数据库默认字符集
   ALTER DATABASE my_database CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
   -- 修改表字符集
   ALTER TABLE users CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
   ```
2. **确认连接层字符集**：
   确保应用连接驱动参数中带有了编码设置，例如 Java 连接字符串中配置：`characterEncoding=utf8`（在 8.0 驱动中会自动对齐为 utf8mb4）。

---

## 故障 10：CPU 使用率高达 100%（High CPU Spikes）

### 故障现象
服务器监控报警 CPU 持续耗尽在 100%，数据库处理延时（RT）翻倍，出现连接大量堆积。

### 产生原因
1. 存在未加索引的超大表全表扫描。
2. 存在不合理的聚合分析类复杂 SQL（例如高频的大表关联 `JOIN` 或大量的正则过滤 `REGEXP`）。
3. 统计信息失真，导致优化器选择了错误的低效执行计划。

### 诊断排查
1. **查看占用 CPU 最多的活跃线程**：
   ```sql
   SELECT pid, start_time, duration, sql_text 
   FROM sys.processlist 
   WHERE state = 'Executing' ORDER BY duration DESC;
   ```
2. **重新计算优化器统计信息**：
   如果发现有索引但优化器没选，尝试重建表统计指标：
   ```sql
   ANALYZE TABLE users;
   ```

### 解决方案
1. **抓出慢查询并添加 Hint 应急**：
   对于选错执行计划的查询，在无法立即改写 SQL 时，可以使用临时 `FORCE INDEX`：
   ```sql
   SELECT * FROM users FORCE INDEX (idx_create_time) WHERE create_time >= '...';
   ```
2. **配置慢查询自动熔断机制**（使用 MySQL 8.0 的语句执行超时参数）：
   ```sql
   -- 限制全会话下只读查询最大执行时间不超过 5000 毫秒，避免烂 SQL 长时间霸占 CPU
   SET GLOBAL max_execution_time = 5000;
   ```

---

## 故障 11：临时表频繁落盘（Created_tmp_disk_tables 偏高）

### 故障现象
进行大表查询、排序或者聚合计算时，I/O 吞吐急剧升高，性能下滑。

### 产生原因
MySQL 在执行类似 `GROUP BY` 或 `DISTINCT` 的多表复杂操作时，如果中间产生的结果集超过了系统变量 `tmp_table_size` 的阈值，或者是结果集中含有 `BLOB` / `TEXT` 等大字段（在内存临时表中无法很好存储），就会被强制转换为**磁盘临时表**（On-Disk Temporary Table），造成严重的物理读写损耗。

### 诊断排查
观察全局指标的变化：
```sql
SHOW GLOBAL STATUS LIKE 'Created_tmp%';
-- 比较 Created_tmp_tables 与 Created_tmp_disk_tables 的比例，若后者增长过快，说明磁盘临时表高频发生。
```

### 解决方案
1. **调大内存临时表限值**：
   ```sql
   SET GLOBAL tmp_table_size = 64M;
   SET GLOBAL max_heap_table_size = 64M;
   ```
2. **优化 SQL 查询**：
   - 杜绝在聚合查询或临时表排序中选择 `TEXT` / `BLOB` 列，如必须取出这些大字段，建议将其拆分为二阶段按 ID 延迟查询。
   - 优化索引，将 `GROUP BY` 列或 `ORDER BY` 列纳入索引，利用索引物理顺序避免生成内部临时表排序。

---

## 故障 12：客户端主机被拦截（Host is Blocked Because of Connection Errors）

### 故障现象
客户端机器连接数据库时抛出严重异常：
`ERROR 1129 (HY000): Host '172.16.50.88' is blocked because of many connection errors; unblock with 'mysqladmin flush-hosts'`。

### 产生原因
该客户端 IP 在尝试建立连接时，发生了多次握手失败、DNS 解析超时或连续的身份验证失败错误，报错累计次数超过了系统设定的 `max_connect_errors` 阈值。为了保护安全，MySQL 决定将其 IP 进行锁定拦截。

### 解决方案
1. **快速解锁**：
   登录数据库服务器，在命令行刷新 host 缓存：
   ```sql
   FLUSH HOSTS;
   -- 8.0 亦可在交互模式下直接运行
   ```
2. **调高容错阈值**：
   ```sql
   SET GLOBAL max_connect_errors = 10000;
   ```
3. **关闭反向域名解析（提升连接效率，防止解析挂起）**：
   在 `/etc/my.cnf` 中配置 `[mysqld]`：
   ```ini
   skip-name-resolve = ON
   ```

---

## 故障 13：数据表损坏或物理损坏（Table/Index Corruption）

### 故障现象
查询某张表时直接返回报错：
`ERROR 1030 (HY000): Got error 127 from storage engine` 或系统发生 Crash 提示表空间（.ibd）损坏。

### 产生原因
物理服务器突发断电、物理硬件或磁盘介质发生故障、操作系统 Bug，或者是在写入文件时 mysqld 被外部暴力杀死。

### 解决方案
1. **利用 `innodb_force_recovery` 进行救灾恢复**：
   - 在主配置文件 `/etc/my.cnf` 中添加参数（模式值从 1 开始测试，最高可设为 6，建议逐步调大）：
     ```ini
     [mysqld]
     innodb_force_recovery = 1
     ```
   - 启动 mysqld 服务，在此模式下数据库会被强行拉起但设定为**只读**。
   - 将损坏表的数据导出备份：
     ```bash
     mysqldump -u root -p my_database corrupted_table > corrupted_table.sql
     ```
   - 数据安全导出后，注释掉 `innodb_force_recovery` 配置并正常重启。
   - 删掉旧表结构，导入导出的数据进行原地重建。

---

## 故障 14：慢日志/错误日志爆满打满系统磁盘（Log Space Exhaustion）

### 故障现象
数据库宕机且无法重启，使用 `df -h` 查看发现数据或日志挂载分区的剩余空间为 0。

### 产生原因
1. 开启了 `log_queries_not_using_indexes`（记录所有未使用索引的查询），导致慢查询日志疯狂膨胀。
2. 误开 `general_log` (全量通用审计日志)，导致任何 SQL 命令都被物理落盘，高并发下数天即可打满数百 GB 磁盘。

### 解决方案
1. **安全释放空间**：
   - 严禁对 `.ibd` 核心数据文件做任何手动删除。
   - 对日志文件，可执行文件截断操作（释放其在 Linux 中的物理句柄）：
     ```bash
     > /app/mysql/3306/log/slowlog/slow.log
     ```
2. **优化参数设置**：
   ```sql
   -- 建议关闭记录未建索引查询选项，防止无意义写入
   SET GLOBAL log_queries_not_using_indexes = OFF;
   -- 确保 general_log 在排障后被关闭
   SET GLOBAL general_log = OFF;
   ```
3. **配合系统 Logrotate 机制**：对 MySQL 慢查询和错误日志定制自动切割与清理策略。
   在 Linux 系统中，使用 `logrotate` 是最标准的日志轮转方案。针对本指南的配置路径（慢查询日志 `/app/mysql/3306/log/slow/slow.log`，错误日志 `/app/mysql/3306/log/error/error.log`），我们可以采用以下两种方式之一来实现自动切割与清理：

   #### 方案 A：平滑轮转法（推荐，最安全）
   该方案在日志轮转后，通过向 MySQL 发送信号（`FLUSH LOGS`）指示其关闭旧日志句柄并重新打开新日志文件。能够避免任何日志丢失，适用于高并发、对日志完整性要求极高的生产环境。

   ##### 步骤 1：在 MySQL 中创建低权限的轮转管理账号
   为了安全起见，切勿在脚本中硬编码 `root` 密码。建议创建一个仅具有 `RELOAD` 权限的专用管理用户：
   ```sql
   CREATE USER 'mysql_rotate'@'localhost' IDENTIFIED BY 'Rotate_Password_2026';
   GRANT RELOAD ON *.* TO 'mysql_rotate'@'localhost';
   FLUSH PRIVILEGES;
   ```

   ##### 步骤 2：创建安全的 MySQL 客户端配置文件
   在系统中创建 `/etc/logrotate.d/mysqladmin.cnf` 文件，保存该用户的账号密码，并严格控制该文件的访问权限：
   ```ini
   [client]
   user = mysql_rotate
   password = Rotate_Password_2026
   host = localhost
   port = 3306
   socket = /tmp/mysql.sock
   ```
   设置文件权限，仅允许 root 读取：
   ```bash
   chmod 600 /etc/logrotate.d/mysqladmin.cnf
   chown root:root /etc/logrotate.d/mysqladmin.cnf
   ```

   ##### 步骤 3：编写 logrotate 配置文件
   新建或编辑 `/etc/logrotate.d/mysql` 配置文件，写入以下内容：
   ```text
   /app/mysql/3306/log/error/error.log
   /app/mysql/3306/log/slow/slow.log
   {
       daily                 # 每天切割一次
       rotate 30             # 保留最近 30 天的日志文件
       missingok             # 如果日志文件不存在，忽略错误不报错
       notifempty            # 日志为空时不进行切割
       compress              # 对历史日志进行 gzip 压缩
       delaycompress         # 延迟一天压缩（即最新的轮转日志 error.log.1 不压缩，方便排查）
       sharedscripts         # 所有日志切割完成后，统一执行一次 postrotate 脚本
       create 660 mysql mysql # 创建新日志文件的权限和属主/属组
       postrotate
           # 使用之前配置的低权限账号通知 MySQL 重新打开日志文件句柄
           if test -x /usr/bin/mysqladmin && \
              /usr/bin/mysqladmin --defaults-extra-file=/etc/logrotate.d/mysqladmin.cnf ping &>/dev/null; then
               /usr/bin/mysqladmin --defaults-extra-file=/etc/logrotate.d/mysqladmin.cnf flush-logs
           fi
       endscript
   }
   ```

   ---

   #### 方案 B：在线截断法（免密快捷，有微小丢失风险）
   如果不想在 MySQL 中创建任何账号，或者不想维护配置文件，可以使用 `copytruncate` 模式。
   该模式的工作原理是先将当前日志文件复制出一份副本，然后清空（truncate）原日志文件。

   ##### 编写 logrotate 配置文件
   新建或编辑 `/etc/logrotate.d/mysql` 配置文件：
   ```text
   /app/mysql/3306/log/error/error.log
   /app/mysql/3306/log/slow/slow.log
   {
       daily
       rotate 15             # 空间有限可保留 15 天
       missingok
       notifempty
       compress
       delaycompress
       copytruncate          # 在线复制并截断，无需 flush-logs 动作
   }
   ```
   > [!WARNING]
   > **注意**：`copytruncate` 在复制与清空的极短时间间隔内，若有大量并发日志写入，可能会造成极少量的日志行丢失。对于日志量极大且不允许任何丢失的系统，应首选**方案 A**。

   ---

   #### 步骤 4：测试与手动触发
   配置完成后，建议手动执行一次测试以确保配置正确：
   ```bash
   # 1. 调试执行（仅输出过程，不实际切割日志）
   logrotate -d /etc/logrotate.d/mysql

   # 2. 强制执行一次轮转（实际切割日志，验证是否生成压缩包、新日志是否正常写入）
   logrotate -f /etc/logrotate.d/mysql
   ```

---

## 故障 15：InnoDB 内部信号量长时间等待警告（InnoDB: Long Semaphore Wait）

### 故障现象
MySQL 错误日志中开始频繁警告：
`InnoDB: Long semaphore wait: ...` 接着伴随进程崩溃，或者系统在没有任何行锁持有的情况下彻底死锁失去响应。

### 产生原因
1. 高并发多线程读写引发 InnoDB 内存中的内部锁互斥（如 Latch 锁、Mutex 锁冲突）。
2. 底层发生物理 I/O 阻塞或夯死，或者系统内存爆满频繁发生 Swap 页交换。

### 解决方案
1. **物理 I/O 诊断**：
   利用 `iostat -x 1 5` 检查磁盘 `await` 和 `%util` 指标。若已接近 100%，需先解决底层存储或硬件阵列的瓶颈。
2. **分析锁等待树**：
   运行 `SHOW ENGINE INNODB STATUS;`，定位 `SEMAPHORES` 块。
3. **关闭 Swap 分区或降低倾向度（Swappiness）**：
   大内存数据库服务器应尽量避免物理页调入虚拟内存。建议将 Linux 内核参数 `vm.swappiness` 设置为 1 或 10，保证数据常驻物理内存。

---

## 故障 16：从库复制线程中断（Replication Error 1062/1032）

### 故障现象
使用 `SHOW REPLICA STATUS;`（8.0.22及以上）时，显示复制线程 `Replica_SQL_Running` 状态为 `No`。报错信息：
- `Error 1062: Duplicate entry ... for key 'PRIMARY'`。
- `Error 1032: Key not found ...`。

### 产生原因
1. 主备架构中，备库处于非只读状态（`read_only=OFF`），业务用户直接连入备库进行了新增或删除操作，导致从库产生了“自发事务”。当主库同步相同主键数据时发生主键冲突（1062），或者找不到待删除的目标行（1032）。

### 解决方案
1. **跳过冲突事务（应急恢复复制）**：
   - **GTID 模式下**（我们的 MGR/集群部署模式）：
     找出从库卡住事务的 GTID，在从库上注入一个空的事务将其跳过：
     ```sql
     STOP REPLICA;
     SET @@SESSION.GTID_NEXT= '主库产生冲突事务的GTID:序列号';
     BEGIN; COMMIT; -- 注入空事务
     SET @@SESSION.GTID_NEXT= 'AUTOMATIC';
     START REPLICA;
     ```
   - **非 GTID 模式下**：
     ```sql
     STOP REPLICA;
     SET GLOBAL sql_replica_skip_counter = 1;
     START REPLICA;
     ```
2. **固化只读设置**：
   确保所有的备库/SECONDARY 节点都严格配置了 `read_only=ON` 与 `super_read_only=ON`，规避误写。

---

## 故障 17：大表历史数据清理困难（Large Scale Deletion Performance Drop）

### 故障现象
尝试通过 `DELETE FROM table WHERE create_time < '2025-01-01'` 清理一年前的历史数据，结果发现执行了数个小时没完，导致其他针对该表的写业务全部挂起（行锁等待超时），甚至导致 Binlog/Undo 爆棚。

### 产生原因
`DELETE` 操作会产生海量的 Undo Log 事务回滚记录，并且会锁定所有扫描行，引发锁升级。删除大量记录后，还会产生大量的数据页碎片，磁盘空间完全不释放。

### 解决方案
1. **归档重建表方式（适用于数据量极大的场景）**：
   如果清理的数据占比非常高，直接复制保留数据更高效：
   ```sql
   -- 1. 创建结构相同的新表
   CREATE TABLE users_new LIKE users;
   -- 2. 只把需要保留的数据插过去
   INSERT INTO users_new SELECT * FROM users WHERE create_time >= '2025-01-01';
   -- 3. 原子重命名交换两表
   RENAME TABLE users TO users_old, users_new TO users;
   -- 4. 直接物理 DROP 掉旧表（瞬间释放物理磁盘空间）
   DROP TABLE users_old;
   ```
2. **利用分区表（Partitioning）进行快速流转**：
   - 核心系统表建议使用**按月/按天分区**。
   - 需要清理历史数据时，直接删除对应历史分区：
     ```sql
     -- 毫秒级删除一整月数据并彻底释放磁盘，完全不锁其他分区
     ALTER TABLE logs DROP PARTITION p202501;
     ```

---

## 故障 18：Table Open Cache 命中率低下（Opened_tables 异常增长）

### 故障现象
高并发或进行多表复杂联合查询时，MySQL 反应迟钝。

### 产生原因
数据库中存在大量的数据表，但是系统参数 `table_open_cache`（表描述符缓存数）设置偏低。当并发读写频繁轮转打开不同的表时，MySQL 必须频繁从物理磁盘读取 `.ibd` 表定义元数据，产生缓存挤出效应。

### 诊断排查
```sql
SHOW STATUS LIKE 'Opened_tables';
-- 若此值经常呈线性高速攀升，说明缓存池太小，旧表句柄不断被剔除并重新打开。
```

### 解决方案
1. **调大表定义和打开表句柄缓存上限**：
   ```sql
   SET GLOBAL table_open_cache = 8000;
   SET GLOBAL table_definition_cache = 4000;
   ```
2. **优化程序库**：避免在一个数据库实例内无限制创建分表（例如单数据库内生成上万张散表），这不仅挤占句柄空间，还会严重增加系统崩溃恢复（Crash Recovery）的时间。

---

## 故障 19：InnoDB Undo Log 无法收缩导致共享表空间膨胀

### 故障现象
磁盘分区剩余空间不足，查看发现 InnoDB 共享表空间 `ibdata1` 或者独立的 undo 物理文件（如 `undo_001`）体积膨胀到了几百 GB，且重启或删除数据后空间**完全不回缩**。

### 产生原因
1. 系统中存在一个从数天前开始执行就从未提交的长事务，或者应用连接池中的某连接开启了事务但忘记执行 `commit`/`rollback` 归还连接。
2. 导致 InnoDB 必须把该事务以来的所有老旧事务的 Undo 版本历史全部保留在回滚段（Rollback Segment）中，Purge 线程无法回收，导致物理文件无限膨胀。

### 诊断排查
```sql
-- 查询回滚段的历史版本链积压长度
SHOW ENGINE INNODB STATUS;
-- 查看 TRANSACTIONS 块，并关注 "History list length" 值（若超过数十万，说明 undo purge 发生严重积压）。
```

### 解决方案
1. **终止阻塞的事务根源**：
   寻找未提交时间最长的活跃事务线程并将其 `KILL`：
   ```sql
   SELECT trx_id, trx_started, trx_mysql_thread_id FROM information_schema.innodb_trx ORDER BY trx_started ASC LIMIT 1;
   ```
2. **配置 Undo Log 自动截断与回缩（MySQL 8.0 最佳实践）**：
   确保开启了以下全局参数（在 8.0 中默认开启），这样在长事务终止后，MySQL 能够自动将独立的 Undo 表空间回缩清理到 10M 初始大小：
   ```sql
   SET GLOBAL innodb_undo_log_truncate = ON;
   SET GLOBAL innodb_max_undo_log_size = 1073741824; -- 设为 1G 时触发截断清理
   ```

---

## 故障 20：Redo Log 写磁盘瓶颈（Redo Log Disk I/O Bottleneck）

### 故障现象
高并发批处理（例如批量数据导入或海量写入）时，系统吞吐量进入平原区无法突破，服务器磁盘 IOPS 报警，大量连接在等待提交事务。

### 产生原因
配置了 MySQL 的“双一原则”（安全级别最高但 I/O 损耗最大）：
- `innodb_flush_log_at_trx_commit = 1`（每次提交事务都必须物理刷盘 Redo Log）。
- `sync_binlog = 1`（每次提交都刷盘 Binlog）。
在未配备高速 NVMe/SSD 或是没有写缓存的传统存储上，这会导致磁盘进行高频微小碎片的同步写，从而让写 I/O 被强行限制在磁头物理转速瓶颈下。

### 解决方案
1. **折中方案：降级为安全模式 2（大幅提升高并发高吞吐能力）**：
   如果应用层可以接受在**操作系统突然挂掉/硬件断电**时，丢失最多约 1~2 秒的已提交事务数据（注意：仅仅是操作系统挂掉才会丢，MySQL 进程崩溃是完全不丢的）：
   ```sql
   -- 将 Redo 日志写盘模式由 1 调整为 2 (写 OS Cache，每秒由操作系统执行刷盘)
   SET GLOBAL innodb_flush_log_at_trx_commit = 2;
   -- 可配合将 binlog 刷盘设置为 1000 次批量刷新
   SET GLOBAL sync_binlog = 1000;
   ```
   *调整该配置后，整体写入吞吐量通常能带来 5~10 倍的飞跃。*
2. **合并小事务为批量提交**：
   对于开发人员，严禁在 `for` 循环中做单条插入，必须将业务优化为批量插入 `INSERT INTO t VALUES (1), (2), (3)...;` 或显式开启大事务 `START TRANSACTION; ... COMMIT;` 以降低刷盘频次。

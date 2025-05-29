# mysql-mgr-ha-experiment

基于容器的测试基于 MGR 的 MySQL 高可用解决方案

```bash
# 下载MySQL 8.0.42的deb包
wget https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-server_8.0.42-1ubuntu24.04_amd64.deb-bundle.tar

# 解压deb包
mkdir -p mysql-deb
tar -xvf mysql-server_8.0.42-1ubuntu24.04_amd64.deb-bundle.tar -C mysql-deb
```

## 创建 Dockerfile

```dockerfile
# 略
```

## 构建 Docker 镜像

```bash
docker build --progress=plain -t mysql-mgr-ha:8.0.42 .
```

## 启动单机 MySQL 容器

```bash
# 启动 MySQL 容器
docker run -d --rm --name mysql-mgr-ha \
    -p 3306:3306 \
    -e DB_PASSWORD=test@1234 \
    -v $PWD/data:/var/lib/mysql \
    mysql-mgr-ha:8.0.42

# 查看容器日志
docker logs -f mysql-mgr-ha

# 进入 MySQL 容器
docker exec -it mysql-mgr-ha mysql -uroot -ptest@1234 -e "show databases;"
```

## 启动 MGR 集群

```bash
docker compose up -d
docker exec -it db1 mysql -uroot -ptest@1234
docker exec -it db2 mysql -uroot -ptest@1234
docker exec -it db3 mysql -uroot -ptest@1234
```

```sql
-- 在 db1 上设置 MGR 集群
CREATE USER 'repl'@'%' IDENTIFIED  WITH mysql_native_password BY 'repl_password';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
FLUSH PRIVILEGES;

-- 启动组复制引导
SET GLOBAL group_replication_bootstrap_group = ON;
START GROUP_REPLICATION;
SET GLOBAL group_replication_bootstrap_group = OFF;

-- 检查组状态（应显示ONLINE）
SELECT * FROM performance_schema.replication_group_members;

-- 配置当 db1 作为 SECONDARY 节点时的复制通道
CHANGE MASTER TO MASTER_USER='repl', MASTER_PASSWORD='repl_password' FOR CHANNEL 'group_replication_recovery';

-- 检查是否处于单主模式（不太推荐使用多主模式，存在各种问题）
SHOW VARIABLES LIKE 'group_replication_single_primary_mode';
```

```sql
-- 设置复制通道
CHANGE MASTER TO MASTER_USER='repl', MASTER_PASSWORD='repl_password' FOR CHANNEL 'group_replication_recovery';
-- 启动组复制
START GROUP_REPLICATION;
-- 验证节点状态
SELECT * FROM performance_schema.replication_group_members;
```

## 测试 MGR 集群

```sql
-- 在 db1 上创建测试数据库
CREATE DATABASE test;

-- 在 db1 上创建测试表
USE test;
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL
);

-- 在 db1 上插入数据
INSERT INTO users (name) VALUES ('Alice'), ('Bob');

-- 在 db1,db2,db3 上查询数据
USE test;
SELECT * FROM users;

-- 在 db2 上插入数据，预期将报错，无法写入
INSERT INTO users (name) VALUES ('Charlie');
```

## 修改配置，每次启动时自动开启组复制

```bash
# 修改 db1/db2/db3 的 MySQL 配置，使其启动时自动开启组复制
sed -i 's/^loose-group_replication_start_on_boot = OFF/loose-group_replication_start_on_boot = ON/' conf/db1.cnf conf/db2.cnf conf/db3.cnf
```

## 故障恢复测试

```bash
# 停止 db1 容器
docker stop db1
# 查看 db2 和 db3 的状态
docker exec -it db2 mysql -uroot -ptest@1234 -e "SELECT * FROM performance_schema.replication_group_members;"
docker exec -it db3 mysql -uroot -ptest@1234 -e "SELECT * FROM performance_schema.replication_group_members;"
# 发现 db2 和 db3 仍然在线，db1 已经 UNREACHABLE 了
# 再过一阵，db2 和 db3 会自动选举出新的主节点，db1 会被踢出集群
# 重启 db1 容器
docker start db1
# 查看 db1 的状态
docker exec -it db1 mysql -uroot -ptest@1234 -e "SELECT * FROM performance_schema.replication_group_members;"
```

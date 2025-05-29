# mysql-mgr-ha-experiment

## 省流步骤总结

1. 准备三台 db 主机服务器 db1/db2/db3
2. db1/db2/db3 依次安装相关 deb 包
3. db1/db2/db3 配置 mysqld.cnf 配置文件，其中配置了三个节点的信息
4. db1/db2/db3 执行 shell 命令，初始化数据目录，设置数据库 root 用户密码
5. db1/db2/db3 修改 auto.cnf 文件，各自设置互不相同的独立 server_uuid
6. db1/db2/db3 执行 shell 命令，后台启动 MySQL 服务
7. db1 执行 SQL 命令，创建复制用户 repl，开启组复制引导，开启组复制
8. db2/db3 执行 SQL 命令，设置复制通道，启动组复制
9. db1/db2/db3 执行 SQL 命令，验证组复制状态，测试数据同步（可选）
10. 修改 db1/db2/db3 的 mysqld.cnf 配置，使其启动时自动开启组复制
11. 测试自动故障转移，模拟 db1 宕机，验证 db2/db3 自动选举出新的主节点（可选）
12. 配置 MySQL Router 中间件，实现重试和故障转移，自动路由写请求到主节点（可选）

## 镜像准备

基于容器的测试基于 MGR 的 MySQL 高可用解决方案

```bash
# 下载MySQL 8.0.42的deb包
wget https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-server_8.0.42-1ubuntu24.04_amd64.deb-bundle.tar

# 解压deb包
mkdir -p mysql-deb
tar -xvf mysql-server_8.0.42-1ubuntu24.04_amd64.deb-bundle.tar -C mysql-deb

# 下载 MySQL Router 8.0.42 的 deb 包
# 在 https://dev.mysql.com/downloads/router/ 下载

cd mysql-deb
wget https://cdn.mysql.com//Downloads/MySQL-Router/mysql-router_8.0.42-1ubuntu24.04_amd64.deb

wget https://cdn.mysql.com//Downloads/MySQL-Router/mysql-router-community_8.0.42-1ubuntu24.04_amd64.deb

wget https://cdn.mysql.com//Downloads/MySQL-Router/mysql-router-community-dbgsym_8.0.42-1ubuntu24.04_amd64.deb
cd
```

### 构建 Docker 镜像

安装 MySQL 8.0.42 和 MySQL Router 8.0.42 的 Dockerfile

创建 `Dockerfile` 文件，

```dockerfile
# 略，请参考 Dockerfile 文件
```

构建镜像

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

## 启动 MGR 集群 (使用密码认证，已废弃不推荐)

```bash
docker compose up -d
docker exec -it db1 mysql -uroot -ptest@1234
docker exec -it db2 mysql -uroot -ptest@1234
docker exec -it db3 mysql -uroot -ptest@1234
```

在 db1 上配置以下 SQL

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

在 db2/db3 上配置以下 SQL

```sql
-- 设置复制通道
CHANGE MASTER TO MASTER_USER='repl', MASTER_PASSWORD='repl_password' FOR CHANNEL 'group_replication_recovery';
-- 启动组复制
START GROUP_REPLICATION;
-- 验证节点状态
SELECT * FROM performance_schema.replication_group_members;
```

## 启动 MGR 集群 (使用 SSL/TLS + 密码认证)

MySQL 8.0 版本开始不推荐使用密码认证，推荐使用 SSL 加密认证

```bash
# 生成证书
# 在宿主机生成证书（若使用 Docker，需挂载到容器）
mkdir -p ssl
# 生成 CA 证书
openssl req -x509 -newkey rsa:4096 -nodes -days 3650 \
  -keyout ca-key.pem -out ca.pem \
  -subj "/CN=MySQL MGR CA"
# 生成服务器证书
openssl req -x509 -newkey rsa:4096 -nodes -days 3650 \
  -keyout server-key.pem -out server-cert.pem \
  -subj "/CN=mysql-mgr-node"
# 生成客户端证书
openssl req -x509 -newkey rsa:4096 -nodes -days 3650 \
  -keyout client-key.pem -out client-cert.pem \
  -subj "/CN=mysql-mgr-client"
chmod 600 ca.pem ca-key.pem server-cert.pem server-key.pem

docker compose up -d
docker exec -it db1 mysql -uroot -ptest@1234
docker exec -it db2 mysql -uroot -ptest@1234
docker exec -it db3 mysql -uroot -ptest@1234
```

在 db1 上配置以下 SQL

```sql
-- 在 db1 上设置 MGR 集群
CREATE USER 'repl'@'%' IDENTIFIED  WITH caching_sha2_password BY 'repl_password';
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

在 db2/db3 上配置以下 SQL

```sql
-- 设置复制通道
CHANGE MASTER TO MASTER_USER='repl', MASTER_PASSWORD='repl_password' FOR CHANNEL 'group_replication_recovery';
-- 启动组复制
START GROUP_REPLICATION;
-- 验证节点状态
SELECT * FROM performance_schema.replication_group_members;
```

### 测试 MGR 集群同步

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

### 开启自动组复制

```bash
# 修改 db1/db2/db3 的 MySQL 配置，使其启动时自动开启组复制
sed -i 's/^loose-group_replication_start_on_boot = OFF/loose-group_replication_start_on_boot = ON/' conf/db1.cnf conf/db2.cnf conf/db3.cnf
```

### 自动故障恢复测试

故障转移演习

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

## 配置 MySQL Router 中间件

实现自动路由到主节点

略，未完待续

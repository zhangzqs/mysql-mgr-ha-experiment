# 基于 Docker 构建 MySQL Innodb 集群

## 参考文档

[Streamlining MySQL InnoDB Cluster Deployment: Simplifying Setup with Docker Containers](https://itnext.io/setting-up-mysql-innodb-cluster-with-mysql-shell-plus-mysql-router-using-just-docker-containers-9cdbfb6026af)

## 创建 Docker 网络

```bash
docker network create innodbnet


```

## 启动 MySQL 实例

```bash
# 清理实例
for N in 1 2 3 4; do
    docker stop mysql$N
    docker rm mysql$N
done

# 启动四个 MySQL 实例
for N in 1 2 3 4; do
    docker run -d \
        --name=mysql$N \
        --hostname=mysql$N \
        --net=innodbnet \
      -e MYSQL_ROOT_PASSWORD=root mysql/mysql-server:8.0
done

for N in 1 2 3 4; do
    docker start mysql$N
done
```

## 创建用户并授予权限

```bash
for N in 1 2 3 4; do
docker exec -it mysql$N mysql -uroot -proot \
  -e "CREATE USER 'inno'@'%' IDENTIFIED BY 'inno';" \
  -e "GRANT ALL privileges ON *.* TO 'inno'@'%' with grant option;" \
  -e "reset master;"
done

# 检查用户是否被创建
for N in 1 2 3 4; do
docker exec -it mysql$N mysql -uinno -pinno \
  -e "SHOW VARIABLES WHERE Variable_name = 'hostname';" \
  -e "SELECT user FROM mysql.user where user = 'inno';"
done
```

## 配置 MySQL 服务器加入 innodb 集群

```bash
docker exec -it mysql1 mysqlsh -uroot -proot -S/var/run/mysqld/mysqlx.sock
```

```js
// 输入inno密码，连接到实例进行检查
dba.checkInstanceConfiguration("inno@mysql1:3306");
dba.checkInstanceConfiguration("inno@mysql2:3306");
dba.checkInstanceConfiguration("inno@mysql3:3306");
dba.checkInstanceConfiguration("inno@mysql4:3306");
```

以 mysql2 为例，预期会有如下输出

```bash
Validating MySQL instance at mysql2:3306 for use in an InnoDB cluster...

This instance reports its own address as mysql2:3306
Clients and other cluster members will communicate with it through this address by default. If this is not correct, the report_host MySQL system variable should be changed.

Checking whether existing tables comply with Group Replication requirements...
No incompatible tables detected

Checking instance configuration...

NOTE: Some configuration options need to be fixed:
+----------------------------------------+---------------+----------------+--------------------------------------------------+
| Variable                               | Current Value | Required Value | Note                                             |
+----------------------------------------+---------------+----------------+--------------------------------------------------+
| binlog_transaction_dependency_tracking | COMMIT_ORDER  | WRITESET       | Update the server variable                       |
| enforce_gtid_consistency               | OFF           | ON             | Update read-only variable and restart the server |
| gtid_mode                              | OFF           | ON             | Update read-only variable and restart the server |
| server_id                              | 1             | <unique ID>    | Update read-only variable and restart the server |
+----------------------------------------+---------------+----------------+--------------------------------------------------+

Some variables need to be changed, but cannot be done dynamically on the server.
NOTE: Please use the dba.configureInstance() command to repair these issues.

{
    "config_errors": [
        {
            "action": "server_update",
            "current": "COMMIT_ORDER",
            "option": "binlog_transaction_dependency_tracking",
            "required": "WRITESET"
        },
        {
            "action": "server_update+restart",
            "current": "OFF",
            "option": "enforce_gtid_consistency",
            "required": "ON"
        },
        {
            "action": "server_update+restart",
            "current": "OFF",
            "option": "gtid_mode",
            "required": "ON"
        },
        {
            "action": "server_update+restart",
            "current": "1",
            "option": "server_id",
            "required": "<unique ID>"
        }
    ],
    "status": "error"
}
```

```js
dba.configureInstance("inno@mysql1:3306");
// 第一个问题输入y
// 第二个问题输入n
dba.configureInstance("inno@mysql2:3306");
dba.configureInstance("inno@mysql3:3306");
dba.configureInstance("inno@mysql4:3306");
```

## 重启容器

```bash
docker restart mysql1 mysql2 mysql3 mysql4
```

## 创建 InnoDB 集群

```bash
docker exec -it mysql1 mysqlsh -uroot -proot -S/var/run/mysqld/mysqlx.sock
```

```js
\c inno@mysql1:3306

var cluster = dba.createCluster("mycluster")
cluster.status() // 查看集群状态
cluster.describe() // 查看集群描述
```

预计如下输出：

```js
{
    "clusterName": "mycluster",
    "defaultReplicaSet": {
        "name": "default",
        "primary": "mysql1:3306",
        "ssl": "REQUIRED",
        "status": "OK_NO_TOLERANCE",
        "statusText": "Cluster is NOT tolerant to any failures.",
        "topology": {
            "mysql1:3306": {
                "address": "mysql1:3306",
                "memberRole": "PRIMARY",
                "mode": "R/W",
                "readReplicas": {},
                "replicationLag": "applier_queue_applied",
                "role": "HA",
                "status": "ONLINE",
                "version": "8.0.32"
            }
        },
        "topologyMode": "Single-Primary"
    },
    "groupInformationSourceMember": "mysql1:3306"
}
```

## 添加实例到 InnoDB 集群

```js
cluster.addInstance("inno@mysql2:3306");
cluster.addInstance("inno@mysql3:3306");
cluster.addInstance("inno@mysql4:3306");

// 所有问题输入 I

cluster.describe();
```

预计输出如下：

```json
{
  "clusterName": "mycluster",
  "defaultReplicaSet": {
    "name": "default",
    "topology": [
      {
        "address": "mysql1:3306",
        "label": "mysql1:3306",
        "role": "HA"
      },
      {
        "address": "mysql2:3306",
        "label": "mysql2:3306",
        "role": "HA"
      },
      {
        "address": "mysql3:3306",
        "label": "mysql3:3306",
        "role": "HA"
      },
      {
        "address": "mysql4:3306",
        "label": "mysql4:3306",
        "role": "HA"
      }
    ],
    "topologyMode": "Single-Primary"
  }
}
```

## 部署 MySQL Router

```bash
docker run -d --name mysql-router --net=innodbnet \
   -e MYSQL_HOST=mysql1 \
   -e MYSQL_PORT=3306 \
   -e MYSQL_USER=inno \
   -e MYSQL_PASSWORD=inno \
   -e MYSQL_INNODB_CLUSTER_MEMBERS=4 \
   mysql/mysql-router

docker logs mysql-router
```

```bash
➜  innodb_cluster git:(master) ✗ docker logs mysql-router

[Entrypoint] MYSQL_CREATE_ROUTER_USER is not set, Router will generate a new account to be used at runtime.
[Entrypoint] Set it to 0 to reuse inno instead.
[Entrypoint] Succesfully contacted mysql server at mysql1:3306. Checking for cluster state.
0
12
[Entrypoint] Successfully contacted cluster with 4 members. Bootstrapping.
[Entrypoint] Succesfully contacted mysql server at mysql1. Trying to bootstrap.
Please enter MySQL password for inno:
# Bootstrapping MySQL Router instance at '/tmp/mysqlrouter'...

- Creating account(s) (only those that are needed, if any)
- Verifying account (using it to run SQL queries that would be run by Router)
- Storing account in keyring
- Adjusting permissions of generated files
- Creating configuration /tmp/mysqlrouter/mysqlrouter.conf

# MySQL Router configured for the InnoDB Cluster 'mycluster'

After this MySQL Router has been started with the generated configuration

    $ mysqlrouter -c /tmp/mysqlrouter/mysqlrouter.conf

InnoDB Cluster 'mycluster' can be reached by connecting to:

## MySQL Classic protocol

- Read/Write Connections: localhost:6446
- Read/Only Connections:  localhost:6447

## MySQL X protocol

- Read/Write Connections: localhost:6448
- Read/Only Connections:  localhost:6449

[Entrypoint] Starting mysql-router.
2025-06-04 03:58:43 io INFO [7f49ff40e780] starting 16 io-threads, using backend 'linux_epoll'
2025-06-04 03:58:43 http_server INFO [7f49ff40e780] listening on 0.0.0.0:8443
2025-06-04 03:58:43 metadata_cache_plugin INFO [7f49f244d700] Starting Metadata Cache
2025-06-04 03:58:43 metadata_cache INFO [7f49f244d700] Connections using ssl_mode 'PREFERRED'
2025-06-04 03:58:43 metadata_cache INFO [7f49f0449700] Starting metadata cache refresh thread
2025-06-04 03:58:43 routing INFO [7f49d2ffd700] [routing:bootstrap_ro] started: routing strategy = round-robin-with-fallback
2025-06-04 03:58:43 routing INFO [7f49d2ffd700] Start accepting connections for routing routing:bootstrap_ro listening on 6447
2025-06-04 03:58:43 routing INFO [7f49d1ffb700] [routing:bootstrap_x_ro] started: routing strategy = round-robin-with-fallback
2025-06-04 03:58:43 routing INFO [7f49d1ffb700] Start accepting connections for routing routing:bootstrap_x_ro listening on 6449
2025-06-04 03:58:43 routing INFO [7f49d17fa700] [routing:bootstrap_x_rw] started: routing strategy = first-available
2025-06-04 03:58:43 routing INFO [7f49d27fc700] [routing:bootstrap_rw] started: routing strategy = first-available
2025-06-04 03:58:43 routing INFO [7f49d27fc700] Start accepting connections for routing routing:bootstrap_rw listening on 6446
2025-06-04 03:58:43 routing INFO [7f49d17fa700] Start accepting connections for routing routing:bootstrap_x_rw listening on 6448
2025-06-04 03:58:43 metadata_cache INFO [7f49f0449700] Connected with metadata server running on mysql1:3306
2025-06-04 03:58:43 metadata_cache INFO [7f49f0449700] Potential changes detected in cluster after metadata refresh (view_id=0)
2025-06-04 03:58:43 metadata_cache INFO [7f49f0449700] Metadata for cluster 'mycluster' has 4 member(s), single-primary:
2025-06-04 03:58:43 metadata_cache INFO [7f49f0449700]     mysql1:3306 / 33060 - mode=RW
2025-06-04 03:58:43 metadata_cache INFO [7f49f0449700]     mysql2:3306 / 33060 - mode=RO
2025-06-04 03:58:43 metadata_cache INFO [7f49f0449700]     mysql3:3306 / 33060 - mode=RO
2025-06-04 03:58:43 metadata_cache INFO [7f49f0449700]     mysql4:3306 / 33060 - mode=RO
```

## 测试集群复制

```bash
docker run -d --name=mysql-client --hostname=mysql-client --net=innodbnet -e MYSQL_ROOT_PASSWORD=root "mysql/mysql-server:8.0"
```

通过 router 添加一些数据

```bash
docker exec -it mysql-client mysql -h mysql-router -P 6446 -uinno -pinno \
  -e "create database TEST; use TEST; CREATE TABLE t1 (id INT NOT NULL PRIMARY KEY) ENGINE=InnoDB; show tables;" \
  -e "INSERT INTO TEST.t1 VALUES(1); INSERT INTO TEST.t1 VALUES(2); INSERT INTO TEST.t1 VALUES(3);"
```

在另一个读端口可以读数据

```bash
docker exec -it mysql-client mysql -h mysql-router -P 6447 -uinno -pinno \
  -e "SELECT * FROM TEST.t1;"
```

也可以直接在四个 MySQL 实例上直接查询数据

```bash
for N in 1 2 3 4
do docker exec -it mysql$N mysql -uinno -pinno \
  -e "SHOW VARIABLES WHERE Variable_name = 'hostname';" \
  -e "SELECT * FROM TEST.t1;"
done
```

## 测试集群的高可用性

```bash
docker exec -it mysql-client mysqlsh -h mysql-router -P 6447 -uinno -pinno
var cluster = dba.getCluster("mycluster")
cluster.status()
```

当前 mysql1 是 primary 节点

模拟 mysql1 宕机

```bash
docker stop mysql1
```

再查看集群状态`cluster.status()`，发现已经切主到 mysql2 上了

## 清理测试环境

```bash
docker stop mysql1 mysql2 mysql3 mysql4 mysql-router mysql-client
```

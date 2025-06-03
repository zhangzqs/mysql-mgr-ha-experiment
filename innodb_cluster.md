# MySQL InnoDB Cluster 集群配置

## 参考资料

[Mysql InnoDB Cluster 简述](https://zhuanlan.zhihu.com/p/6455873)
[Streamlining MySQL InnoDB Cluster Deployment: Simplifying Setup with Docker Containers](https://itnext.io/setting-up-mysql-innodb-cluster-with-mysql-shell-plus-mysql-router-using-just-docker-containers-9cdbfb6026af)

## 配置 MySQL Router 中间件

三个节点分别执行

```bash
docker exec -it db1 mysql -uroot -ptest@1234 -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY 'test@1234'; FLUSH PRIVILEGES;"
docker exec -it db2 mysql -uroot -ptest@1234 -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY 'test@1234'; FLUSH PRIVILEGES;"
docker exec -it db3 mysql -uroot -ptest@1234 -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY 'test@1234'; FLUSH PRIVILEGES;"
docker exec -it db1 mysqlsh root@localhost:3306 --password=test@1234
docker exec -it db2 mysqlsh root@localhost:3306 --password=test@1234
docker exec -it db3 mysqlsh root@localhost:3306 --password=test@1234

dba.configureInstance();
dba.checkInstanceConfiguration("root@db1:3306");

dba.createCluster('myCluster');
var cluster = dba.getCluster('myCluster');
cluster.addInstance('root@db2:3306');
cluster.addInstance('root@db3:3306');

```

[MySQL Router 8.0 配置文档](https://dev.mysql.com/doc/mysql-router/8.0/en/)

实现自动路由写请求到主节点，读请求在各个节点间负载均衡。

在任意节点执行，确保所有节点状态处于 ONLINE

```sql
SELECT * FROM performance_schema.replication_group_members;
```

在 db1 上创建 MySQL Router 用户，用于授权给 MySQL Router 中间件访问一些数据库集群的元数据。

`mysqlrouter_password` 是 `mysqlrouter`用户的密码，需自行设置。

```sh
docker exec -it db1 mysql -uroot -ptest@1234
```

```sql
CREATE USER 'mysqlrouter'@'%' IDENTIFIED WITH mysql_native_password BY 'mysqlrouter_password';
GRANT SELECT ON mysql_innodb_cluster_metadata.* TO 'mysqlrouter'@'%';
GRANT SELECT ON performance_schema.* TO 'mysqlrouter'@'%';
FLUSH PRIVILEGES;
```

在 db1 上执行以下命令，生成 MySQL Router 的配置文件。

```sh
docker exec -it db1 bash
```

```bash
mysqlrouter --bootstrap mysqlrouter@db1:3306 --directory /tmp/myrouter --conf-use-sockets --user=mysql --account mysqlrouter --account-create always
```

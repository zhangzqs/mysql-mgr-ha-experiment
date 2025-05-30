准备虚拟机，下载安装包

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

# 安装router
apt install -y ./mysql-router-community_8.0.42-1ubuntu24.04_amd64.deb
apt install -y ./mysql-router-community-dbgsym_8.0.42-1ubuntu24.04_amd64.deb
apt install -y ./mysql-router_8.0.42-1ubuntu24.04_amd64.deb

# 安装common
apt install -y ./mysql-common_8.0.42-1ubuntu24.04_amd64.deb

# 安装client
apt install -y ./mysql-community-client-plugins_8.0.42-1ubuntu24.04_amd64.deb
apt install -y ./mysql-community-client-core_8.0.42-1ubuntu24.04_amd64.deb
apt install -y ./mysql-community-client_8.0.42-1ubuntu24.04_amd64.deb
apt install -y ./mysql-client_8.0.42-1ubuntu24.04_amd64.deb

# 安装server
apt install -y ./mysql-community-server-core_8.0.42-1ubuntu24.04_amd64.deb
apt install -y ./mysql-community-server_8.0.42-1ubuntu24.04_amd64.deb
apt install -y ./mysql-server_8.0.42-1ubuntu24.04_amd64.deb

```

默认安装过程中有个向导，不过可以不用管，这样 root 用户相当于没设置密码。

可以单独设置 root 密码

```bash
ALTER USER 'root'@'localhost' IDENTIFIED BY 'test@1234';
FLUSH PRIVILEGES;
```

#!/bin/bash
# 如果能找到 /etc/mysql/ssl 目录，则将其中所有文件所属用户改为 mysql
if [ -d /etc/mysql/ssl ]; then
    echo "Changing ownership of /etc/mysql/ssl to mysql user..."
    chown -R mysql:mysql /etc/mysql/ssl
    echo "Ownership changed."
else
    echo "/etc/mysql/ssl directory not found, skipping ownership change."
fi

# 写入初始化init.sql脚本到tmp
if [ ! -f /tmp/init.sql ]; then
    echo "Creating init.sql script..."
    cat <<EOF >/tmp/init.sql
ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
FLUSH PRIVILEGES;
EOF
    echo "init.sql script created."
fi

# 如果 /var/lib/mysql 目录为空，则初始化
if [ ! -d /var/lib/mysql/mysql ]; then
    echo "Initializing MySQL database..."
    mysqld --initialize --user=mysql --datadir=/var/lib/mysql --init-file=/tmp/init.sql
    echo "MySQL database initialized."
else
    echo "MySQL database already initialized."
fi

tail -f /var/log/mysql/error.log &
# 启动 MySQL 服务
echo "[auto]" >/var/lib/mysql/auto.cnf
echo "server-uuid=$(uuidgen)" >>/var/lib/mysql/auto.cnf
mysqld --user=mysql --datadir=/var/lib/mysql --log-error=/var/log/mysql/error.log --pid-file=/var/run/mysqld/mysqld.pid --socket=/var/run/mysqld/mysqld.sock &

# 等待 MySQL 启动
while ! mysqladmin ping --silent; do
    echo "Waiting for MySQL to start..."
    sleep 1
done
echo "MySQL started successfully."
# 等待 MySQL 进程结束
wait
# 处理容器停止信号
trap 'echo "Stopping MySQL..."; mysqladmin shutdown; exit 0' SIGTERM SIGINT
# 保持容器运行
while true; do
    sleep 60
done

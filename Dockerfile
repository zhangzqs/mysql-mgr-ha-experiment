FROM ubuntu:24.04

# 换源并更新
RUN sed -i 's@//.*archive.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list.d/ubuntu.sources
RUN apt update && apt upgrade -y 
RUN apt install -y uuid-runtime

# 复制MySQL安装包
COPY ./mysql-deb /tmp/

# 安装router
RUN apt install -y /tmp/mysql-router-community_8.0.42-1ubuntu24.04_amd64.deb
RUN apt install -y /tmp/mysql-router-community-dbgsym_8.0.42-1ubuntu24.04_amd64.deb
RUN apt install -y /tmp/mysql-router_8.0.42-1ubuntu24.04_amd64.deb

# 安装common
RUN apt install -y /tmp/mysql-common_8.0.42-1ubuntu24.04_amd64.deb

# 安装client
RUN apt install -y /tmp/mysql-community-client-plugins_8.0.42-1ubuntu24.04_amd64.deb
RUN apt install -y /tmp/mysql-community-client-core_8.0.42-1ubuntu24.04_amd64.deb
RUN apt install -y /tmp/mysql-community-client_8.0.42-1ubuntu24.04_amd64.deb
RUN apt install -y /tmp/mysql-client_8.0.42-1ubuntu24.04_amd64.deb

# 安装server
RUN apt install -y /tmp/mysql-community-server-core_8.0.42-1ubuntu24.04_amd64.deb
RUN apt install -y /tmp/mysql-community-server_8.0.42-1ubuntu24.04_amd64.deb
RUN apt install -y /tmp/mysql-server_8.0.42-1ubuntu24.04_amd64.deb

# 设置环境变量
ENV MYSQL_HOME=/usr/bin
ENV PATH=$MYSQL_HOME:$PATH

ADD entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3306
ENTRYPOINT ["/entrypoint.sh"]
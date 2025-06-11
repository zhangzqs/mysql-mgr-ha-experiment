# 基于 Cloud-Init 的 MySQL 初始化安装测试

## 基于 LXD 的 Cloud-Init 实验测试

```bash
sudo snap install lxd
 # 将当前用户加入 lxd 组
sudo usermod -aG lxd $USER
# 确认当前用户已加入 lxd 组
groups $USER
lxd init --minimal

# 列举当前已存在的镜像
sudo lxc image list

# 列举已存在的镜像
sudo lxc image list images:

# 启动 LXD 容器并使用 cloud-init 初始化
sudo lxc launch ubuntu:noble my-test --config=user.user-data="$(cat hello.ud)"

# 进入容器shell
sudo lxc shell my-test

# 进入容器后，执行以下命令等待 cloud-init 完成初始化
cloud-init status --wait
# 查询user data
cloud-init query userdata
# 验证 cloud-init 有效性
cloud-init schema --system --annotate
# 验证cloud-init脚本执行完成
cat /var/tmp/hello-world.txt

# 停止并删除容器
sudo lxc stop my-test
sudo lxc rm my-test
```

## 修复 LXD 容器网络问题

```bash
# 列出所有网络
sudo lxc network list
# 查看默认网桥的配置，可以看到ipv4地址为 10.231.245.1/24
sudo lxc network show lxdbr0
# 禁用ipv6
sudo lxc network set lxdbr0 ipv6.address none
sudo lxc network set lxdbr0 ipv6.nat false
# 开启 ipv4 dhcp
sudo lxc network set lxdbr0 ipv4.dhcp true
# 重启网络
sudo lxc config device show mysql-test 
sudo lxc exec mysql-test -- ip a

# 查看iptables NAT规则
sudo iptables -t nat -L -n -v
# 发现没有该网段的NAT规则，手工添加
sudo iptables -t nat -A POSTROUTING -s 10.231.245.0/24 ! -d 0.0.0.0/24 -j MASQUERADE
sudo iptables -t nat -D POSTROUTING 5
```

## 创建 MySQL LXD 镜像

```bash
sudo lxc stop mysql-test
sudo lxc rm mysql-test
# 基于ubuntu24.04创建一个新的 LXD 容器
sudo lxc launch ubuntu:noble mysql-test
# 进入容器 shell
sudo lxc shell mysql-test
# 在容器内安装 MySQL
sudo apt update
sudo apt install -y mysql-client-8.0 mysql-server-8.0 mysql-router mysql-shell
```

#!/bin/bash

# Squid代理服务器一键安装配置脚本
# 用户名: Mario
# 密码: 111111

set -e

echo "=========================================="
echo "       Squid代理服务器一键安装脚本"
echo "=========================================="

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo "请使用root权限运行此脚本"
    echo "使用方法: sudo bash install_squid_proxy.sh"
    exit 1
fi

# 检测操作系统
if [ -f /etc/debian_version ]; then
    OS="debian"
    echo "检测到Debian/Ubuntu系统"
elif [ -f /etc/redhat-release ]; then
    OS="redhat"
    echo "检测到RedHat/CentOS系统"
else
    echo "不支持的操作系统"
    exit 1
fi

echo "正在更新系统包..."

# 根据操作系统安装Squid
if [ "$OS" = "debian" ]; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y squid apache2-utils
elif [ "$OS" = "redhat" ]; then
    yum update -y
    yum install -y squid httpd-tools
fi

echo "Squid安装完成"

# 备份原配置文件
echo "备份原配置文件..."
cp /etc/squid/squid.conf /etc/squid/squid.conf.backup.$(date +%Y%m%d_%H%M%S)

# 创建新的配置文件
echo "创建新的Squid配置..."
cat > /etc/squid/squid.conf << 'EOF'
# Squid代理服务器配置文件

# 监听端口
http_port 3128

# 身份验证配置
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd
auth_param basic children 5 startup=5 idle=1
auth_param basic realm Squid proxy-caching web server
auth_param basic credentialsttl 2 hours
auth_param basic casesensitive off

# 访问控制列表
acl authenticated proxy_auth REQUIRED
acl localnet src 0.0.0.0/0
acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 21
acl Safe_ports port 443
acl Safe_ports port 70
acl Safe_ports port 210
acl Safe_ports port 1025-65535
acl Safe_ports port 280
acl Safe_ports port 488
acl Safe_ports port 591
acl Safe_ports port 777
acl CONNECT method CONNECT

# 访问规则
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localhost manager
http_access deny manager
http_access allow authenticated
http_access deny all

# 缓存配置
cache_mem 256 MB
maximum_object_size_in_memory 512 KB
cache_dir ufs /var/spool/squid 1000 16 256

# 日志配置
access_log /var/log/squid/access.log squid
cache_log /var/log/squid/cache.log

# 其他配置
coredump_dir /var/spool/squid
refresh_pattern ^ftp:        1440    20%    10080
refresh_pattern ^gopher:    1440    0%    1440
refresh_pattern -i (/cgi-bin/|\?) 0    0%    0
refresh_pattern .        0    20%    4320

# 隐藏版本信息
httpd_suppress_version_string on

# 转发配置
forwarded_for delete
via off

EOF

echo "配置文件创建完成"

# 创建用户认证文件
echo "创建用户认证..."
htpasswd -bc /etc/squid/passwd Mario 111111
chown proxy:proxy /etc/squid/passwd
chmod 640 /etc/squid/passwd

echo "用户认证设置完成 (用户名: Mario, 密码: 111111)"

# 创建缓存目录
echo "初始化缓存目录..."
if [ "$OS" = "debian" ]; then
    squid -z 2>/dev/null || true
elif [ "$OS" = "redhat" ]; then
    squid -z 2>/dev/null || true
fi

# 测试配置文件
echo "测试配置文件..."
squid -k parse

# 启动和启用Squid服务
echo "启动Squid服务..."
systemctl restart squid
systemctl enable squid

# 检查服务状态
sleep 3
if systemctl is-active --quiet squid; then
    echo "✅ Squid服务启动成功"
else
    echo "❌ Squid服务启动失败"
    echo "请检查日志: tail -f /var/log/squid/cache.log"
    exit 1
fi

# 配置防火墙
echo "配置防火墙..."
if command -v ufw >/dev/null 2>&1; then
    # Ubuntu/Debian with ufw
    ufw allow 3128/tcp
    echo "UFW防火墙规则已添加"
elif command -v firewall-cmd >/dev/null 2>&1; then
    # CentOS/RHEL with firewalld
    firewall-cmd --permanent --add-port=3128/tcp
    firewall-cmd --reload
    echo "Firewalld防火墙规则已添加"
elif command -v iptables >/dev/null 2>&1; then
    # 使用iptables
    iptables -A INPUT -p tcp --dport 3128 -j ACCEPT
    # 保存iptables规则
    if [ "$OS" = "debian" ]; then
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
    elif [ "$OS" = "redhat" ]; then
        iptables-save > /etc/sysconfig/iptables 2>/dev/null || true
    fi
    echo "Iptables防火墙规则已添加"
else
    echo "⚠️  未检测到防火墙，请手动开放3128端口"
fi

# 获取服务器IP地址
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}')

echo ""
echo "=========================================="
echo "       Squid代理服务器安装完成！"
echo "=========================================="
echo ""
echo "代理服务器信息:"
echo "  服务器地址: $SERVER_IP"
echo "  端口: 3128"
echo "  认证方式: 用户名密码"
echo "  用户名: Mario"
echo "  密码: 111111"
echo ""
echo "代理配置示例:"
echo "  HTTP代理: $SERVER_IP:3128"
echo "  HTTPS代理: $SERVER_IP:3128"
echo ""
echo "在adsPower中配置:"
echo "  1. 代理类型: HTTP"
echo "  2. 代理地址: $SERVER_IP"
echo "  3. 代理端口: 3128"
echo "  4. 用户名: Mario"
echo "  5. 密码: 111111"
echo ""
echo "服务管理命令:"
echo "  启动服务: systemctl start squid"
echo "  停止服务: systemctl stop squid"
echo "  重启服务: systemctl restart squid"
echo "  查看状态: systemctl status squid"
echo "  查看日志: tail -f /var/log/squid/access.log"
echo ""
echo "配置文件位置: /etc/squid/squid.conf"
echo "用户认证文件: /etc/squid/passwd"
echo ""
echo "=========================================="
echo "       安装完成，代理服务器已就绪！"
echo "=========================================="
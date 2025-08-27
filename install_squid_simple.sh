#!/bin/bash

# 简化版Squid安装脚本 - 去除复杂的错误处理
echo "=========================================="
echo "       Squid代理服务器简化安装脚本"
echo "=========================================="

# 检查root权限
if [ "$EUID" -ne 0 ]; then 
    echo "请使用root权限运行此脚本"
    exit 1
fi

# 停止现有服务（忽略错误）
echo "停止现有Squid服务..."
systemctl stop squid 2>/dev/null || true
pkill -f squid 2>/dev/null || true
sleep 2

# 安装必要组件
echo "安装Squid和相关组件..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y squid apache2-utils curl net-tools

# 创建配置文件
echo "创建Squid配置文件..."
cat > /etc/squid/squid.conf << 'EOF'
# 基本配置
http_port 3128

# 认证配置
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd
auth_param basic children 5
auth_param basic realm "Squid Proxy Server"
auth_param basic credentialsttl 2 hours

# 访问控制
acl authenticated proxy_auth REQUIRED
acl localhost src 127.0.0.1/32
acl SSL_ports port 443
acl Safe_ports port 80 21 443 70 210 1025-65535 280 488 591 777
acl CONNECT method CONNECT

# 访问规则
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localhost
http_access allow authenticated
http_access deny all

# 基本设置
cache_mem 64 MB
cache_dir ufs /var/spool/squid 1000 16 256
access_log stdio:/var/log/squid/access.log
cache_log /var/log/squid/cache.log
coredump_dir /var/spool/squid

# 隐藏代理信息
forwarded_for delete
via off

# 刷新模式
refresh_pattern ^ftp: 1440 20% 10080
refresh_pattern ^gopher: 1440 0% 1440
refresh_pattern -i (/cgi-bin/|\?) 0 0% 0
refresh_pattern . 0 20% 4320
EOF

# 创建认证文件
echo "创建用户认证文件..."
rm -f /etc/squid/passwd
htpasswd -bc /etc/squid/passwd Mario 111111

# 设置权限
chown proxy:proxy /etc/squid/passwd 2>/dev/null || chown squid:squid /etc/squid/passwd
chmod 640 /etc/squid/passwd

# 验证配置
echo "验证配置文件..."
if ! squid -k parse; then
    echo "配置文件有错误，但继续尝试启动..."
fi

# 初始化缓存
echo "初始化缓存目录..."
mkdir -p /var/spool/squid
chown -R proxy:proxy /var/spool/squid 2>/dev/null || chown -R squid:squid /var/spool/squid
squid -z 2>/dev/null || true

# 启动服务
echo "启动Squid服务..."
systemctl enable squid
systemctl start squid

# 等待启动
sleep 5

# 检查状态
echo "检查服务状态..."
if systemctl is-active --quiet squid; then
    echo "✅ Squid服务启动成功"
    
    # 检查端口
    if netstat -tlnp | grep :3128 >/dev/null 2>&1 || ss -tlnp | grep :3128 >/dev/null 2>&1; then
        echo "✅ 端口3128正在监听"
        
        # 测试连接
        echo "测试代理连接..."
        sleep 2
        if timeout 10 curl -x localhost:3128 --proxy-user Mario:111111 -I http://httpbin.org/ip >/dev/null 2>&1; then
            echo "✅ 代理连接测试成功"
        else
            echo "⚠️  代理连接测试失败，请检查认证设置"
        fi
    else
        echo "❌ 端口3128未在监听"
    fi
else
    echo "❌ Squid服务启动失败"
    echo "查看错误日志:"
    tail -10 /var/log/squid/cache.log 2>/dev/null || echo "无法读取日志"
fi

# 配置防火墙
echo "配置防火墙..."
if command -v ufw >/dev/null 2>&1; then
    ufw allow 3128/tcp 2>/dev/null || true
    echo "UFW防火墙规则已添加"
fi

# 获取服务器IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}')

echo ""
echo "=========================================="
echo "       安装完成"
echo "=========================================="
echo "代理服务器信息:"
echo "  服务器地址: $SERVER_IP"
echo "  端口: 3128"
echo "  用户名: Mario"
echo "  密码: 111111"
echo ""
echo "测试命令:"
echo "  curl -x localhost:3128 --proxy-user Mario:111111 -I http://httpbin.org/ip"
echo ""
echo "adsPower配置:"
echo "  代理类型: HTTP"
echo "  服务器: $SERVER_IP"
echo "  端口: 3128"
echo "  用户名: Mario"
echo "  密码: 111111"
echo "=========================================="
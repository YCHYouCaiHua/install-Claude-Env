#!/bin/bash

# Squid代理服务器一键安装配置脚本 - 无认证版本
# 简化版本，移除所有认证功能，确保稳定运行

echo "=========================================="
echo "       Squid代理服务器安装脚本(无认证版)"
echo "=========================================="

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo "请使用root权限运行此脚本"
    echo "使用方法: sudo bash install_squid_proxy.sh"
    exit 1
fi

echo "开始安装Squid代理服务器..."

# 1. 清理现有环境
echo "=========================================="
echo "1. 清理现有环境"
echo "=========================================="

echo "停止现有Squid服务..."
systemctl stop squid 2>/dev/null || echo "服务未运行或不存在"

echo "清理Squid进程..."
pkill -f squid 2>/dev/null || echo "没有运行的Squid进程"

echo "检查并释放端口3128..."
fuser -k 3128/tcp 2>/dev/null || echo "端口未被占用"

echo "备份并清理配置文件..."
if [ -f /etc/squid/squid.conf ]; then
    cp /etc/squid/squid.conf /etc/squid/squid.conf.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
fi

echo "清理缓存目录..."
rm -rf /var/spool/squid/* 2>/dev/null || true

sleep 2

# 2. 检测操作系统并安装
echo "=========================================="
echo "2. 检测系统并安装组件"
echo "=========================================="

if [ -f /etc/debian_version ]; then
    echo "检测到Debian/Ubuntu系统"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y squid curl net-tools
elif [ -f /etc/redhat-release ]; then
    echo "检测到RedHat/CentOS系统"
    yum update -y
    yum install -y squid curl net-tools
else
    echo "不支持的操作系统"
    exit 1
fi

echo "组件安装完成"

# 3. 创建简化配置文件
echo "=========================================="
echo "3. 创建Squid配置文件"
echo "=========================================="

cat > /etc/squid/squid.conf << 'EOF'
# Squid代理服务器配置文件 - 无认证版本

# 监听端口
http_port 3128

# 访问控制 - 允许所有连接（无认证）
http_access allow all

# 基本设置
cache_mem 64 MB
maximum_object_size 1024 MB
cache_dir ufs /var/spool/squid 1000 16 256

# 日志配置
access_log stdio:/var/log/squid/access.log
cache_log /var/log/squid/cache.log

# 隐藏代理信息
forwarded_for delete
via off

# 缓存设置
coredump_dir /var/spool/squid

# 刷新模式
refresh_pattern ^ftp: 1440 20% 10080
refresh_pattern ^gopher: 1440 0% 1440  
refresh_pattern -i (/cgi-bin/|\?) 0 0% 0
refresh_pattern . 0 20% 4320

# 隐藏版本信息
httpd_suppress_version_string on
EOF

echo "配置文件创建完成"

# 4. 验证配置文件
echo "=========================================="
echo "4. 验证配置文件"
echo "=========================================="

if squid -k parse; then
    echo "✅ 配置文件语法正确"
else
    echo "❌ 配置文件有语法错误，但继续尝试启动"
fi

# 5. 初始化和启动服务
echo "=========================================="
echo "5. 初始化和启动服务"
echo "=========================================="

echo "创建缓存目录..."
mkdir -p /var/spool/squid
chown -R proxy:proxy /var/spool/squid 2>/dev/null || chown -R squid:squid /var/spool/squid 2>/dev/null

echo "初始化Squid缓存..."
squid -z 2>/dev/null || echo "缓存初始化完成或已存在"

echo "启动Squid服务..."
systemctl enable squid 2>/dev/null || true
systemctl start squid

# 等待服务启动
sleep 5

# 6. 验证服务状态
echo "=========================================="
echo "6. 验证服务状态"
echo "=========================================="

if systemctl is-active --quiet squid; then
    echo "✅ Squid服务运行正常"
    
    # 检查端口监听
    if netstat -tlnp 2>/dev/null | grep :3128 >/dev/null || ss -tlnp 2>/dev/null | grep :3128 >/dev/null; then
        echo "✅ 端口3128正在监听"
    else
        echo "❌ 端口3128未在监听"
        echo "等待更长时间..."
        sleep 5
    fi
    
    # 测试代理连接
    echo "测试代理连接..."
    sleep 2
    if timeout 15 curl -x localhost:3128 -I http://httpbin.org/ip >/dev/null 2>&1; then
        echo "✅ 代理连接测试成功"
        
        # 获取代理后的IP
        PROXY_IP=$(timeout 10 curl -x localhost:3128 -s http://httpbin.org/ip 2>/dev/null | grep -o '"origin": "[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "无法获取")
        if [ "$PROXY_IP" != "无法获取" ]; then
            echo "✅ 代理IP获取成功: $PROXY_IP"
        fi
    else
        echo "⚠️  代理连接测试失败，可能需要等待更长时间"
        echo "请稍后手动测试: curl -x localhost:3128 -I http://httpbin.org/ip"
    fi
else
    echo "❌ Squid服务启动失败"
    echo "查看错误日志:"
    tail -10 /var/log/squid/cache.log 2>/dev/null || echo "无法读取日志文件"
    echo "尝试手动启动: systemctl start squid"
fi

# 7. 配置防火墙
echo "=========================================="
echo "7. 配置防火墙"
echo "=========================================="

if command -v ufw >/dev/null 2>&1; then
    ufw allow 3128/tcp 2>/dev/null || true
    echo "UFW防火墙规则已添加"
elif command -v firewall-cmd >/dev/null 2>&1; then
    firewall-cmd --permanent --add-port=3128/tcp 2>/dev/null || true
    firewall-cmd --reload 2>/dev/null || true
    echo "Firewalld防火墙规则已添加"
else
    echo "⚠️  请手动在云服务器控制台开放3128端口"
fi

# 8. 获取服务器信息
SERVER_IP=$(timeout 10 curl -s ifconfig.me 2>/dev/null || timeout 10 curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}' 2>/dev/null || echo "请手动获取服务器IP")

# 9. 显示结果
echo ""
echo "=========================================="
echo "       Squid代理服务器安装完成！"
echo "=========================================="
echo ""
echo "🌐 代理服务器信息:"
echo "  服务器地址: $SERVER_IP"
echo "  端口: 3128"
echo "  认证方式: 无认证"
echo ""
echo "📋 代理配置示例:"
echo "  HTTP代理: $SERVER_IP:3128"
echo "  HTTPS代理: $SERVER_IP:3128"
echo ""
echo "🔧 在adsPower中配置:"
echo "  1. 代理类型: HTTP"
echo "  2. 代理地址: $SERVER_IP"
echo "  3. 代理端口: 3128"
echo "  4. 用户名: (留空)"
echo "  5. 密码: (留空)"
echo ""
echo "🧪 测试命令:"
echo "  本地测试: curl -x localhost:3128 -I http://httpbin.org/ip"
echo "  获取IP: curl -x localhost:3128 -s http://httpbin.org/ip"
echo ""
echo "📊 服务管理命令:"
echo "  启动服务: systemctl start squid"
echo "  停止服务: systemctl stop squid"
echo "  重启服务: systemctl restart squid"
echo "  查看状态: systemctl status squid"
echo "  查看日志: tail -f /var/log/squid/access.log"
echo ""
echo "📁 重要文件:"
echo "  配置文件: /etc/squid/squid.conf"
echo "  访问日志: /var/log/squid/access.log"
echo "  错误日志: /var/log/squid/cache.log"
echo ""

# 最终状态检查
if systemctl is-active --quiet squid; then
    if netstat -tlnp 2>/dev/null | grep :3128 >/dev/null || ss -tlnp 2>/dev/null | grep :3128 >/dev/null; then
        echo "🎉 状态: 代理服务器运行正常，可以使用！"
    else
        echo "⚠️  状态: 服务已启动，端口可能需要更多时间初始化"
    fi
else
    echo "❌ 状态: 服务启动异常，请检查日志或重新运行脚本"
fi

echo ""
echo "=========================================="
echo "       安装脚本执行完成！"
echo "=========================================="
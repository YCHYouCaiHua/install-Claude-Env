#!/bin/bash

# Squid代理服务器一键安装配置脚本
# 用户名: Mario
# 密码: 111111
# 支持全新安装和修复已有环境

# 启用错误处理但允许某些命令失败
set -e
trap 'echo "脚本执行出错，正在尝试修复..."; set +e' ERR

echo "=========================================="
echo "       Squid代理服务器一键安装脚本"
echo "=========================================="

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo "请使用root权限运行此脚本"
    echo "使用方法: sudo bash install_squid_proxy.sh"
    exit 1
fi

# 环境检查和清理函数
cleanup_environment() {
    echo "=========================================="
    echo "       环境检查和清理"
    echo "=========================================="
    
    # 1. 检查并停止现有Squid服务
    echo "1. 检查现有Squid服务..."
    if systemctl is-active --quiet squid 2>/dev/null; then
        echo "发现运行中的Squid服务，正在停止..."
        systemctl stop squid || true
    fi
    
    # 强制清理所有Squid进程
    echo "2. 清理所有Squid进程..."
    pkill -f squid 2>/dev/null || true
    sleep 2
    
    # 3. 检查端口占用
    echo "3. 检查3128端口占用..."
    if netstat -tlnp 2>/dev/null | grep :3128 >/dev/null || ss -tlnp 2>/dev/null | grep :3128 >/dev/null; then
        echo "端口3128被占用，尝试释放..."
        fuser -k 3128/tcp 2>/dev/null || true
        sleep 2
    fi
    
    # 4. 备份现有配置（如果存在）
    if [ -f /etc/squid/squid.conf ]; then
        echo "4. 备份现有配置文件..."
        cp /etc/squid/squid.conf /etc/squid/squid.conf.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
    fi
    
    # 5. 清理损坏的缓存
    echo "5. 清理可能损坏的缓存..."
    if [ -d /var/spool/squid ]; then
        rm -rf /var/spool/squid/* 2>/dev/null || true
    fi
    
    echo "环境清理完成"
}

# 检测认证程序路径
detect_auth_program() {
    AUTH_PROGRAM=""
    for path in "/usr/lib/squid/basic_ncsa_auth" "/usr/lib/squid3/basic_ncsa_auth" "/usr/libexec/squid/basic_ncsa_auth"; do
        if [ -f "$path" ] && [ -x "$path" ]; then
            AUTH_PROGRAM="$path"
            echo "找到认证程序: $AUTH_PROGRAM"
            return 0
        fi
    done
    
    echo "未找到认证程序，尝试搜索..."
    AUTH_PROGRAM=$(find /usr -name "*ncsa_auth*" -type f -executable 2>/dev/null | head -1)
    if [ -n "$AUTH_PROGRAM" ]; then
        echo "找到认证程序: $AUTH_PROGRAM"
        return 0
    fi
    
    echo "⚠️  未找到认证程序，将重新安装apache2-utils"
    return 1
}

# 验证并修复安装
verify_installation() {
    echo "=========================================="
    echo "       验证安装"
    echo "=========================================="
    
    # 检查Squid是否已安装
    if ! command -v squid >/dev/null 2>&1; then
        echo "Squid未安装，需要重新安装"
        return 1
    fi
    
    # 检查apache2-utils是否已安装
    if ! command -v htpasswd >/dev/null 2>&1; then
        echo "apache2-utils未安装，需要重新安装"
        return 1
    fi
    
    # 检查认证程序
    if ! detect_auth_program; then
        return 1
    fi
    
    echo "基本组件已安装"
    return 0
}

# 执行环境清理
cleanup_environment

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

# 验证和安装组件
if ! verify_installation; then
    echo "需要（重新）安装组件..."
    
    # 根据操作系统安装Squid
    if [ "$OS" = "debian" ]; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y
        apt-get install -y squid apache2-utils curl net-tools
    elif [ "$OS" = "redhat" ]; then
        yum update -y
        yum install -y squid httpd-tools curl net-tools
    fi
    
    echo "组件安装完成"
    
    # 重新检测认证程序
    if ! detect_auth_program; then
        echo "❌ 认证程序安装失败"
        exit 1
    fi
else
    echo "组件已就绪，跳过安装步骤"
    # 确保能找到认证程序
    detect_auth_program
fi

# 创建新的配置文件
echo "创建新的Squid配置..."
cat > /etc/squid/squid.conf << EOF
# Squid代理服务器配置文件

# 监听端口
http_port 3128

# 身份验证配置
auth_param basic program $AUTH_PROGRAM /etc/squid/passwd
auth_param basic children 5
auth_param basic realm "Squid Proxy Server"
auth_param basic credentialsttl 2 hours

# 访问控制列表（使用兼容的语法）
acl authenticated proxy_auth REQUIRED
acl localhost src 127.0.0.1/32
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
http_access allow localhost
http_access allow authenticated
http_access deny all

# 缓存配置
cache_mem 64 MB
maximum_object_size 1024 MB
cache_dir ufs /var/spool/squid 1000 16 256

# 日志配置（使用兼容格式）
access_log stdio:/var/log/squid/access.log
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
rm -f /etc/squid/passwd
htpasswd -bc /etc/squid/passwd Mario 111111

# 设置正确的权限
chown proxy:proxy /etc/squid/passwd 2>/dev/null || chown squid:squid /etc/squid/passwd 2>/dev/null
chmod 640 /etc/squid/passwd

echo "用户认证设置完成 (用户名: Mario, 密码: 111111)"

# 测试认证程序
echo "测试认证程序..."
if echo "Mario:111111" | $AUTH_PROGRAM /etc/squid/passwd >/dev/null 2>&1; then
    echo "✅ 认证程序测试成功"
else
    echo "❌ 认证程序测试失败"
    echo "尝试修复权限..."
    chmod 644 /etc/squid/passwd
    if echo "Mario:111111" | $AUTH_PROGRAM /etc/squid/passwd >/dev/null 2>&1; then
        echo "✅ 权限修复后认证程序正常"
    else
        echo "❌ 认证程序仍有问题，但继续安装"
    fi
fi

# 测试配置文件语法
echo "测试配置文件语法..."
if squid -k parse; then
    echo "✅ 配置文件语法正确"
else
    echo "❌ 配置文件语法错误，但继续尝试启动"
fi

# 创建缓存目录
echo "初始化缓存目录..."
mkdir -p /var/spool/squid
chown -R proxy:proxy /var/spool/squid 2>/dev/null || chown -R squid:squid /var/spool/squid 2>/dev/null
squid -z 2>/dev/null || true

# 启动和启用Squid服务
echo "启动Squid服务..."
systemctl enable squid 2>/dev/null || true

# 尝试启动服务，如果失败则进行故障排除
start_squid_with_retry() {
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "尝试启动Squid服务 (第${attempt}次)..."
        
        if systemctl start squid 2>/dev/null; then
            sleep 3
            if systemctl is-active --quiet squid; then
                echo "✅ Squid服务启动成功"
                return 0
            fi
        fi
        
        echo "启动失败，检查错误日志..."
        tail -5 /var/log/squid/cache.log 2>/dev/null || echo "无法读取日志"
        
        if [ $attempt -lt $max_attempts ]; then
            echo "等待5秒后重试..."
            sleep 5
        fi
        
        attempt=$((attempt + 1))
    done
    
    echo "⚠️  Squid服务启动失败，尝试最后的修复..."
    
    # 最后的修复尝试：使用最简配置
    cat > /etc/squid/squid.conf << EOF
http_port 3128
auth_param basic program $AUTH_PROGRAM /etc/squid/passwd
auth_param basic children 5
auth_param basic realm "Squid Proxy"
acl authenticated proxy_auth REQUIRED
http_access allow authenticated
http_access deny all
cache_mem 64 MB
forwarded_for delete
via off
EOF
    
    squid -z 2>/dev/null || true
    systemctl start squid 2>/dev/null
    sleep 3
    
    if systemctl is-active --quiet squid; then
        echo "✅ 使用简化配置启动成功"
        return 0
    else
        echo "❌ 所有启动尝试均失败"
        return 1
    fi
}

start_squid_with_retry

# 最终验证和测试
echo "=========================================="
echo "       最终验证测试"
echo "=========================================="

# 检查服务是否真的在运行
if systemctl is-active --quiet squid; then
    echo "✅ Squid服务正在运行"
    
    # 检查端口监听
    echo "检查端口监听..."
    if netstat -tlnp 2>/dev/null | grep :3128 >/dev/null || ss -tlnp 2>/dev/null | grep :3128 >/dev/null; then
        echo "✅ 端口3128正在监听"
    else
        echo "❌ 端口3128未在监听"
    fi
    
    # 测试代理连接
    echo "测试代理连接..."
    sleep 2
    if timeout 10 curl -x localhost:3128 --proxy-user Mario:111111 -I http://httpbin.org/ip >/dev/null 2>&1; then
        echo "✅ 代理连接测试成功"
    else
        echo "⚠️  代理连接测试失败，但服务已启动"
        echo "可能是网络或认证问题，请稍后重试"
    fi
else
    echo "❌ Squid服务未运行，但安装过程已完成"
    echo "请检查日志: tail -f /var/log/squid/cache.log"
fi

# 配置防火墙
echo "配置防火墙..."
if command -v ufw >/dev/null 2>&1; then
    # Ubuntu/Debian with ufw
    ufw allow 3128/tcp 2>/dev/null || true
    echo "UFW防火墙规则已添加"
elif command -v firewall-cmd >/dev/null 2>&1; then
    # CentOS/RHEL with firewalld
    firewall-cmd --permanent --add-port=3128/tcp 2>/dev/null || true
    firewall-cmd --reload 2>/dev/null || true
    echo "Firewalld防火墙规则已添加"
elif command -v iptables >/dev/null 2>&1; then
    # 使用iptables
    iptables -A INPUT -p tcp --dport 3128 -j ACCEPT 2>/dev/null || true
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
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}' || echo "请手动获取服务器IP")

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
echo "  查看日志: tail -f /var/log/squid/cache.log"
echo "  查看访问日志: tail -f /var/log/squid/access.log"
echo ""
echo "故障排除:"
echo "  重新运行此脚本: sudo bash install_squid_proxy.sh"
echo "  手动测试连接: curl -x localhost:3128 --proxy-user Mario:111111 -I http://httpbin.org/ip"
echo "  配置文件位置: /etc/squid/squid.conf"
echo "  用户认证文件: /etc/squid/passwd"
echo ""

# 最终状态检查
if systemctl is-active --quiet squid && netstat -tlnp 2>/dev/null | grep :3128 >/dev/null; then
    echo "🎉 状态: 代理服务器运行正常，可以使用！"
elif systemctl is-active --quiet squid; then
    echo "⚠️  状态: 服务已启动，但端口检查异常，请稍等片刻再测试"
else
    echo "❌ 状态: 服务未正常运行，请查看上方的错误信息或重新运行脚本"
fi

echo ""
echo "=========================================="
echo "       安装脚本执行完成！"
echo "=========================================="
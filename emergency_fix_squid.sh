#!/bin/bash

echo "=========================================="
echo "       Squid紧急修复脚本"
echo "=========================================="

# 停止所有Squid进程
echo "1. 停止所有Squid进程..."
systemctl stop squid
pkill -f squid

echo "2. 清理缓存目录..."
rm -rf /var/spool/squid/*
mkdir -p /var/spool/squid

echo "3. 创建最简配置文件..."
cat > /etc/squid/squid.conf << 'EOF'
http_port 3128
acl all src 0.0.0.0/0
http_access allow all
cache_mem 64 MB
EOF

echo "4. 测试配置文件..."
squid -k parse
if [ $? -ne 0 ]; then
    echo "❌ 配置文件错误"
    exit 1
fi

echo "5. 设置权限..."
chown -R proxy:proxy /var/spool/squid 2>/dev/null || chown -R squid:squid /var/spool/squid

echo "6. 初始化缓存..."
squid -z

echo "7. 启动Squid..."
systemctl start squid
sleep 3

echo "8. 检查服务状态..."
systemctl status squid --no-pager

echo "9. 检查端口..."
netstat -tlnp | grep :3128 || ss -tlnp | grep :3128

echo "10. 测试连接（无认证）..."
curl -x localhost:3128 -I http://httpbin.org/ip -m 5

if [ $? -eq 0 ]; then
    echo "✅ 基本代理功能正常"
    
    echo "11. 重新添加认证功能..."
    systemctl stop squid
    
    # 找到认证程序
    AUTH_PROGRAM=""
    for path in "/usr/lib/squid/basic_ncsa_auth" "/usr/lib/squid3/basic_ncsa_auth" "/usr/libexec/squid/basic_ncsa_auth"; do
        if [ -f "$path" ]; then
            AUTH_PROGRAM="$path"
            break
        fi
    done
    
    if [ -n "$AUTH_PROGRAM" ]; then
        echo "找到认证程序: $AUTH_PROGRAM"
        
        # 创建认证文件
        htpasswd -bc /etc/squid/passwd Mario 111111
        chown proxy:proxy /etc/squid/passwd 2>/dev/null || chown squid:squid /etc/squid/passwd
        chmod 644 /etc/squid/passwd
        
        # 创建带认证的配置
        cat > /etc/squid/squid.conf << EOF
http_port 3128
auth_param basic program $AUTH_PROGRAM /etc/squid/passwd
auth_param basic children 5
auth_param basic realm "Squid Proxy"
acl authenticated proxy_auth REQUIRED
acl all src 0.0.0.0/0
http_access allow authenticated
http_access deny all
cache_mem 64 MB
forwarded_for delete
via off
EOF
        
        squid -z
        systemctl start squid
        sleep 3
        
        echo "12. 测试认证代理..."
        curl -x localhost:3128 --proxy-user Mario:111111 -I http://httpbin.org/ip -m 5
        
    else
        echo "⚠️  未找到认证程序，保持无认证模式"
    fi
else
    echo "❌ 代理功能异常，查看日志："
    tail -10 /var/log/squid/cache.log
fi

echo ""
echo "=========================================="
echo "修复脚本完成"
echo "=========================================="
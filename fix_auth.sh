#!/bin/bash

echo "=========================================="
echo "       修复Squid认证问题"
echo "=========================================="

# 停止服务
systemctl stop squid

echo "1. 检查认证程序路径..."
AUTH_PROGRAM=""
if [ -f "/usr/lib/squid/basic_ncsa_auth" ]; then
    AUTH_PROGRAM="/usr/lib/squid/basic_ncsa_auth"
    echo "找到认证程序: $AUTH_PROGRAM"
elif [ -f "/usr/lib/squid3/basic_ncsa_auth" ]; then
    AUTH_PROGRAM="/usr/lib/squid3/basic_ncsa_auth"
    echo "找到认证程序: $AUTH_PROGRAM"
elif [ -f "/usr/libexec/squid/basic_ncsa_auth" ]; then
    AUTH_PROGRAM="/usr/libexec/squid/basic_ncsa_auth"
    echo "找到认证程序: $AUTH_PROGRAM"
else
    echo "未找到认证程序，尝试搜索..."
    find /usr -name "*ncsa_auth*" 2>/dev/null | head -1
    AUTH_PROGRAM=$(find /usr -name "*ncsa_auth*" 2>/dev/null | head -1)
fi

if [ -z "$AUTH_PROGRAM" ]; then
    echo "❌ 未找到认证程序，重新安装apache2-utils"
    apt-get update
    apt-get install -y apache2-utils
    AUTH_PROGRAM="/usr/lib/squid/basic_ncsa_auth"
fi

echo "2. 删除旧的认证文件..."
rm -f /etc/squid/passwd

echo "3. 创建新的认证文件..."
htpasswd -bc /etc/squid/passwd Mario 111111

echo "4. 测试认证文件..."
echo "Mario:111111" | $AUTH_PROGRAM /etc/squid/passwd
if [ $? -eq 0 ]; then
    echo "✅ 认证文件测试成功"
else
    echo "❌ 认证文件测试失败"
fi

echo "5. 设置正确的权限..."
chown proxy:proxy /etc/squid/passwd 2>/dev/null || chown squid:squid /etc/squid/passwd
chmod 644 /etc/squid/passwd

echo "6. 创建简化的配置文件..."
cat > /etc/squid/squid.conf << EOF
# HTTP端口
http_port 3128

# 认证配置
auth_param basic program $AUTH_PROGRAM /etc/squid/passwd
auth_param basic children 5
auth_param basic realm "Squid Proxy Server"
auth_param basic credentialsttl 2 hours

# 访问控制
acl authenticated proxy_auth REQUIRED
acl all src 0.0.0.0/0

# 允许通过认证的用户访问
http_access allow authenticated
http_access deny all

# 隐藏代理信息
forwarded_for delete
via off

# 基本设置
cache_mem 64 MB
maximum_object_size 1024 MB
cache_dir ufs /var/spool/squid 1000 16 256

# 日志
access_log /var/log/squid/access.log
cache_log /var/log/squid/cache.log
EOF

echo "7. 验证配置文件..."
squid -k parse
if [ $? -ne 0 ]; then
    echo "❌ 配置文件有错误"
    exit 1
fi

echo "8. 重新初始化缓存..."
squid -z

echo "9. 启动Squid服务..."
systemctl start squid
sleep 5

echo "10. 检查服务状态..."
systemctl status squid --no-pager

echo "11. 测试认证..."
sleep 2
echo "测试代理连接..."
curl -x localhost:3128 --proxy-user Mario:111111 -I http://httpbin.org/ip -v

echo ""
echo "12. 显示认证文件内容..."
echo "认证文件内容:"
cat /etc/squid/passwd

echo ""
echo "13. 手动测试认证程序..."
echo "手动测试认证:"
echo "Mario" | $AUTH_PROGRAM /etc/squid/passwd

echo ""
echo "=========================================="
echo "认证修复完成"
echo "=========================================="
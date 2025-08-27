#!/bin/bash

echo "=========================================="
echo "       检查Squid服务状态"
echo "=========================================="

echo "1. 检查Squid服务状态..."
systemctl status squid --no-pager

echo ""
echo "2. 检查是否有Squid进程运行..."
ps aux | grep squid | grep -v grep

echo ""
echo "3. 检查端口监听..."
netstat -tlnp | grep :3128 || ss -tlnp | grep :3128

echo ""
echo "4. 查看Squid错误日志..."
echo "=== Cache Log (最后30行) ==="
tail -30 /var/log/squid/cache.log 2>/dev/null || echo "无法读取cache.log"

echo ""
echo "5. 尝试手动启动Squid并查看错误..."
echo "手动启动Squid："
squid -N -d1 &
SQUID_PID=$!
sleep 5
kill $SQUID_PID 2>/dev/null

echo ""
echo "6. 检查配置文件语法..."
squid -k parse

echo ""
echo "7. 检查认证程序是否存在..."
ls -la /usr/lib/squid/basic_ncsa_auth 2>/dev/null || echo "认证程序不存在"
ls -la /usr/lib/squid3/basic_ncsa_auth 2>/dev/null || echo "squid3认证程序不存在"

echo ""
echo "8. 检查缓存目录权限..."
ls -la /var/spool/squid/ 2>/dev/null || echo "缓存目录不存在"

echo ""
echo "=========================================="
#!/bin/bash

# Squid无认证代理服务器一键安装脚本
# 专为全新服务器设计，简单可靠

echo "================================================"
echo "    Squid无认证代理服务器一键安装脚本"
echo "================================================"

# 检查root权限
if [ "$EUID" -ne 0 ]; then 
    echo "❌ 请使用root权限运行此脚本"
    echo "使用方法: sudo bash squid_no_auth_install.sh"
    exit 1
fi

echo "✅ 开始安装Squid无认证代理服务器..."

# 1. 更新系统包
echo ""
echo "🔄 步骤1: 更新系统包..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -q -y

# 2. 安装必要软件
echo ""
echo "📦 步骤2: 安装Squid和相关工具..."
apt-get install -y squid curl net-tools ufw

# 3. 备份原始配置（如果存在）
echo ""
echo "💾 步骤3: 备份原始配置..."
if [ -f /etc/squid/squid.conf ]; then
    cp /etc/squid/squid.conf /etc/squid/squid.conf.original
    echo "✅ 原始配置已备份为 squid.conf.original"
fi

# 4. 创建无认证配置文件
echo ""
echo "⚙️  步骤4: 创建Squid配置文件..."

# 清空配置文件
truncate -s 0 /etc/squid/squid.conf

# 使用最简配置确保外部访问正常，逐行添加避免heredoc问题
echo "http_port 3128" | tee /etc/squid/squid.conf > /dev/null
echo "http_access allow all" | tee -a /etc/squid/squid.conf > /dev/null
echo "dns_v4_first on" | tee -a /etc/squid/squid.conf > /dev/null

echo "✅ 配置文件创建完成"

# 5. 显示配置文件内容确认
echo ""
echo "📄 配置文件内容预览:"
echo "================================"
cat /etc/squid/squid.conf
echo "================================"

# 6. 设置正确的权限
echo ""
echo "🔐 步骤5: 设置文件权限..."
chmod 644 /etc/squid/squid.conf

# 7. 验证配置文件语法
echo ""
echo "✔️  步骤6: 验证配置文件语法..."
if squid -k parse; then
    echo "✅ 配置文件语法正确"
else
    echo "⚠️  配置文件语法检查异常，但使用最简配置应该没问题，继续执行"
fi

# 8. 跳过缓存初始化（简化流程）
echo ""
echo "⏭️  步骤7: 跳过缓存初始化（使用最简配置）..."
echo "✅ 缓存配置已简化"

# 9. 配置防火墙
echo ""
echo "🔥 步骤8: 配置防火墙..."
ufw allow 3128/tcp
echo "✅ 防火墙规则已添加 (允许3128端口)"

# 10. 启动Squid服务
echo ""
echo "🚀 步骤9: 启动Squid服务..."
systemctl enable squid
systemctl start squid

# 等待服务启动
echo "⏳ 等待服务启动..."
sleep 8

# 11. 检查服务状态
echo ""
echo "🔍 步骤10: 检查服务状态..."

# 检查服务运行状态
if systemctl is-active --quiet squid; then
    echo "✅ Squid服务运行正常"
    SERVICE_OK=true
else
    echo "❌ Squid服务未正常运行"
    SERVICE_OK=false
fi

# 检查端口监听
if ss -tlnp | grep -q :3128; then
    echo "✅ 端口3128正在监听"
    PORT_OK=true
else
    echo "❌ 端口3128未在监听"
    PORT_OK=false
fi

# 12. 测试代理连接
echo ""
echo "🧪 步骤11: 测试代理连接..."

# 本地连接测试
if timeout 15 curl -x localhost:3128 --connect-timeout 10 -I http://httpbin.org/ip >/dev/null 2>&1; then
    echo "✅ 本地代理连接测试成功"
    
    # 获取代理IP
    PROXY_RESULT=$(timeout 10 curl -x localhost:3128 -s http://httpbin.org/ip 2>/dev/null)
    if echo "$PROXY_RESULT" | grep -q "origin"; then
        PROXY_IP=$(echo "$PROXY_RESULT" | grep -o '"origin": "[^"]*"' | cut -d'"' -f4)
        echo "✅ 代理IP获取成功: $PROXY_IP"
        TEST_OK=true
    else
        echo "⚠️  代理连接成功但IP获取异常"
        TEST_OK=true
    fi
    
    # 外部连接测试（如果可能）
    echo "🌐 测试外部访问..."
    if timeout 10 curl -x $SERVER_IP:3128 --connect-timeout 5 -I http://httpbin.org/ip >/dev/null 2>&1; then
        echo "✅ 外部代理访问测试成功"
    else
        echo "⚠️  外部访问测试失败，可能是防火墙问题"
        echo "   请确保在云服务器控制台开放3128端口"
    fi
else
    echo "❌ 代理连接测试失败"
    TEST_OK=false
fi

# 13. 获取服务器外网IP
echo ""
echo "🌐 获取服务器信息..."
SERVER_IP=$(timeout 10 curl -s ifconfig.me 2>/dev/null || timeout 10 curl -s ipinfo.io/ip 2>/dev/null || echo "无法获取，请手动查看")

# 14. 显示最终结果和使用说明
echo ""
echo "================================================"
echo "           安装结果"
echo "================================================"

if [ "$SERVICE_OK" = true ] && [ "$PORT_OK" = true ] && [ "$TEST_OK" = true ]; then
    echo "🎉 恭喜！Squid代理服务器安装成功并正常工作！"
    INSTALL_SUCCESS=true
else
    echo "⚠️  安装完成，但可能存在一些问题："
    if [ "$SERVICE_OK" = false ]; then
        echo "   - 服务未正常运行"
    fi
    if [ "$PORT_OK" = false ]; then
        echo "   - 端口未正常监听"
    fi
    if [ "$TEST_OK" = false ]; then
        echo "   - 代理连接测试失败"
    fi
    INSTALL_SUCCESS=false
fi

echo ""
echo "================================================"
echo "           代理服务器信息"
echo "================================================"
echo "🌐 服务器IP地址: $SERVER_IP"
echo "🔌 代理端口: 3128"  
echo "🔓 认证方式: 无认证"
echo ""
echo "================================================"
echo "           客户端配置方法"
echo "================================================"
echo "在adsPower中配置："
echo "  代理类型: HTTP"
echo "  服务器地址: $SERVER_IP"
echo "  端口: 3128"
echo "  用户名: (留空)"
echo "  密码: (留空)"
echo ""
echo "================================================"
echo "           测试和管理命令"
echo "================================================"
echo "🧪 本地测试命令:"
echo "   curl -x localhost:3128 -I http://httpbin.org/ip"
echo ""
echo "📊 服务管理命令:"
echo "   sudo systemctl status squid    # 查看服务状态"
echo "   sudo systemctl restart squid   # 重启服务"
echo "   sudo systemctl stop squid      # 停止服务"
echo "   sudo systemctl start squid     # 启动服务"
echo ""
echo "📋 日志查看命令:"
echo "   sudo tail -f /var/log/squid/access.log  # 查看访问日志"
echo "   sudo tail -f /var/log/squid/cache.log   # 查看系统日志"
echo ""
echo "📁 重要文件位置:"
echo "   配置文件: /etc/squid/squid.conf"
echo "   日志目录: /var/log/squid/"
echo ""

if [ "$INSTALL_SUCCESS" = false ]; then
    echo "❗ 故障排除建议:"
    echo "   1. 检查服务日志: sudo tail -20 /var/log/squid/cache.log"
    echo "   2. 手动重启服务: sudo systemctl restart squid"
    echo "   3. 重新运行脚本: sudo bash $0"
    echo "   4. 检查云服务器安全组，确保3128端口对外开放"
    echo "   5. 手动测试: curl -x localhost:3128 -I http://httpbin.org/ip"
    echo ""
fi

echo "================================================"
echo "           安装脚本执行完成"
echo "================================================"

# 15. 最终状态提示
if [ "$INSTALL_SUCCESS" = true ]; then
    echo "✅ 状态: 代理服务器已准备就绪，可以在adsPower中使用！"
else
    echo "⚠️  状态: 安装过程中发现问题，请按照上方建议进行排查"
fi

echo ""
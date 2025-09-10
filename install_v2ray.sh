#!/bin/bash

# V2Ray 一键安装脚本
# 基于 233boy 的 V2Ray 安装脚本
# 使用方法: ./install_v2ray.sh

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# 检查系统要求
check_system() {
    print_message $BLUE "检查系统环境..."
    
    # 检查是否为root用户
    if [ "$EUID" -ne 0 ]; then
        print_message $RED "❌ 请使用root用户运行此脚本"
        echo "   使用 sudo ./install_v2ray.sh 或切换到root用户"
        exit 1
    fi
    
    # 检查操作系统
    if [[ "$OSTYPE" == "darwin"* ]]; then
        print_message $YELLOW "⚠️  检测到macOS系统，V2Ray服务器通常部署在Linux系统"
        read -p "是否继续？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_message $YELLOW "安装已取消"
            exit 0
        fi
    fi
    
    # 检查网络连接
    if ! ping -c 1 google.com &> /dev/null && ! ping -c 1 github.com &> /dev/null; then
        print_message $YELLOW "⚠️  网络连接可能存在问题，但会继续尝试安装"
    fi
    
    print_message $GREEN "✅ 系统检查完成"
}

# 检查依赖
check_dependencies() {
    print_message $BLUE "检查系统依赖..."
    
    local missing_deps=()
    
    # 检查wget
    if ! command -v wget &> /dev/null; then
        missing_deps+=("wget")
    fi
    
    # 检查curl作为备选
    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        missing_deps+=("curl 或 wget")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_message $YELLOW "缺少依赖: ${missing_deps[*]}"
        print_message $BLUE "尝试自动安装依赖..."
        
        # 检测包管理器并安装
        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y wget curl
        elif command -v yum &> /dev/null; then
            yum install -y wget curl
        elif command -v dnf &> /dev/null; then
            dnf install -y wget curl
        elif command -v brew &> /dev/null; then
            brew install wget curl
        else
            print_message $RED "❌ 无法自动安装依赖，请手动安装: ${missing_deps[*]}"
            exit 1
        fi
    fi
    
    print_message $GREEN "✅ 依赖检查完成"
}

# 下载并执行V2Ray安装脚本
install_v2ray() {
    print_message $BLUE "开始安装V2Ray..."
    
    local script_url="https://git.io/v2ray.sh"
    
    # 显示将要执行的命令
    print_message $YELLOW "将要执行的命令:"
    print_message $YELLOW "bash <(wget -qO- -o- $script_url)"
    
    # 确认安装
    echo ""
    read -p "是否继续安装V2Ray？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_message $YELLOW "安装已取消"
        exit 0
    fi
    
    print_message $BLUE "正在下载并执行V2Ray安装脚本..."
    
    # 执行安装命令
    if command -v wget &> /dev/null; then
        bash <(wget -qO- -o- "$script_url")
    elif command -v curl &> /dev/null; then
        bash <(curl -sL "$script_url")
    else
        print_message $RED "❌ 无法下载安装脚本，缺少wget或curl"
        exit 1
    fi
}

# 显示安装后信息
post_install_info() {
    print_message $GREEN "🎉 V2Ray安装脚本执行完成！"
    
    echo ""
    print_message $BLUE "📋 常用V2Ray管理命令:"
    echo "  v2ray                 # 显示管理菜单"
    echo "  v2ray info            # 查看配置信息"
    echo "  v2ray config          # 修改配置"
    echo "  v2ray link            # 生成配置链接"
    echo "  v2ray infolink        # 生成配置信息和链接"
    echo "  v2ray qr              # 生成二维码"
    echo "  v2ray ss              # 修改Shadowsocks配置"
    echo "  v2ray ssinfo          # 查看Shadowsocks配置信息"
    echo "  v2ray ssqr            # 生成Shadowsocks二维码"
    echo "  v2ray status          # 查看运行状态"
    echo "  v2ray start           # 启动V2Ray"
    echo "  v2ray stop            # 停止V2Ray"
    echo "  v2ray restart         # 重启V2Ray"
    echo "  v2ray log             # 查看运行日志"
    echo "  v2ray update          # 更新V2Ray"
    echo "  v2ray update.sh       # 更新脚本"
    echo "  v2ray uninstall       # 卸载V2Ray"
    
    echo ""
    print_message $YELLOW "💡 提示:"
    echo "  - 首次安装后建议运行 'v2ray info' 查看配置信息"
    echo "  - 使用 'v2ray qr' 生成二维码供客户端扫描"
    echo "  - 配置文件位置: /etc/v2ray/config.json"
    echo "  - 如需防火墙配置，请根据端口设置相应规则"
}

# 主函数
main() {
    echo "=================================================="
    print_message $BLUE "V2Ray 一键安装脚本"
    print_message $BLUE "基于 233boy 的 V2Ray 安装脚本"
    echo "=================================================="
    
    # 系统检查
    check_system
    
    # 依赖检查
    check_dependencies
    
    # 安装V2Ray
    install_v2ray
    
    # 显示安装后信息
    post_install_info
}

# 脚本入口点
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
#!/bin/bash

# V2Ray 服务器一键安装脚本 (Ubuntu)
# 使用方法: bash v2ray-install.sh

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印函数
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为 root 用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "请使用 root 权限运行此脚本!"
        exit 1
    fi
}

# 检查系统版本
check_system() {
    if [[ ! -f /etc/os-release ]]; then
        print_error "无法确定系统版本"
        exit 1
    fi
    
    . /etc/os-release
    if [[ $ID != "ubuntu" ]]; then
        print_error "此脚本仅支持 Ubuntu 系统"
        exit 1
    fi
    
    print_info "检测到系统: Ubuntu $VERSION_ID"
}

# 更新系统
update_system() {
    print_info "更新系统包..."
    apt update -q
    apt upgrade -y
    apt install -y curl wget unzip jq
}

# 安装 V2Ray
install_v2ray() {
    print_info "下载并安装 V2Ray..."
    
    # 使用官方安装脚本
    bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
    
    if [[ $? -eq 0 ]]; then
        print_success "V2Ray 安装完成"
    else
        print_error "V2Ray 安装失败"
        exit 1
    fi
}

# 生成配置文件
generate_config() {
    print_info "生成 V2Ray 配置文件..."
    
    # 生成 UUID
    UUID=$(uuidgen)
    PORT=$(shuf -i 10000-65000 -n 1)
    
    # 创建配置文件
    cat > /usr/local/etc/v2ray/config.json << EOF
{
    "log": {
        "loglevel": "warning",
        "access": "/var/log/v2ray/access.log",
        "error": "/var/log/v2ray/error.log"
    },
    "inbounds": [
        {
            "port": $PORT,
            "protocol": "vmess",
            "settings": {
                "clients": [
                    {
                        "id": "$UUID",
                        "level": 1,
                        "alterId": 0
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "security": "none"
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "settings": {}
        },
        {
            "protocol": "blackhole",
            "settings": {},
            "tag": "blocked"
        }
    ],
    "routing": {
        "rules": [
            {
                "type": "field",
                "ip": ["geoip:private"],
                "outboundTag": "blocked"
            }
        ]
    }
}
EOF

    # 创建日志目录
    mkdir -p /var/log/v2ray
    touch /var/log/v2ray/access.log
    touch /var/log/v2ray/error.log
    
    print_success "配置文件生成完成"
    
    # 保存配置信息到文件
    cat > /root/v2ray-config.txt << EOF
V2Ray 服务器配置信息
====================
服务器地址: $(curl -s ipinfo.io/ip)
端口: $PORT
用户ID (UUID): $UUID
额外ID: 0
加密方式: auto
传输协议: tcp
伪装类型: none

Clash 配置示例:
proxies:
  - name: "my-v2ray"
    type: vmess
    server: $(curl -s ipinfo.io/ip)
    port: $PORT
    uuid: $UUID
    alterId: 0
    cipher: auto
EOF
}

# 跳过防火墙配置 (用户不需要)
skip_firewall() {
    print_info "跳过防火墙配置..."
}

# 启动服务
start_service() {
    print_info "启动 V2Ray 服务..."
    
    systemctl enable v2ray
    systemctl start v2ray
    
    sleep 3
    
    if systemctl is-active --quiet v2ray; then
        print_success "V2Ray 服务启动成功"
    else
        print_error "V2Ray 服务启动失败"
        systemctl status v2ray
        exit 1
    fi
}

# 显示配置信息
show_config() {
    print_success "V2Ray 安装完成!"
    echo
    print_info "配置信息已保存到: /root/v2ray-config.txt"
    echo
    cat /root/v2ray-config.txt
    echo
    print_warning "请保存好上述配置信息!"
    print_info "服务管理命令:"
    echo "  启动: systemctl start v2ray"
    echo "  停止: systemctl stop v2ray"
    echo "  重启: systemctl restart v2ray"
    echo "  状态: systemctl status v2ray"
    echo "  日志: journalctl -u v2ray -f"
}

# 主函数
main() {
    print_info "开始安装 V2Ray 服务器..."
    echo
    
    check_root
    check_system
    update_system
    install_v2ray
    generate_config
    skip_firewall
    start_service
    show_config
    
    print_success "安装完成! 🎉"
}

# 运行主函数
main
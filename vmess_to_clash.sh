#!/bin/bash

# VMess to Clash Configuration Converter
# 基于Shell的VMess链接转换为Clash配置文件工具
# 作者: Claude
# 版本: 1.0

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 全局变量
OUTPUT_FILE="clash_config.yaml"
TEMP_DIR="/tmp/vmess_converter_$$"
PROXIES_FILE="$TEMP_DIR/proxies.yaml"
NODE_COUNT=0

# 打印带颜色的消息
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# 检查依赖
check_dependencies() {
    print_message $BLUE "检查系统依赖..."
    
    local missing_deps=()
    
    # 检查base64命令
    if ! command -v base64 &> /dev/null; then
        missing_deps+=("base64")
    fi
    
    # 检查jq命令 (用于JSON解析)
    if ! command -v jq &> /dev/null; then
        print_message $YELLOW "jq未安装，尝试自动安装..."
        
        # 检测系统类型并安装jq
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if command -v brew &> /dev/null; then
                brew install jq
            else
                print_message $RED "请先安装Homebrew，然后运行: brew install jq"
                exit 1
            fi
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if command -v apt-get &> /dev/null; then
                sudo apt-get update && sudo apt-get install -y jq
            elif command -v yum &> /dev/null; then
                sudo yum install -y jq
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y jq
            else
                print_message $RED "无法自动安装jq，请手动安装"
                exit 1
            fi
        else
            print_message $RED "不支持的操作系统，请手动安装jq"
            exit 1
        fi
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_message $RED "缺少依赖: ${missing_deps[*]}"
        exit 1
    fi
    
    print_message $GREEN "✅ 依赖检查完成"
}

# 创建临时目录
create_temp_dir() {
    mkdir -p "$TEMP_DIR"
    echo "" > "$PROXIES_FILE"
}

# 清理临时文件
cleanup() {
    rm -rf "$TEMP_DIR"
}

# 注册清理函数
trap cleanup EXIT

# 解码VMess链接
decode_vmess_link() {
    local vmess_link="$1"
    
    # 移除vmess://前缀
    local encoded_data="${vmess_link#vmess://}"
    
    # Base64解码
    local decoded_data
    if decoded_data=$(echo "$encoded_data" | base64 -d 2>/dev/null); then
        echo "$decoded_data"
    else
        # 尝试添加填充
        local padding_length=$((4 - ${#encoded_data} % 4))
        if [ $padding_length -ne 4 ]; then
            local padded_data="$encoded_data"
            for ((i=0; i<padding_length; i++)); do
                padded_data="${padded_data}="
            done
            echo "$padded_data" | base64 -d 2>/dev/null || return 1
        else
            return 1
        fi
    fi
}

# 转换VMess配置为Clash代理
vmess_to_clash_proxy() {
    local vmess_json="$1"
    
    # 解析JSON字段
    local name=$(echo "$vmess_json" | jq -r '.ps // "VMess节点"')
    local server=$(echo "$vmess_json" | jq -r '.add // ""')
    local port=$(echo "$vmess_json" | jq -r '.port // "443"')
    local uuid=$(echo "$vmess_json" | jq -r '.id // ""')
    local aid=$(echo "$vmess_json" | jq -r '.aid // "0"')
    local scy=$(echo "$vmess_json" | jq -r '.scy // "auto"')
    local net=$(echo "$vmess_json" | jq -r '.net // "tcp"')
    local path=$(echo "$vmess_json" | jq -r '.path // "/"')
    local host=$(echo "$vmess_json" | jq -r '.host // ""')
    local tls=$(echo "$vmess_json" | jq -r '.tls // ""')
    local sni=$(echo "$vmess_json" | jq -r '.sni // ""')
    local type=$(echo "$vmess_json" | jq -r '.type // ""')
    
    # 验证必要字段
    if [ -z "$server" ] || [ -z "$uuid" ]; then
        print_message $RED "❌ VMess配置缺少必要字段"
        return 1
    fi
    
    # 生成Clash代理配置 - 使用正确的YAML格式
    {
        echo "  - name: \"$name\""
        echo "    type: vmess"
        echo "    server: $server"
        echo "    port: $port"
        echo "    uuid: $uuid"
        echo "    alterId: $aid"
        echo "    cipher: $scy"
        
        # 添加网络协议配置
        case "$net" in
            "ws")
                echo "    network: ws"
                echo "    ws-opts:"
                echo "      path: \"$path\""
                if [ -n "$host" ]; then
                    echo "      headers:"
                    echo "        Host: \"$host\""
                fi
                ;;
            "tcp")
                echo "    network: tcp"
                if [ "$type" = "http" ]; then
                    echo "    http-opts:"
                    echo "      path:"
                    echo "        - \"$path\""
                    if [ -n "$host" ]; then
                        echo "      headers:"
                        echo "        Host:"
                        echo "          - \"$host\""
                    fi
                fi
                ;;
            "grpc")
                echo "    network: grpc"
                echo "    grpc-opts:"
                echo "      grpc-service-name: \"$path\""
                ;;
        esac
        
        # 添加TLS配置
        if [ "$tls" = "tls" ]; then
            echo "    tls: true"
            if [ -n "$sni" ]; then
                echo "    servername: \"$sni\""
            elif [ -n "$host" ]; then
                echo "    servername: \"$host\""
            fi
        fi
    } >> "$PROXIES_FILE"
    
    NODE_COUNT=$((NODE_COUNT + 1))
    print_message $GREEN "✅ 成功添加节点: $name ($server:$port)"
}


# 创建完整的Clash配置文件
create_clash_config() {
    print_message $BLUE "生成Clash配置文件..."
    
    # 生成代理名称数组
    local proxy_names=()
    while IFS= read -r name; do
        proxy_names+=("$name")
    done < <(grep "name:" "$PROXIES_FILE" | sed 's/.*name: "\(.*\)"/\1/')
    
    # 开始写入配置文件
    {
        echo "port: 7890"
        echo "socks-port: 7891" 
        echo "allow-lan: false"
        echo "mode: rule"
        echo "log-level: info"
        echo "external-controller: 127.0.0.1:9090"
        echo ""
        echo "dns:"
        echo "  enable: true"
        echo "  ipv6: false"
        echo "  listen: 0.0.0.0:53"
        echo "  enhanced-mode: fake-ip"
        echo "  fake-ip-range: 198.18.0.1/16"
        echo "  nameserver:"
        echo "    - 223.5.5.5"
        echo "    - 114.114.114.114"
        echo "  fallback:"
        echo "    - 8.8.8.8"
        echo "    - 1.1.1.1"
        echo ""
        echo "proxies:"
    } > "$OUTPUT_FILE"
    
    # 添加代理配置
    if [ -s "$PROXIES_FILE" ]; then
        cat "$PROXIES_FILE" >> "$OUTPUT_FILE"
    else
        print_message $RED "❌ 没有有效的代理配置"
        exit 1
    fi
    
    # 添加代理组配置
    {
        echo ""
        echo "proxy-groups:"
        echo "  - name: \"🚀 节点选择\""
        echo "    type: select"
        echo "    proxies:"
        echo "      - \"♻️ 自动选择\""
        echo "      - DIRECT"
        
        # 添加所有代理名称
        for name in "${proxy_names[@]}"; do
            echo "      - \"$name\""
        done
        
        echo ""
        echo "  - name: \"♻️ 自动选择\""
        echo "    type: url-test"
        echo "    url: http://www.gstatic.com/generate_204"
        echo "    interval: 300"
        echo "    proxies:"
        
        # 添加所有代理名称
        for name in "${proxy_names[@]}"; do
            echo "      - \"$name\""
        done
        
        echo ""
        echo "  - name: \"🌍 国外媒体\""
        echo "    type: select"
        echo "    proxies:"
        echo "      - \"🚀 节点选择\""
        echo "      - \"♻️ 自动选择\""
        echo "      - DIRECT"
        echo ""
        echo "  - name: \"📺 哔哩哔哩\""
        echo "    type: select"
        echo "    proxies:"
        echo "      - DIRECT"
        echo "      - \"🚀 节点选择\""
        echo ""
        echo "  - name: \"🍃 应用净化\""
        echo "    type: select"
        echo "    proxies:"
        echo "      - REJECT"
        echo "      - DIRECT"
        echo ""
        echo "rules:"
        echo "  - DOMAIN-SUFFIX,google.com,🚀 节点选择"
        echo "  - DOMAIN-SUFFIX,youtube.com,🌍 国外媒体"
        echo "  - DOMAIN-SUFFIX,netflix.com,🌍 国外媒体"
        echo "  - DOMAIN-SUFFIX,bilibili.com,📺 哔哩哔哩"
        echo "  - DOMAIN-SUFFIX,doubleclick.net,🍃 应用净化"
        echo "  - GEOIP,CN,DIRECT"
        echo "  - MATCH,🚀 节点选择"
    } >> "$OUTPUT_FILE"
    
    print_message $GREEN "✅ Clash配置文件已生成: $(pwd)/$OUTPUT_FILE"
}

# 主函数
main() {
    echo "=================================================="
    print_message $BLUE "VMess to Clash 配置转换器 (Shell版本)"
    echo "=================================================="
    
    # 检查依赖并创建临时目录
    check_dependencies
    create_temp_dir
    
    print_message $BLUE "🎯 开始转换流程..."
    
    # 交互式输入VMess链接
    while true; do
        echo ""
        print_message $YELLOW "请输入VMess链接 (输入 'done' 完成输入, 'exit' 退出):"
        read -r -p "VMess链接: " vmess_link
        
        case "$vmess_link" in
            "exit"|"EXIT")
                print_message $YELLOW "退出程序"
                exit 0
                ;;
            "done"|"DONE")
                if [ $NODE_COUNT -eq 0 ]; then
                    print_message $RED "未添加任何节点，请至少添加一个节点"
                    continue
                fi
                break
                ;;
            vmess://*)
                print_message $BLUE "正在解析VMess链接..."
                
                # 解码VMess链接
                if vmess_json=$(decode_vmess_link "$vmess_link"); then
                    # 验证JSON格式
                    if echo "$vmess_json" | jq . >/dev/null 2>&1; then
                        vmess_to_clash_proxy "$vmess_json"
                    else
                        print_message $RED "❌ VMess链接格式错误或解析失败"
                    fi
                else
                    print_message $RED "❌ VMess链接解码失败"
                fi
                ;;
            "")
                continue
                ;;
            *)
                print_message $RED "错误: 请输入有效的VMess链接 (以 vmess:// 开头)"
                ;;
        esac
    done
    
    if [ $NODE_COUNT -eq 0 ]; then
        print_message $RED "没有有效的节点配置，退出程序"
        exit 1
    fi
    
    # 生成Clash配置文件
    create_clash_config
    
    # 显示结果
    print_message $BLUE "📋 配置摘要:"
    echo "  📁 文件位置: $(pwd)/$OUTPUT_FILE"
    echo "  🔢 节点数量: $NODE_COUNT"
    echo ""
    print_message $GREEN "🎉 转换完成! 请将 $OUTPUT_FILE 导入Clash客户端使用"
}

# 脚本入口点
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
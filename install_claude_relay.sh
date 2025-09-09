#!/bin/bash

# Claude Relay Service Installation Script for Ubuntu
# This script installs Node.js, Redis, Caddy and sets up the claude-relay-service with domain configuration

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Starting Claude Relay Service installation...${NC}"
echo "============================================="

# Function to prompt for user input
prompt_user_input() {
    echo ""
    echo -e "${YELLOW}📝 请配置你的域名信息（可选）：${NC}"
    echo -e "如果你有域名，将自动配置 Caddy 反向代理和 HTTPS"
    echo -e "如果没有域名，则只配置本地访问"
    echo ""
    
    read -p "是否配置域名？(y/n) [默认: n]: " use_domain
    use_domain=${use_domain:-n}
    
    DOMAIN=""
    if [[ $use_domain == "y" || $use_domain == "Y" ]]; then
        echo ""
        read -p "🌐 请输入你的域名（例如：api.example.com）: " DOMAIN
        
        if [[ -z "$DOMAIN" ]]; then
            echo -e "${RED}❌ 域名不能为空，将跳过域名配置${NC}"
            DOMAIN=""
        else
            echo -e "${GREEN}✅ 域名设置为: $DOMAIN${NC}"
        fi
    fi
}

# Get user input for domain configuration
prompt_user_input

# Install Node.js 18.x
echo -e "${BLUE}📦 安装 Node.js 18.x...${NC}"
echo "📋 即将执行: curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -"
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
echo -e "${GREEN}✅ Node.js 仓库配置完成${NC}"

echo "📋 即将执行: sudo apt-get install -y nodejs"
sudo apt-get install -y nodejs
echo -e "${GREEN}✅ Node.js 安装完成${NC}"

# Update package list and install Redis
echo "📋 即将执行: sudo apt update"
sudo apt update
echo "✅ 软件包列表更新完成"

echo "📋 即将执行: sudo apt install redis-server"
sudo apt install redis-server
echo "✅ Redis 服务器安装完成"

# Start Redis service
echo "📋 即将执行: sudo systemctl start redis-server"
sudo systemctl start redis-server
echo "✅ Redis 服务启动完成"

# Install Caddy if domain is configured
if [[ -n "$DOMAIN" ]]; then
    echo -e "${BLUE}📦 安装 Caddy 反向代理服务器...${NC}"
    
    # Check if Caddy is already installed
    if command -v caddy &> /dev/null; then
        echo "⚠️ Caddy 已安装，跳过安装步骤"
    else
        echo "📋 即将执行: 安装 Caddy GPG 密钥和仓库"
        sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
        
        sudo apt update
        echo "📋 即将执行: sudo apt install -y caddy"
        sudo apt install -y caddy
        echo "✅ Caddy 安装完成"
    fi
fi

# Clone the repository
echo -e "${BLUE}📦 克隆项目仓库...${NC}"
echo "📋 即将执行: git clone https://github.com/Wei-Shaw/claude-relay-service.git"
git clone https://github.com/Wei-Shaw/claude-relay-service.git
echo "✅ 仓库克隆完成"

echo "📋 即将执行: cd claude-relay-service"
cd claude-relay-service
echo "✅ 已进入项目目录"

# Install npm dependencies
echo "📋 即将执行: npm install"
npm install
echo "✅ npm 依赖包安装完成"

# Copy configuration files
echo "📋 即将执行: cp config/config.example.js config/config.js"
cp config/config.example.js config/config.js
echo "✅ config.js 文件创建完成"

echo "📋 即将执行: cp .env.example .env"
cp .env.example .env
echo "✅ .env 文件创建完成"

# Edit .env file with specific values
echo "📋 即将执行: sed 命令更新 .env 配置文件"
sed -i 's/JWT_SECRET=your-jwt-secret-here/JWT_SECRET=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyLTEyMyIsInNjb3BlIjoicmVhZDphbGwiLCJpYXQiOjE2OTMyMjMxMTR9.rC4YHZh_jVbLOM6Vx7X4BNQZGeiEC7-Mp7khWnJHZu4/' .env
sed -i 's/API_KEY_PREFIX=cr_/API_KEY_PREFIX=ych_/' .env
sed -i 's/ENCRYPTION_KEY=your-encryption-key-here/ENCRYPTION_KEY=oPkxyIBrLPDnS-JaW7FPSHJY_DWerQ9hYgL80D-wiws=/' .env

# Configure host binding based on domain setup
if [[ -n "$DOMAIN" ]]; then
    echo "🔧 配置服务为本地监听（通过 Caddy 反向代理）"
    sed -i 's/HOST=0.0.0.0/HOST=127.0.0.1/' .env
else
    echo "🔧 配置服务为公网访问（直接访问）"
fi

echo "✅ .env 配置文件更新完成"

echo "📋 即将执行: cat .env"
echo "修改后的 .env 文件内容:"
echo "----------------------------------------"
cat .env
echo "----------------------------------------"
echo "✅ .env 文件内容显示完成"

# Install web dependencies and clone web-dist
echo "📋 即将执行: npm run install:web"
npm run install:web
echo "✅ Web 依赖包安装完成"

echo "📋 即将执行: mkdir -p web/admin-spa/dist"
mkdir -p web/admin-spa/dist
echo "✅ 目录创建完成"

echo "📋 即将执行: git clone -b web-dist https://github.com/Wei-Shaw/claude-relay-service.git web/admin-spa/dist"
git clone -b web-dist https://github.com/Wei-Shaw/claude-relay-service.git web/admin-spa/dist
echo "✅ Web 构建文件克隆完成"

# Run setup
echo "📋 即将执行: npm run setup"
npm run setup
echo "✅ 项目设置完成"

# Configure Caddy if domain is set
configure_caddy() {
    if [[ -n "$DOMAIN" ]]; then
        echo -e "${BLUE}🔧 配置 Caddy 反向代理...${NC}"
        
        # Backup existing Caddyfile if it exists
        if [[ -f "/etc/caddy/Caddyfile" ]]; then
            echo "📋 备份现有 Caddyfile"
            sudo cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.backup.$(date +%Y%m%d_%H%M%S)
        fi
        
        # Create new Caddyfile configuration
        echo "📋 创建 Caddy 配置文件"
        sudo tee /etc/caddy/Caddyfile > /dev/null <<EOF
# Claude Relay Service Caddy Configuration
$DOMAIN {
    # 反向代理到本地服务
    reverse_proxy 127.0.0.1:3000 {
        # 支持流式响应（SSE）
        flush_interval -1
        
        # 传递真实IP
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
        
        # 超时设置（适合长连接）
        transport http {
            read_timeout 300s
            write_timeout 300s
            dial_timeout 30s
        }
    }
    
    # 安全头部
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Frame-Options "DENY"
        X-Content-Type-Options "nosniff"
        -Server
    }
}
EOF
        
        # Validate Caddy configuration
        echo "📋 验证 Caddy 配置"
        if sudo caddy validate --config /etc/caddy/Caddyfile; then
            echo "✅ Caddy 配置验证通过"
        else
            echo -e "${RED}❌ Caddy 配置验证失败${NC}"
            return 1
        fi
        
        # Start and enable Caddy service
        echo "📋 启动 Caddy 服务"
        sudo systemctl start caddy
        sudo systemctl enable caddy
        
        # Check Caddy status
        if systemctl is-active --quiet caddy; then
            echo "✅ Caddy 服务启动成功"
        else
            echo -e "${RED}❌ Caddy 服务启动失败${NC}"
            return 1
        fi
    fi
}

# Start daemon service
echo "📋 即将执行: npm run service:start:daemon"
npm run service:start:daemon
echo "✅ 守护进程服务启动完成"

# Configure Caddy reverse proxy
configure_caddy

echo "============================================="
echo -e "${GREEN}🎉 Claude Relay Service 安装完成！${NC}"
echo -e "${GREEN}🚀 服务现在正在守护进程模式下运行${NC}"
echo ""

# Display access information
echo -e "${YELLOW}📋 访问信息：${NC}"
echo "----------------------------------------"

if [[ -n "$DOMAIN" ]]; then
    echo -e "${GREEN}🌐 Web 管理界面：${NC}"
    echo "   https://$DOMAIN/web"
    echo ""
    echo -e "${GREEN}🔗 API 端点：${NC}"
    echo "   Claude API: https://$DOMAIN/api/"
    echo "   Gemini API: https://$DOMAIN/gemini/"
    echo "   OpenAI 兼容: https://$DOMAIN/openai/"
    echo ""
    echo -e "${GREEN}🔒 HTTPS：${NC}自动配置 Let's Encrypt SSL 证书"
else
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP")
    echo -e "${GREEN}🌐 Web 管理界面：${NC}"
    echo "   本地: http://localhost:3000/web"
    echo "   公网: http://$SERVER_IP:3000/web"
    echo ""
    echo -e "${GREEN}🔗 API 端点：${NC}"
    echo "   Claude API: http://$SERVER_IP:3000/api/"
    echo "   Gemini API: http://$SERVER_IP:3000/gemini/"
    echo "   OpenAI 兼容: http://$SERVER_IP:3000/openai/"
    echo ""
    echo -e "${YELLOW}⚠️  注意：${NC}使用 HTTP 连接，建议配置域名和 HTTPS"
fi

echo ""
echo -e "${BLUE}📂 管理员凭据：${NC}"
echo "   查看文件: data/init.json"
echo ""
echo -e "${BLUE}🔧 服务管理命令：${NC}"
echo "   查看状态: npm run service:status"
echo "   查看日志: npm run service:logs"
echo "   重启服务: npm run service:restart:daemon"
echo "   停止服务: npm run service:stop"
echo "----------------------------------------"
echo ""
if [[ -n "$DOMAIN" ]]; then
    echo -e "${YELLOW}🔥 防火墙配置提醒：${NC}"
    echo "   确保服务器防火墙开放以下端口："
    echo "   • 80 (HTTP) - Let's Encrypt 验证"
    echo "   • 443 (HTTPS) - 正式访问端口"
    echo ""
    echo -e "${BLUE}💡 域名解析提醒：${NC}"
    echo "   请确保域名 $DOMAIN 已正确解析到此服务器 IP"
    echo "   DNS 解析生效后，Let's Encrypt 将自动申请 SSL 证书"
else
    echo -e "${YELLOW}🔥 防火墙配置提醒：${NC}"
    echo "   如需外网访问，请确保服务器防火墙开放端口："
    echo "   • 3000 - Claude Relay Service 服务端口"
fi
echo ""
echo -e "${GREEN}✨ 安装完成！请根据上方信息访问管理界面${NC}"
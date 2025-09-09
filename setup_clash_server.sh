#!/bin/bash

# Clash服务器自动配置脚本 - Ubuntu 优化版
# 支持IP和域名两种模式，自动生成随机管理密码
# 
# 系统要求: Ubuntu 18.04+ 或 Debian 10+
# 使用方法: 
#   sudo bash setup_clash_server.sh                    # 交互式安装
#   sudo bash setup_clash_server.sh <IP地址或域名>      # 自动生成密码
#   sudo bash setup_clash_server.sh <IP地址或域名> <密码> # 指定密码

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 获取服务器信息
if [ $# -eq 1 ]; then
    SERVER=$1
elif [ $# -eq 2 ]; then
    SERVER=$1
    PASSWORD=$2
else
    echo -e "${YELLOW}欢迎使用Clash服务器自动配置脚本${NC}"
    echo ""
    
    # 获取服务器地址
    while true; do
        read -p "请输入服务器IP地址或域名: " SERVER
        if [ -n "$SERVER" ]; then
            break
        else
            log_warn "服务器地址不能为空，请重新输入"
        fi
    done
    
    echo ""
fi

# 如果没有提供密码，则生成随机密码
if [ -z "$PASSWORD" ]; then
    log_info "正在生成随机管理密码..."
    PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 10)
    if [ -z "$PASSWORD" ]; then
        # 备用方法：使用date和随机数
        PASSWORD=$(date +%s | sha256sum | base64 | head -c 10 | tr -dc A-Za-z0-9)
    fi
    log_info "管理密码已生成"
fi

# 检测是否为域名或IP
if [[ $SERVER =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    IS_IP=true
    log_info "检测到IP地址: $SERVER"
else
    IS_IP=false
    log_info "检测到域名: $SERVER"
fi

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
    log_error "请使用sudo运行此脚本"
    log_error "正确用法: sudo bash setup_clash_server.sh"
    exit 1
fi

# 检查系统要求
echo "正在执行: 检查系统环境..."
if ! command -v curl >/dev/null 2>&1; then
    echo "⚠️ 警告: curl 未安装，将在后续步骤中安装"
fi

if ! command -v wget >/dev/null 2>&1; then
    echo "⚠️ 警告: wget 未安装，将在后续步骤中安装"
fi

# 检查网络连接
if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo "⚠️ 警告: 网络连接可能存在问题"
fi

echo "✓ 完成: 系统环境检查"

log_info "开始配置Clash服务器..."
log_info "服务器: $SERVER"
log_info "密码: $PASSWORD"

# 更新系统
echo "正在执行: 更新系统包..."
apt update && apt upgrade -y
echo "✓ 完成: 系统包更新"

# 安装必要的软件包 (Ubuntu/Debian适配)
echo "正在执行: 安装必要软件包..."
echo "正在执行: 安装基础工具 (curl wget unzip jq)..."
if ! apt install -y curl wget unzip jq; then
    log_error "基础工具安装失败"
    exit 1
fi
echo "✓ 完成: 基础工具安装"

# 根据模式选择Web服务器
if [ "$IS_IP" = true ]; then
    log_info "使用IP模式，安装配置Nginx..."
    echo "正在执行: 安装 Nginx Web服务器..."
    if ! apt install -y nginx; then
        log_error "Nginx 安装失败"
        exit 1
    fi
    echo "✓ 完成: Nginx 安装"
    
    # 启动 Nginx 服务
    echo "正在执行: 启动 Nginx 服务..."
    systemctl enable nginx
    systemctl start nginx
    echo "✓ 完成: Nginx 服务启动"
else
    log_info "使用域名模式，安装Caddy..."
    
    # 先安装nginx作为备用
    echo "正在执行: 安装 Nginx (备用)..."
    apt install -y nginx
    echo "✓ 完成: Nginx 安装"
    
    echo "正在执行: 添加 Caddy 软件源..."
    apt install -y debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
    echo "✓ 完成: Caddy 软件源配置"
    
    echo "正在执行: 更新包列表并安装 Caddy..."
    apt update
    if ! apt install -y caddy; then
        log_error "Caddy 安装失败，将使用 Nginx"
        IS_IP=true  # 回退到IP模式使用Nginx
    else
        echo "✓ 完成: Caddy 安装"
        
        echo "正在执行: 停用 Nginx 服务 (使用 Caddy)..."
        systemctl stop nginx
        systemctl disable nginx
        echo "✓ 完成: Nginx 服务停用"
    fi
fi

# 安装Clash Meta (mihomo)
log_info "安装Clash Meta (mihomo)..."
cd /opt

# 优先使用Ubuntu/Debian的包管理器安装
INSTALL_SUCCESS=false

echo "正在执行: 检测系统环境并选择最佳安装方式..."

# 检测操作系统类型
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
    OS_VERSION=$VERSION_ID
    echo "✓ 检测到系统: $PRETTY_NAME"
else
    OS_ID="unknown"
    echo "⚠️ 警告: 无法确定操作系统类型"
fi

# Ubuntu/Debian 优先使用 APT 包管理器
if [ "$OS_ID" = "ubuntu" ] || [ "$OS_ID" = "debian" ]; then
    echo "正在执行: Ubuntu/Debian 系统，优先使用 APT 安装..."
    
    # 更新包列表
    echo "正在执行: 更新 APT 包列表..."
    apt update
    echo "✓ 完成: APT 包列表更新"
    
    # 检查系统仓库是否有 mihomo
    echo "正在执行: 检查系统仓库中的 mihomo..."
    if apt-cache search mihomo 2>/dev/null | grep -q "mihomo"; then
        echo "正在执行: 通过 APT 从系统仓库安装 mihomo..."
        if apt install -y mihomo; then
            ln -sf /usr/bin/mihomo /opt/clash-meta
            chmod +x /opt/clash-meta
            INSTALL_SUCCESS=true
            echo "✓ 完成: 通过 APT 系统仓库安装 mihomo"
        fi
    else
        echo "⚠️ 信息: 系统仓库中未找到 mihomo，尝试下载官方 deb 包"
        
        # 获取最新版本号
        echo "正在执行: 获取最新版本信息..."
        CLASH_VERSION=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | grep '"tag_name"' | cut -d '"' -f 4 2>/dev/null)
        if [ -z "$CLASH_VERSION" ]; then
            CLASH_VERSION="v1.19.13"  # 备用版本
            echo "⚠️ 警告: 无法获取最新版本，使用备用版本 $CLASH_VERSION"
        else
            echo "✓ 获取到版本: $CLASH_VERSION"
        fi
        
        echo "正在执行: 下载 mihomo deb 包..."
        if wget -q --timeout=30 -O mihomo.deb "https://github.com/MetaCubeX/mihomo/releases/download/$CLASH_VERSION/mihomo-linux-amd64-$CLASH_VERSION.deb"; then
            echo "✓ 完成: deb 包下载"
            
            echo "正在执行: 安装 deb 包..."
            if dpkg -i mihomo.deb 2>/dev/null; then
                ln -sf /usr/bin/mihomo /opt/clash-meta
                chmod +x /opt/clash-meta
                rm -f mihomo.deb
                INSTALL_SUCCESS=true
                echo "✓ 完成: 通过 deb 包安装 mihomo"
            else
                echo "正在执行: 修复依赖关系..."
                apt install -f -y
                if dpkg -i mihomo.deb; then
                    ln -sf /usr/bin/mihomo /opt/clash-meta
                    chmod +x /opt/clash-meta
                    rm -f mihomo.deb
                    INSTALL_SUCCESS=true
                    echo "✓ 完成: 通过 deb 包安装 mihomo (依赖已修复)"
                else
                    rm -f mihomo.deb
                    echo "❌ deb 包安装失败"
                fi
            fi
        else
            echo "❌ deb 包下载失败"
        fi
    fi
# 其他Linux发行版的备用安装方式
else
    echo "正在执行: 检测到非 Ubuntu/Debian 系统，尝试其他安装方式..."
    
    # 检查是否有 Homebrew (少数情况)
    if command -v brew >/dev/null 2>&1; then
        echo "正在执行: 发现 Homebrew，尝试安装..."
        if brew install mihomo; then
            ln -sf $(brew --prefix)/bin/mihomo /opt/clash-meta
            chmod +x /opt/clash-meta
            INSTALL_SUCCESS=true
            echo "✓ 完成: 通过 Homebrew 安装 mihomo"
        fi
    fi
    
    # RPM 系统 (RHEL/CentOS/Fedora)
    if [ "$INSTALL_SUCCESS" = false ] && (command -v yum >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1); then
        echo "正在执行: 检测到 RPM 系统，下载 rpm 包..."
        CLASH_VERSION=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | grep '"tag_name"' | cut -d '"' -f 4 2>/dev/null)
        if [ -z "$CLASH_VERSION" ]; then
            CLASH_VERSION="v1.19.13"
        fi
        
        if wget -q --timeout=30 -O mihomo.rpm "https://github.com/MetaCubeX/mihomo/releases/download/$CLASH_VERSION/mihomo-linux-amd64-$CLASH_VERSION.rpm"; then
            if command -v dnf >/dev/null 2>&1; then
                dnf localinstall -y mihomo.rpm
            elif command -v yum >/dev/null 2>&1; then
                yum localinstall -y mihomo.rpm
            else
                rpm -i mihomo.rpm
            fi
            
            if [ $? -eq 0 ]; then
                ln -sf /usr/bin/mihomo /opt/clash-meta
                chmod +x /opt/clash-meta
                rm -f mihomo.rpm
                INSTALL_SUCCESS=true
                echo "✓ 完成: 通过 rpm 包安装 mihomo"
            else
                rm -f mihomo.rpm
                echo "❌ rpm 包安装失败"
            fi
        fi
    fi
fi

# 最后尝试直接下载二进制文件
if [ "$INSTALL_SUCCESS" = false ]; then
    echo "正在执行: 包管理器安装失败，尝试直接下载二进制文件..."
    
    # 获取最新版本号
    CLASH_VERSION=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | grep '"tag_name"' | cut -d '"' -f 4)
    if [ -z "$CLASH_VERSION" ]; then
        CLASH_VERSION="v1.19.13"  # 备用版本
        echo "⚠️ 警告: 无法获取最新版本，使用备用版本 $CLASH_VERSION"
    else
        echo "✓ 获取到版本信息: $CLASH_VERSION"
    fi
    
    # 尝试下载兼容版本
    if wget -O clash-meta.gz "https://github.com/MetaCubeX/mihomo/releases/download/$CLASH_VERSION/mihomo-linux-amd64-compatible-$CLASH_VERSION.gz" 2>/dev/null; then
        echo "正在执行: 解压并配置二进制文件..."
        gunzip clash-meta.gz
        mv clash-meta mihomo
        chmod +x mihomo
        mv mihomo clash-meta
        INSTALL_SUCCESS=true
        echo "✓ 完成: 二进制文件安装 (兼容版本)"
        
    elif wget -O clash-meta.gz "https://github.com/MetaCubeX/mihomo/releases/download/$CLASH_VERSION/mihomo-linux-amd64-$CLASH_VERSION.gz" 2>/dev/null; then
        echo "正在执行: 解压并配置二进制文件..."
        gunzip clash-meta.gz
        mv clash-meta mihomo
        chmod +x mihomo
        mv mihomo clash-meta
        INSTALL_SUCCESS=true
        echo "✓ 完成: 二进制文件安装 (标准版本)"
    fi
fi

# 检查安装结果
if [ "$INSTALL_SUCCESS" = false ]; then
    echo "❌ 错误: 所有安装方式均失败"
    echo "请检查网络连接或手动安装 mihomo"
    echo "手动安装方法："
    echo "1. 访问 https://github.com/MetaCubeX/mihomo/releases"
    echo "2. 下载适合你系统的版本"
    echo "3. 解压并将可执行文件移动到 /opt/clash-meta"
    exit 1
else
    # 验证安装
    if [ -x "/opt/clash-meta" ]; then
        VERSION=$(/opt/clash-meta -v 2>/dev/null || echo "未知版本")
        echo "✓ 验证: mihomo 安装成功，版本: $VERSION"
    else
        echo "❌ 错误: 安装验证失败，可执行文件不存在"
        exit 1
    fi
fi

# 创建clash用户
echo "正在执行: 创建 clash 用户..."
useradd -r -s /bin/false clash || true
echo "✓ 完成: clash 用户创建"

# 创建必要目录
echo "正在执行: 创建 Clash 相关目录..."
mkdir -p /etc/clash-meta
mkdir -p /var/log/clash-meta
mkdir -p /var/lib/clash-meta
chown -R clash:clash /etc/clash-meta /var/log/clash-meta /var/lib/clash-meta
echo "✓ 完成: 目录结构创建"

# 创建Clash配置文件
echo "正在执行: 生成 Clash 主配置文件..."
cat > /etc/clash-meta/config.yaml << EOF
port: 7890
allow-lan: true
bind-address: "*"
mode: rule
log-level: info
external-controller: 127.0.0.1:9090
external-ui: dashboard
secret: "$PASSWORD"

# HTTP代理配置
listeners:
  - name: http
    type: http
    port: 7890
    bind-address: "*"
  - name: https
    type: http
    port: 7891
    bind-address: "*"

# DNS配置
dns:
  enable: true
  ipv6: false
  listen: 0.0.0.0:5353
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  nameserver:
    - 223.5.5.5
    - 119.29.29.29
  fallback:
    - 8.8.8.8
    - 1.1.1.1

# 代理配置
proxies: []

proxy-groups:
  - name: "PROXY"
    type: select
    proxies:
      - DIRECT

rules:
  - MATCH,DIRECT
EOF
echo "✓ 完成: Clash 主配置文件生成"

# 创建订阅配置模板
echo "正在执行: 生成订阅配置模板..."
cat > /etc/clash-meta/subscription.yaml << EOF
# Clash订阅配置
# 服务器信息: $SERVER
# 密码: $PASSWORD

proxies:
  - name: "$SERVER-http"
    type: http
    server: $SERVER
    port: 7890
    username: user
    password: $PASSWORD

  - name: "$SERVER-https"
    type: http
    server: $SERVER
    port: 7891
    username: user
    password: $PASSWORD
    tls: true

proxy-groups:
  - name: "PROXY"
    type: select
    proxies:
      - "$SERVER-http"
      - "$SERVER-https"
      - DIRECT

rules:
  - DOMAIN-SUFFIX,google.com,PROXY
  - DOMAIN-SUFFIX,youtube.com,PROXY  
  - DOMAIN-SUFFIX,github.com,PROXY
  - DOMAIN-KEYWORD,google,PROXY
  - GEOIP,CN,DIRECT
  - MATCH,PROXY
EOF
echo "✓ 完成: 订阅配置模板生成"

# 创建Web订阅服务
echo "正在执行: 创建 Web 订阅服务目录..."
mkdir -p /var/www/clash-sub
echo "✓ 完成: Web 目录创建"

if [ "$IS_IP" = true ]; then
    PROTOCOL="http"
    PORT=":80"
else
    PROTOCOL="https"
    PORT=""
fi

echo "正在执行: 生成 Web 主页文件..."
cat > /var/www/clash-sub/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Clash订阅服务</title>
    <meta charset="utf-8">
</head>
<body>
    <h1>Clash订阅服务</h1>
    <p>订阅链接: <a href="$PROTOCOL://$SERVER$PORT/sub">$PROTOCOL://$SERVER$PORT/sub</a></p>
    <p>Clash面板: <a href="$PROTOCOL://$SERVER$PORT/ui">$PROTOCOL://$SERVER$PORT/ui</a></p>
</body>
</html>
EOF
echo "✓ 完成: Web 主页文件生成"

# 配置Web服务器
echo "正在执行: 配置 Web 服务器..."

if [ "$IS_IP" = true ]; then
    # 配置Nginx
    cat > /etc/nginx/sites-available/clash-sub << EOF
server {
    listen 80 default_server;
    server_name _;
    
    root /var/www/clash-sub;
    index index.html;
    
    # 主页
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    # 订阅链接
    location /sub {
        add_header Content-Type "text/plain; charset=utf-8";
        add_header Content-Disposition "attachment; filename=clash.yaml";
        alias /etc/clash-meta/subscription.yaml;
    }
    
    # Clash面板
    location /ui/ {
        proxy_pass http://127.0.0.1:9090/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
    
    # API代理
    location /api/ {
        proxy_pass http://127.0.0.1:9090/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF
    echo "✓ 完成: Nginx 配置文件生成"
    
    echo "正在执行: 启用 Nginx 配置..."
    ln -sf /etc/nginx/sites-available/clash-sub /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    echo "✓ 完成: Nginx 配置启用"
    
else
    # 配置Caddy
    cat > /etc/caddy/Caddyfile << EOF
$SERVER {
    # 主页
    handle / {
        root * /var/www/clash-sub
        file_server
    }
    
    # 订阅链接
    handle /sub {
        header Content-Type "text/plain; charset=utf-8"
        header Content-Disposition "attachment; filename=clash.yaml"
        root * /etc/clash-meta
        rewrite * /subscription.yaml
        file_server
    }
    
    # Clash面板
    handle /ui/* {
        reverse_proxy 127.0.0.1:9090
    }
    
    # API代理
    handle /api/* {
        reverse_proxy 127.0.0.1:9090
    }
}
EOF
    echo "✓ 完成: Caddy 配置文件生成"
fi

# 创建systemd服务文件
echo "正在执行: 创建 systemd 服务文件..."
cat > /etc/systemd/system/clash-meta.service << EOF
[Unit]
Description=Clash Meta Service
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=30
StartLimitBurst=3

[Service]
Type=simple
User=clash
Group=clash
ExecStart=/opt/clash-meta -d /etc/clash-meta
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=5
TimeoutStartSec=30
TimeoutStopSec=10

# 确保服务健康运行的额外配置
Environment=GOMAXPROCS=2
LimitNOFILE=1048576
LimitNPROC=1048576

# 安全配置
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/etc/clash-meta /var/log/clash-meta /var/lib/clash-meta

[Install]
WantedBy=multi-user.target
EOF
echo "✓ 完成: systemd 服务文件创建"

# 下载Clash Dashboard
echo "正在执行: 下载 Clash Dashboard..."
cd /var/lib/clash-meta
wget -O dashboard.zip https://github.com/Dreamacro/clash-dashboard/archive/refs/heads/gh-pages.zip
echo "✓ 完成: Dashboard 下载"

echo "正在执行: 解压并配置 Dashboard..."
unzip dashboard.zip
mv clash-dashboard-gh-pages dashboard
rm dashboard.zip
chown -R clash:clash dashboard
echo "✓ 完成: Dashboard 配置"

# 启动并配置所有服务为自动启动
echo "正在执行: 重新加载 systemd 配置..."
systemctl daemon-reload
echo "✓ 完成: systemd 配置重载"

echo "正在执行: 配置 Clash Meta 服务自动启动..."
systemctl enable clash-meta
systemctl start clash-meta
echo "✓ 完成: Clash Meta 服务启动并设置为开机自启"

if [ "$IS_IP" = false ]; then
    echo "正在执行: 配置 Caddy 服务自动启动..."
    systemctl enable caddy
    systemctl restart caddy
    echo "✓ 完成: Caddy 服务启动并设置为开机自启"
    
    # 确保 Nginx 不会自动启动 (避免端口冲突)
    echo "正在执行: 禁用 Nginx 自动启动..."
    systemctl disable nginx
    systemctl stop nginx
    echo "✓ 完成: Nginx 已禁用"
else
    echo "正在执行: 配置 Nginx 服务自动启动..."
    systemctl enable nginx
    systemctl restart nginx
    echo "✓ 完成: Nginx 服务启动并设置为开机自启"
fi

# 额外的服务健康检查和自启动确认
echo "正在执行: 验证服务自动启动配置..."

# 检查 Clash Meta 自启动状态
if systemctl is-enabled clash-meta >/dev/null 2>&1; then
    echo "✓ Clash Meta 已配置为开机自启"
else
    echo "⚠️ 警告: Clash Meta 自启动配置可能失败"
    systemctl enable clash-meta
fi

# 检查 Web 服务器自启动状态
if [ "$IS_IP" = false ]; then
    if systemctl is-enabled caddy >/dev/null 2>&1; then
        echo "✓ Caddy 已配置为开机自启"
    else
        echo "⚠️ 警告: Caddy 自启动配置可能失败"
        systemctl enable caddy
    fi
else
    if systemctl is-enabled nginx >/dev/null 2>&1; then
        echo "✓ Nginx 已配置为开机自启"
    else
        echo "⚠️ 警告: Nginx 自启动配置可能失败"
        systemctl enable nginx
    fi
fi

echo "✓ 完成: 所有服务自动启动配置验证"

# 创建服务监控脚本
echo "正在执行: 创建服务监控和自动恢复脚本..."
cat > /usr/local/bin/clash-monitor.sh << 'EOF'
#!/bin/bash

# Clash服务监控脚本
# 每5分钟检查一次服务状态，如果停止则自动重启

check_and_restart_service() {
    local service_name=$1
    local service_desc=$2
    
    if ! systemctl is-active --quiet $service_name; then
        echo "[$(date)] $service_desc 服务已停止，正在重启..."
        systemctl start $service_name
        
        if systemctl is-active --quiet $service_name; then
            echo "[$(date)] $service_desc 服务重启成功"
        else
            echo "[$(date)] $service_desc 服务重启失败"
        fi
    fi
}

# 检查 Clash Meta 服务
check_and_restart_service "clash-meta" "Clash Meta"

# 检查 Web 服务器
if systemctl is-enabled caddy >/dev/null 2>&1; then
    check_and_restart_service "caddy" "Caddy"
elif systemctl is-enabled nginx >/dev/null 2>&1; then
    check_and_restart_service "nginx" "Nginx"
fi
EOF

chmod +x /usr/local/bin/clash-monitor.sh
echo "✓ 完成: 服务监控脚本创建"

# 创建定时任务
echo "正在执行: 配置定时监控任务..."
cat > /etc/cron.d/clash-monitor << EOF
# Clash服务监控 - 每5分钟检查一次
*/5 * * * * root /usr/local/bin/clash-monitor.sh >> /var/log/clash-monitor.log 2>&1
EOF

echo "✓ 完成: 定时监控任务配置"

# 启用网络等待服务 (确保网络完全就绪后再启动服务)
echo "正在执行: 启用网络等待服务..."
systemctl enable systemd-networkd-wait-online.service 2>/dev/null || true
echo "✓ 完成: 网络等待服务配置"

# 配置防火墙 (Ubuntu 默认使用 UFW)
# 最终的服务自启动验证
echo "正在执行: 执行服务自启动完整性检查..."

# 创建自启动状态报告
AUTO_START_REPORT=""

# 检查所有服务的自启动状态
services_to_check=("clash-meta")
if [ "$IS_IP" = false ]; then
    services_to_check+=("caddy")
else
    services_to_check+=("nginx")
fi

echo "服务自启动状态检查:"
for service in "${services_to_check[@]}"; do
    if systemctl is-enabled $service >/dev/null 2>&1; then
        echo "✓ $service: 已启用自动启动"
        AUTO_START_REPORT="$AUTO_START_REPORT\n✓ $service: 开机自启已配置"
    else
        echo "❌ $service: 自动启动未正确配置"
        AUTO_START_REPORT="$AUTO_START_REPORT\n❌ $service: 开机自启配置失败"
        # 尝试重新启用
        systemctl enable $service
    fi
    
    if systemctl is-active --quiet $service; then
        echo "✓ $service: 当前正在运行"
        AUTO_START_REPORT="$AUTO_START_REPORT, 当前运行中"
    else
        echo "❌ $service: 当前未运行"
        AUTO_START_REPORT="$AUTO_START_REPORT, 当前未运行"
    fi
done

echo "✓ 完成: 服务自启动验证"

echo "正在执行: 配置 Ubuntu 防火墙规则..."
if command -v ufw >/dev/null; then
    echo "正在执行: 允许必要端口通过防火墙..."
    ufw --force enable
    ufw allow 22/tcp comment "SSH"
    ufw allow 80/tcp comment "HTTP"
    ufw allow 443/tcp comment "HTTPS" 
    ufw allow 7890/tcp comment "Clash HTTP Proxy"
    ufw allow 7891/tcp comment "Clash HTTPS Proxy"
    echo "✓ 完成: UFW 防火墙配置"
    
    echo "防火墙状态:"
    ufw status numbered
else
    echo "⚠️ 警告: 未检测到 ufw"
    echo "请手动配置防火墙开放以下端口:"
    echo "- 22 (SSH)"
    echo "- 80 (HTTP)" 
    echo "- 443 (HTTPS)"
    echo "- 7890 (Clash HTTP)"
    echo "- 7891 (Clash HTTPS)"
fi

# 等待服务启动
sleep 5

# 检查服务状态
echo "正在执行: 检查服务运行状态..."
if systemctl is-active --quiet clash-meta; then
    echo "✓ 验证完成: Clash Meta 服务运行正常"
else
    echo "✗ 验证失败: Clash Meta 服务启动失败"
fi

if [ "$IS_IP" = false ]; then
    if systemctl is-active --quiet caddy; then
        echo "✓ 验证完成: Caddy 服务运行正常"
    else
        echo "✗ 验证失败: Caddy 服务启动失败"
    fi
else
    if systemctl is-active --quiet nginx; then
        echo "✓ 验证完成: Nginx 服务运行正常"
    else
        echo "✗ 验证失败: Nginx 服务启动失败"
    fi
fi

# 获取系统信息
SERVER_IP=$(hostname -I | awk '{print $1}')
TOTAL_MEM=$(free -h | awk '/^Mem:/{print $2}')
AVAILABLE_MEM=$(free -h | awk '/^Mem:/{print $7}')
DISK_USAGE=$(df -h / | awk 'NR==2{printf "%s/%s (%s)", $3,$2,$5}')

# 显示配置信息
clear
echo -e "${GREEN}"
echo "████████████████████████████████████████████████████"
echo "█                                                  █"
echo "█          Clash服务器配置完成！                   █"
echo "█                                                  █"
echo "████████████████████████████████████████████████████"
echo -e "${NC}"
echo ""

echo -e "${YELLOW}==================== 系统信息 ====================${NC}"
echo -e "服务器IP地址: ${GREEN}$SERVER_IP${NC}"
echo -e "内存使用情况: ${GREEN}$AVAILABLE_MEM/$TOTAL_MEM 可用${NC}"
echo -e "磁盘使用情况: ${GREEN}$DISK_USAGE${NC}"
echo -e "系统时间: ${GREEN}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo ""

echo -e "${YELLOW}==================== 服务器配置 ====================${NC}"
echo -e "服务器地址: ${GREEN}$SERVER${NC}"
echo -e "管理密码: ${RED}$PASSWORD${NC} ${YELLOW}(请妥善保存!)${NC}"
echo -e "运行模式: ${GREEN}$([ "$IS_IP" = true ] && echo "IP模式 (HTTP)" || echo "域名模式 (HTTPS)")${NC}"
echo ""

echo -e "${YELLOW}==================== 访问地址 ====================${NC}"
echo -e "主页地址: ${GREEN}$PROTOCOL://$SERVER$PORT${NC}"
echo -e "订阅链接: ${GREEN}$PROTOCOL://$SERVER$PORT/sub${NC}"
echo -e "管理面板: ${GREEN}$PROTOCOL://$SERVER$PORT/ui${NC}"
echo -e "API接口: ${GREEN}$PROTOCOL://$SERVER$PORT/api${NC}"
echo ""

echo -e "${YELLOW}==================== 代理设置 ====================${NC}"
echo -e "HTTP代理: ${GREEN}$SERVER:7890${NC}"
echo -e "HTTPS代理: ${GREEN}$SERVER:7891${NC}"
echo -e "SOCKS5代理: ${GREEN}$SERVER:7890${NC}"
echo -e "DNS服务: ${GREEN}$SERVER:5353${NC}"
echo ""

echo -e "${YELLOW}==================== 🚀 客户端使用指南 ====================${NC}"
echo -e "${GREEN}📋 订阅链接:${NC}"
echo -e "   ${GREEN}$PROTOCOL://$SERVER$PORT/sub${NC}"
echo ""
echo -e "${GREEN}🔥 Clash 客户端配置 (推荐):${NC}"
echo -e "   1️⃣ 下载Clash客户端:"
echo -e "      • Windows: Clash for Windows"
echo -e "      • macOS: ClashX Pro 或 Clash for Windows"
echo -e "      • Android: Clash for Android"
echo -e "      • iOS: Shadowrocket 或 Quantumult X"
echo ""
echo -e "   2️⃣ 添加订阅配置:"
echo -e "      • 打开Clash客户端"
echo -e "      • 找到 '配置' 或 'Profiles' 选项"
echo -e "      • 选择 '从URL导入' 或 'Remote Config'"
echo -e "      • 粘贴订阅链接: ${GREEN}$PROTOCOL://$SERVER$PORT/sub${NC}"
echo -e "      • 点击 '下载' 或 '导入'"
echo -e "      • 选择新导入的配置文件"
echo ""
echo -e "   3️⃣ 启用代理:"
echo -e "      • 选择代理模式: '规则模式' 或 'Rule'"
echo -e "      • 在节点选择中选择服务器节点"
echo -e "      • 开启系统代理开关"
echo ""
echo -e "${GREEN}⚙️ 手动代理配置 (各平台通用):${NC}"
echo -e "   ${YELLOW}HTTP/HTTPS 代理:${NC} ${GREEN}$SERVER:7890${NC}"
echo -e "   ${YELLOW}SOCKS5 代理:${NC} ${GREEN}$SERVER:7890${NC}"
echo ""
echo -e "${GREEN}🖥️ 各平台手动代理设置:${NC}"
echo ""
echo -e "   ${YELLOW}📱 Windows 系统:${NC}"
echo -e "   • 设置 → 网络和Internet → 代理"
echo -e "   • 开启'使用代理服务器'"
echo -e "   • 地址: ${GREEN}$SERVER${NC}  端口: ${GREEN}7890${NC}"
echo ""
echo -e "   ${YELLOW}🍎 macOS 系统:${NC}"
echo -e "   • 系统偏好设置 → 网络 → 高级 → 代理"
echo -e "   • 勾选'网页代理(HTTP)'和'安全网页代理(HTTPS)'"
echo -e "   • 服务器: ${GREEN}$SERVER${NC}  端口: ${GREEN}7890${NC}"
echo ""
echo -e "   ${YELLOW}🐧 Linux 系统:${NC}"
echo -e "   • 终端设置环境变量:"
echo -e "     export http_proxy=http://$SERVER:7890"
echo -e "     export https_proxy=http://$SERVER:7890"
echo -e "   • 或在网络设置中配置HTTP代理"
echo ""
echo -e "   ${YELLOW}📱 Android 设备:${NC}"
echo -e "   • WiFi设置 → 长按当前WiFi → 修改网络"
echo -e "   • 高级选项 → 代理 → 手动"
echo -e "   • 主机名: ${GREEN}$SERVER${NC}  端口: ${GREEN}7890${NC}"
echo ""
echo -e "   ${YELLOW}📱 iOS 设备:${NC}"
echo -e "   • 设置 → WiFi → 当前网络 → 配置代理"
echo -e "   • 选择'手动'"
echo -e "   • 服务器: ${GREEN}$SERVER${NC}  端口: ${GREEN}7890${NC}"
echo ""
echo -e "${GREEN}🌐 浏览器代理插件 (便捷方式):${NC}"
echo -e "   • Chrome: SwitchyOmega"
echo -e "   • Firefox: FoxyProxy"
echo -e "   • 配置HTTP代理: ${GREEN}$SERVER:7890${NC}"
echo ""
echo -e "${GREEN}💡 使用建议:${NC}"
echo -e "   ✅ 推荐使用Clash客户端 (功能完整，规则自动切换)"
echo -e "   ⚡ 临时使用可配置系统代理"
echo -e "   🔄 定期更新订阅配置 (右键配置→更新)"
echo -e "   📊 可通过管理面板监控流量: ${GREEN}$PROTOCOL://$SERVER$PORT/ui${NC}"
echo ""

echo -e "${YELLOW}==================== 服务管理 ====================${NC}"
echo -e "查看服务状态:"
echo -e "  sudo systemctl status clash-meta"
echo -e "  sudo systemctl status $([ "$IS_IP" = true ] && echo "nginx" || echo "caddy")"
echo ""
echo -e "重启服务:"
echo -e "  sudo systemctl restart clash-meta"
echo -e "  sudo systemctl restart $([ "$IS_IP" = true ] && echo "nginx" || echo "caddy")"
echo ""
echo -e "查看实时日志:"
echo -e "  sudo journalctl -u clash-meta -f"
echo -e "  sudo journalctl -u $([ "$IS_IP" = true ] && echo "nginx" || echo "caddy") -f"
echo ""
echo -e "检查自启动状态:"
echo -e "  sudo systemctl is-enabled clash-meta"
echo -e "  sudo systemctl is-enabled $([ "$IS_IP" = true ] && echo "nginx" || echo "caddy")"
echo ""

echo -e "${YELLOW}==================== 开机自启动状态 ====================${NC}"
echo -e "${AUTO_START_REPORT}"
echo ""
echo -e "服务监控:"
echo -e "• 已配置自动监控脚本: ${GREEN}/usr/local/bin/clash-monitor.sh${NC}"
echo -e "• 监控日志位置: ${GREEN}/var/log/clash-monitor.log${NC}"
echo -e "• 检查频率: ${GREEN}每5分钟${NC}"
echo ""

echo -e "${YELLOW}==================== 配置文件位置 ====================${NC}"
echo -e "Clash配置文件: ${GREEN}/etc/clash-meta/config.yaml${NC}"
echo -e "订阅配置文件: ${GREEN}/etc/clash-meta/subscription.yaml${NC}"
echo -e "Web服务配置: ${GREEN}$([ "$IS_IP" = true ] && echo "/etc/nginx/sites-available/clash-sub" || echo "/etc/caddy/Caddyfile")${NC}"
echo -e "日志文件目录: ${GREEN}/var/log/clash-meta/${NC}"
echo ""

echo -e "${YELLOW}==================== 防火墙规则 ====================${NC}"
echo -e "已开放端口: ${GREEN}80, 443, 7890, 7891${NC}"
echo -e "查看防火墙状态: ${GREEN}sudo ufw status${NC}"
echo ""

echo -e "${YELLOW}==================== 测试连接 ====================${NC}"
echo -e "测试Web服务:"
echo -e "  curl -I $PROTOCOL://$SERVER$PORT"
echo ""
echo -e "测试代理连接:"
echo -e "  curl -x http://$SERVER:7890 -I http://google.com"
echo ""
echo -e "测试API接口:"
echo -e "  curl -H \"Authorization: Bearer $PASSWORD\" $PROTOCOL://$SERVER$PORT/api/version"
echo ""

echo -e "${YELLOW}==================== 重要信息 ====================${NC}"
echo -e "${RED}⚠️  管理密码 (请立即保存): ${GREEN}$PASSWORD${NC}"
echo -e "   这个密码用于:"
echo -e "   • 访问Clash管理面板"
echo -e "   • API接口认证"
echo -e "   • 配置修改"
echo ""

echo -e "${YELLOW}==================== 安全建议 ====================${NC}"
echo -e "${RED}重要提醒:${NC}"
echo -e "1. ${RED}立即保存管理密码: $PASSWORD${NC}"
echo -e "2. 建议定期更新系统和组件"
echo -e "3. 监控服务器资源使用情况"
echo -e "4. 定期检查日志文件"
if [ "$IS_IP" = false ]; then
echo -e "5. 确保域名 ${GREEN}$SERVER${NC} 已正确解析到此服务器"
fi
echo ""

echo -e "${YELLOW}==================== 🔧 故障排除指南 ====================${NC}"
echo -e "${GREEN}🚨 常见问题及解决方案:${NC}"
echo ""
echo -e "${YELLOW}❌ 问题1: 无法访问订阅链接或管理面板${NC}"
echo -e "   🔍 检查步骤:"
echo -e "   • 确认服务运行: sudo systemctl status clash-meta"
echo -e "   • 检查防火墙: sudo ufw status"
echo -e "   • 测试端口: telnet $SERVER 80 (或443)"
if [ "$IS_IP" = false ]; then
echo -e "   • 验证域名解析: nslookup $SERVER"
echo -e "   • 检查SSL证书: curl -I https://$SERVER"
fi
echo ""
echo -e "${YELLOW}❌ 问题2: Clash客户端连接失败${NC}"
echo -e "   🔍 检查步骤:"
echo -e "   • 确认代理端口开放: sudo netstat -tlnp | grep 7890"
echo -e "   • 测试代理连接: curl -x http://$SERVER:7890 http://www.google.com"
echo -e "   • 检查订阅配置是否更新"
echo ""
echo -e "${YELLOW}❌ 问题3: 订阅链接下载失败${NC}"
echo -e "   🔍 检查步骤:"
echo -e "   • 检查Web服务: sudo systemctl status $([ "$IS_IP" = true ] && echo "nginx" || echo "caddy")"
echo -e "   • 测试订阅链接: curl $PROTOCOL://$SERVER$PORT/sub"
echo -e "   • 重启Web服务: sudo systemctl restart $([ "$IS_IP" = true ] && echo "nginx" || echo "caddy")"
echo ""
echo -e "${YELLOW}❌ 问题4: 手动代理无法上网${NC}"
echo -e "   🔍 检查步骤:"
echo -e "   • 确认代理地址: ${GREEN}$SERVER:7890${NC}"
echo -e "   • 检查代理协议: 使用HTTP代理 (不是SOCKS5)"
echo -e "   • 清除浏览器缓存和DNS缓存"
echo ""
if [ "$IS_IP" = false ]; then
echo -e "${YELLOW}❌ 问题5: SSL证书相关问题${NC}"
echo -e "   🔍 检查步骤:"
echo -e "   • 等待Caddy自动申请SSL证书 (可能需要几分钟)"
echo -e "   • 检查域名是否正确解析到服务器IP"
echo -e "   • 查看Caddy日志: sudo journalctl -u caddy -f"
echo -e "   • 重启Caddy服务: sudo systemctl restart caddy"
echo ""
fi
echo -e "${GREEN}🛠️ 通用排查命令:${NC}"
echo -e "   • 查看所有服务状态: sudo systemctl status clash-meta $([ "$IS_IP" = true ] && echo "nginx" || echo "caddy")"
echo -e "   • 查看端口占用: sudo netstat -tlnp | grep -E '80|443|7890|7891'"
echo -e "   • 查看防火墙状态: sudo ufw status numbered"
echo -e "   • 测试网络连通性: ping $SERVER"
echo ""
echo -e "${GREEN}📞 获取帮助:${NC}"
echo -e "   • 查看详细日志: sudo journalctl -u clash-meta -n 100"
echo -e "   • 监控服务状态: sudo journalctl -u clash-meta -f"
echo -e "   • 重启所有相关服务: sudo systemctl restart clash-meta $([ "$IS_IP" = true ] && echo "nginx" || echo "caddy")"
echo ""

if [ "$IS_IP" = true ]; then
    log_info "使用IP模式，通过HTTP协议访问"
    log_warn "建议使用域名模式以获得HTTPS加密"
else
    log_info "使用域名模式，SSL证书将由Caddy自动管理"
    log_warn "请确保域名 $SERVER 已正确解析到服务器IP: $SERVER_IP"
fi

echo ""
echo -e "${GREEN}🎉 ================= 配置完成！服务器已准备就绪 ================= 🎉${NC}"
echo ""
echo -e "${YELLOW}🚀 快速开始 (3步搞定):${NC}"
echo -e "   1️⃣ ${GREEN}复制订阅链接:${NC} $PROTOCOL://$SERVER$PORT/sub"
echo -e "   2️⃣ ${GREEN}下载Clash客户端${NC} (推荐Clash for Windows)"
echo -e "   3️⃣ ${GREEN}导入订阅配置${NC} 并开启代理"
echo ""
if [ "$IS_IP" = false ]; then
echo -e "${YELLOW}⚠️ 域名用户注意:${NC}"
echo -e "   • 请先将域名 ${GREEN}$SERVER${NC} 解析到服务器IP: ${GREEN}$SERVER_IP${NC}"
echo -e "   • 等待DNS生效后再使用 (通常5-30分钟)"
echo ""
fi
echo -e "${YELLOW}🔗 重要链接:${NC}"
echo -e "   📋 订阅地址: ${GREEN}$PROTOCOL://$SERVER$PORT/sub${NC}"
echo -e "   🎛️ 管理面板: ${GREEN}$PROTOCOL://$SERVER$PORT/ui${NC}"
echo -e "   🏠 服务主页: ${GREEN}$PROTOCOL://$SERVER$PORT${NC}"
echo -e "   🔑 管理密码: ${RED}$PASSWORD${NC}"
echo ""
echo -e "${GREEN}💡 温馨提示:${NC}"
echo -e "   • 脚本已配置开机自启动，服务器重启后自动运行"
echo -e "   • 每5分钟自动检查服务状态，异常时自动重启"
echo -e "   • 如有问题，请查看上方的故障排除指南"
echo ""
echo -e "${GREEN}感谢使用 Clash 服务器自动配置脚本！${NC}"
echo ""
#!/bin/bash

# Clash服务器自动配置脚本 - 支持IP订阅功能
# 使用方法: sudo bash setup_clash_server.sh <IP地址或域名> <密码>

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
if [ $# -eq 2 ]; then
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
    
    # 获取密码
    while true; do
        read -s -p "请输入管理密码: " PASSWORD
        echo ""
        if [ -n "$PASSWORD" ]; then
            read -s -p "请再次确认密码: " PASSWORD_CONFIRM
            echo ""
            if [ "$PASSWORD" = "$PASSWORD_CONFIRM" ]; then
                break
            else
                log_warn "两次输入的密码不一致，请重新输入"
            fi
        else
            log_warn "密码不能为空，请重新输入"
        fi
    done
    
    echo ""
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
    exit 1
fi

log_info "开始配置Clash服务器..."
log_info "服务器: $SERVER"
log_info "密码: $PASSWORD"

# 更新系统
log_info "更新系统包..."
apt update && apt upgrade -y

# 安装必要的软件包
log_info "安装必要软件包..."
apt install -y curl wget unzip jq nginx

# 配置Nginx或Caddy
if [ "$IS_IP" = true ]; then
    log_info "使用IP模式，配置Nginx..."
    # 使用nginx作HTTP服务器
else
    log_info "使用域名模式，安装Caddy..."
    apt install -y debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
    apt update
    apt install -y caddy
    
    # 停止nginx，使用Caddy
    systemctl stop nginx
    systemctl disable nginx
fi

# 下载Clash Meta
log_info "下载Clash Meta..."
cd /opt
CLASH_VERSION="v1.18.0"
wget -O clash-meta.tar.gz "https://github.com/MetaCubeX/mihomo/releases/download/$CLASH_VERSION/mihomo-linux-amd64-$CLASH_VERSION.tar.gz"
tar -xzf clash-meta.tar.gz
mv mihomo clash-meta
chmod +x clash-meta

# 创建clash用户
useradd -r -s /bin/false clash || true

# 创建必要目录
mkdir -p /etc/clash-meta
mkdir -p /var/log/clash-meta
mkdir -p /var/lib/clash-meta
chown -R clash:clash /etc/clash-meta /var/log/clash-meta /var/lib/clash-meta

# 创建Clash配置文件
log_info "创建Clash配置文件..."
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

# 创建订阅配置模板
log_info "创建订阅配置模板..."
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

# 创建Web订阅服务
log_info "创建Web订阅服务..."
mkdir -p /var/www/clash-sub

if [ "$IS_IP" = true ]; then
    PROTOCOL="http"
    PORT=":80"
else
    PROTOCOL="https"
    PORT=""
fi

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

# 配置Web服务器
log_info "配置Web服务器..."

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
    
    # 启用nginx配置
    ln -sf /etc/nginx/sites-available/clash-sub /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
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
fi

# 创建systemd服务文件
log_info "创建systemd服务..."
cat > /etc/systemd/system/clash-meta.service << EOF
[Unit]
Description=Clash Meta Service
After=network.target

[Service]
Type=simple
User=clash
Group=clash
ExecStart=/opt/clash-meta -d /etc/clash-meta
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# 下载Clash Dashboard
log_info "下载Clash Dashboard..."
cd /var/lib/clash-meta
wget -O dashboard.zip https://github.com/Dreamacro/clash-dashboard/archive/refs/heads/gh-pages.zip
unzip dashboard.zip
mv clash-dashboard-gh-pages dashboard
rm dashboard.zip
chown -R clash:clash dashboard

# 启动服务
log_info "启动服务..."
systemctl daemon-reload
systemctl enable clash-meta
systemctl start clash-meta
systemctl enable caddy
systemctl restart caddy

# 配置防火墙
log_info "配置防火墙..."
if command -v ufw >/dev/null; then
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 7890/tcp
    ufw allow 7891/tcp
    ufw --force enable
fi

# 等待服务启动
sleep 5

# 检查服务状态
log_info "检查服务状态..."
if systemctl is-active --quiet clash-meta; then
    log_info "✓ Clash Meta服务运行正常"
else
    log_error "✗ Clash Meta服务启动失败"
fi

if systemctl is-active --quiet caddy; then
    log_info "✓ Caddy服务运行正常"
else
    log_error "✗ Caddy服务启动失败"
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
echo -e "管理密码: ${RED}$PASSWORD${NC}"
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

echo -e "${YELLOW}==================== 客户端配置 ====================${NC}"
echo -e "1. 复制订阅链接到剪贴板:"
echo -e "   ${GREEN}$PROTOCOL://$SERVER$PORT/sub${NC}"
echo ""
echo -e "2. 在Clash客户端中添加订阅:"
echo -e "   - 打开Clash客户端"
echo -e "   - 点击'配置'或'Profiles'"
echo -e "   - 选择'从URL导入'或'Download from URL'"
echo -e "   - 粘贴上述订阅链接"
echo -e "   - 点击'下载'或'Import'"
echo ""
echo -e "3. 手动代理设置 (如果不使用Clash):"
echo -e "   HTTP/HTTPS代理: ${GREEN}$SERVER:7890${NC}"
echo -e "   SOCKS5代理: ${GREEN}$SERVER:7890${NC}"
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

echo -e "${YELLOW}==================== 安全建议 ====================${NC}"
echo -e "${RED}重要提醒:${NC}"
echo -e "1. 请妥善保管管理密码: ${RED}$PASSWORD${NC}"
echo -e "2. 建议定期更新系统和组件"
echo -e "3. 监控服务器资源使用情况"
echo -e "4. 定期检查日志文件"
if [ "$IS_IP" = false ]; then
echo -e "5. 确保域名 ${GREEN}$SERVER${NC} 已正确解析到此服务器"
fi
echo ""

echo -e "${YELLOW}==================== 故障排除 ====================${NC}"
echo -e "常见问题解决:"
echo -e "1. 无法访问管理面板 → 检查服务状态和防火墙"
echo -e "2. 代理连接失败 → 检查端口是否开放"
echo -e "3. 订阅链接无效 → 检查Web服务是否正常"
echo -e "4. SSL证书问题 → 等待Caddy自动申请或检查DNS解析"
echo ""

if [ "$IS_IP" = true ]; then
    log_info "使用IP模式，通过HTTP协议访问"
    log_warn "建议使用域名模式以获得HTTPS加密"
else
    log_info "使用域名模式，SSL证书将由Caddy自动管理"
    log_warn "请确保域名 $SERVER 已正确解析到服务器IP: $SERVER_IP"
fi

echo ""
echo -e "${GREEN}配置完成！服务器已准备就绪。${NC}"
echo -e "${YELLOW}如需帮助，请查看上述信息或联系管理员。${NC}"
echo ""
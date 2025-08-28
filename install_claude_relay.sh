#!/bin/bash

# Claude Relay Service Installation Script for Ubuntu
# This script installs Node.js, Redis, and sets up the claude-relay-service

set -e  # Exit on any error

echo "Starting Claude Relay Service installation..."
echo "============================================="

# Install Node.js 18.x
echo "📋 即将执行: curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -"
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
echo "✅ Node.js 仓库配置完成"

echo "📋 即将执行: sudo apt-get install -y nodejs"
sudo apt-get install -y nodejs
echo "✅ Node.js 安装完成"

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

# Clone the repository
echo "📋 即将执行: git clone https://github.com/Wei-Shaw//claude-relay-service.git"
git clone https://github.com/Wei-Shaw//claude-relay-service.git
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
echo "✅ .env 配置文件更新完成"

echo "📋 即将执行: cat .env"
echo "修改后的 .env 文件内容:"
echo "----------------------------------------"
cat .env
echo "----------------------------------------"
echo "✅ .env 文件内容显示完成"

# Install web dependencies and build
echo "📋 即将执行: npm run install:web"
npm run install:web
echo "✅ Web 依赖包安装完成"

echo "📋 即将执行: npm run build:web"
npm run build:web
echo "✅ Web 应用构建完成"

# Run setup
echo "📋 即将执行: npm run setup"
npm run setup
echo "✅ 项目设置完成"

# Start daemon service
echo "📋 即将执行: npm run service:start:daemon"
npm run service:start:daemon
echo "✅ 守护进程服务启动完成"

echo "============================================="
echo "🎉 Claude Relay Service 安装完成！"
echo "🚀 服务现在正在守护进程模式下运行"
#!/bin/bash

# Claude 清理脚本 - 彻底清除所有 Claude 相关文件和配置
# 版本: 1.0
# 作者: Claude Assistant
# 描述: 彻底清除系统中所有 Claude 相关文件、配置、缓存和环境变量

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}   Claude 完整清理脚本 v1.0    ${NC}"
echo -e "${BLUE}================================${NC}"
echo ""
echo -e "${YELLOW}⚠️  警告: 此脚本将自动完成 Claude 的清理、重装和配置${NC}"
echo "包括清理旧版本、重新安装最新版本、配置 API 信息等，操作不可逆！"
echo ""
echo "此脚本将自动执行以下操作："
echo "• 彻底清理现有 Claude 安装（配置、缓存、环境变量等）"
echo "• 卸载所有包管理器中的 Claude 相关包"
echo "• 自动备份并清理 Shell 配置文件"
echo "• 重新安装最新版本的 Claude SDK"
echo "• 配置 API 地址和 Token（需要用户输入）"
echo "• 自动写入环境变量配置"
echo ""
read -p "是否继续执行？(y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}操作已取消${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}开始清理 Claude 相关文件和配置...${NC}"

# 检查并卸载通过 npm/npx 安装的 claude-code
if command -v npx >/dev/null 2>&1; then
    echo "正在执行: 卸载 @anthropic/claude-code..."
    npm uninstall -g @anthropic/claude-code 2>/dev/null || true
    echo "✓ 完成: 卸载 @anthropic/claude-code"
fi

# 清除 Claude 配置目录
CLAUDE_CONFIG_DIR="$HOME/.config/claude"
if [ -d "$CLAUDE_CONFIG_DIR" ]; then
    echo "正在执行: 删除 Claude 配置目录: $CLAUDE_CONFIG_DIR"
    rm -rf "$CLAUDE_CONFIG_DIR"
    echo "✓ 完成: 删除 Claude 配置目录"
fi

# 清除 Claude 缓存目录
CLAUDE_CACHE_DIR="$HOME/.cache/claude"
if [ -d "$CLAUDE_CACHE_DIR" ]; then
    echo "正在执行: 删除 Claude 缓存目录: $CLAUDE_CACHE_DIR"
    rm -rf "$CLAUDE_CACHE_DIR"
    echo "✓ 完成: 删除 Claude 缓存目录"
fi

# 清除 Claude 数据目录
CLAUDE_DATA_DIR="$HOME/.local/share/claude"
if [ -d "$CLAUDE_DATA_DIR" ]; then
    echo "正在执行: 删除 Claude 数据目录: $CLAUDE_DATA_DIR"
    rm -rf "$CLAUDE_DATA_DIR"
    echo "✓ 完成: 删除 Claude 数据目录"
fi

# 清除可能的其他配置文件
CLAUDE_FILES=(
    "$HOME/.claude"
    "$HOME/.clauderc"
    "$HOME/.claude.json"
    "$HOME/.claude.yaml"
    "$HOME/.claude.yml"
    "$HOME/.anthropic"
    "$HOME/.anthropic.json"
    "$HOME/.anthropic.yaml"
    "$HOME/.anthropic.yml"
    "$HOME/Library/Application Support/Claude"
    "$HOME/Library/Preferences/claude"
    "$HOME/Library/Caches/Claude"
    "$HOME/.config/anthropic"
)

for file in "${CLAUDE_FILES[@]}"; do
    if [ -f "$file" ] || [ -d "$file" ]; then
        echo "正在执行: 删除 Claude 配置文件: $file"
        rm -rf "$file"
        echo "✓ 完成: 删除配置文件 $file"
    fi
done

# 清除环境变量（从常见的配置文件中）
SHELL_CONFIGS=(
    "$HOME/.bashrc"
    "$HOME/.zshrc"
    "$HOME/.bash_profile"
    "$HOME/.zsh_profile"
    "$HOME/.profile"
    "$HOME/.zshenv"
    "$HOME/.bash_login"
    "$HOME/.zlogin"
    "$HOME/.config/fish/config.fish"
)

echo "正在执行: 清除环境变量配置..."
for config in "${SHELL_CONFIGS[@]}"; do
    if [ -f "$config" ]; then
        echo "正在执行: 处理配置文件 $config"
        # 备份原文件
        cp "$config" "$config.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
        
        # 删除 Claude 相关的环境变量
        sed -i.tmp '/CLAUDE/d; /ANTHROPIC/d' "$config" 2>/dev/null || true
        rm -f "$config.tmp" 2>/dev/null || true
        
        echo "✓ 完成: 清理 $config 中的 Claude 相关环境变量"
    fi
done
echo "✓ 完成: 环境变量配置清理"

# 清除包管理器中的 Claude 相关包
echo "正在执行: 检查并清理包管理器..."

# npm 相关清理
if command -v npm >/dev/null 2>&1; then
    echo "正在执行: 清理 npm 缓存和全局包..."
    npm uninstall -g @anthropic/claude-code 2>/dev/null || true
    npm uninstall -g claude 2>/dev/null || true
    npm uninstall -g claude-cli 2>/dev/null || true
    npm cache clean --force 2>/dev/null || true
    echo "✓ 完成: npm 清理"
fi

# yarn 相关清理
if command -v yarn >/dev/null 2>&1; then
    echo "正在执行: 清理 yarn 缓存和全局包..."
    yarn global remove @anthropic/claude-code 2>/dev/null || true
    yarn global remove claude 2>/dev/null || true
    yarn cache clean 2>/dev/null || true
    echo "✓ 完成: yarn 清理"
fi

# pnpm 相关清理
if command -v pnpm >/dev/null 2>&1; then
    echo "正在执行: 清理 pnpm 缓存和全局包..."
    pnpm uninstall -g @anthropic/claude-code 2>/dev/null || true
    pnpm uninstall -g claude 2>/dev/null || true
    pnpm store prune 2>/dev/null || true
    echo "✓ 完成: pnpm 清理"
fi

# pip 相关清理（如果有 Python 版本的 Claude）
if command -v pip >/dev/null 2>&1; then
    echo "正在执行: 清理 pip 中的 Claude 相关包..."
    pip uninstall claude-cli -y 2>/dev/null || true
    pip uninstall anthropic -y 2>/dev/null || true
    echo "✓ 完成: pip 清理"
fi

# brew 相关清理（macOS）
if command -v brew >/dev/null 2>&1; then
    echo "正在执行: 清理 Homebrew 中的 Claude 相关包..."
    brew uninstall claude 2>/dev/null || true
    brew uninstall claude-cli 2>/dev/null || true
    brew cleanup 2>/dev/null || true
    echo "✓ 完成: Homebrew 清理"
fi

# 清除可能的临时文件和日志
echo "正在执行: 清理临时文件和日志..."
# 优化版本：限制搜索深度和范围，避免全盘扫描
find /tmp -maxdepth 2 -name "*claude*" -type f -delete 2>/dev/null || true
find /tmp -maxdepth 2 -name "*anthropic*" -type f -delete 2>/dev/null || true
# 只在常见的日志目录中搜索，避免扫描整个家目录
find "$HOME" -maxdepth 1 -name "*.log" \( -name "*claude*" -o -name "*anthropic*" \) -delete 2>/dev/null || true
if [ -d "$HOME/Library/Logs" ]; then
    find "$HOME/Library/Logs" -maxdepth 2 -name "*claude*" -delete 2>/dev/null || true
    find "$HOME/Library/Logs" -maxdepth 2 -name "*anthropic*" -delete 2>/dev/null || true
fi
if [ -d "$HOME/.local/share" ]; then
    find "$HOME/.local/share" -maxdepth 2 -name "*claude*.log" -delete 2>/dev/null || true
    find "$HOME/.local/share" -maxdepth 2 -name "*anthropic*.log" -delete 2>/dev/null || true
fi

# 清除可能的 Docker 容器和镜像
if command -v docker >/dev/null 2>&1; then
    echo "正在执行: 清理 Docker 中的 Claude 相关容器和镜像..."
    docker ps -a --format "table {{.Names}}" | grep -i claude | xargs -r docker rm -f 2>/dev/null || true
    docker images --format "table {{.Repository}}:{{.Tag}}" | grep -i claude | xargs -r docker rmi -f 2>/dev/null || true
    docker images --format "table {{.Repository}}:{{.Tag}}" | grep -i anthropic | xargs -r docker rmi -f 2>/dev/null || true
fi

echo "✓ 完成: 临时文件和日志清理"

# 清除系统级安装（需要管理员权限）
if [ "$EUID" -eq 0 ]; then
    echo "正在执行: 以管理员权限运行，清理系统级文件..."
    rm -rf /usr/local/bin/claude* 2>/dev/null || true
    rm -rf /usr/local/lib/node_modules/@anthropic 2>/dev/null || true
    rm -rf /usr/local/lib/node_modules/claude* 2>/dev/null || true
    rm -rf /opt/claude* 2>/dev/null || true
    rm -rf /usr/bin/claude* 2>/dev/null || true
    rm -rf /usr/share/claude* 2>/dev/null || true
    echo "✓ 完成: 系统级文件清理"
fi

# 清除 PATH 中的 Claude 相关路径
echo "建议手动检查并清除 PATH 中的 Claude 相关路径"

# 验证清理结果
echo -e "${BLUE}正在执行: 验证清理结果...${NC}"
remaining_files=()

# 检查主要目录是否还存在
for dir in "$HOME/.config/claude" "$HOME/.cache/claude" "$HOME/.local/share/claude" "$HOME/Library/Application Support/Claude"; do
    if [ -d "$dir" ]; then
        remaining_files+=("目录: $dir")
    fi
done

# 检查主要配置文件是否还存在
for file in "$HOME/.claude" "$HOME/.clauderc" "$HOME/.anthropic"; do
    if [ -f "$file" ]; then
        remaining_files+=("文件: $file")
    fi
done

# 检查是否还有全局包
if command -v npm >/dev/null 2>&1; then
    if npm list -g @anthropic/claude-code 2>/dev/null | grep -q "@anthropic/claude-code"; then
        remaining_files+=("npm包: @anthropic/claude-code")
    fi
fi

if [ ${#remaining_files[@]} -eq 0 ]; then
    echo -e "${GREEN}✓ 验证完成: 所有 Claude 相关文件已成功清理${NC}"
else
    echo -e "${YELLOW}⚠️  发现以下文件可能需要手动清理:${NC}"
    for item in "${remaining_files[@]}"; do
        echo -e "${YELLOW}  - $item${NC}"
    done
fi

echo ""
echo -e "${GREEN}✅ Claude 清理完成！${NC}"
echo ""
echo -e "${BLUE}已清理的内容包括：${NC}"
echo "- Claude 配置目录和数据目录"
echo "- Claude 缓存文件和日志文件"
echo "- macOS Library 相关目录"
echo "- 环境变量配置（已备份原文件）"
echo "- 包管理器全局包和缓存 (npm/yarn/pnpm/pip/brew)"
echo "- 系统级安装文件"
echo "- 临时文件和 Docker 资源"
echo "- Shell 配置文件中的相关变量"
echo ""
echo -e "${YELLOW}⚠️  注意事项：${NC}"
echo "1. 配置文件已自动备份（.backup.时间戳）"
echo "2. 请重新启动终端或运行 'source ~/.bashrc'（或相应的配置文件）"
echo "3. 如果使用了其他包管理器安装 Claude，可能需要手动清理"
echo "4. 如需恢复配置，可使用备份文件"
echo ""

# 自动开始重新安装 Claude SDK
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}    Claude SDK 重新安装        ${NC}"
echo -e "${BLUE}================================${NC}"
echo ""
echo -e "${GREEN}开始重新安装 Claude SDK...${NC}"

# 验证清理是否完成
echo "正在执行: 验证清理完成状态..."

# 检查关键目录是否已被清理
cleanup_failed=false
critical_dirs=(
    "$HOME/.config/claude"
    "$HOME/.cache/claude"
    "$HOME/.local/share/claude"
)

for dir in "${critical_dirs[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "${RED}❌ 错误: 关键目录未被清理: $dir${NC}"
        cleanup_failed=true
    fi
done

# 检查全局包是否已被卸载
if command -v npm >/dev/null 2>&1; then
    if npm list -g @anthropic/claude-code 2>/dev/null | grep -q "@anthropic/claude-code"; then
        echo -e "${RED}❌ 错误: npm 全局包 @anthropic/claude-code 仍然存在${NC}"
        cleanup_failed=true
    fi
fi

# 如果清理验证失败，终止安装
if [ "$cleanup_failed" = true ]; then
    echo ""
    echo -e "${RED}❌ 安装终止: 检测到清理过程未完全成功${NC}"
    echo -e "${YELLOW}请检查上述错误信息，手动清理剩余文件后重新运行脚本${NC}"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ 验证完成: 清理状态正常，可以开始安装${NC}"
echo ""

# 开始安装过程
echo "正在执行: 安装 Claude SDK..."

# 检查 Node.js 和 npm 是否可用
if ! command -v node >/dev/null 2>&1; then
    echo -e "${RED}❌ 错误: 未检测到 Node.js，请先安装 Node.js${NC}"
    echo "建议安装方式: https://nodejs.org/ 或使用 brew install node"
    exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
    echo -e "${RED}❌ 错误: 未检测到 npm，请先安装 npm${NC}"
    exit 1
fi

echo "✓ Node.js 版本: $(node --version)"
echo "✓ npm 版本: $(npm --version)"
echo ""

# 安装最新版本的 Claude SDK
echo "正在执行: 通过 npm 安装 @anthropic/claude-code..."
if npm install -g @anthropic-ai/claude-code; then
    echo -e "${GREEN}✓ 完成: Claude SDK 安装成功${NC}"

    # 验证安装
    if command -v claude >/dev/null 2>&1; then
        echo -e "${GREEN}✓ 验证: Claude 命令可用${NC}"
        echo "Claude 版本: $(claude --version 2>/dev/null || echo '无法获取版本信息')"
    else
        echo -e "${YELLOW}⚠️  警告: Claude 命令不可用，可能需要重启终端或重新加载 PATH${NC}"
    fi

    echo ""
    echo -e "${GREEN}✅ Claude SDK 重新安装完成！${NC}"
    echo ""

    # API 配置部分
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}      API 配置 (必填)         ${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
    echo "需要配置 Claude API 信息才能继续。"
    echo ""

    # 获取用户的 shell 配置文件（使用 $SHELL 环境变量检测默认 shell）
    if [[ "$SHELL" == *"zsh"* ]]; then
        SHELL_CONFIG="$HOME/.zshrc"
    elif [[ "$SHELL" == *"bash"* ]]; then
        # macOS 上优先使用 .bash_profile，Linux 上使用 .bashrc
        if [[ "$OSTYPE" == "darwin"* ]]; then
            SHELL_CONFIG="$HOME/.bash_profile"
        else
            SHELL_CONFIG="$HOME/.bashrc"
        fi
    else
        # 默认检查顺序（基于文件存在性）
        if [ -f "$HOME/.zshrc" ]; then
            SHELL_CONFIG="$HOME/.zshrc"
        elif [ -f "$HOME/.bash_profile" ]; then
            SHELL_CONFIG="$HOME/.bash_profile"
        elif [ -f "$HOME/.bashrc" ]; then
            SHELL_CONFIG="$HOME/.bashrc"
        else
            # 如果都不存在，在 macOS 上默认创建 .zshrc
            if [[ "$OSTYPE" == "darwin"* ]]; then
                SHELL_CONFIG="$HOME/.zshrc"
            else
                SHELL_CONFIG="$HOME/.bashrc"
            fi
        fi
    fi

    echo "检测到的默认 Shell: $SHELL"
    echo "将配置写入: $SHELL_CONFIG"
    echo ""

    # 输入 API URL（必填）
    api_url=""
    while [ -z "$api_url" ]; do
        echo -n "请输入 Claude API 地址 (必填): "
        read api_url
        if [ -z "$api_url" ]; then
            echo -e "${RED}❌ 错误: API 地址不能为空，请重新输入${NC}"
        fi
    done

    # 输入 API Token（必填）
    api_token=""
    while [ -z "$api_token" ]; do
        echo -n "请输入您的 API Token (必填): "
        read api_token
        if [ -z "$api_token" ]; then
            echo -e "${RED}❌ 错误: API Token 不能为空，请重新输入${NC}"
        fi
    done

    # 写入配置文件
    echo ""
    echo "正在执行: 配置 API 信息到 $SHELL_CONFIG..."

    # 备份配置文件
    cp "$SHELL_CONFIG" "$SHELL_CONFIG.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true

    # 添加配置注释
    echo "" >> "$SHELL_CONFIG"
    echo "# Claude API 配置 - 由 clean_claude.sh 添加 $(date)" >> "$SHELL_CONFIG"

    # 添加 API URL
    echo "export ANTHROPIC_BASE_URL=\"$api_url\"" >> "$SHELL_CONFIG"
    echo -e "${GREEN}✓ 已添加 API 地址配置${NC}"

    # 添加 API Token
    echo "export ANTHROPIC_AUTH_TOKEN=\"$api_token\"" >> "$SHELL_CONFIG"
    echo -e "${GREEN}✓ 已添加 API Token 配置${NC}"

    echo "" >> "$SHELL_CONFIG"

    echo -e "${GREEN}✓ API 配置已写入 $SHELL_CONFIG${NC}"
    echo -e "${YELLOW}⚠️  请重启终端或运行以下命令使配置生效:${NC}"
    echo "source $SHELL_CONFIG"
    echo ""

    # 验证配置
    echo "配置验证："
    echo "API 地址: $api_url"
    echo "API Token: $(echo "$api_token" | sed 's/./*/g')"  # 隐藏 token 显示

    echo ""
    echo -e "${BLUE}后续步骤：${NC}"
    echo "1. 重启终端或运行: source $SHELL_CONFIG"
    echo "2. 运行 'claude --help' 验证安装"
    echo "3. 运行 'claude' 开始使用"
    echo ""

else
    echo -e "${RED}❌ 错误: Claude SDK 安装失败${NC}"
    echo "请检查网络连接和 npm 配置，或尝试手动安装:"
    echo "npm install -g @anthropic/claude-code"
    exit 1
fi

echo ""
echo -e "${GREEN}感谢使用 Claude 清理脚本！${NC}"
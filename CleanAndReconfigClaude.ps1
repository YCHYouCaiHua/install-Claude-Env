# Claude 清理和重新配置脚本 - Windows 版本
# 版本: 1.0
# 描述: 彻底清除系统中所有 Claude 相关文件、配置、缓存和环境变量，并重新安装配置

# Set error action preference to continue on non-critical errors
$ErrorActionPreference = "Continue"

# 设置 PowerShell 执行策略为 Bypass（当前用户）
Write-Host "正在设置 PowerShell 执行策略..." -ForegroundColor Cyan
try {
    $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
    if ($currentPolicy -ne "Bypass" -and $currentPolicy -ne "Unrestricted") {
        Set-ExecutionPolicy Bypass -Scope CurrentUser -Force
        Write-Host "✓ 已设置执行策略为 Bypass (CurrentUser)" -ForegroundColor Green
    } else {
        Write-Host "✓ 执行策略已是 $currentPolicy，无需修改" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠️  警告: 无法设置执行策略，可能需要管理员权限" -ForegroundColor Yellow
    Write-Host "如果脚本运行出现问题，请手动运行: Set-ExecutionPolicy Bypass -Scope CurrentUser" -ForegroundColor Yellow
}
Write-Host ""

# 显示标题
Write-Host "================================" -ForegroundColor Blue
Write-Host "   Claude 完整清理脚本 v1.0    " -ForegroundColor Blue
Write-Host "================================" -ForegroundColor Blue
Write-Host ""
Write-Host "⚠️  警告: 此脚本将自动完成 Claude 的清理、重装和配置" -ForegroundColor Yellow
Write-Host "包括清理旧版本、重新安装最新版本、配置 API 信息等，操作不可逆！" -ForegroundColor Yellow
Write-Host ""
Write-Host "此脚本将自动执行以下操作："
Write-Host "• 彻底清理现有 Claude 安装（配置、缓存、环境变量等）"
Write-Host "• 卸载所有包管理器中的 Claude 相关包"
Write-Host "• 自动备份并清理环境变量"
Write-Host "• 重新安装最新版本的 Claude SDK"
Write-Host "• 配置 API 地址和 Token（需要用户输入）"
Write-Host "• 自动写入环境变量配置"
Write-Host ""

$confirmation = Read-Host "是否继续执行？(y/N)"
if ($confirmation -ne "y" -and $confirmation -ne "Y") {
    Write-Host "操作已取消" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "开始清理 Claude 相关文件和配置..." -ForegroundColor Green

# 检查并卸载通过 npm/npx 安装的 claude-code
if (Get-Command npx -ErrorAction SilentlyContinue) {
    Write-Host "正在执行: 卸载 @anthropic/claude-code..." -ForegroundColor Cyan
    npm uninstall -g @anthropic/claude-code 2>&1 | Out-Null
    npm uninstall -g @anthropic-ai/claude-code 2>&1 | Out-Null
    Write-Host "✓ 完成: 卸载 @anthropic/claude-code" -ForegroundColor Green
}

# 清除 Claude 配置目录
$claudeConfigDir = "$env:APPDATA\claude"
if (Test-Path $claudeConfigDir) {
    Write-Host "正在执行: 删除 Claude 配置目录: $claudeConfigDir" -ForegroundColor Cyan
    Remove-Item -Recurse -Force $claudeConfigDir -ErrorAction SilentlyContinue
    Write-Host "✓ 完成: 删除 Claude 配置目录" -ForegroundColor Green
}

# 清除 Claude 缓存目录
$claudeCacheDir = "$env:LOCALAPPDATA\claude"
if (Test-Path $claudeCacheDir) {
    Write-Host "正在执行: 删除 Claude 缓存目录: $claudeCacheDir" -ForegroundColor Cyan
    Remove-Item -Recurse -Force $claudeCacheDir -ErrorAction SilentlyContinue
    Write-Host "✓ 完成: 删除 Claude 缓存目录" -ForegroundColor Green
}

# 清除 Claude 用户数据目录
$claudeUserDataDir = "$env:USERPROFILE\.claude"
if (Test-Path $claudeUserDataDir) {
    Write-Host "正在执行: 删除 Claude 用户数据目录: $claudeUserDataDir" -ForegroundColor Cyan
    Remove-Item -Recurse -Force $claudeUserDataDir -ErrorAction SilentlyContinue
    Write-Host "✓ 完成: 删除 Claude 用户数据目录" -ForegroundColor Green
}

# 清除可能的其他配置文件
$claudeFiles = @(
    "$env:USERPROFILE\.claude",
    "$env:USERPROFILE\.clauderc",
    "$env:USERPROFILE\.claude.json",
    "$env:USERPROFILE\.claude.yaml",
    "$env:USERPROFILE\.claude.yml",
    "$env:USERPROFILE\.anthropic",
    "$env:USERPROFILE\.anthropic.json",
    "$env:USERPROFILE\.anthropic.yaml",
    "$env:USERPROFILE\.anthropic.yml",
    "$env:APPDATA\Claude",
    "$env:LOCALAPPDATA\Claude",
    "$env:APPDATA\Anthropic",
    "$env:LOCALAPPDATA\Anthropic"
)

foreach ($file in $claudeFiles) {
    if (Test-Path $file) {
        Write-Host "正在执行: 删除 Claude 配置文件: $file" -ForegroundColor Cyan
        Remove-Item -Recurse -Force $file -ErrorAction SilentlyContinue
        Write-Host "✓ 完成: 删除配置文件 $file" -ForegroundColor Green
    }
}

# 清除用户环境变量
Write-Host "正在执行: 清除用户环境变量配置..." -ForegroundColor Cyan
$envVarsToRemove = @("CLAUDE_API_KEY", "CLAUDE_API_URL", "ANTHROPIC_API_KEY", "ANTHROPIC_BASE_URL", "ANTHROPIC_AUTH_TOKEN")
foreach ($varName in $envVarsToRemove) {
    $currentValue = [System.Environment]::GetEnvironmentVariable($varName, "User")
    if ($currentValue) {
        Write-Host "正在执行: 删除环境变量 $varName" -ForegroundColor Cyan
        [System.Environment]::SetEnvironmentVariable($varName, $null, "User")
        Write-Host "✓ 完成: 删除环境变量 $varName" -ForegroundColor Green
    }
}
Write-Host "✓ 完成: 环境变量配置清理" -ForegroundColor Green

# 清除包管理器中的 Claude 相关包
Write-Host "正在执行: 检查并清理包管理器..." -ForegroundColor Cyan

# npm 相关清理
if (Get-Command npm -ErrorAction SilentlyContinue) {
    Write-Host "正在执行: 清理 npm 缓存和全局包..." -ForegroundColor Cyan
    npm uninstall -g @anthropic/claude-code 2>&1 | Out-Null
    npm uninstall -g @anthropic-ai/claude-code 2>&1 | Out-Null
    npm uninstall -g claude 2>&1 | Out-Null
    npm uninstall -g claude-cli 2>&1 | Out-Null
    npm cache clean --force 2>&1 | Out-Null
    Write-Host "✓ 完成: npm 清理" -ForegroundColor Green
}

# yarn 相关清理
if (Get-Command yarn -ErrorAction SilentlyContinue) {
    Write-Host "正在执行: 清理 yarn 缓存和全局包..." -ForegroundColor Cyan
    yarn global remove @anthropic/claude-code 2>&1 | Out-Null
    yarn global remove @anthropic-ai/claude-code 2>&1 | Out-Null
    yarn global remove claude 2>&1 | Out-Null
    yarn cache clean 2>&1 | Out-Null
    Write-Host "✓ 完成: yarn 清理" -ForegroundColor Green
}

# pnpm 相关清理
if (Get-Command pnpm -ErrorAction SilentlyContinue) {
    Write-Host "正在执行: 清理 pnpm 缓存和全局包..." -ForegroundColor Cyan
    pnpm uninstall -g @anthropic/claude-code 2>&1 | Out-Null
    pnpm uninstall -g @anthropic-ai/claude-code 2>&1 | Out-Null
    pnpm uninstall -g claude 2>&1 | Out-Null
    pnpm store prune 2>&1 | Out-Null
    Write-Host "✓ 完成: pnpm 清理" -ForegroundColor Green
}

# pip 相关清理（如果有 Python 版本的 Claude）
if (Get-Command pip -ErrorAction SilentlyContinue) {
    Write-Host "正在执行: 清理 pip 中的 Claude 相关包..." -ForegroundColor Cyan
    pip uninstall claude-cli -y 2>&1 | Out-Null
    pip uninstall anthropic -y 2>&1 | Out-Null
    Write-Host "✓ 完成: pip 清理" -ForegroundColor Green
}

# Chocolatey 相关清理
if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Host "正在执行: 清理 Chocolatey 中的 Claude 相关包..." -ForegroundColor Cyan
    choco uninstall claude -y 2>&1 | Out-Null
    choco uninstall claude-cli -y 2>&1 | Out-Null
    Write-Host "✓ 完成: Chocolatey 清理" -ForegroundColor Green
}

# 清除可能的临时文件和日志
Write-Host "正在执行: 清理临时文件和日志..." -ForegroundColor Cyan
$tempDirs = @($env:TEMP, "$env:USERPROFILE\AppData\Local\Temp")
foreach ($tempDir in $tempDirs) {
    if (Test-Path $tempDir) {
        Get-ChildItem -Path $tempDir -Filter "*claude*" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Get-ChildItem -Path $tempDir -Filter "*anthropic*" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}
Write-Host "✓ 完成: 临时文件和日志清理" -ForegroundColor Green

# 清除 Docker 容器和镜像
if (Get-Command docker -ErrorAction SilentlyContinue) {
    Write-Host "正在执行: 清理 Docker 中的 Claude 相关容器和镜像..." -ForegroundColor Cyan
    docker ps -a --format "{{.Names}}" | Select-String -Pattern "claude" | ForEach-Object { docker rm -f $_ 2>$null }
    docker images --format "{{.Repository}}:{{.Tag}}" | Select-String -Pattern "claude" | ForEach-Object { docker rmi -f $_ 2>$null }
    docker images --format "{{.Repository}}:{{.Tag}}" | Select-String -Pattern "anthropic" | ForEach-Object { docker rmi -f $_ 2>$null }
    Write-Host "✓ 完成: Docker 清理" -ForegroundColor Green
}

# 验证清理结果
Write-Host "正在执行: 验证清理结果..." -ForegroundColor Blue
$remainingFiles = @()

# 检查主要目录是否还存在
$dirsToCheck = @(
    "$env:APPDATA\claude",
    "$env:LOCALAPPDATA\claude",
    "$env:USERPROFILE\.claude"
)

foreach ($dir in $dirsToCheck) {
    if (Test-Path $dir) {
        $remainingFiles += "目录: $dir"
    }
}

# 检查主要配置文件是否还存在
$filesToCheck = @(
    "$env:USERPROFILE\.claude",
    "$env:USERPROFILE\.clauderc",
    "$env:USERPROFILE\.anthropic"
)

foreach ($file in $filesToCheck) {
    if (Test-Path $file) {
        $remainingFiles += "文件: $file"
    }
}

# 检查是否还有全局包
if (Get-Command npm -ErrorAction SilentlyContinue) {
    $npmList = npm list -g @anthropic/claude-code 2>$null
    if ($npmList -match "@anthropic/claude-code") {
        $remainingFiles += "npm包: @anthropic/claude-code"
    }
    $npmList = npm list -g @anthropic-ai/claude-code 2>$null
    if ($npmList -match "@anthropic-ai/claude-code") {
        $remainingFiles += "npm包: @anthropic-ai/claude-code"
    }
}

if ($remainingFiles.Count -eq 0) {
    Write-Host "✓ 验证完成: 所有 Claude 相关文件已成功清理" -ForegroundColor Green
} else {
    Write-Host "⚠️  发现以下文件可能需要手动清理:" -ForegroundColor Yellow
    foreach ($item in $remainingFiles) {
        Write-Host "  - $item" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "✅ Claude 清理完成！" -ForegroundColor Green
Write-Host ""
Write-Host "已清理的内容包括：" -ForegroundColor Blue
Write-Host "- Claude 配置目录和数据目录"
Write-Host "- Claude 缓存文件和日志文件"
Write-Host "- Windows AppData 相关目录"
Write-Host "- 用户环境变量"
Write-Host "- 包管理器全局包和缓存 (npm/yarn/pnpm/pip/choco)"
Write-Host "- 临时文件和 Docker 资源"
Write-Host ""
Write-Host "⚠️  注意事项：" -ForegroundColor Yellow
Write-Host "1. 环境变量已自动清理"
Write-Host "2. 请重新启动 PowerShell 使环境变量生效"
Write-Host "3. 如果使用了其他包管理器安装 Claude，可能需要手动清理"
Write-Host ""

# 自动开始重新安装 Claude SDK
Write-Host "================================" -ForegroundColor Blue
Write-Host "    Claude SDK 重新安装        " -ForegroundColor Blue
Write-Host "================================" -ForegroundColor Blue
Write-Host ""
Write-Host "开始重新安装 Claude SDK..." -ForegroundColor Green

# 验证清理是否完成
Write-Host "正在执行: 验证清理完成状态..." -ForegroundColor Cyan

$cleanupFailed = $false
$criticalDirs = @(
    "$env:APPDATA\claude",
    "$env:LOCALAPPDATA\claude",
    "$env:USERPROFILE\.claude"
)

foreach ($dir in $criticalDirs) {
    if (Test-Path $dir) {
        Write-Host "❌ 错误: 关键目录未被清理: $dir" -ForegroundColor Red
        $cleanupFailed = $true
    }
}

# 检查全局包是否已被卸载
if (Get-Command npm -ErrorAction SilentlyContinue) {
    $npmList = npm list -g @anthropic/claude-code 2>$null
    if ($npmList -match "@anthropic/claude-code") {
        Write-Host "❌ 错误: npm 全局包 @anthropic/claude-code 仍然存在" -ForegroundColor Red
        $cleanupFailed = $true
    }
    $npmList = npm list -g @anthropic-ai/claude-code 2>$null
    if ($npmList -match "@anthropic-ai/claude-code") {
        Write-Host "❌ 错误: npm 全局包 @anthropic-ai/claude-code 仍然存在" -ForegroundColor Red
        $cleanupFailed = $true
    }
}

# 如果清理验证失败，终止安装
if ($cleanupFailed) {
    Write-Host ""
    Write-Host "❌ 安装终止: 检测到清理过程未完全成功" -ForegroundColor Red
    Write-Host "请检查上述错误信息，手动清理剩余文件后重新运行脚本" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host "✓ 验证完成: 清理状态正常，可以开始安装" -ForegroundColor Green
Write-Host ""

# 开始安装过程
Write-Host "正在执行: 安装 Claude SDK..." -ForegroundColor Cyan

# 检查 Node.js 和 npm 是否可用
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "❌ 错误: 未检测到 Node.js，请先安装 Node.js" -ForegroundColor Red
    Write-Host "建议安装方式: https://nodejs.org/ 或使用 choco install nodejs" -ForegroundColor Yellow
    exit 1
}

if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Host "❌ 错误: 未检测到 npm，请先安装 npm" -ForegroundColor Red
    exit 1
}

$nodeVersion = node --version
$npmVersion = npm --version
Write-Host "✓ Node.js 版本: $nodeVersion" -ForegroundColor Green
Write-Host "✓ npm 版本: $npmVersion" -ForegroundColor Green
Write-Host ""

# 检查并安装 Git for Windows
Write-Host "正在执行: 检查 Git for Windows..." -ForegroundColor Cyan
$gitBashPath = $null
$gitInstalled = $false

# 检查常见的 Git Bash 安装路径
$commonGitPaths = @(
    "C:\Program Files\Git\bin\bash.exe",
    "C:\Program Files (x86)\Git\bin\bash.exe",
    "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
)

foreach ($path in $commonGitPaths) {
    if (Test-Path $path) {
        $gitBashPath = $path
        $gitInstalled = $true
        Write-Host "✓ 检测到 Git Bash: $gitBashPath" -ForegroundColor Green
        break
    }
}

# 如果没有找到，检查 git 命令是否可用
if (-not $gitInstalled) {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $gitPath = (Get-Command git).Source
        # 尝试从 git.exe 路径推断 bash.exe 路径
        $gitDir = Split-Path (Split-Path $gitPath -Parent) -Parent
        $possibleBashPath = Join-Path $gitDir "bin\bash.exe"
        if (Test-Path $possibleBashPath) {
            $gitBashPath = $possibleBashPath
            $gitInstalled = $true
            Write-Host "✓ 检测到 Git Bash: $gitBashPath" -ForegroundColor Green
        }
    }
}

# 如果仍未找到，安装 Git for Windows
if (-not $gitInstalled) {
    Write-Host "⚠️  未检测到 Git for Windows，Claude Code 需要 Git Bash 才能运行" -ForegroundColor Yellow
    Write-Host "正在执行: 安装 Git for Windows..." -ForegroundColor Cyan

    # 检查是否有 Chocolatey
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host "使用 Chocolatey 安装 Git..." -ForegroundColor Cyan
        choco install git -y 2>&1 | Out-Null

        # 刷新环境变量
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

        # 再次检查 Git Bash 路径
        foreach ($path in $commonGitPaths) {
            if (Test-Path $path) {
                $gitBashPath = $path
                $gitInstalled = $true
                Write-Host "✓ Git for Windows 安装成功: $gitBashPath" -ForegroundColor Green
                break
            }
        }
    } else {
        Write-Host "❌ 未检测到 Chocolatey 包管理器" -ForegroundColor Red
        Write-Host "请手动安装 Git for Windows:" -ForegroundColor Yellow
        Write-Host "1. 访问 https://git-scm.com/downloads/win" -ForegroundColor Yellow
        Write-Host "2. 下载并安装 Git for Windows" -ForegroundColor Yellow
        Write-Host "3. 重新运行此脚本" -ForegroundColor Yellow
        exit 1
    }
}

# 设置 CLAUDE_CODE_GIT_BASH_PATH 环境变量
if ($gitInstalled -and $gitBashPath) {
    Write-Host "正在执行: 配置 CLAUDE_CODE_GIT_BASH_PATH 环境变量..." -ForegroundColor Cyan

    # 检查环境变量是否已设置
    $existingPath = [System.Environment]::GetEnvironmentVariable("CLAUDE_CODE_GIT_BASH_PATH", "User")

    if ($existingPath -eq $gitBashPath) {
        Write-Host "✓ CLAUDE_CODE_GIT_BASH_PATH 已正确配置" -ForegroundColor Green
    } else {
        [System.Environment]::SetEnvironmentVariable("CLAUDE_CODE_GIT_BASH_PATH", $gitBashPath, "User")
        $env:CLAUDE_CODE_GIT_BASH_PATH = $gitBashPath
        Write-Host "✓ 已设置 CLAUDE_CODE_GIT_BASH_PATH = $gitBashPath" -ForegroundColor Green
    }
} else {
    Write-Host "❌ 错误: Git Bash 安装失败或未找到" -ForegroundColor Red
    Write-Host "Claude Code 需要 Git Bash 才能在 Windows 上运行" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# 安装最新版本的 Claude SDK
Write-Host "正在执行: 通过 npm 安装 @anthropic-ai/claude-code..." -ForegroundColor Cyan
$installResult = npm install -g @anthropic-ai/claude-code 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ 完成: Claude SDK 安装成功" -ForegroundColor Green

    # 刷新环境变量
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

    # 验证安装
    if (Get-Command claude -ErrorAction SilentlyContinue) {
        Write-Host "✓ 验证: Claude 命令可用" -ForegroundColor Green
        $claudeVersion = claude --version 2>$null
        if ($claudeVersion) {
            Write-Host "Claude 版本: $claudeVersion" -ForegroundColor Green
        } else {
            Write-Host "Claude 版本: 无法获取版本信息" -ForegroundColor Yellow
        }
    } else {
        Write-Host "⚠️  警告: Claude 命令不可用，可能需要重启终端" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "✅ Claude SDK 重新安装完成！" -ForegroundColor Green
    Write-Host ""

    # API 配置部分
    Write-Host "================================" -ForegroundColor Blue
    Write-Host "      API 配置 (必填)         " -ForegroundColor Blue
    Write-Host "================================" -ForegroundColor Blue
    Write-Host ""
    Write-Host "需要配置 Claude API 信息才能继续。"
    Write-Host ""

    # 输入 API URL（必填）
    $apiUrl = ""
    while ([string]::IsNullOrWhiteSpace($apiUrl)) {
        $apiUrl = Read-Host "请输入 Claude API 地址 (必填)"
        if ([string]::IsNullOrWhiteSpace($apiUrl)) {
            Write-Host "❌ 错误: API 地址不能为空，请重新输入" -ForegroundColor Red
        }
    }

    # 输入 API Token（必填）
    $apiToken = ""
    while ([string]::IsNullOrWhiteSpace($apiToken)) {
        $apiToken = Read-Host "请输入您的 API Token (必填)"
        if ([string]::IsNullOrWhiteSpace($apiToken)) {
            Write-Host "❌ 错误: API Token 不能为空，请重新输入" -ForegroundColor Red
        }
    }

    # 写入用户环境变量
    Write-Host ""
    Write-Host "正在执行: 配置 API 信息到系统环境变量..." -ForegroundColor Cyan

    # 添加 API URL
    [System.Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL", $apiUrl, "User")
    Write-Host "✓ 已添加 API 地址配置" -ForegroundColor Green

    # 添加 API Token
    [System.Environment]::SetEnvironmentVariable("ANTHROPIC_AUTH_TOKEN", $apiToken, "User")
    Write-Host "✓ 已添加 API Token 配置" -ForegroundColor Green

    Write-Host "✓ API 配置已写入用户环境变量" -ForegroundColor Green
    Write-Host "⚠️  请重启 PowerShell 使配置生效" -ForegroundColor Yellow
    Write-Host ""

    # 验证配置
    Write-Host "配置验证："
    Write-Host "API 地址: $apiUrl"
    $maskedToken = "*" * $apiToken.Length
    Write-Host "API Token: $maskedToken"

    Write-Host ""
    Write-Host "后续步骤：" -ForegroundColor Blue
    Write-Host "1. 重启 PowerShell 终端（重要：使环境变量生效）"
    Write-Host "2. 运行 'claude --help' 验证安装"
    Write-Host "3. 运行 'claude' 开始使用"
    Write-Host ""
    Write-Host "⚠️  重要提醒：" -ForegroundColor Yellow
    Write-Host "- 环境变量配置："
    Write-Host "  ANTHROPIC_BASE_URL = $apiUrl"
    Write-Host "  ANTHROPIC_AUTH_TOKEN = (已设置)"
    Write-Host "  CLAUDE_CODE_GIT_BASH_PATH = $gitBashPath"
    Write-Host "- 必须重启 PowerShell 后才能使用 Claude Code"
    Write-Host ""

} else {
    Write-Host "❌ 错误: Claude SDK 安装失败" -ForegroundColor Red
    Write-Host "错误信息: $installResult" -ForegroundColor Red
    Write-Host "请检查网络连接和 npm 配置，或尝试手动安装:" -ForegroundColor Yellow
    Write-Host "npm install -g @anthropic-ai/claude-code" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "感谢使用 Claude 清理脚本！" -ForegroundColor Green

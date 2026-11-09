#!/bin/bash
# Tailscale 安装脚本
# 适用于 Ubuntu/Debian 系统

set -e

echo "=========================================="
echo "Tailscale 安装脚本"
echo "=========================================="

# 检查是否为 root 或有 sudo 权限
if [ "$EUID" != "0" ]; then
    echo "请使用 sudo 运行此脚本"
    echo "用法: sudo bash install.sh"
    exit 1
fi

# 检查系统类型
if ! command -v apt &> /dev/null; then
    echo "错误: 此脚本仅支持 Debian/Ubuntu 系统"
    exit 1
fi

echo ""
echo ">>> 检查现有安装..."
if command -v tailscale &> /dev/null; then
    VERSION=$(tailscale version | head -1)
    echo "Tailscale 已安装: $VERSION"
    read -p "是否重新安装? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "跳过安装"
    else
        apt remove -y tailscale || true
    fi
fi

echo ""
echo ">>> 安装 Tailscale..."

# 方法 1: 使用官方安装脚本
curl -fsSL https://tailscale.com/install.sh | sh

echo ""
echo ">>> 验证安装..."
tailscale version

echo ""
echo ">>> 创建环境文件..."
if [ ! -f /etc/default/tailscaled ]; then
    echo "PORT=0" > /etc/default/tailscaled
    echo "✓ 创建 /etc/default/tailscaled"
else
    echo "✓ /etc/default/tailscaled 已存在"
fi

echo ""
echo ">>> 重载 systemd..."
systemctl daemon-reload

echo ""
echo ">>> 启动 tailscaled 服务..."
systemctl start tailscaled
systemctl enable tailscaled

echo ""
echo ">>> 检查服务状态..."
if systemctl is-active --quiet tailscaled; then
    echo "✓ tailscaled 服务正在运行"
else
    echo "✗ tailscaled 服务未运行"
    echo "检查日志: journalctl -u tailscaled -n 20"
    exit 1
fi

echo ""
echo "=========================================="
echo "安装完成!"
echo "=========================================="
echo ""
echo "下一步:"
echo "1. 运行 'sudo tailscale up' 启动并认证"
echo "2. 在浏览器中打开认证链接"
echo "3. 登录你的 Tailscale 账号"
echo ""
echo "认证后，使用 'tailscale status' 查看你的 Tailscale IP"

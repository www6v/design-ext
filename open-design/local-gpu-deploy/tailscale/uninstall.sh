#!/bin/bash
# Tailscale 卸载脚本

set -e

echo "=========================================="
echo "Tailscale 卸载"
echo "=========================================="
echo ""
echo "警告: 这将完全移除 Tailscale"
read -p "确定要继续吗? (y/N) " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "取消卸载"
    exit 0
fi

# 停止服务
echo ""
echo ">>> 停止服务..."
sudo systemctl stop tailscaled 2>/dev/null || true
sudo tailscale down 2>/dev/null || true

# 禁用服务
echo ">>> 禁用服务..."
sudo systemctl disable tailscaled 2>/dev/null || true

# 卸载软件包
echo ">>> 卸载 Tailscale..."
sudo apt remove -y tailscale 2>/dev/null || true
sudo apt autoremove -y 2>/dev/null || true

# 删除配置文件
echo ">>> 删除配置文件..."
sudo rm -rf /etc/default/tailscaled 2>/dev/null || true
sudo rm -rf /var/lib/tailscale 2>/dev/null || true
sudo rm -rf /var/run/tailscale 2>/dev/null || true

echo ""
echo "=========================================="
echo "卸载完成"
echo "=========================================="

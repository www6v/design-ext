#!/bin/bash
# Tailscale 启动脚本
# 启动 Tailscale 并显示连接信息

set -e

echo "=========================================="
echo "Tailscale 启动"
echo "=========================================="

# 检查 tailscaled 是否运行
if ! systemctl is-active --quiet tailscaled; then
    echo ">>> 启动 tailscaled 服务..."

    # 检查环境文件
    if [ ! -f /etc/default/tailscaled ]; then
        echo ">>> 创建环境文件..."
        echo "PORT=0" | sudo tee /etc/default/tailscaled
        sudo systemctl daemon-reload
    fi

    sudo systemctl start tailscaled
    sleep 2
fi

# 检查 Tailscale 状态
STATUS=$(tailscale status 2>/dev/null || echo "")

if [ -z "$STATUS" ] || echo "$STATUS" | grep -q "not logged in"; then
    echo ""
    echo ">>> Tailscale 未登录，开始认证..."
    echo ""
    sudo tailscale up
else
    echo ""
    echo "✓ Tailscale 已连接"
    echo ""
    echo "当前状态:"
    tailscale status
    echo ""
    echo "=========================================="
    echo "Tailscale IP:"
    tailscale ip -4
    echo "=========================================="
fi

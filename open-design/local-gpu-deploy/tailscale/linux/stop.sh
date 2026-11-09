#!/bin/bash
# Tailscale 停止脚本

echo "=========================================="
echo "Tailscale 停止"
echo "=========================================="

# 断开 Tailscale 连接
if tailscale status &>/dev/null; then
    echo ">>> 断开 Tailscale 连接..."
    sudo tailscale down
    echo "✓ 已断开连接"
else
    echo "Tailscale 未连接"
fi

# 停止 tailscaled 服务
if systemctl is-active --quiet tailscaled; then
    echo ">>> 停止 tailscaled 服务..."
    sudo systemctl stop tailscaled
    echo "✓ 服务已停止"
else
    echo "tailscaled 服务未运行"
fi

echo ""
echo "=========================================="
echo "完成"
echo "=========================================="
echo ""
echo "重新启动: sudo bash start.sh"

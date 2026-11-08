#!/bin/bash
# Tailscale 状态检查脚本

echo "=========================================="
echo "Tailscale 状态"
echo "=========================================="

# 检查 tailscaled 服务
echo ""
echo ">>> tailscaled 服务:"
if systemctl is-active --quiet tailscaled; then
    echo "✓ 正在运行"
else
    echo "✗ 未运行"
fi

# 检查 Tailscale 连接
echo ""
echo ">>> Tailscale 连接:"
STATUS=$(tailscale status 2>/dev/null)
if [ -z "$STATUS" ]; then
    echo "✗ 未连接"
else
    echo "$STATUS"
fi

# 显示本机 IP
echo ""
echo ">>> 本机 Tailscale IP:"
IP=$(tailscale ip -4 2>/dev/null)
if [ -n "$IP" ]; then
    echo "$IP"
else
    echo "未分配 IP"
fi

# 检查 API 服务
echo ""
echo ">>> Diffusers API 服务:"
if curl -s http://localhost:7865/health &>/dev/null; then
    echo "✓ 正在运行 (localhost:7865)"

    # 从 Tailscale 网络测试
    if [ -n "$IP" ]; then
        if curl -s --max-time 5 "http://$IP:7865/health" &>/dev/null; then
            echo "✓ 可从 Tailscale 网络访问 ($IP:7865)"
        else
            echo "✗ 无法从 Tailscale 网络访问"
        fi
    fi
else
    echo "✗ 未运行"
fi

echo ""
echo "=========================================="
echo "其他设备访问地址:"
echo "=========================================="
if [ -n "$IP" ]; then
    echo "API: http://$IP:7865/v1"
    echo "Health: http://$IP:7865/health"
    echo "Docs: http://$IP:7865/docs"
else
    echo "Tailscale 未连接"
fi

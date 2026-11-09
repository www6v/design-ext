#!/bin/bash
# Tailscale 网络连接测试脚本

echo "=========================================="
echo "Tailscale 连接测试"
echo "=========================================="

# 获取本机 Tailscale IP
LOCAL_IP=$(tailscale ip -4 2>/dev/null)
if [ -z "$LOCAL_IP" ]; then
    echo "✗ Tailscale 未连接"
    exit 1
fi

echo "本机 Tailscale IP: $LOCAL_IP"
echo ""

# 显示所有连接的设备
echo ">>> 网络中的设备:"
tailscale status
echo ""

# 测试 API 服务
echo "=========================================="
echo "API 服务测试"
echo "=========================================="

API_PORT=7865

# 检查本地 API
echo ""
echo ">>> 本地测试 (localhost):"
if curl -s --max-time 5 "http://localhost:$API_PORT/health" | grep -q '"status":"ok"'; then
    echo "✓ API 服务正常"
    curl -s "http://localhost:$API_PORT/health" | python3 -m json.tool 2>/dev/null || true
else
    echo "✗ API 服务不可用"
fi

# 从 Tailscale IP 测试
echo ""
echo ">>> Tailscale 网络测试 ($LOCAL_IP):"
if curl -s --max-time 5 "http://$LOCAL_IP:$API_PORT/health" | grep -q '"status":"ok"'; then
    echo "✓ 可从 Tailscale 网络访问"
else
    echo "✗ 无法从 Tailscale 网络访问"
fi

# 测试图片生成
echo ""
echo "=========================================="
echo "图片生成测试"
echo "=========================================="

read -p "是否测试图片生成? (y/N) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo ">>> 发送生成请求..."
    echo "Prompt: 'a red apple'"
    echo ""

    RESPONSE=$(curl -s --max-time 300 -X POST "http://localhost:$API_PORT/v1/images/generations" \
        -H "Content-Type: application/json" \
        -d '{
            "prompt": "a red apple on a white background",
            "model": "flux-dev",
            "n": 1,
            "size": "512x512",
            "num_inference_steps": 10
        }')

    if echo "$RESPONSE" | python3 -c "
import sys
import json
import base64

try:
    data = json.load(sys.stdin)
    if 'data' in data and len(data['data']) > 0:
        img_data = data['data'][0].get('b64_json', '')
        if img_data:
            img_bytes = base64.b64decode(img_data)
            print(f'✓ 图片生成成功!')
            print(f'  大小: {len(img_bytes)} bytes')
            sys.exit(0)
    print('✗ 图片生成失败')
    sys.exit(1)
except Exception as e:
    print(f'✗ 错误: {e}')
    sys.exit(1)
" 2>/dev/null; then
        echo "✓ 端到端测试通过!"
    else
        echo "✗ 端到端测试失败"
    fi
fi

echo ""
echo "=========================================="
echo "测试完成"
echo "=========================================="
echo ""
echo "其他设备可以使用以下地址访问:"
echo "  API: http://$LOCAL_IP:$API_PORT/v1"
echo "  Health: http://$LOCAL_IP:$API_PORT/health"
echo "  Docs: http://$LOCAL_IP:$API_PORT/docs"

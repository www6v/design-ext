# OpenDesign 本地 GPU 生图部署方案

> RTX 3090 (24GB VRAM) + Fooocus/ComfyUI + Cloudflare Tunnel + OpenDesign Custom Image API

---

## 目录

1. [架构概览](#架构概览)
2. [3090 机器部署](#3090-机器部署)
3. [网络访问配置](#网络访问配置)
4. [OpenDesign 配置](#opendesign-配置)
5. [模型选择指南](#模型选择指南)
6. [故障排查](#故障排查)

---

## 架构概览

```
┌─────────────────────────────────────────────────────────────────┐
│                      OpenDesign Web UI                          │
│                 http://127.0.0.1:7456                           │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    OpenDesign Daemon                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Custom Image API Provider                               │  │
│  │  POST https://<tunnel>.trycloudflare.com/v1/images/...   │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼ (HTTPS via Cloudflare Tunnel)
┌─────────────────────────────────────────────────────────────────┐
│                    家用路由器 (NAT)                              │
│         公网 IP (动态) / 无公网 IP 均可                          │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                  RTX 3090 机器 (家中)                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Cloudflared (Tunnel Client)                              │  │
│  │  ↓                                                        │  │
│  │  Fooocus / ComfyUI (OpenAI Compatible API)                │  │
│  │  http://localhost:7865/v1/images/generations              │  │
│  │  ↓                                                        │  │
│  │  NVIDIA RTX 3090 (24GB VRAM)                              │  │
│  │  → FLUX.1-dev / SDXL / SD 3.5                            │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3090 机器部署

### 系统要求

- **GPU**: NVIDIA RTX 3090 (24GB VRAM)
- **OS**: Ubuntu 20.04/22.04/24.04 或 Windows 10/11
- **CUDA**: 11.8+ 或 12.x
- **Python**: 3.10+
- **磁盘**: 50GB+ (模型文件较大)

### 方案 A: Fooocus (推荐 - 最简单)

Fooocus 是开箱即用的 Stable Diffusion 前端，自带 OpenAI 兼容 API。

#### 1. 安装依赖

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y python3-pip python3-venv git

# 安装 NVIDIA 驱动 (如果未安装)
sudo apt install -y nvidia-driver-535  # 或更新版本

# 验证 GPU
nvidia-smi
```

#### 2. 克隆并安装 Fooocus

```bash
cd ~
git clone https://github.com/lllyasviel/Fooocus.git
cd Fooocus

# 创建虚拟环境
python3 -m venv venv
source venv/bin/activate

# 安装依赖
pip install -r requirements_versions.txt
```

#### 3. 下载模型 (首次运行自动下载)

```bash
# 首次运行会自动下载模型，约 10-20 分钟
# 也可以手动预下载：
python entry_with_update.py --download-model flux1-dev-fp8.safetensors
```

#### 4. 启动服务 (启用 OpenAI 兼容 API)

```bash
# 启动 Fooocus 并监听所有网络接口
python entry_with_update.py --listen --port 7865 --always-high-vram
```

**关键参数说明**：
- `--listen`: 监听 0.0.0.0，允许外部访问
- `--port 7865`: 使用端口 7865
- `--always-high-vram`: 强制使用全部 VRAM (3090 有 24GB，足够)

#### 5. 启用 OpenAI 兼容 API 模式

Fooocus 默认支持 OpenAI 兼容 API，端点为：
```
POST http://localhost:7865/v1/images/generations
```

**请求示例**：
```bash
curl -X POST http://localhost:7865/v1/images/generations \
  -H "Content-Type: application/json" \
  -d '{
    "model": "fooocus",
    "prompt": "a beautiful mountain landscape",
    "n": 1,
    "size": "1024x1024"
  }'
```

---

### 方案 B: ComfyUI + OpenAI API 插件

ComfyUI 更灵活，适合高级用户。

#### 1. 安装 ComfyUI

```bash
cd ~
git clone https://github.com/comfyanonymous/ComfyUI.git
cd ComfyUI

python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

#### 2. 安装 OpenAI 兼容 API 插件

```bash
cd custom_nodes
git clone https://github.com/putteruser/comfyui-openai-api.git
cd ..
```

#### 3. 下载模型

```bash
# 创建模型目录
mkdir -p models/checkpoints

# 下载 FLUX.1-dev (推荐)
# 从 https://huggingface.co/black-forest-labs/FLUX.1-dev 下载
# 或使用 SDXL:
wget -P models/checkpoints/ https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors
```

#### 4. 启动服务

```bash
python main.py --listen --port 8188 --highvram
```

#### 5. OpenAI API 端点

```
POST http://localhost:8188/v1/images/generations
```

---

### 方案 C: 纯 Python API 服务 (轻量级)

如果你只需要 API，不需要 Web UI：

```bash
# 安装 diffusers
pip install diffusers transformers accelerate torch

# 创建 API 服务
cat > ~/image-api.py << 'EOF'
from flask import Flask, request, jsonify
from diffusers import FluxPipeline
import torch
import base64
import io
from PIL import Image

app = Flask(__name__)

# 加载模型 (首次运行会下载)
pipe = FluxPipeline.from_pretrained(
    "black-forest-labs/FLUX.1-dev",
    torch_dtype=torch.float16
).to("cuda")

@app.route("/v1/images/generations", methods=["POST"])
def generate():
    data = request.json
    prompt = data.get("prompt", "")
    size = data.get("size", "1024x1024")
    width, height = map(int, size.split("x"))
    
    image = pipe(prompt, width=width, height=height).images[0]
    
    # 转换为 base64
    buffered = io.BytesIO()
    image.save(buffered, format="PNG")
    img_str = base64.b64encode(buffered.getvalue()).decode()
    
    return jsonify({
        "data": [{"b64_json": img_str}]
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=7865)
EOF

# 运行
python ~/image-api.py
```

---

## 网络访问配置

你的 3090 机器在家里路由器后面，需要从 OpenDesign 机器访问。以下是三种方案：

---

### 方案 A: Cloudflare Tunnel (推荐 - 免费、安全、无需公网IP)

#### 1. 在 3090 机器上安装 cloudflared

```bash
# Ubuntu/Debian
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb

# 验证安装
cloudflared --version
```

#### 2. 创建 Tunnel

```bash
# 登录 Cloudflare (需要 Cloudflare 账号，免费)
cloudflared tunnel login

# 创建 tunnel
cloudflared tunnel create opendesign-gpu

# 配置 tunnel
cat > ~/.cloudflared/config.yml << EOF
tunnel: <TUNNEL_ID>
credentials-file: /home/<USER>/.cloudflared/<TUNNEL_ID>.json

ingress:
  - hostname: gpu.yourdomain.com
    service: http://localhost:7865
  - service: http_status:404
EOF
```

**或者使用快速模式 (无需域名)**：

```bash
# 快速模式 - 会生成一个随机 URL
cloudflared tunnel --url http://localhost:7865
```

输出类似：
```
INF Registered tunnel connection
INF Connection registered conn_id=...
INF https://abc123-xyz.trycloudflare.com
```

记下这个 URL：`https://abc123-xyz.trycloudflare.com`

#### 3. 设置开机自启 (可选)

```bash
# 创建 systemd 服务
sudo cat > /etc/systemd/system/cloudflared.service << EOF
[Unit]
Description=Cloudflare Tunnel
After=network.target

[Service]
Type=simple
User=<YOUR_USER>
ExecStart=/usr/local/bin/cloudflared tunnel --url http://localhost:7865
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable cloudflared
sudo systemctl start cloudflared
```

---

### 方案 B: 端口转发 (需要路由器权限和公网IP)

#### 1. 获取公网 IP

```bash
curl ifconfig.me
# 或访问 https://whatismyipaddress.com
```

#### 2. 路由器设置端口转发

登录路由器管理界面 (通常是 `192.168.1.1` 或 `192.168.0.1`)：

```
转发规则:
外部端口: 7865
内部 IP: <3090机器的局域网IP, 如 192.168.1.100>
内部端口: 7865
协议: TCP
```

#### 3. 配置动态 DNS (如果公网IP是动态的)

```bash
# 使用 ddclient 或路由器自带的 DDNS 功能
sudo apt install ddclient
```

#### 4. 访问地址

```
http://<你的公网IP>:7865
```

⚠️ **注意**: 直接暴露端口到公网有安全风险，建议加密码或使用 HTTPS。

---

### 方案 C: Tailscale (P2P VPN - 最安全)

Tailscale 在两台机器之间建立加密的 P2P 连接，无需公网IP，无需端口转发。

#### 1. 两台机器都安装 Tailscale

**3090 机器**:
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
# 会输出一个 URL，在浏览器打开并登录
```

**OpenDesign 机器**:
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

#### 2. 获取 Tailscale IP

```bash
# 在 3090 机器上
tailscale ip -4
# 输出类似: 100.64.0.1
```

#### 3. 访问地址

```
http://100.64.0.1:7865
```

✅ **优点**: 
- 无需公网IP
- 无需端口转发
- 端到端加密
- 穿透 NAT

---

## OpenDesign 配置

### 1. 打开 Settings

访问 `http://127.0.0.1:7456/settings`

### 2. 选择 Custom Image API

在"媒体生成供应商"中找到 **Custom Image API**，点击配置。

### 3. 填写配置

| 字段 | 值 |
|------|-----|
| **API Key** | (可选，或随便填一个如 `local`) |
| **Base URL** | `https://abc123-xyz.trycloudflare.com/v1` (Cloudflare Tunnel) <br> 或 `http://100.64.0.1:7865/v1` (Tailscale) <br> 或 `http://<公网IP>:7865/v1` (端口转发) |
| **模型** | `fooocus` 或 `flux-dev` 或 `sdxl` (取决于你部署的模型) |

### 4. 测试连接

在 OpenDesign 中创建一个新项目，选择图像生成，观察是否成功。

---

## 模型选择指南

### RTX 3090 (24GB VRAM) 可运行的模型

| 模型 | 显存占用 | 生成速度 (1024x1024) | 质量 | 推荐场景 |
|------|----------|---------------------|------|----------|
| **FLUX.1-dev** | ~12GB | 10-20s | ⭐⭐⭐⭐⭐ | 通用、高质量 |
| **FLUX.1-schnell** | ~12GB | 3-8s | ⭐⭐⭐⭐ | 快速迭代 |
| **SDXL 1.0** | ~7GB | 5-10s | ⭐⭐⭐⭐ | 通用、生态丰富 |
| **SD 3.5 Medium** | ~10GB | 8-15s | ⭐⭐⭐⭐ | 文字渲染好 |
| **SD 1.5 + LCM** | ~4GB | 1-3s | ⭐⭐⭐ | 极速、草图 |
| **SD 1.5 + RealisticVision** | ~4GB | 5-8s | ⭐⭐⭐⭐ | 人像、写实 |

### 推荐配置

**最佳质量**:
- 模型: FLUX.1-dev (fp8 量化版，约 12GB)
- 采样步数: 20-30
- 分辨率: 1024x1024

**最佳速度**:
- 模型: FLUX.1-schnell 或 SD 1.5 + LCM
- 采样步数: 4-8
- 分辨率: 512x512 或 768x768

**最佳性价比**:
- 模型: SDXL 1.0
- 采样步数: 20-25
- 分辨率: 1024x1024
- 配合 LCM LoRA 可加速到 5-8s

---

## 故障排查

### 问题 1: OpenDesign 返回 404

**原因**: Base URL 路径不对

**解决**: 确保 Base URL 包含 `/v1`，完整格式为：
```
https://<tunnel>.trycloudflare.com/v1
```

### 问题 2: 连接超时

**原因**: Tunnel 未启动或端口未监听

**检查**:
```bash
# 在 3090 机器上
curl http://localhost:7865/v1/images/generations -X POST \
  -H "Content-Type: application/json" \
  -d '{"prompt":"test","model":"test"}'
```

### 问题 3: CUDA Out of Memory

**原因**: 显存不足

**解决**:
```bash
# Fooocus 启动参数
python entry_with_update.py --listen --port 7865 --lowvram

# 或使用更小的模型
# SD 1.5 只需 4GB
```

### 问题 4: 模型下载慢

**解决**: 使用国内镜像
```bash
# 设置 HuggingFace 镜像
export HF_ENDPOINT=https://hf-mirror.com
```

### 问题 5: Cloudflare Tunnel 断开

**解决**: 检查 systemd 服务状态
```bash
sudo systemctl status cloudflared
sudo journalctl -u cloudflared -f  # 查看实时日志
```

---

## 成本对比

| 方案 | 单次生图成本 | 质量 | 速度 |
|------|-------------|------|------|
| **本地 3090 (本方案)** | **¥0** (电费约 ¥0.01) | ⭐⭐⭐⭐⭐ | 10-20s |
| Fal.ai (flux-schnell) | ~¥0.02 | ⭐⭐⭐⭐ | 3-8s |
| Fal.ai (flux-pro) | ~¥0.15 | ⭐⭐⭐⭐⭐ | 60-180s |
| OpenAI (gpt-image-2) | ~¥0.35 | ⭐⭐⭐⭐ | 10-30s |
| Midjourney | ~¥1.0 | ⭐⭐⭐⭐⭐ | 60s |

**结论**: 本地 3090 生图成本几乎为零，质量可媲美 Midjourney，是最经济的方案。

---

## 下一步

1. **部署模型**: 选择 Fooocus 或 ComfyUI 方案，在 3090 机器上安装
2. **配置网络**: 使用 Cloudflare Tunnel 或 Tailscale 暴露服务
3. **配置 OpenDesign**: 在 Settings 中添加 Custom Image API
4. **测试生图**: 创建新项目，测试本地模型生图

---

## 参考资源

- [Fooocus GitHub](https://github.com/lllyasviel/Fooocus)
- [ComfyUI GitHub](https://github.com/comfyanonymous/ComfyUI)
- [Cloudflare Tunnel 文档](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- [Tailscale 文档](https://tailscale.com/kb/)
- [FLUX.1 模型](https://huggingface.co/black-forest-labs/FLUX.1-dev)
- [OpenDesign Custom Image API](https://platform.openai.com/docs/api-reference/images)

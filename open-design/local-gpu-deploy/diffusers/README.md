# Diffusers 文生图部署方案

> RTX 3090 + HuggingFace Diffusers + FastAPI + Tailscale P2P VPN + OpenDesign

---

## 目录

1. [架构概览](#架构概览)
2. [系统要求](#系统要求)
3. [部署步骤](#部署步骤)
4. [API 接口说明](#api-接口说明)
5. [OpenDesign 配置](#opendesign-配置)
6. [模型选择](#模型选择)
7. [Tailscale 配置](#tailscale-配置)
8. [运维管理](#运维管理)
9. [故障排查](#故障排查)

---

## 架构概览

```
┌─────────────────────────────────────────────────────────────────┐
│              OpenDesign Web UI (腾讯云)                          │
│              https://your-opendesign-domain.com                 │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Tailscale Client                                        │  │
│  │  IP: 100.64.0.1 (示例)                                   │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          │ Tailscale P2P VPN (端到端加密)
                          │ 直连，无需公网 IP
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│              RTX 3090 机器 (本地 GPU 服务器)                     │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Tailscale Client                                        │  │
│  │  IP: 100.64.0.2 (示例)                                   │  │
│  │  ↓                                                        │  │
│  │  FastAPI Server (port 7865)                               │  │
│  │  ├── POST /v1/images/generations  (OpenAI 兼容)          │  │
│  │  ├── GET  /health                                         │  │
│  │  └── GET  /v1/models                                      │  │
│  │  ↓                                                        │  │
│  │  Diffusers Pipeline                                        │  │
│  │  ├── SDXL 1.0 (默认)                                        │  │
│  │  ├── FLUX.1-dev (fp8)                                     │  │
│  │  └── FLUX.1-schnell                                       │  │
│  │  ↓                                                        │  │
│  │  NVIDIA RTX 3090 (24GB VRAM)                              │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘

✅ 优势:
- 端到端加密，数据不经过第三方
- 无需公网 IP，无需端口转发
- P2P 直连，低延迟
- 两台机器都安装 Tailscale 即可
```

---

## 系统要求

| 项目 | 要求 | 当前状态 |
|------|------|---------|
| **GPU** | NVIDIA RTX 3090 (24GB VRAM) | ✅ 已满足 |
| **CUDA** | 11.8+ 或 12.x | ✅ CUDA 13.0 |
| **Python** | 3.10+ | ✅ Python 3.10.12 |
| **磁盘** | 50GB+ (模型文件较大) | ⚠️ 需检查 |
| **内存** | 16GB+ | ⚠️ 需检查 |

---

## 部署步骤

### 1. 创建项目目录结构

```bash
/home/wangwei/wei/workspacePy/design/design-ext/open-design/local-gpu-deploy/diffusers/
├── README.md                    # 本文档
├── requirements.txt             # Python 依赖
├── config.py                    # 配置文件
├── server.py                    # FastAPI 服务
├── models.py                    # 模型管理
├── schemas.py                   # Pydantic 数据模型
├── install.sh                   # 安装脚本
├── start.sh                     # 启动脚本
├── stop.sh                      # 停止脚本
├── logs/                        # 日志目录
│   └── server.log
└── outputs/                     # 生成的图片缓存
    └── ...
```

> **注意**: 网络方案使用 **Tailscale**，需要在本地 GPU 机器和腾讯云服务器上都安装 Tailscale

### 2. 安装依赖

```bash
cd /home/wangwei/wei/workspacePy/design/design-ext/open-design/local-gpu-deploy/diffusers

# 创建虚拟环境
python3 -m venv venv
source venv/bin/activate

# 安装 PyTorch (CUDA 12.x)
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# 安装其他依赖
pip install -r requirements.txt
```

### 3. 下载模型 (可选 - 首次运行自动下载)

```bash
# 设置 HuggingFace 镜像 (国内加速)
export HF_ENDPOINT=https://hf-mirror.com

# 预热缓存 - 下载 SDXL 模型
python -c "
from diffusers import StableDiffusionXLPipeline
import torch
pipe = StableDiffusionXLPipeline.from_pretrained(
    'stabilityai/stable-diffusion-xl-base-1.0',
    torch_dtype=torch.float16
).to('cuda')
print('Model loaded successfully!')
"
```

### 4. 启动服务

```bash
# 启动 API 服务
python server.py --host 0.0.0.0 --port 7865

# 或指定模型
python server.py --model sdxl --port 7865
```

### 5. 配置 Tailscale (两台机器都需要)

#### 5.1 在本地 GPU 机器上安装 Tailscale

```bash
# 安装 Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# 启动 Tailscale
sudo tailscale up

# 输出示例:
# To authenticate, visit: https://login.tailscale.com/xxx
# 在浏览器中打开链接并登录

# 查看 Tailscale IP
tailscale ip -4
# 输出: 100.64.0.2
```

#### 5.2 在腾讯云服务器上安装 Tailscale

```bash
# SSH 到腾讯云服务器
ssh user@your-tencent-server

# 安装 Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# 启动 Tailscale
sudo tailscale up

# 登录并获取 IP
tailscale ip -4
# 输出: 100.64.0.1
```

#### 5.3 验证连通性

```bash
# 在腾讯云服务器上测试
ping 100.64.0.2  # GPU 机器的 Tailscale IP

# 测试 API 连通性
curl http://100.64.0.2:7865/health
```

#### 5.4 (可选) 配置 Tailscale ACL 限制访问

```bash
# 在 Tailscale Admin Console (https://login.tailscale.com/admin/acls)
# 添加 ACL 规则，只允许腾讯云服务器访问 GPU 机器
{
  "acls": [
    {
      "action": "accept",
      "src": ["tencent-server"],
      "dst": ["gpu-machine:7865"]
    }
  ]
}
```

### 6. 配置 systemd 服务 (可选 - 开机自启)

```bash
sudo tee /etc/systemd/system/diffusers-api.service > /dev/null << EOF
[Unit]
Description=Diffusers Image Generation API
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$(pwd)
Environment="PATH=$(pwd)/venv/bin"
Environment="HF_ENDPOINT=https://hf-mirror.com"
ExecStart=$(pwd)/venv/bin/python server.py --host 0.0.0.0 --port 7865
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable diffusers-api
sudo systemctl start diffusers-api
```

---

## API 接口说明

### OpenAI 兼容接口

#### 生成图片

```bash
POST /v1/images/generations
```

**请求参数**:

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `prompt` | string | ✅ | 文本描述 |
| `model` | string | ❌ | 模型名称 (默认: sdxl) |
| `n` | integer | ❌ | 生成数量 (默认: 1) |
| `size` | string | ❌ | 图片尺寸 (默认: 1024x1024) |
| `response_format` | string | ❌ | 返回格式: `b64_json` 或 `url` (默认: b64_json) |
| `num_inference_steps` | integer | ❌ | 推理步数 (默认: 20) |
| `guidance_scale` | float | ❌ | 引导系数 (默认: 7.5) |
| `seed` | integer | ❌ | 随机种子 (可选) |

**请求示例**:

```bash
curl -X POST https://your-tunnel.trycloudflare.com/v1/images/generations \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "a beautiful mountain landscape at sunset, 4k, high quality",
    "model": "sdxl",
    "n": 1,
    "size": "1024x1024",
    "num_inference_steps": 20,
    "guidance_scale": 7.5
  }'
```

**响应示例**:

```json
{
  "created": 1700000000,
  "data": [
    {
      "b64_json": "iVBORw0KGgoAAAANSUhEUg...",
      "revised_prompt": "a beautiful mountain landscape at sunset, 4k, high quality"
    }
  ]
}
```

#### 健康检查

```bash
GET /health
```

**响应**:

```json
{
  "status": "ok",
  "gpu": "NVIDIA GeForce RTX 3090",
  "gpu_memory_used": "351MiB",
  "gpu_memory_total": "24576MiB",
  "model_loaded": true,
  "current_model": "sdxl"
}
```

#### 列出可用模型

```bash
GET /v1/models
```

**响应**:

```json
{
  "data": [
    {"id": "sdxl", "object": "model"},
    {"id": "flux-dev", "object": "model"},
    {"id": "flux-schnell", "object": "model"}
  ]
}
```

---

## OpenDesign 配置

### 1. 打开 Settings

访问 `http://127.0.0.1:7456/settings`

### 2. 选择 Custom Image API

在"媒体生成供应商"中找到 **Custom Image API**，点击配置。

### 3. 填写配置

| 字段 | 值 |
|------|-----|
| **API Key** | (可选，留空或填 `local`) |
| **Base URL** | `http://100.64.0.2:7865/v1` (GPU 机器的 Tailscale IP) |
| **模型** | `sdxl` |

> **注意**: Tailscale 使用内网 IP，格式为 `100.x.x.x`，端口为 `7865`

### 4. 测试连接

在 OpenDesign 中创建一个新项目，选择图像生成，观察是否成功。

---

## 模型选择

### RTX 3090 (24GB VRAM) 推荐模型

| 模型 | 显存占用 | 生成速度 | 质量 | 推荐场景 |
|------|----------|---------|------|----------|
| **FLUX.1-dev** | ~12GB | 10-20s | ⭐⭐⭐⭐⭐ | 通用、高质量 |
| **FLUX.1-schnell** | ~12GB | 3-8s | ⭐⭐⭐⭐ | 快速迭代 |
| **SDXL 1.0** | ~7GB | 5-10s | ⭐⭐⭐⭐ | 通用、生态丰富 |
| **SD 3.5 Medium** | ~10GB | 8-15s | ⭐⭐⭐⭐ | 文字渲染好 |

### 环境变量配置

```bash
# 默认模型
export DEFAULT_MODEL=sdxl

# 模型缓存路径
export HF_HOME=/home/wangwei/.cache/huggingface

# HuggingFace 镜像 (国内加速)
export HF_ENDPOINT=https://hf-mirror.com
```

---

## Tailscale 配置

### 完整安装指南

Tailscale 是一个零配置的 VPN 工具，可以在多台设备之间建立安全的 P2P 连接。

### 步骤 1: 在 GPU 机器上安装 Tailscale

```bash
# Ubuntu/Debian
curl -fsSL https://tailscale.com/install.sh | sh

# 启动 Tailscale
sudo tailscale up

# 输出示例:
# To authenticate, visit: https://login.tailscale.com/xxx
# 在浏览器中打开链接，使用 Google/Microsoft/GitHub 账号登录
```

### 步骤 2: 在腾讯云服务器上安装 Tailscale

```bash
# SSH 到腾讯云服务器
ssh user@your-tencent-server

# 安装 Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# 启动 Tailscale (使用相同的账号登录)
sudo tailscale up
```

### 步骤 3: 获取 GPU 机器的 Tailscale IP

```bash
# 在 GPU 机器上
tailscale ip -4
# 输出: 100.64.0.2 (示例)
```

### 步骤 4: 验证连通性

```bash
# 在腾讯云服务器上
ping 100.64.0.2

# 测试 API
curl http://100.64.0.2:7865/health
```

### 步骤 5: 配置防火墙 (可选)

```bash
# 在 GPU 机器上，允许 Tailscale 网络访问 7865 端口
sudo ufw allow from 100.0.0.0/8 to any port 7865
```

### 步骤 6: 配置 Tailscale 开机自启

```bash
# 启用 tailscaled 服务
sudo systemctl enable tailscaled
sudo systemctl start tailscaled

# 验证状态
sudo systemctl status tailscaled
```

### Tailscale 常用命令

```bash
# 查看状态
tailscale status

# 查看 IP
tailscale ip

# 测试其他设备连通性
tailscale ping 100.64.0.1

# 断开连接
sudo tailscale down

# 重新连接
sudo tailscale up
```

---

## 运维管理

### 查看服务状态

```bash
# systemd 服务
sudo systemctl status diffusers-api

# 查看日志
sudo journalctl -u diffusers-api -f

# 或查看本地日志
tail -f logs/server.log
```

### 重启服务

```bash
sudo systemctl restart diffusers-api
```

### 更新模型

```bash
# 进入虚拟环境
source venv/bin/activate

# 预热新模型
python -c "
from diffusers import FluxPipeline
import torch
pipe = FluxPipeline.from_pretrained(
    'black-forest-labs/FLUX.1-schnell',
    torch_dtype=torch.float16
).to('cuda')
print('Model loaded successfully!')
"
```

### 性能监控

```bash
# 监控 GPU 使用率
watch -n 1 nvidia-smi

# 监控服务请求
curl http://localhost:7865/health | jq
```

---

## 故障排查

### 问题 1: CUDA Out of Memory

**症状**: 生成图片时报错 `CUDA out of memory`

**解决**:

```python
# 方法 1: 使用 fp8 量化模型
pipe = FluxPipeline.from_pretrained(
    "black-forest-labs/FLUX.1-dev",
    torch_dtype=torch.float8_e4m3fn  # 使用 fp8
).to("cuda")

# 方法 2: 降低分辨率
size = "512x512"  # 而不是 1024x1024

# 方法 3: 启用模型卸载
pipe.enable_model_cpu_offload()
```

### 问题 2: 模型下载慢

**症状**: 首次下载模型非常慢

**解决**:

```bash
# 使用 HuggingFace 镜像
export HF_ENDPOINT=https://hf-mirror.com

# 或使用 huggingface-cli 下载
pip install huggingface_hub[hf_xet]
huggingface-cli download black-forest-labs/FLUX.1-dev --local-dir ./models/flux-dev
```

### 问题 3: Tailscale 连接断开

**症状**: 腾讯云无法访问本地服务

**解决**:

```bash
# 在 GPU 机器上检查 Tailscale 状态
tailscale status

# 检查 Tailscale 服务
sudo systemctl status tailscaled

# 重启 Tailscale
sudo systemctl restart tailscaled

# 重新连接
sudo tailscale up

# 在腾讯云服务器上测试连通性
ping 100.64.0.2
curl http://100.64.0.2:7865/health
```

### 问题 4: API 返回 404

**症状**: OpenDesign 配置后测试失败

**检查**:

1. 确保 Base URL 包含 `/v1`:
   - ✅ `http://100.64.0.2:7865/v1`
   - ❌ `http://100.64.0.2:7865`

2. 检查 Tailscale 连通性:
   ```bash
   # 在腾讯云服务器上
   tailscale ping 100.64.0.2
   ```

3. 检查本地服务是否正常:
   ```bash
   # 在 GPU 机器上
   curl http://localhost:7865/health
   curl http://localhost:7865/v1/models
   ```

4. 检查防火墙是否允许 Tailscale:
   ```bash
   # 在 GPU 机器上
   sudo ufw allow from 100.0.0.0/8 to any port 7865
   ```

### 问题 5: 生成速度慢

**症状**: 生成一张图片需要很长时间

**优化**:

```bash
# 1. 使用 FLUX.1-schnell (更快)
python server.py --model flux-schnell

# 2. 减少推理步数
curl -X POST ... -d '{"num_inference_steps": 10}'

# 3. 降低分辨率
curl -X POST ... -d '{"size": "512x512"}'

# 4. 确保使用 fp16
# 检查 server.py 中是否设置了 torch_dtype=torch.float16
```

---

## 性能基准测试

### RTX 3090 参考性能

| 模型 | 分辨率 | 步数 | 生成时间 |
|------|--------|------|---------|
| FLUX.1-dev | 1024x1024 | 20 | ~15s |
| FLUX.1-dev | 512x512 | 20 | ~8s |
| FLUX.1-schnell | 1024x1024 | 4 | ~3s |
| SDXL 1.0 | 1024x1024 | 20 | ~8s |

### 压力测试

```bash
# 并发测试
for i in {1..5}; do
  curl -X POST http://localhost:7865/v1/images/generations \
    -H "Content-Type: application/json" \
    -d "{\"prompt\": \"test image $i\", \"size\": \"512x512\"}" &
done
wait
```

---

## 安全建议

### 1. 添加 API Key 验证

```python
# 在 server.py 中添加
API_KEY = os.getenv("API_KEY", "your-secret-key")

@app.middleware("http")
async def verify_api_key(request: Request, call_next):
    if request.url.path.startswith("/v1/"):
        api_key = request.headers.get("Authorization", "").replace("Bearer ", "")
        if api_key != API_KEY:
            return JSONResponse({"error": "Unauthorized"}, status_code=401)
    return await call_next(request)
```

### 2. 配置 Tailscale ACL 限制访问

```bash
# 在 Tailscale Admin Console (https://login.tailscale.com/admin/acls)
# 添加 ACL 规则，只允许特定设备访问

{
  "acls": [
    {
      "action": "accept",
      "src": ["tag:opendesign-server"],
      "dst": ["tag:gpu-machine:7865"]
    }
  ],
  "tagOwners": {
    "tag:opendesign-server": ["autogroup:admin"],
    "tag:gpu-machine": ["autogroup:admin"]
  }
}
```

### 3. 使用 Tailscale Funnel (可选 - 公网访问)

如果需要从其他设备访问，可以使用 Tailscale Funnel:

```bash
# 在 GPU 机器上
tailscale funnel 7865

# 这会生成一个公网 URL，如:
# https://your-machine.tail1234.ts.net/
```

### 4. Tailscale 优势

✅ **端到端加密**: 数据直接在两台机器间传输，不经过第三方
✅ **零配置**: 无需端口转发、SSL 证书等
✅ **低延迟**: P2P 直连，无需中转服务器
✅ **安全**: 只有授权设备可以访问

---

## 成本对比

| 方案 | 单次生图成本 | 质量 | 速度 |
|------|-------------|------|------|
| **本地 3090 (本方案)** | **¥0** (电费约 ¥0.01) | ⭐⭐⭐⭐⭐ | 10-20s |
| Fal.ai (flux-schnell) | ~¥0.02 | ⭐⭐⭐⭐ | 3-8s |
| OpenAI (gpt-image-2) | ~¥0.35 | ⭐⭐⭐⭐ | 10-30s |
| Midjourney | ~¥1.0 | ⭐⭐⭐⭐⭐ | 60s |

---

## 参考资源

- [Diffusers 文档](https://huggingface.co/docs/diffusers)
- [FLUX.1 模型](https://huggingface.co/black-forest-labs/FLUX.1-dev)
- [FastAPI 文档](https://fastapi.tiangolo.com/)
- [Tailscale 文档](https://tailscale.com/kb/)
- [OpenAI Image API](https://platform.openai.com/docs/api-reference/images)

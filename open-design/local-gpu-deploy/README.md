# OpenDesign 本地 GPU 生图部署方案

> RTX 3090 (24GB VRAM) + Diffusers + Tailscale P2P VPN + OpenDesign Custom Image API

---

## 当前部署状态

- **服务状态**: ✅ 运行中
- **模型**: SDXL 1.0 (默认)
- **Tailscale IP**: 100.94.242.79
- **API 端点**: http://100.94.242.79:7865/v1
- **显存占用**: ~7GB (SDXL)

> **注意**: FLUX.1-dev 模型因显存不足 (OOM) 已停用，当前使用 SDXL 作为默认模型。

---

## 目录

1. [架构概览](#架构概览)
2. [快速开始](#快速开始)
3. [服务管理](#服务管理)
4. [OpenDesign 配置](#opendesign-配置)
5. [模型选择指南](#模型选择指南)
6. [故障排查](#故障排查)

---

## 架构概览

```
┌─────────────────────────────────────────────────────────────────┐
│                      OpenDesign Web UI                          │
│              (腾讯云服务器 / 本地 Linux)                          │
│                  Tailscale IP: 100.x.x.x                       │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          │ Tailscale P2P VPN (端到端加密)
                          │ 直连，无需公网 IP
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│              RTX 3090 机器 (本地 GPU 服务器)                     │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Tailscale Client                                        │  │
│  │  IP: 100.94.242.79                                       │  │
│  │  ↓                                                        │  │
│  │  FastAPI Server (port 7865)                               │  │
│  │  ├── POST /v1/images/generations  (OpenAI 兼容)          │  │
│  │  ├── GET  /health                                         │  │
│  │  └── GET  /v1/models                                      │  │
│  │  ↓                                                        │  │
│  │  Diffusers Pipeline                                        │  │
│  │  ├── SDXL 1.0 (默认，~7GB)                                │  │
│  │  ├── FLUX.1-dev (已停用，OOM)                             │  │
│  │  └── FLUX.1-schnell (可选)                                │  │
│  │  ↓                                                        │  │
│  │  NVIDIA RTX 3090 (24GB VRAM)                              │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

**优势**:
- ✅ 端到端加密，数据不经过第三方
- ✅ 无需公网 IP，无需端口转发
- ✅ P2P 直连，低延迟
- ✅ SDXL 模型稳定，不会 OOM

---

## 快速开始

### 1. 启动 Diffusers 服务

```bash
cd /home/wangwei/wei/workspacePy/design/design-ext/open-design/local-gpu-deploy/diffusers

# 启动 SDXL 服务 (默认，稳定)
./start.sh --port=7865 --model=sdxl

# 或启动 FLUX 服务 (需要更多显存，可能 OOM)
# ./start.sh --port=7865 --model=flux-dev
```

### 2. 确认 Tailscale 连接

```bash
cd /home/wangwei/wei/workspacePy/design/design-ext/open-design/local-gpu-deploy/tailscale

# 检查 Tailscale 状态
sudo tailscale status

# 查看本机 Tailscale IP
tailscale ip -4
# 输出: 100.94.242.79
```

### 3. 测试服务

```bash
# 本地测试
curl http://localhost:7865/health

# 通过 Tailscale 测试
curl http://100.94.242.79:7865/health
```

### 4. 生成图片

```bash
curl -X POST http://100.94.242.79:7865/v1/images/generations \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "a beautiful mountain landscape at sunset, 4k, high quality",
    "model": "sdxl",
    "n": 1,
    "size": "1024x1024",
    "num_inference_steps": 20
  }'
```

---

## 服务管理

### 启动服务

```bash
# 进入 diffusers 目录
cd /home/wangwei/wei/workspacePy/design/design-ext/open-design/local-gpu-deploy/diffusers

# 启动 SDXL (推荐)
./start.sh --model=sdxl

# 启动 FLUX (实验性，可能 OOM)
# ./start.sh --model=flux-dev
```

### 停止服务

```bash
# 停止当前服务
./stop.sh

# 或强制停止
pkill -f "python server.py"
```

### 查看状态

```bash
# 检查服务健康状态
curl http://localhost:7865/health | python3 -m json.tool

# 查看 GPU 使用情况
nvidia-smi

# 查看服务日志
tail -f logs/server.log
```

### 重启服务

```bash
# 停止并重新启动
./stop.sh && ./start.sh --model=sdxl
```

---

## OpenDesign 配置

### 1. 打开 Settings

在你的 Linux 机器上访问 OpenDesign: `http://127.0.0.1:7456/settings`

### 2. 选择 Custom Image API

在"媒体生成供应商"中找到 **Custom Image API**，点击配置。

### 3. 填写配置

| 字段 | 值 |
|------|-----|
| **API Key** | (留空) |
| **Base URL** | `http://100.94.242.79:7865/v1` |
| **模型** | `sdxl` |

> **注意**: 
> - 确保你的 Linux 机器也已安装并登录 Tailscale（同一个账号）
> - Base URL 必须包含 `/v1` 后缀
> - 当前默认模型为 `sdxl`（FLUX 模型因显存问题已停用）

### 4. 测试连接

在 OpenDesign 中创建一个新项目，选择图像生成，观察是否成功。

---

## 模型选择指南

### 当前可用模型

| 模型 | 显存占用 | 生成速度 (1024x1024) | 质量 | 状态 |
|------|----------|---------------------|------|------|
| **SDXL 1.0** | ~7GB | 5-10s | ⭐⭐⭐⭐ | ✅ **默认，推荐** |
| **FLUX.1-dev** | ~20GB | 10-20s | ⭐⭐⭐⭐⭐ | ❌ 已停用 (OOM) |
| **FLUX.1-schnell** | ~12GB | 3-8s | ⭐⭐⭐⭐ | ⚠️ 可选，但未测试 |

### 为什么使用 SDXL 而不是 FLUX？

FLUX.1-dev 模型虽然质量更高，但在 RTX 3090 (24GB) 上生成图片时需要约 20GB+ 显存，容易导致 CUDA Out of Memory (OOM) 错误。SDXL 模型只需约 7GB 显存，运行稳定，质量也很优秀。

### 推荐配置

**最佳稳定性 (当前配置)**:
- 模型: SDXL 1.0
- 采样步数: 20-25
- 分辨率: 1024x1024
- 显存占用: ~7GB

**如果尝试 FLUX (风险)**:
- 模型: FLUX.1-dev
- 采样步数: 20
- 分辨率: 512x512 (降低分辨率以减少显存)
- 显存占用: ~20GB (可能 OOM)

---

## 故障排查

### 问题 1: 服务无法启动

**症状**: 启动时报错或立即退出

**检查**:
```bash
# 查看服务日志
tail -f /home/wangwei/wei/workspacePy/design/design-ext/open-design/local-gpu-deploy/diffusers/logs/server.log

# 检查 GPU 状态
nvidia-smi

# 检查端口占用
ss -tlnp | grep 7865
```

### 问题 2: CUDA Out of Memory

**症状**: 生成图片时报错 `CUDA out of memory`

**解决**:
```bash
# 1. 使用 SDXL 模型 (推荐)
./start.sh --model=sdxl

# 2. 降低分辨率
curl -X POST ... -d '{"size": "512x512"}'

# 3. 减少推理步数
curl -X POST ... -d '{"num_inference_steps": 15}'
```

### 问题 3: Tailscale 连接断开

**症状**: 其他设备无法访问 GPU 服务

**解决**:
```bash
# 检查 Tailscale 状态
sudo tailscale status

# 重新连接
sudo tailscale up

# 查看 Tailscale IP
tailscale ip -4
```

### 问题 4: OpenDesign 返回 404

**症状**: 配置后测试失败

**检查**:
1. 确保 Base URL 包含 `/v1`:
   - ✅ `http://100.94.242.79:7865/v1`
   - ❌ `http://100.94.242.79:7865`

2. 检查 Tailscale 连通性:
   ```bash
   # 在 OpenDesign 机器上
   tailscale ping 100.94.242.79
   curl http://100.94.242.79:7865/health
   ```

### 问题 5: 生成速度慢

**症状**: 生成一张图片需要很长时间

**优化**:
```bash
# 1. 减少推理步数
curl -X POST ... -d '{"num_inference_steps": 15}'

# 2. 降低分辨率
curl -X POST ... -d '{"size": "512x512"}'

# 3. 监控 GPU 使用率
watch -n 1 nvidia-smi
```

---

## 文件位置

| 类型 | 路径 |
|------|------|
| **Diffusers 服务** | `/home/wangwei/wei/workspacePy/design/design-ext/open-design/local-gpu-deploy/diffusers/` |
| **Tailscale 配置** | `/home/wangwei/wei/workspacePy/design/design-ext/open-design/local-gpu-deploy/tailscale/` |
| **模型文件** | `/data/models/models/` |
| **生成的图片** | `/home/wangwei/wei/workspacePy/design/design-ext/open-design/local-gpu-deploy/diffusers/outputs/` |
| **服务日志** | `/home/wangwei/wei/workspacePy/design/design-ext/open-design/local-gpu-deploy/diffusers/logs/` |

---

## 参考资源

- [Diffusers 部署文档](./diffusers/README.md)
- [Tailscale 配置文档](./tailscale/README.md)
- [Diffusers 官方文档](https://huggingface.co/docs/diffusers)
- [SDXL 模型](https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0)
- [Tailscale 文档](https://tailscale.com/kb/)
- [OpenAI Image API](https://platform.openai.com/docs/api-reference/images)

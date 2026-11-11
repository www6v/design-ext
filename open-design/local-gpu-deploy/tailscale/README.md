# Tailscale 网络配置

> 通过 Tailscale P2P VPN 实现多设备安全访问本地 GPU 服务器

---

## 目录

1. [架构概览](#架构概览)
2. [GPU 机器配置](#gpu-机器配置)
3. [笔记本配置](#笔记本配置)
4. [腾讯云服务器配置](#腾讯云服务器配置)
5. [OpenDesign 配置](#opendesign-配置)
6. [故障排查](#故障排查)

---

## 架构概览

```
┌─────────────────────────┐    ┌─────────────────────────┐
│   腾讯云 (OpenDesign)    │    │   笔记本 (OpenDesign)    │
│   Tailscale IP: 100.64.x.1│  │   Tailscale IP: 100.64.x.3│
└───────────┬─────────────┘    └───────────┬─────────────┘
            │                               │
            │     Tailscale P2P VPN         │
            │        (端到端加密)             │
            └───────────┬───────────────────┘
                        │
                        ▼
            ┌─────────────────────────┐
            │   GPU 机器 (RTX 3090)    │
            │   Tailscale IP: 100.74.141.86│
            │   API: 0.0.0.0:7865      │
            └─────────────────────────┘
```

### 优势

- ✅ **端到端加密**: 数据直接在设备间传输，不经过第三方
- ✅ **无需公网 IP**: 无需端口转发，无需公网 IP
- ✅ **P2P 直连**: 低延迟，高性能
- ✅ **跨平台**: 支持 Linux、Windows、macOS、Android、iOS
- ✅ **零配置**: 无需复杂的网络配置

---

## GPU 机器配置

### 1. 安装 Tailscale

```bash
# 运行安装脚本
sudo bash install.sh

# 或手动安装
curl -fsSL https://tailscale.com/install.sh | sh
```

### 2. 启动并认证

```bash
# 创建环境文件 (如果缺失)
echo "PORT=0" | sudo tee /etc/default/tailscaled

# 启动 tailscaled 服务
sudo systemctl daemon-reload
sudo systemctl start tailscaled
sudo systemctl enable tailscaled

# 启动 Tailscale 并获取认证链接
sudo tailscale up

# 输出示例:
# To authenticate, visit: https://login.tailscale.com/a/xxxxx
# 在浏览器中打开链接并登录
```

### 3. 查看 Tailscale IP

```bash
tailscale status
# 输出示例:
# 100.74.141.86  wangwei-x99  www6v@  linux  -
```

### 4. 验证服务

```bash
# 确保 Diffusers API 服务正在运行
curl http://localhost:7865/health

# 从 Tailscale 网络测试
curl http://100.74.141.86:7865/health
```

---

## 笔记本配置

### Linux 笔记本

```bash
# 1. 安装 Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# 2. 启动并认证
sudo tailscale up
# 在浏览器中打开链接，登录同一个 Tailscale 账号

# 3. 查看 GPU 机器的 IP
tailscale status

# 4. 测试连接
ping 100.74.141.86

# 5. 测试 API
curl http://100.74.141.86:7865/health
```

### Windows 笔记本

1. 下载安装: https://tailscale.com/download/windows
2. 安装并运行
3. 登录同一个 Tailscale 账号
4. 在 PowerShell 中测试:
   ```powershell
   Test-Connection 100.74.141.86
   Invoke-RestMethod http://100.74.141.86:7865/health
   ```

### macOS 笔记本

```bash
# 使用 Homebrew 安装
brew install tailscale

# 或下载 App: https://tailscale.com/download/mac

# 启动并认证
sudo tailscale up
```

---

## 腾讯云服务器配置

```bash
# 1. 安装 Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# 2. 启动并认证
sudo tailscale up
# 登录同一个 Tailscale 账号

# 3. 查看 GPU 机器的 IP
tailscale status

# 4. 测试连接
ping 100.74.141.86

# 5. 测试 API
curl http://100.74.141.86:7865/health
```

---

## OpenDesign 配置

### 在笔记本或腾讯云的 OpenDesign 中配置

1. 打开 Settings: `http://127.0.0.1:7456/settings`

2. 在"媒体生成供应商"中选择 **Custom Image API**

3. 填写配置:

| 字段 | 值 |
|------|-----|
| **API Key** | (可选，留空) |
| **Base URL** | `http://100.74.141.86:7865/v1` |
| **模型** | `sdxl` |

4. 测试连接

---

## 故障排查

### 问题 1: tailscaled 服务启动失败

**症状**: `Failed to start tailscaled.service`

**解决**:
```bash
# 检查是否缺少环境文件
cat /etc/default/tailscaled

# 如果不存在，创建它
echo "PORT=0" | sudo tee /etc/default/tailscaled

# 重载 systemd 配置
sudo systemctl daemon-reload

# 重启服务
sudo systemctl restart tailscaled
```

### 问题 2: 无法连接其他设备

**症状**: `ping 100.x.x.x` 无响应

**检查**:
```bash
# 1. 确认 Tailscale 正在运行
tailscale status

# 2. 确认设备在同一网络
# 所有设备必须登录同一个 Tailscale 账号

# 3. 检查防火墙
sudo ufw allow from 100.0.0.0/8
```

### 问题 3: API 返回空响应

**症状**: `curl http://100.x.x.x:7865/v1/images/generations` 返回空

**检查**:
```bash
# 1. 确认 API 服务正在运行
curl http://localhost:7865/health

# 2. 检查服务日志
tail -f /home/wangwei/wei/workspacePy/design/design-ext/open-design/local-gpu-deploy/diffusers/logs/server.log

# 3. 确认端口监听
sudo netstat -tlnp | grep 7865
```

### 问题 4: 认证链接过期

**症状**: 认证链接无法使用

**解决**:
```bash
# 重新生成认证链接
sudo tailscale up
```

---

## 常用命令

```bash
# 查看状态
tailscale status

# 查看 IP
tailscale ip

# 测试其他设备
tailscale ping 100.74.141.86

# 断开连接
sudo tailscale down

# 重新连接
sudo tailscale up

# 查看服务状态
sudo systemctl status tailscaled

# 重启服务
sudo systemctl restart tailscaled

# 查看日志
sudo journalctl -u tailscaled -f
```

---

## 安全建议

### 1. 使用 Tailscale ACL

在 Tailscale Admin Console (https://login.tailscale.com/admin/acls) 配置访问控制:

```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["*"],
      "dst": ["tag:gpu-server:7865"]
    }
  ],
  "tagOwners": {
    "tag:gpu-server": ["autogroup:admin"]
  }
}
```

### 2. 添加 API Key 验证

在 GPU 机器上设置环境变量:
```bash
export API_KEY="your-secret-key"
```

在请求中添加 Header:
```bash
curl -H "Authorization: Bearer your-secret-key" http://100.74.141.86:7865/v1/images/generations
```

### 3. 限制端口访问

只允许 Tailscale 网络访问 API 端口:
```bash
sudo ufw allow from 100.0.0.0/8 to any port 7865
sudo ufw deny 7865
```

---

## 参考资源

- [Tailscale 官方文档](https://tailscale.com/kb/)
- [Tailscale GitHub](https://github.com/tailscale/tailscale)
- [Tailscale ACL 文档](https://tailscale.com/kb/1018/acls/)

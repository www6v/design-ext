# Tailscale Linux 部署

> 在 Linux 服务器上部署 Tailscale P2P VPN

---

## 文件说明

| 文件 | 说明 |
|------|------|
| `install.sh` | 安装脚本 - 安装 Tailscale 并初始化服务 |
| `start.sh` | 启动脚本 - 启动 Tailscale 并认证 |
| `stop.sh` | 停止脚本 - 断开连接并停止服务 |
| `status.sh` | 状态检查 - 查看连接状态和 API 可访问性 |
| `test.sh` | 连接测试 - 测试 API 和图片生成 |
| `uninstall.sh` | 卸载脚本 - 完全移除 Tailscale |
| `tailscaled.env` | 环境配置文件 (参考) |
| `tailscaled.service` | systemd 服务文件 (参考) |

---

## 快速开始

### 1. 安装

```bash
sudo bash install.sh
```

安装完成后，脚本会提示下一步操作。

### 2. 启动并认证

```bash
sudo bash start.sh
```

脚本会输出认证链接，在浏览器中打开并登录 Tailscale 账号。

### 3. 查看状态

```bash
bash status.sh
```

### 4. 测试连接

```bash
bash test.sh
```

---

## 常用命令

```bash
# 查看 Tailscale 状态
tailscale status

# 查看本机 Tailscale IP
tailscale ip -4

# 查看其他设备
tailscale ping <设备名或IP>

# 查看服务日志
sudo journalctl -u tailscaled -f
```

---

## 停止/卸载

```bash
# 停止服务
sudo bash stop.sh

# 完全卸载
sudo bash uninstall.sh
```

---

## 故障排查

### tailscaled 服务启动失败

```bash
# 检查环境文件
cat /etc/default/tailscaled

# 如果不存在，创建它
echo "PORT=0" | sudo tee /etc/default/tailscaled
sudo systemctl daemon-reload
sudo systemctl restart tailscaled
```

### 无法连接其他设备

```bash
# 1. 确认服务运行
sudo systemctl status tailscaled

# 2. 确认登录状态
tailscale status

# 3. 检查防火墙
sudo ufw allow from 100.0.0.0/8
```

### 认证链接过期

```bash
sudo tailscale up
```

---

## 安全建议

### 限制 API 端口访问

```bash
# 只允许 Tailscale 网络访问
sudo ufw allow from 100.0.0.0/8 to any port 7865
sudo ufw deny 7865
```

### 添加 API Key 验证

在 GPU 机器上设置环境变量:
```bash
export API_KEY="your-secret-key"
```

请求时添加 Header:
```bash
curl -H "Authorization: Bearer your-secret-key" http://<tailscale-ip>:7865/v1/images/generations
```

---

## 参考

- [Tailscale 官方文档](https://tailscale.com/kb/)
- [Tailscale GitHub](https://github.com/tailscale/tailscale)

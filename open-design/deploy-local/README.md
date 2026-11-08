# OpenDesign 本地部署

本目录包含在本地部署 OpenDesign Web 端所需的全部脚本。

## 架构

```
┌─────────────────────────────────────────────┐
│                  浏览器                       │
│           http://127.0.0.1:7456              │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│              Daemon (Node.js)                │
│  ┌─────────────┐      ┌─────────────────┐  │
│  │  API 服务    │      │  静态文件服务    │  │
│  │  /api/*     │      │  / (Web 产出)   │  │
│  └─────────────┘      └─────────────────┘  │
│                                             │
│  ┌──────────────────────────────────────┐  │
│  │  Agent 调度 (Claude/Codex/DSH/...)   │  │
│  └──────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│           本地 Agent CLI (可选)              │
│     Claude Code / Codex / DSH / ...        │
└─────────────────────────────────────────────┘
```

**生产模式**: Daemon 同时服务 API 和 Web 静态产出, 单进程部署。
**开发模式**: Daemon + Next.js 开发服务器, 支持热重载。

---

## 快速开始

### 1. 环境要求

- **Node.js**: `24.x` (必须)
- **pnpm**: `10.33.2` (由 Corepack 自动管理)
- **OS**: Linux / macOS / WSL2

检查版本:
```bash
node --version   # 应为 v24.x
```

### 2. 一键初始化

```bash
cd /home/wangwei/wei/workspacePy/design/design-ext/open-design/deploy-local
bash setup.sh
```

这会:
- 检查 Node.js 版本
- 启用 Corepack (pnpm 10.33.2)
- 安装所有依赖
- 创建 `.env` 配置文件 (含随机 API Token)

### 3. 构建

```bash
bash build.sh
```

构建产出:
- `apps/daemon/dist/cli.js` — Daemon CLI
- `apps/web/out/` — Web 静态产出

### 4. 启动

**生产模式** (推荐):
```bash
bash start.sh
```

**后台运行**:
```bash
bash start.sh --background
```

**开发模式** (热重载):
```bash
bash start-dev.sh
```

### 5. 访问

打开浏览器: **http://127.0.0.1:7456**

---

## 脚本说明

| 脚本 | 用途 | 用法 |
|---|---|---|
| `setup.sh` | 初始化环境, 安装依赖 | `bash setup.sh` |
| `build.sh` | 构建 daemon + web | `bash build.sh` |
| `start.sh` | 启动生产服务 | `bash start.sh [--background]` |
| `start-dev.sh` | 启动开发服务 (热重载) | `bash start-dev.sh [--ports 7457:5175]` |
| `stop.sh` | 停止服务 | `bash stop.sh` |
| `status.sh` | 检查状态 | `bash status.sh` |

---

## 配置

配置文件: `.env` (从 `env.example` 复制)

```bash
# 端口
OD_PORT=7456                    # Daemon 端口
OD_WEB_PORT=5173                # Web 开发端口 (开发模式)

# 认证
OD_API_TOKEN=<your-token>       # API Token (openssl rand -hex 32)
OPEN_DESIGN_DISABLE_API_AUTH=1  # 设为 1 禁用认证 (本地环境)

# Node
NODE_OPTIONS=--max-old-space-size=2048  # 堆内存上限

# Agent API Key (可选)
ANTHROPIC_API_KEY=
OPENAI_API_KEY=
```

---

## 常用场景

### 场景 1: 纯本地开发

```bash
bash setup.sh
bash start-dev.sh
# 浏览器打开 http://127.0.0.1:5173
```

### 场景 2: 构建后本地预览

```bash
bash setup.sh
bash build.sh
bash start.sh
# 浏览器打开 http://127.0.0.1:7456
```

### 场景 3: 后台服务

```bash
bash build.sh
bash start.sh --background
bash status.sh          # 检查状态
bash stop.sh            # 停止
```

### 场景 4: 自定义端口

```bash
bash start-dev.sh --ports 7457:5175
# 浏览器打开 http://127.0.0.1:5175
```

---

## 故障排查

### Daemon 启动失败

```bash
# 检查端口占用
ss -tlnp | grep 7456
lsof -i :7456

# 检查日志
cat logs/daemon.log

# 重新构建
bash build.sh --skip-web
```

### Web 无法访问

```bash
# 检查状态
bash status.sh

# 检查构建产出
ls -la ../open-design-main/apps/web/out/

# 重新构建 web
bash build.sh --skip-daemon
```

### 端口冲突

修改 `.env`:
```bash
OD_PORT=7457  # 换一个未被占用的端口
```

### Node 版本不对

```bash
# 使用 nvm
nvm install 24
nvm use 24

# 或使用 fnm
fnm install 24
fnm use 24
```

---

## 目录结构

```
deploy-local/
├── README.md           # 本文档
├── env.example         # 环境变量模板
├── .env                # 实际配置 (git 忽略)
├── setup.sh            # 初始化脚本
├── build.sh            # 构建脚本
├── start.sh            # 启动脚本 (生产)
├── start-dev.sh        # 启动脚本 (开发)
├── stop.sh             # 停止脚本
├── status.sh           # 状态检查
├── .daemon.pid         # Daemon PID (运行时)
└── logs/               # 日志目录 (后台模式)
    └── daemon.log
```

---

## 相关链接

- [项目 README](../README.md) — 项目整体分析
- [架构文档](../ARCHITECTURE.md) — 含 Mermaid 架构图
- [官方 QuickStart](../../open-design-main/QUICKSTART.md) — 官方快速开始
- [官方部署文档](../../open-design-main/deploy/README.md) — Docker 部署

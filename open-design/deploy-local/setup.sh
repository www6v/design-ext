#!/usr/bin/env bash
# ============================================================
# OpenDesign 本地部署 - 环境初始化
# ============================================================
# 用途: 首次部署前运行, 安装依赖
# 用法: bash setup.sh
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../open-design-main" && pwd)"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

echo ""
echo "============================================"
echo "  OpenDesign 本地部署 - 环境初始化"
echo "============================================"
echo ""

# ---- 检查 Node.js ----
info "检查 Node.js 版本..."
if ! command -v node &>/dev/null; then
    err "未找到 Node.js, 请先安装 Node.js 24"
    exit 1
fi

NODE_VERSION=$(node --version | sed 's/v//' | cut -d. -f1)
if [[ "$NODE_VERSION" != "24" ]]; then
    err "Node.js 版本不匹配: 需要 v24.x, 当前 $(node --version)"
    err "请使用 nvm/fnm 切换到 Node 24:"
    err "  nvm install 24 && nvm use 24"
    err "  或: fnm install 24 && fnm use 24"
    exit 1
fi
ok "Node.js $(node --version)"

# ---- 检查/启用 Corepack ----
info "检查 Corepack..."
if ! command -v corepack &>/dev/null; then
    warn "Corepack 不可用, 尝试启用..."
    corepack enable 2>/dev/null || {
        err "Corepack 启用失败, 请手动安装 pnpm 10.33.2:"
        err "  npm install -g pnpm@10.33.2"
        exit 1
    }
fi
ok "Corepack $(corepack --version 2>/dev/null || echo 'available')"

# ---- 切换到项目目录 ----
info "项目目录: $PROJECT_ROOT"
cd "$PROJECT_ROOT"

# ---- 安装依赖 (使用项目锁定的 pnpm 10.33.2) ----
info "安装依赖 (pnpm install)..."
echo "  这将使用项目锁定的 pnpm@10.33.2 (通过 Corepack)"
echo ""

# 设置 pnpm 版本
corepack prepare pnpm@10.33.2 --activate 2>/dev/null || true

# 安装
pnpm install --frozen-lockfile

ok "依赖安装完成"

# ---- 创建 .env (如果不存在) ----
if [[ ! -f "$SCRIPT_DIR/.env" ]]; then
    info "创建 .env 配置文件..."
    cp "$SCRIPT_DIR/env.example" "$SCRIPT_DIR/.env"

    # 生成随机 API Token
    if command -v openssl &>/dev/null; then
        TOKEN=$(openssl rand -hex 32)
        sed -i "s/^OD_API_TOKEN=$/OD_API_TOKEN=$TOKEN/" "$SCRIPT_DIR/.env"
        ok ".env 已创建 (含随机 API Token)"
    else
        ok ".env 已创建 (请手动设置 OD_API_TOKEN)"
    fi
else
    warn ".env 已存在, 跳过创建"
fi

echo ""
echo "============================================"
echo "  初始化完成!"
echo "============================================"
echo ""
echo "后续步骤:"
echo "  1. 构建项目:  bash $SCRIPT_DIR/build.sh"
echo "  2. 启动服务:  bash $SCRIPT_DIR/start.sh"
echo "  3. 打开浏览器: http://127.0.0.1:7456"
echo ""
echo "开发模式 (热重载):"
echo "  bash $SCRIPT_DIR/start-dev.sh"
echo ""

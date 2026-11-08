#!/usr/bin/env bash
# ============================================================
# OpenDesign 本地部署 - 构建
# ============================================================
# 用途: 构建 daemon + web 静态产出
# 用法: bash build.sh [--skip-daemon] [--skip-web]
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

SKIP_DAEMON=false
SKIP_WEB=false

for arg in "$@"; do
    case "$arg" in
        --skip-daemon) SKIP_DAEMON=true ;;
        --skip-web)    SKIP_WEB=true ;;
        *)             warn "未知参数: $arg" ;;
    esac
done

echo ""
echo "============================================"
echo "  OpenDesign 本地部署 - 构建"
echo "============================================"
echo ""

cd "$PROJECT_ROOT"

# ---- 加载 .env ----
if [[ -f "$SCRIPT_DIR/.env" ]]; then
    info "加载环境变量: $SCRIPT_DIR/.env"
    set -a
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/.env"
    set +a
fi

# ---- 类型检查 (可选, 加速构建时跳过) ----
if [[ "${OD_SKIP_TYPECHECK:-0}" != "1" ]]; then
    info "类型检查 (设置 OD_SKIP_TYPECHECK=1 跳过)..."
    pnpm typecheck || warn "类型检查有警告 (继续构建)"
fi

# ---- 构建 Daemon ----
if [[ "$SKIP_DAEMON" == "false" ]]; then
    info "构建 Daemon..."
    pnpm --filter @open-design/daemon build
    ok "Daemon 构建完成"
else
    warn "跳过 Daemon 构建"
fi

# ---- 构建 Web ----
if [[ "$SKIP_WEB" == "false" ]]; then
    info "构建 Web (静态导出)..."
    # 默认静态导出模式 (daemon 直接服务)
    # 如需 SSR 模式, 设置 OD_WEB_OUTPUT_MODE=server
    pnpm --filter @open-design/web build
    ok "Web 构建完成"
else
    warn "跳过 Web 构建"
fi

# ---- 验证产出 ----
echo ""
info "验证构建产出..."

DAEMON_CLI="$PROJECT_ROOT/apps/daemon/dist/cli.js"
WEB_OUT="$PROJECT_ROOT/apps/web/out"

if [[ -f "$DAEMON_CLI" ]]; then
    ok "Daemon CLI: $DAEMON_CLI"
else
    err "Daemon CLI 未找到: $DAEMON_CLI"
    exit 1
fi

if [[ -d "$WEB_OUT" ]]; then
    WEB_FILES=$(find "$WEB_OUT" -type f | wc -l)
    ok "Web 静态产出: $WEB_OUT ($WEB_FILES 个文件)"
else
    err "Web 产出未找到: $WEB_OUT"
    exit 1
fi

echo ""
echo "============================================"
echo "  构建完成!"
echo "============================================"
echo ""
echo "启动服务:"
echo "  bash $SCRIPT_DIR/start.sh"
echo ""

#!/usr/bin/env bash
# ============================================================
# OpenDesign 本地部署 - 启动 (生产模式)
# ============================================================
# 用途: 启动 daemon, 同时服务 API + Web 静态产出
# 用法: bash start.sh [--background]
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../open-design-main" && pwd)"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

BACKGROUND=false
for arg in "$@"; do
    case "$arg" in
        --background|-b) BACKGROUND=true ;;
        *)               warn "未知参数: $arg" ;;
    esac
done

echo ""
echo "============================================"
echo "  OpenDesign 本地部署 - 启动 (生产模式)"
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
else
    warn ".env 不存在, 使用默认配置"
    warn "建议先运行: bash $SCRIPT_DIR/setup.sh"
fi

# ---- 检查构建产出 ----
DAEMON_CLI="$PROJECT_ROOT/apps/daemon/dist/cli.js"
WEB_OUT="$PROJECT_ROOT/apps/web/out"

if [[ ! -f "$DAEMON_CLI" ]]; then
    err "Daemon 未构建, 请先运行: bash $SCRIPT_DIR/build.sh"
    exit 1
fi

if [[ ! -d "$WEB_OUT" ]]; then
    err "Web 未构建, 请先运行: bash $SCRIPT_DIR/build.sh"
    exit 1
fi

# ---- 端口配置 ----
PORT="${OD_PORT:-7456}"

# ---- 检查端口占用 ----
if command -v ss &>/dev/null; then
    if ss -tlnp 2>/dev/null | grep -q ":${PORT} "; then
        err "端口 $PORT 已被占用"
        err "请修改 .env 中的 OD_PORT, 或停止占用进程"
        exit 1
    fi
elif command -v lsof &>/dev/null; then
    if lsof -i ":${PORT}" &>/dev/null; then
        err "端口 $PORT 已被占用"
        exit 1
    fi
fi

# ---- 环境变量 ----
export OD_PORT="$PORT"
export NODE_ENV=production

# 静态导出模式 (daemon 直接服务)
export OD_WEB_OUTPUT_MODE=""

info "配置:"
info "  Daemon 端口: $PORT"
info "  工作目录:    $PROJECT_ROOT"
info "  Web 产出:    $WEB_OUT"
echo ""

# ---- 启动 ----
if [[ "$BACKGROUND" == "true" ]]; then
    info "后台启动..."
    mkdir -p "$SCRIPT_DIR/logs"
    nohup node "$DAEMON_CLI" \
        --port "$PORT" \
        --no-open \
        > "$SCRIPT_DIR/logs/daemon.log" 2>&1 &
    DAEMON_PID=$!
    echo "$DAEMON_PID" > "$SCRIPT_DIR/.daemon.pid"
    ok "Daemon 已启动 (PID: $DAEMON_PID)"
    ok "日志: $SCRIPT_DIR/logs/daemon.log"

    # 等待启动
    sleep 2

    # 检查是否成功启动
    if kill -0 "$DAEMON_PID" 2>/dev/null; then
        ok "进程运行中"
    else
        err "启动失败, 请检查日志: $SCRIPT_DIR/logs/daemon.log"
        rm -f "$SCRIPT_DIR/.daemon.pid"
        exit 1
    fi
else
    info "前台启动 (Ctrl+C 停止)..."
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  OpenDesign 已启动                     ║${NC}"
    echo -e "${CYAN}║                                        ║${NC}"
    echo -e "${CYAN}║  ${GREEN}http://127.0.0.1:${PORT}${CYAN}                 ║${NC}"
    echo -e "${CYAN}║                                        ║${NC}"
    echo -e "${CYAN}║  Ctrl+C 停止                           ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo ""

    node "$DAEMON_CLI" --port "$PORT" --no-open
fi

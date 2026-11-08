#!/usr/bin/env bash
# ============================================================
# OpenDesign 本地部署 - 停止
# ============================================================
# 用途: 停止运行中的 daemon 和开发服务器
# 用法: bash stop.sh
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
echo "  OpenDesign 本地部署 - 停止"
echo "============================================"
echo ""

# ---- 方法 1: 使用 tools-dev stop (推荐) ----
info "尝试使用 tools-dev stop..."
cd "$PROJECT_ROOT"

if pnpm tools-dev stop 2>/dev/null; then
    ok "tools-dev 管理的服务已停止"
else
    warn "tools-dev stop 失败或未找到运行中的服务"
fi

# ---- 方法 2: 停止 PID 文件记录的进程 ----
if [[ -f "$SCRIPT_DIR/.daemon.pid" ]]; then
    PID=$(cat "$SCRIPT_DIR/.daemon.pid")
    if kill -0 "$PID" 2>/dev/null; then
        info "停止 Daemon (PID: $PID)..."
        kill "$PID" 2>/dev/null || true
        sleep 1
        if kill -0 "$PID" 2>/dev/null; then
            warn "进程未响应, 强制终止..."
            kill -9 "$PID" 2>/dev/null || true
        fi
        ok "Daemon 已停止"
    else
        warn "PID $PID 不存在"
    fi
    rm -f "$SCRIPT_DIR/.daemon.pid"
fi

# ---- 方法 3: 清理端口占用 ----
PORT="${OD_PORT:-7456}"
info "检查端口 $PORT..."

if command -v ss &>/dev/null; then
    PIDS=$(ss -tlnp 2>/dev/null | grep ":${PORT} " | grep -oP 'pid=\K[0-9]+' || true)
elif command -v lsof &>/dev/null; then
    PIDS=$(lsof -t -i ":${PORT}" 2>/dev/null || true)
else
    PIDS=""
fi

if [[ -n "$PIDS" ]]; then
    for PID in $PIDS; do
        info "终止端口 $PORT 上的进程 (PID: $PID)..."
        kill "$PID" 2>/dev/null || true
    done
    sleep 1
    ok "端口 $PORT 已释放"
else
    ok "端口 $PORT 未被占用"
fi

echo ""
echo "============================================"
echo "  停止完成"
echo "============================================"
echo ""

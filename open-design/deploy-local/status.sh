#!/usr/bin/env bash
# ============================================================
# OpenDesign 本地部署 - 状态检查
# ============================================================
# 用途: 检查 daemon 和 web 服务状态
# 用法: bash status.sh
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
ok()    { echo -e "${GREEN}[✓]${NC}     $*"; }
fail()  { echo -e "${RED}[✗]${NC}     $*"; }
warn()  { echo -e "${YELLOW}[!]${NC}     $*"; }

echo ""
echo "============================================"
echo "  OpenDesign 本地部署 - 状态检查"
echo "============================================"
echo ""

cd "$PROJECT_ROOT"

# ---- 加载 .env ----
if [[ -f "$SCRIPT_DIR/.env" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/.env"
    set +a
fi

PORT="${OD_PORT:-7456}"

# ---- 检查构建产出 ----
info "构建产出:"

DAEMON_CLI="$PROJECT_ROOT/apps/daemon/dist/cli.js"
WEB_OUT="$PROJECT_ROOT/apps/web/out"

if [[ -f "$DAEMON_CLI" ]]; then
    DAEMON_SIZE=$(du -h "$DAEMON_CLI" | cut -f1)
    ok "Daemon CLI: $DAEMON_CLI ($DAEMON_SIZE)"
else
    fail "Daemon CLI: 未构建"
fi

if [[ -d "$WEB_OUT" ]]; then
    WEB_FILES=$(find "$WEB_OUT" -type f | wc -l)
    WEB_SIZE=$(du -sh "$WEB_OUT" | cut -f1)
    ok "Web 静态产出: $WEB_OUT ($WEB_FILES 文件, $WEB_SIZE)"
else
    fail "Web 静态产出: 未构建"
fi

echo ""

# ---- 检查运行状态 ----
info "运行状态:"

# 检查 tools-dev 状态
if pnpm tools-dev status --json 2>/dev/null | grep -q '"running"'; then
    ok "tools-dev 管理的服务: 运行中"
else
    warn "tools-dev 管理的服务: 未运行或无法检测"
fi

# 检查端口
if command -v ss &>/dev/null; then
    if ss -tlnp 2>/dev/null | grep -q ":${PORT} "; then
        PROC=$(ss -tlnp 2>/dev/null | grep ":${PORT} " | head -1)
        ok "端口 $PORT: 已监听"
        info "  $PROC"
    else
        fail "端口 $PORT: 未监听"
    fi
elif command -v lsof &>/dev/null; then
    if lsof -i ":${PORT}" &>/dev/null; then
        ok "端口 $PORT: 已监听"
    else
        fail "端口 $PORT: 未监听"
    fi
else
    warn "无法检查端口 (缺少 ss 或 lsof)"
fi

# 检查 PID 文件
if [[ -f "$SCRIPT_DIR/.daemon.pid" ]]; then
    PID=$(cat "$SCRIPT_DIR/.daemon.pid")
    if kill -0 "$PID" 2>/dev/null; then
        ok "Daemon PID: $PID (运行中)"
    else
        warn "Daemon PID: $PID (已退出)"
    fi
fi

echo ""

# ---- HTTP 健康检查 ----
info "健康检查:"

HEALTH_URL="http://127.0.0.1:${PORT}/api/health"
if command -v curl &>/dev/null; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_URL" 2>/dev/null || echo "000")
    if [[ "$HTTP_CODE" == "200" ]]; then
        ok "HTTP $HEALTH_URL → 200 OK"
    elif [[ "$HTTP_CODE" == "000" ]]; then
        fail "HTTP $HEALTH_URL → 连接失败"
    else
        warn "HTTP $HEALTH_URL → $HTTP_CODE"
    fi
else
    warn "curl 不可用, 跳过 HTTP 检查"
fi

echo ""

# ---- 访问地址 ----
if ss -tlnp 2>/dev/null | grep -q ":${PORT} " || lsof -i ":${PORT}" &>/dev/null 2>&1; then
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  访问地址:                             ║${NC}"
    echo -e "${CYAN}║  ${GREEN}http://127.0.0.1:${PORT}${CYAN}               ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
fi

echo ""

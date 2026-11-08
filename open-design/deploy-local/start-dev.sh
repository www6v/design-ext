#!/usr/bin/env bash
# ============================================================
# OpenDesign 本地部署 - 启动 (开发模式, 热重载)
# ============================================================
# 用途: 启动开发服务器, 支持热重载
# 用法: bash start-dev.sh [--ports 7457:5175]
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

DAEMON_PORT=7456
WEB_PORT=5173

for arg in "$@"; do
    case "$arg" in
        --ports)
            shift
            IFS=':' read -r DAEMON_PORT WEB_PORT <<< "$1"
            ;;
        --ports=*)
            IFS=':' read -r DAEMON_PORT WEB_PORT <<< "${arg#*=}"
            ;;
    esac
done

echo ""
echo "============================================"
echo "  OpenDesign 本地部署 - 开发模式"
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

# ---- 检查 Daemon 是否已构建 ----
DAEMON_CLI="$PROJECT_ROOT/apps/daemon/dist/cli.js"
if [[ ! -f "$DAEMON_CLI" ]]; then
    warn "Daemon 未构建, 先构建..."
    pnpm --filter @open-design/daemon build
fi

# ---- 端口配置 ----
export OD_PORT="$DAEMON_PORT"

info "配置:"
info "  Daemon 端口: $DAEMON_PORT"
info "  Web 端口:    $WEB_PORT"
echo ""

echo -e "${CYAN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  OpenDesign 开发模式                           ║${NC}"
echo -e "${CYAN}║                                                ║${NC}"
echo -e "${CYAN}║  ${GREEN}http://127.0.0.1:${WEB_PORT}${CYAN} (Web + Hot Reload)    ║${NC}"
echo -e "${CYAN}║  ${GREEN}http://127.0.0.1:${DAEMON_PORT}${CYAN} (Daemon API)       ║${NC}"
echo -e "${CYAN}║                                                ║${NC}"
echo -e "${CYAN}║  Ctrl+C 停止                                   ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════╝${NC}"
echo ""

# ---- 启动开发服务器 ----
# tools-dev run web: 前台启动 daemon + web (热重载)
pnpm tools-dev run web --daemon-port "$DAEMON_PORT" --web-port "$WEB_PORT"

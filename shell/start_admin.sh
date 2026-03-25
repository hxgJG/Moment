#!/usr/bin/env bash
# =============================================================================
# 拾光记 Moment — 启动 Web 管理后台（开发模式）
#
# 用法：
#   bash shell/start_admin.sh
#   chmod +x shell/start_admin.sh && ./shell/start_admin.sh
#
# 打开方式：
#   1. 执行本脚本会先释放默认端口 5173 上已存在的监听进程，再启动 Vite
#   2. 浏览器访问 http://localhost:5173（登录页 /login；端口可用 ADMIN_DEV_PORT 修改）
#
# 依赖：
#   - Node.js 18+、npm
#   - 后端 API 已监听 127.0.0.1:8080（脚本启动前会请求 /health；Vite 把 /api 代理到该地址）
#
# 环境变量：
#   NO_OPEN=1              不自动打开浏览器（macOS 下默认会尝试打开登录页）
#   ADMIN_DEV_PORT=…       开发服端口（默认 5173，与 admin/vite.config.js 一致）
#   SKIP_FREE_PORT=1       不尝试结束已占用端口的进程（一般勿用）
#   SKIP_BACKEND_CHECK=1   不检测后端（仅调页面时会代理失败，一般不推荐）
#   BACKEND_HEALTH_URL=…   健康检查 URL（默认 http://127.0.0.1:8080/health）
# =============================================================================

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ADMIN_DIR="${REPO_ROOT}/admin"
ADMIN_DEV_PORT="${ADMIN_DEV_PORT:-5173}"
BACKEND_HEALTH_URL="${BACKEND_HEALTH_URL:-http://127.0.0.1:8080/health}"

say() { printf '%b\n' "$*"; }

have_cmd() { command -v "$1" >/dev/null 2>&1; }

# 启动前端前检测后端是否已就绪（避免 Vite 一直报 proxy ECONNREFUSED）
backend_reachable() {
  if [[ "${SKIP_BACKEND_CHECK:-}" == "1" ]]; then
    return 0
  fi
  if have_cmd curl; then
    local code
    code="$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 2 --max-time 4 "${BACKEND_HEALTH_URL}" 2>/dev/null || echo 000)"
    [[ "${code}" == "200" ]] && return 0
  fi
  # 无 curl 时用 nc 探测 8080（先试 macOS 的 -G，再试 Linux 常见 -w）
  if have_cmd nc; then
    nc -z -G 2 127.0.0.1 8080 2>/dev/null && return 0
    nc -z -w 2 127.0.0.1 8080 2>/dev/null && return 0
  fi
  return 1
}

# 结束占用指定 TCP 监听端口的进程（用于关掉上次脚本未退出的 Vite）
free_tcp_port() {
  local port="$1"
  if [[ "${SKIP_FREE_PORT:-}" == "1" ]]; then
    return 0
  fi
  if ! have_cmd lsof; then
    say "提示：未找到 lsof，无法自动释放端口 ${port}；若启动失败请手动结束占用该端口的进程。"
    return 0
  fi

  local pids
  pids="$(lsof -nP -iTCP:"${port}" -sTCP:LISTEN -t 2>/dev/null | sort -u | tr '\n' ' ')"
  pids="${pids%% }"
  if [[ -z "${pids}" ]]; then
    return 0
  fi

  say "端口 ${port} 已被占用（PID: ${pids}），正在关闭 …"
  # shellcheck disable=SC2086
  kill ${pids} 2>/dev/null || true
  sleep 1

  pids="$(lsof -nP -iTCP:"${port}" -sTCP:LISTEN -t 2>/dev/null | sort -u | tr '\n' ' ')"
  pids="${pids%% }"
  if [[ -n "${pids}" ]]; then
    say "仍占用，执行 kill -9 …"
    # shellcheck disable=SC2086
    kill -9 ${pids} 2>/dev/null || true
    sleep 1
  fi
}

cd "${ADMIN_DIR}" || {
  say "错误：找不到管理端目录 ${ADMIN_DIR}"
  exit 1
}

if ! have_cmd npm; then
  say "错误：未找到 npm，请先安装 Node.js（建议 18+）。"
  exit 1
fi

if [[ ! -d node_modules ]]; then
  say "首次运行：正在 npm install …"
  npm install || exit 1
fi

if ! backend_reachable; then
  say ""
  say "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  say "  错误：当前连不上后端（已检测: ${BACKEND_HEALTH_URL}）"
  say "  管理端请求会经 Vite 代理到 127.0.0.1:8080，未起服务会出现 ECONNREFUSED。"
  say ""
  say "  请先启动 API，任选其一："
  say "    cd \"${REPO_ROOT}/server\" && go run ./cmd/server"
  say "    bash \"${REPO_ROOT}/shell/restart_backend.sh\""
  say ""
  say "  若 MySQL/Redis 未起，可先: docker compose up -d（见仓库 docker-compose.yml）"
  say "  仅想强行打开前端（接口仍会失败）: SKIP_BACKEND_CHECK=1 bash shell/start_admin.sh"
  say "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  say ""
  exit 1
fi

free_tcp_port "${ADMIN_DEV_PORT}"

say ""
say "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
say "  管理后台（Vite）即将启动（端口 ${ADMIN_DEV_PORT}）"
say "  本机访问: http://localhost:${ADMIN_DEV_PORT}"
say "  登录页:   http://localhost:${ADMIN_DEV_PORT}/login"
say "  后端健康检查已通过: ${BACKEND_HEALTH_URL}"
say "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
say ""

if [[ "${NO_OPEN:-}" != "1" ]] && [[ "$(uname -s)" == "Darwin" ]]; then
  (sleep 2 && open "http://localhost:${ADMIN_DEV_PORT}/login") &
fi

exec npm run dev -- --port "${ADMIN_DEV_PORT}"

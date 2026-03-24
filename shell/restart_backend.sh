#!/usr/bin/env bash
# =============================================================================
# 拾光记 Moment — 后端重启助手（面向非后端同学）
#
# 用法（任选其一）：
#   bash shell/restart_backend.sh
#   chmod +x shell/restart_backend.sh && ./shell/restart_backend.sh
#
# 说明：团队约定 MySQL+Redis 用 Docker；后端多在宿主机 go run。本脚本可协助 compose 与端口诊断。
# =============================================================================

# 不使用 set -e，避免菜单输入异常直接退出
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}" || exit 1

# 与 server/configs/config.yaml、docker-compose 默认一致
DEFAULT_HTTP_PORT="${SERVER_HTTP_PORT:-8080}"
COMPOSE_FILE="${REPO_ROOT}/docker-compose.yml"

# -----------------------------------------------------------------------------
# 工具函数
# -----------------------------------------------------------------------------

say() { printf '%b\n' "$*"; }

pause() {
  say ""
  read -r -p "按 Enter 返回菜单… " _ || true
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

compose_cmd() {
  if docker compose version >/dev/null 2>&1; then
    echo "docker compose"
  elif have_cmd docker-compose; then
    echo "docker-compose"
  else
    echo ""
  fi
}

# 监听 port 的进程 PID（每行一个），macOS / Linux 尽量兼容
pids_listening_on_port() {
  local port="$1"
  if have_cmd lsof; then
    lsof -nP -iTCP:"${port}" -sTCP:LISTEN -t 2>/dev/null | sort -u
  elif have_cmd ss; then
    ss -lntp 2>/dev/null | awk -v p=":${port}" '$0 ~ p { print $0 }' | sed -n 's/.*pid=\([0-9]*\).*/\1/p' | sort -u
  else
    say "未找到 lsof/ss，无法检测端口。请自行在系统监视器里结束占用 ${port} 的程序。"
  fi
}

describe_pids() {
  local port="$1"
  local p
  while IFS= read -r p; do
    [[ -z "${p}" ]] && continue
    if have_cmd ps; then
      say "  PID ${p}  $(ps -p "${p}" -o comm= 2>/dev/null || echo '(进程信息不可用)')"
    else
      say "  PID ${p}"
    fi
  done < <(pids_listening_on_port "${port}")
}

kill_port_listeners() {
  local port="$1"
  local pids
  pids="$(pids_listening_on_port "${port}" | tr '\n' ' ')"
  if [[ -z "${pids// }" ]]; then
    say "端口 ${port} 当前没有监听中的进程。"
    return 0
  fi
  say "即将结束以下进程（释放端口 ${port}）："
  describe_pids "${port}"
  say ""
  read -r -p "确认结束？(输入 yes 再回车) " ok
  if [[ "${ok}" != "yes" ]]; then
    say "已取消。"
    return 1
  fi
  local p
  for p in $(pids_listening_on_port "${port}"); do
    [[ -z "${p}" ]] && continue
    if kill "${p}" 2>/dev/null; then
      say "已发送结束信号 → PID ${p}"
    else
      say "无法结束 PID ${p}（可能没有权限，可尝试关闭对应终端窗口或重启电脑后再试）"
    fi
  done
  sleep 1
  if pids_listening_on_port "${port}" | grep -q .; then
    say "仍有进程占用 ${port}，可再执行本菜单项，或手动「活动监视器」搜索对应进程。"
  else
    say "端口 ${port} 已释放。"
  fi
}

curl_health() {
  local port="$1"
  if ! have_cmd curl; then
    say "未安装 curl，跳过健康检查。"
    return 0
  fi
  say "正在请求 http://127.0.0.1:${port}/health …"
  if curl -sS -m 3 "http://127.0.0.1:${port}/health"; then
    say ""
    say "（若上面是 JSON 且含正常字段，说明后端已在响应。）"
  else
    say ""
    say "请求失败：后端可能未启动，或端口不是 ${port}。"
  fi
}

# go run 首次会先编译再监听端口，仅 sleep 2 秒往往不够；轮询 /health 更稳
wait_for_health() {
  local port="$1"
  local wait_sec="${2:-60}"
  local i=0
  if ! have_cmd curl; then
    say "未安装 curl，无法自动探测是否启动成功。"
    return 1
  fi
  while (( i < wait_sec )); do
    if curl -sf -m 2 "http://127.0.0.1:${port}/health" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
    (( ++i )) || true
  done
  return 1
}

show_log_tail() {
  local logf="$1"
  local n="${2:-50}"
  if [[ -f "${logf}" ]]; then
    say "--- ${logf} 末尾 ${n} 行 ---"
    tail -n "${n}" "${logf}" 2>/dev/null || true
    say "--- 日志末尾（若见数据库/Redis 报错，先起依赖或改 config）---"
  else
    say "日志文件不存在: ${logf}"
  fi
}

docker_server_running() {
  have_cmd docker && docker ps --format '{{.Names}}' 2>/dev/null | grep -qx 'moment-server'
}

print_howto_go_run() {
  say ""
  say "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  say "标准流程：先在仓库根启动依赖，再启后端："
  say ""
  say "      cd \"${REPO_ROOT}\""
  say "      docker compose up -d mysql redis"
  say ""
  say "然后在本机启动 Go（任选终端前台或后台）："
  say "      cd \"${REPO_ROOT}/server\""
  say "      go run ./cmd/server"
  say ""
  say "前提：Docker 已安装；Go 1.21+；config 与 compose 默认一致（或已配置 config.local.yaml）。"
  say "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

print_howto_docker() {
  say ""
  say "Compose：仓库含 mysql、redis、server、admin。日常开发多只用 mysql+redis，后端本机 go run。"
  say "若用容器跑后端（moment-server），改 Go 代码后需「重新构建并启动后端」。"
}

# -----------------------------------------------------------------------------
# 菜单：环境诊断
# -----------------------------------------------------------------------------

menu_diagnose() {
  while true; do
    clear 2>/dev/null || true
    say "======== 环境诊断（不知道咋启动时先看这里）========"
    say ""
    say "仓库根目录: ${REPO_ROOT}"
    say "默认 HTTP 端口: ${DEFAULT_HTTP_PORT}（本机 go run 时以 config 为准；Docker 可用环境变量 SERVER_PORT）"
    say ""
    if docker_server_running; then
      say "● Docker：检测到正在运行的容器「moment-server」。"
    else
      say "● Docker：未检测到容器「moment-server」（可能没用 Docker 跑后端，或容器名不同）。"
    fi
    say ""
    say "● 本机端口 ${DEFAULT_HTTP_PORT}："
    if pids_listening_on_port "${DEFAULT_HTTP_PORT}" | grep -q .; then
      describe_pids "${DEFAULT_HTTP_PORT}"
    else
      say "  （当前无进程监听）"
    fi
    say ""
    curl_health "${DEFAULT_HTTP_PORT}"
    say ""
    say "1) 再测一次"
    say "0) 返回上级"
    read -r -p "请选择: " c
    case "${c}" in
      1) continue ;;
      0|"") break ;;
      *) say "无效选项" ; sleep 1 ;;
    esac
  done
}

# -----------------------------------------------------------------------------
# 菜单：Docker
# -----------------------------------------------------------------------------

menu_docker() {
  local dc
  dc="$(compose_cmd)"
  if [[ -z "${dc}" ]]; then
    say "未找到「docker compose」或「docker-compose」，请先安装 Docker Desktop 并启动。"
    pause
    return
  fi
  if [[ ! -f "${COMPOSE_FILE}" ]]; then
    say "找不到 ${COMPOSE_FILE}"
    pause
    return
  fi

  while true; do
    clear 2>/dev/null || true
    say "======== Docker Compose（库 / 缓存 / 可选后端容器）========"
    print_howto_docker
    say ""
    say "1) 只重启后端容器（moment-server）【改配置/容器卡死时常用】"
    say "2) 重新构建镜像并启动后端【改了 Go 代码后选这个】"
    say "3) 启动依赖：MySQL + Redis（数据库/缓存还没起来时）"
    say "4) 启动后端容器（依赖已 healthy 时；等价于 up -d server）"
    say "5) 停止后端容器（暂时不用后端时）"
    say "6) 重启 MySQL + Redis + 后端（整套一起重启）"
    say "7) 查看后端最近日志（约 80 行，看完回到菜单）"
    say "0) 返回上级"
    say ""
    read -r -p "请选择: " c
    case "${c}" in
      1)
        say "执行: ${dc} restart server"
        ${dc} restart server && say "完成。" || say "失败：请把终端里的英文报错复制给开发者。"
        ;;
      2)
        say "执行: ${dc} up -d --build server"
        say "（首次会较慢，需要下载基础镜像并编译）"
        ${dc} up -d --build server && say "完成。" || say "失败：请把终端里的英文报错复制给开发者。"
        ;;
      3)
        say "执行: ${dc} up -d mysql redis"
        ${dc} up -d mysql redis && say "完成。可用「docker compose ps」看 mysql/redis 是否 healthy 后再启动后端。" || say "失败。"
        ;;
      4)
        say "执行: ${dc} up -d server"
        ${dc} up -d server && say "完成。" || say "失败：若提示依赖未就绪，请先执行菜单项 3。"
        ;;
      5)
        say "执行: ${dc} stop server"
        ${dc} stop server && say "完成。" || say "失败。"
        ;;
      6)
        say "执行: ${dc} restart mysql redis server"
        ${dc} restart mysql redis server && say "完成。" || say "失败。"
        ;;
      7)
        say "执行: ${dc} logs --tail=80 server"
        ${dc} logs --tail=80 server 2>&1 || true
        ;;
      0|"") break ;;
      *) say "无效选项" ;;
    esac
    pause
  done
}

# -----------------------------------------------------------------------------
# 菜单：本机 go run
# -----------------------------------------------------------------------------

menu_local_go() {
  while true; do
    clear 2>/dev/null || true
    say "======== 本机 go run（标准：先 docker compose up mysql redis）========"
    say ""
    say "适用：宿主机跑 API；MySQL/Redis 由 Compose 提供。"
    say "常见问题：上次没关终端、或进程还在，导致端口被占用，新开一次会报错。"
    say ""
    say "1) 查看谁占用了端口 ${DEFAULT_HTTP_PORT}"
    say "2) 结束占用 ${DEFAULT_HTTP_PORT} 的进程（需输入 yes 确认）"
    say "3) 结束占用后，显示「如何再次启动」命令（推荐）"
    say "4) 结束占用并后台启动 go run（日志 /tmp/moment-server.log；首次编译可能需数十秒）"
    say "0) 返回上级"
    say ""
    read -r -p "请选择: " c
    case "${c}" in
      1)
        describe_pids "${DEFAULT_HTTP_PORT}"
        if ! pids_listening_on_port "${DEFAULT_HTTP_PORT}" | grep -q .; then
          say "当前无监听。可直接在 server 目录执行: go run ./cmd/server"
        fi
        ;;
      2) kill_port_listeners "${DEFAULT_HTTP_PORT}" ;;
      3)
        kill_port_listeners "${DEFAULT_HTTP_PORT}" || true
        print_howto_go_run
        ;;
      4)
        if ! have_cmd go; then
          say "未找到 go 命令，请先安装 Go。"
          pause
          continue
        fi
        kill_port_listeners "${DEFAULT_HTTP_PORT}" || true
        if pids_listening_on_port "${DEFAULT_HTTP_PORT}" | grep -q .; then
          say "端口仍被占用，未启动后台进程。"
          pause
          continue
        fi
        local logf="/tmp/moment-server.log"
        : >"${logf}" 2>/dev/null || true
        say "后台启动中，日志: ${logf}"
        say "说明：go run 会先编译再监听端口，脚本会最多等待约 60 秒再检查 /health。"
        ( cd "${REPO_ROOT}/server" && nohup go run ./cmd/server >>"${logf}" 2>&1 & )
        if wait_for_health "${DEFAULT_HTTP_PORT}" 60; then
          say "后端已响应。"
          curl_health "${DEFAULT_HTTP_PORT}"
        else
          say "约 60 秒内仍未访问到 /health，可能编译失败或连不上 MySQL/Redis。"
          show_log_tail "${logf}" 60
          say ""
          say "更稳妥做法：选菜单项 3，在新终端前台执行 go run，可直接看到报错。"
        fi
        say "若需停止：菜单项 2 结束占用 ${DEFAULT_HTTP_PORT} 的进程（或关闭对应终端）。"
        ;;
      0|"") break ;;
      *) say "无效选项" ;;
    esac
    pause
  done
}

menu_help() {
  clear 2>/dev/null || true
  say "======== 统一约定（各设备相同）========"
  say ""
  say "【标配】Docker 只负责 MySQL + Redis："
  say "  cd 仓库根 && docker compose up -d mysql redis"
  say "  然后 cd server && go run ./cmd/server（改代码即时生效，无需重建镜像）。"
  say ""
  say "【可选】API 也放进容器：docker compose up -d（含 moment-server）。"
  say "  改 Go 后需重建 server 镜像；且不要与宿主机 go run 同时占 8080。"
  say ""
  say "【例外】不用 Docker 时：自行安装 MySQL/Redis，用 config.local.yaml。"
  say ""
  say "不确定时：主菜单选「环境诊断」。"
  say ""
  pause
}

# -----------------------------------------------------------------------------
# 主菜单
# -----------------------------------------------------------------------------

main_menu() {
  while true; do
    clear 2>/dev/null || true
    say "╔════════════════════════════════════════════════╗"
    say "║   拾光记 Moment — 后端重启 / 启动助手          ║"
    say "╚════════════════════════════════════════════════╝"
    say ""
    say "我不确定怎么启动过后端 → 请先选 4 看环境诊断"
    say ""
    say "1) Docker Compose（起库 / 起后端容器 / 重建镜像）"
    say "2) 本机 go run 后端（约定：MySQL+Redis 已由 Compose 启动）"
    say "3) 看统一约定说明"
    say "4) 环境诊断（端口、健康检查、是否在跑 Docker 后端）"
    say "0) 退出"
    say ""
    read -r -p "请输入数字后回车: " c
    case "${c}" in
      1) menu_docker ;;
      2) menu_local_go ;;
      3) menu_help ;;
      4) menu_diagnose ; pause ;;
      0|q|Q) say "再见。" ; exit 0 ;;
      *) say "无效选项，请重新输入。" ; sleep 1 ;;
    esac
  done
}

main_menu

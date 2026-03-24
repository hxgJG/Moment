#!/usr/bin/env bash
# =============================================================================
# 拾光记 Moment — Flutter 客户端：按平台编译并安装 / 仅构建
#
# 用法：
#   ./shell/build_install_client.sh
#       无参数 → 交互菜单，输入 1、2、3… 即可
#
#   ./shell/build_install_client.sh -p android [--release] [--adb-reverse] …
#       带参数 → 非交互，与旧版一致（适合 CI / 熟练用户）
#
# 环境变量 DART_DEFINES：空格分隔 key=value → --dart-define
# Android：debug 包需 adb install -t；冲突可加 CLI --uninstall-first
# =============================================================================

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}" || exit 1

say() { printf '%b\n' "$*"; }
pause() {
  say ""
  read -r -p "按 Enter 返回菜单… " _ || true
}
have_cmd() { command -v "$1" >/dev/null 2>&1; }

INTERACTIVE=0
PLATFORM=""
DEVICE_ID=""
MODE_DEBUG=1
RUN_PUB_GET=1
ADB_REVERSE=0
UNINSTALL_FIRST=0
LIST_ONLY=0
ANDROID_PACKAGE_ID="com.moment.moment"
EXTRA_DEFINES=()

usage() {
  say "拾光记 Moment — 客户端构建/安装脚本"
  say ""
  say "【推荐】无参数运行，按菜单数字选择。"
  say ""
  say "命令行参数（非交互）："
  say "  -p, --platform   android | ios | macos | linux | web"
  say "  -d, --device     设备 ID"
  say "  --release        release 构建"
  say "  --no-pub         跳过 flutter pub get"
  say "  --adb-reverse    Android：adb reverse tcp:8080 tcp:8080"
  say "  --uninstall-first Android：先卸载再装"
  say "  --define K=V     --dart-define（可重复）"
  say "  --list           flutter devices 后退出"
  say "  -h, --help"
  say ""
  say "环境变量 DART_DEFINES：多个 key=value 空格分隔"
}

parse_cli_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--platform)
        PLATFORM="${2:-}"
        shift 2 || exit 1
        ;;
      -d|--device)
        DEVICE_ID="${2:-}"
        shift 2 || exit 1
        ;;
      --release)
        MODE_DEBUG=0
        shift
        ;;
      --no-pub)
        RUN_PUB_GET=0
        shift
        ;;
      --adb-reverse)
        ADB_REVERSE=1
        shift
        ;;
      --uninstall-first)
        UNINSTALL_FIRST=1
        shift
        ;;
      --define)
        [[ -n "${2:-}" ]] || { say "错误: --define 需要 KEY=value"; exit 1; }
        EXTRA_DEFINES+=(--dart-define="$2")
        shift 2
        ;;
      --list)
        LIST_ONLY=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        say "未知参数: $1"
        usage
        exit 1
        ;;
    esac
  done
}

collect_dart_defines() {
  FLUTTER_EXTRA_ARGS=()
  local pair
  if [[ -n "${DART_DEFINES:-}" ]]; then
    for pair in ${DART_DEFINES}; do
      [[ -z "${pair}" ]] && continue
      FLUTTER_EXTRA_ARGS+=(--dart-define="${pair}")
    done
  fi
  if ((${#EXTRA_DEFINES[@]} > 0)); then
    FLUTTER_EXTRA_ARGS+=("${EXTRA_DEFINES[@]}")
  fi
}

run_flutter_build() {
  local target="$1"
  local cmd=(flutter build "${target}" "${BUILD_MODE[@]}")
  if ((${#FLUTTER_EXTRA_ARGS[@]} > 0)); then
    cmd+=("${FLUTTER_EXTRA_ARGS[@]}")
  fi
  say ">>> ${cmd[*]}"
  "${cmd[@]}" || return 1
  return 0
}

# 多台 Android 设备时让用户选序号；0 台则提示
pick_android_device_interactive() {
  DEVICE_ID=""
  if ! have_cmd adb; then
    say "（未找到 adb，安装步骤将跳过或失败）"
    return 0
  fi
  local -a devs=()
  while IFS= read -r line; do
    [[ -n "${line}" ]] && devs+=("${line}")
  done < <(adb devices 2>/dev/null | awk -F'\t' '$2 == "device" { print $1 }')

  local n="${#devs[@]}"
  if [[ "${n}" -eq 0 ]]; then
    say "当前 adb 未发现已连接设备（需 USB 调试已授权）。"
    say "可仅生成 APK；连接设备后请再选菜单安装。"
    read -r -p "仍继续构建？(y/N) " ok
    [[ "${ok}" =~ ^[yY]$ ]] || return 1
    return 0
  fi
  if [[ "${n}" -eq 1 ]]; then
    DEVICE_ID="${devs[0]}"
    say "使用设备: ${DEVICE_ID}"
    return 0
  fi
  say "检测到多台 Android 设备："
  local i=1
  for d in "${devs[@]}"; do
    say "  ${i}) ${d}"
    ((i++)) || true
  done
  read -r -p "请输入序号 1-${n}（直接回车默认 1）: " pick
  [[ -z "${pick}" ]] && pick=1
  if ! [[ "${pick}" =~ ^[0-9]+$ ]] || [[ "${pick}" -lt 1 || "${pick}" -gt "${n}" ]]; then
    say "无效序号，已改用 1"
    pick=1
  fi
  DEVICE_ID="${devs[$((pick - 1))]}"
  say "已选设备: ${DEVICE_ID}"
  return 0
}

# iOS：可选输入设备 ID，回车交给 flutter 默认
pick_ios_device_interactive() {
  DEVICE_ID=""
  say "如需指定设备，请粘贴「flutter devices」里的设备 ID；直接回车则由 flutter 默认选择。"
  read -r -p "> " line || true
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  DEVICE_ID="${line}"
}

prompt_api_base_interactive() {
  say ""
  say "可选：临时设置 API 地址（写入本次 DART_DEFINES，覆盖 env.dart 默认）"
  say "  例: http://127.0.0.1:8080/v1  或  http://10.0.2.2:8080/v1（模拟器）"
  read -r -p "API_BASE_URL（回车跳过）: " api_url || true
  api_url="${api_url#"${api_url%%[![:space:]]*}"}"
  api_url="${api_url%"${api_url##*[![:space:]]}"}"
  if [[ -n "${api_url}" ]]; then
    export DART_DEFINES="API_BASE_URL=${api_url}"
    say "已设置 DART_DEFINES=${DART_DEFINES}"
  fi
}

execute_build_flow() {
  collect_dart_defines

  if [[ "${RUN_PUB_GET}" -eq 1 ]]; then
    say ">>> flutter pub get"
    flutter pub get || return 1
  fi

  if [[ "${MODE_DEBUG}" -eq 1 ]]; then
    BUILD_MODE=(--debug)
  else
    BUILD_MODE=(--release)
  fi

  case "${PLATFORM}" in
    android)
      if [[ "${ADB_REVERSE}" -eq 1 ]]; then
        if ! have_cmd adb; then
          say "未找到 adb，无法执行 adb reverse。"
          return 1
        fi
        if [[ -n "${DEVICE_ID}" ]]; then
          say ">>> adb -s ${DEVICE_ID} reverse tcp:8080 tcp:8080"
          adb -s "${DEVICE_ID}" reverse tcp:8080 tcp:8080 || return 1
        else
          say ">>> adb reverse tcp:8080 tcp:8080"
          adb reverse tcp:8080 tcp:8080 || return 1
        fi
      fi
      run_flutter_build apk || return 1

      local APK_NAME="app-debug.apk"
      [[ "${MODE_DEBUG}" -eq 0 ]] && APK_NAME="app-release.apk"
      local APK_PATH="${REPO_ROOT}/build/app/outputs/flutter-apk/${APK_NAME}"
      if [[ ! -f "${APK_PATH}" ]]; then
        say "未找到产物: ${APK_PATH}"
        return 1
      fi

      if ! have_cmd adb; then
        say "未找到 adb，已生成 APK："
        say "  ${APK_PATH}"
        return 0
      fi

      local -a ADB_BASE
      if [[ -n "${DEVICE_ID}" ]]; then
        ADB_BASE=(adb -s "${DEVICE_ID}")
      else
        ADB_BASE=(adb)
      fi

      if [[ "${UNINSTALL_FIRST}" -eq 1 ]]; then
        say ">>> 先卸载 ${ANDROID_PACKAGE_ID}（未安装则忽略）"
        "${ADB_BASE[@]}" uninstall "${ANDROID_PACKAGE_ID}" 2>/dev/null || true
      fi

      local -a ADB_INSTALL_FLAGS=(-r -d)
      [[ "${MODE_DEBUG}" -eq 1 ]] && ADB_INSTALL_FLAGS+=(-t)

      say ">>> ${ADB_BASE[*]} install ${ADB_INSTALL_FLAGS[*]} （APK）"
      if ! "${ADB_BASE[@]}" install "${ADB_INSTALL_FLAGS[@]}" "${APK_PATH}"; then
        say ""
        say "安装失败。可尝试菜单「先卸载再装」或命令行 --uninstall-first"
        say "详细命令：${ADB_BASE[*]} install ${ADB_INSTALL_FLAGS[*]} ${APK_PATH}"
        return 1
      fi
      say "完成：Android 已安装。"
      ;;

    ios)
      run_flutter_build ios || return 1
      local -a INSTALL_ARGS=()
      [[ "${MODE_DEBUG}" -eq 1 ]] && INSTALL_ARGS+=(--debug)
      if [[ -n "${DEVICE_ID}" ]]; then
        INSTALL_ARGS+=(-d "${DEVICE_ID}")
      fi
      if ((${#INSTALL_ARGS[@]} > 0)); then
        say ">>> flutter install ${INSTALL_ARGS[*]}"
        flutter install "${INSTALL_ARGS[@]}" || return 1
      else
        say ">>> flutter install"
        flutter install || return 1
      fi
      say "完成：iOS 已安装。"
      ;;

    macos)
      run_flutter_build macos || return 1
      say "完成：macOS 产物在 build/macos/Build/Products/"
      ;;

    linux)
      run_flutter_build linux || return 1
      say "完成：${REPO_ROOT}/build/linux/x64/release/bundle/"
      ;;

    web)
      run_flutter_build web || return 1
      say "完成：${REPO_ROOT}/build/web/"
      ;;

    *)
      say "不支持的平台: ${PLATFORM}"
      return 1
      ;;
  esac
  return 0
}

ensure_prereqs() {
  if ! have_cmd flutter; then
    say "未找到 flutter，请先安装 Flutter SDK 并加入 PATH。"
    return 1
  fi
  if [[ ! -f "${REPO_ROOT}/pubspec.yaml" ]]; then
    say "未找到 pubspec.yaml，请确认在 Moment 仓库中运行本脚本。"
    return 1
  fi
  return 0
}

menu_list_devices() {
  say ">>> flutter devices"
  flutter devices 2>&1 || true
  if have_cmd adb; then
    say ""
    say ">>> adb devices"
    adb devices 2>&1 || true
  fi
}

interactive_main() {
  while true; do
    clear 2>/dev/null || true
    say "╔════════════════════════════════════════════════╗"
    say "║   拾光记 Moment — 客户端构建 / 安装            ║"
    say "╚════════════════════════════════════════════════╝"
    say ""
    say " 1) Android — debug 安装（含 adb reverse 8080，联调本机后端）"
    say " 2) Android — debug 安装（不做 reverse）"
    say " 3) Android — release 安装"
    say " 4) Android — debug + 先卸载旧包再装（解决签名冲突/安装包异常）"
    say " 5) Android — 仅构建 APK（不安装）"
    say " 6) iOS — debug 安装"
    say " 7) iOS — release 安装"
    say " 8) macOS — 仅构建"
    say " 9) Linux — 仅构建"
    say "10) Web — 仅构建"
    say "11) 查看已连接设备（flutter / adb）"
    say "12) 自定义 API 地址（写入本次 DART_DEFINES，再选 1～10 构建）"
    say ""
    say " 0) 退出"
    say ""
    read -r -p "请输入数字后回车: " choice

    case "${choice}" in
      1)
        PLATFORM=android
        MODE_DEBUG=1
        ADB_REVERSE=1
        UNINSTALL_FIRST=0
        RUN_PUB_GET=1
        pick_android_device_interactive || {
          pause
          continue
        }
        execute_build_flow || true
        ;;
      2)
        PLATFORM=android
        MODE_DEBUG=1
        ADB_REVERSE=0
        UNINSTALL_FIRST=0
        RUN_PUB_GET=1
        pick_android_device_interactive || {
          pause
          continue
        }
        execute_build_flow || true
        ;;
      3)
        PLATFORM=android
        MODE_DEBUG=0
        ADB_REVERSE=0
        UNINSTALL_FIRST=0
        RUN_PUB_GET=1
        pick_android_device_interactive || {
          pause
          continue
        }
        execute_build_flow || true
        ;;
      4)
        PLATFORM=android
        MODE_DEBUG=1
        ADB_REVERSE=1
        UNINSTALL_FIRST=1
        RUN_PUB_GET=1
        pick_android_device_interactive || {
          pause
          continue
        }
        execute_build_flow || true
        ;;
      5)
        PLATFORM=android
        MODE_DEBUG=1
        ADB_REVERSE=0
        UNINSTALL_FIRST=0
        RUN_PUB_GET=1
        DEVICE_ID=""
        say ">>> 仅构建 debug APK（不安装）"
        collect_dart_defines
        if [[ "${RUN_PUB_GET}" -eq 1 ]]; then
          flutter pub get || true
        fi
        BUILD_MODE=(--debug)
        run_flutter_build apk || true
        say "产物: ${REPO_ROOT}/build/app/outputs/flutter-apk/app-debug.apk"
        ;;
      6)
        PLATFORM=ios
        MODE_DEBUG=1
        ADB_REVERSE=0
        UNINSTALL_FIRST=0
        RUN_PUB_GET=1
        pick_ios_device_interactive
        execute_build_flow || true
        ;;
      7)
        PLATFORM=ios
        MODE_DEBUG=0
        ADB_REVERSE=0
        UNINSTALL_FIRST=0
        RUN_PUB_GET=1
        pick_ios_device_interactive
        execute_build_flow || true
        ;;
      8)
        PLATFORM=macos
        MODE_DEBUG=1
        ADB_REVERSE=0
        UNINSTALL_FIRST=0
        RUN_PUB_GET=1
        DEVICE_ID=""
        execute_build_flow || true
        ;;
      9)
        PLATFORM=linux
        MODE_DEBUG=1
        ADB_REVERSE=0
        UNINSTALL_FIRST=0
        RUN_PUB_GET=1
        DEVICE_ID=""
        execute_build_flow || true
        ;;
      10)
        PLATFORM=web
        MODE_DEBUG=1
        ADB_REVERSE=0
        UNINSTALL_FIRST=0
        RUN_PUB_GET=1
        DEVICE_ID=""
        execute_build_flow || true
        ;;
      11)
        menu_list_devices
        ;;
      12)
        prompt_api_base_interactive
        ;;
      0|q|Q)
        say "再见。"
        exit 0
        ;;
      *)
        say "无效选项，请输入菜单上的数字。"
        ;;
    esac
    pause
  done
}

# ----------------------------------------------------------------------------- entry
if [[ $# -eq 0 ]]; then
  INTERACTIVE=1
else
  parse_cli_args "$@"
fi

if ! ensure_prereqs; then
  [[ "${INTERACTIVE}" -eq 1 ]] && pause
  exit 1
fi

if [[ "${INTERACTIVE}" -eq 1 ]]; then
  interactive_main
  exit 0
fi

if [[ "${LIST_ONLY}" -eq 1 ]]; then
  menu_list_devices
  exit 0
fi

[[ -z "${PLATFORM}" ]] && PLATFORM="android"

if ! execute_build_flow; then
  exit 1
fi
exit 0

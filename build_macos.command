#!/bin/zsh
setopt NO_NOMATCH
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/$(basename -- "$0")"
SCRIPT_BASENAME=$(basename "$0" | sed 's/\.[^.]*$//')
LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"
: > "$LOG_FILE"

log()            { echo -e "$1" | tee -a "$LOG_FILE"; }
info_echo()      { log "\033[1;34mℹ $1\033[0m"; }
success_echo()   { log "\033[1;32m✔ $1\033[0m"; }
warn_echo()      { log "\033[1;33m⚠ $1\033[0m"; }
error_echo()     { log "\033[1;31m✖ $1\033[0m"; }
highlight_echo() { log "\033[1;36m🔹 $1\033[0m"; }

show_readme_and_wait() {
  clear
  local BOLD_CYAN=$'\033[1;36m'
  local BOLD_YELLOW=$'\033[1;33m'
  local BOLD_GREEN=$'\033[1;32m'
  local BOLD_RED=$'\033[1;31m'
  local RESET=$'\033[0m'

  {
    printf "%s\n" "${BOLD_CYAN}╔════════════════════════════════════════════════════════════╗${RESET}"
    printf "%s\n" "${BOLD_CYAN}║             JobsMockTool - macOS 打包脚本说明              ║${RESET}"
    printf "%s\n" "${BOLD_CYAN}╚════════════════════════════════════════════════════════════╝${RESET}"
    printf "\n"
    printf "%s\n" "${BOLD_GREEN}当前文件：build_macos.command${RESET}"
    printf "%s\n" "用途：把 JobsMockTool 源码打包成 macOS 桌面程序，并生成可安装的 DMG。"
    printf "\n"
    printf "%s\n" "${BOLD_CYAN}JobsMockTool 是什么？${RESET}"
    printf "%s\n" "  一个本地 Mock API 桌面工具，用来在没有真实后端、接口不稳定、"
    printf "%s\n" "  或需要模拟异常数据时，快速启动本机假接口服务。"
    printf "\n"
    printf "%s\n" "${BOLD_CYAN}它主要能做什么？${RESET}"
    printf "%s\n" "  • 配置 GET / POST / PUT / PATCH / DELETE 等接口。"
    printf "%s\n" "  • 配置接口路径、端口、响应头、状态码和返回 JSON。"
    printf "%s\n" "  • 支持多接口、条件响应、配置保存 / 加载和内置请求测试。"
    printf "%s\n" "  • 让前端、iOS、Android、脚本或浏览器直接请求本机 Mock 服务。"
    printf "\n"
    printf "%s\n" "${BOLD_CYAN}本脚本接下来会做什么？${RESET}"
    printf "%s\n" "  1. 检查 python3。"
    printf "%s\n" "  2. 创建或复用当前目录的 .venv 虚拟环境。"
    printf "%s\n" "  3. 安装 requirements.txt 里的依赖。"
    printf "%s\n" "  4. 清理旧的 build / dist 构建产物。"
    printf "%s\n" "  5. 使用 PyInstaller 打包 JobsMockTool.app。"
    printf "%s\n" "  6. 生成 dist/JobsMockTool-Installer.dmg 安装包。"
    printf "\n"
    printf "%s\n" "${BOLD_YELLOW}注意：旧的 build / dist 会被删除；构建过程可能较慢，请不要关闭终端。${RESET}"
    printf "%s\n" "${BOLD_RED}首次打开 App 如被 macOS 拦截：系统设置 → 隐私与安全性 → 仍要打开。${RESET}"
    printf "\n"
    printf "%s\n" "${BOLD_CYAN}准备好后按回车开始；按 Ctrl+C 取消。${RESET}"
  } | tee -a "$LOG_FILE"

  echo ""
  read -r "?👉 按回车开始构建 JobsMockTool macOS 版：" _
}

ensure_python() {
  if ! command -v python3 >/dev/null 2>&1; then
    error_echo "未找到 python3，请先安装 Python。"
    exit 1
  fi
}

main() {
  cd "$SCRIPT_DIR"
  show_readme_and_wait
  ensure_python

  info_echo "创建 / 复用虚拟环境：${SCRIPT_DIR}/.venv"
  python3 -m venv .venv
  source .venv/bin/activate

  info_echo "安装依赖"
  python -m pip install --upgrade pip
  pip install -r requirements.txt

  info_echo "清理旧构建产物"
  rm -rf build dist

  info_echo "开始构建 macOS App。QtWebEngine 体积较大，构建时间会比 Tkinter 版更久。"
  pyinstaller \
    --noconfirm \
    --clean \
    --windowed \
    --onedir \
    --name "JobsMockTool" \
    --osx-bundle-identifier "com.jobs.mocktool" \
    --collect-all PySide6 \
    app.py

  local app_bundle="dist/JobsMockTool.app"
  local dmg_path="dist/JobsMockTool-Installer.dmg"
  local dmg_staging="dist/dmg_staging"

  if [[ ! -d "$app_bundle" ]]; then
    error_echo "未找到 ${app_bundle}，请检查 PyInstaller 输出。"
    exit 1
  fi

  info_echo "生成可拖拽安装 DMG"
  rm -rf "$dmg_staging"
  mkdir -p "$dmg_staging"
  cp -R "$app_bundle" "$dmg_staging/"
  ln -s /Applications "$dmg_staging/Applications"
  rm -f "$dmg_path"

  hdiutil create \
    -volname "JobsMockTool Installer" \
    -srcfolder "$dmg_staging" \
    -ov \
    -format UDZO \
    "$dmg_path"

  success_echo "macOS app bundle: $app_bundle"
  success_echo "macOS installer dmg: $dmg_path"
  warn_echo "如果首次打开被 Gatekeeper 拦截：系统设置 -> 隐私与安全性 -> 仍要打开。"
  info_echo "日志文件：$LOG_FILE"
}

main "$@"

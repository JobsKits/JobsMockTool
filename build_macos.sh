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
  local readme_path="${SCRIPT_DIR}/README.md"
  clear
  if [[ -f "$readme_path" ]]; then
    highlight_echo "============================== README.md =============================="
    cat "$readme_path" | tee -a "$LOG_FILE"
    highlight_echo "======================================================================="
  else
    warn_echo "未找到 README.md，继续执行内置流程说明。"
  fi
  echo ""
  read -r "?👉 已阅读自述文件，按回车继续执行；按 Ctrl+C 取消：" _
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

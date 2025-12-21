#!/usr/bin/env bash
set -Eeuo pipefail

# =================================================
#               GLOBAL SETTINGS
# =================================================
REPO_RAW_BASE="https://raw.githubusercontent.com/d34012/kcioko-install/main"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# =================================================
#                     UTILS
# =================================================
log()   { echo -e "\033[1;32m[+]\033[0m $1"; }
warn()  { echo -e "\033[1;33m[!]\033[0m $1"; }
error() { echo -e "\033[1;31m[x]\033[0m $1"; exit 1; }

pause() {
    read -rp "Нажмите Enter для продолжения..."
}

require_root() {
    if [ "$EUID" -ne 0 ]; then
        warn "Требуются права root, пробую sudo..."
        exec sudo bash "$0" "$@"
    fi
}

# =================================================
#              CORE INSTALL FUNCTION
# =================================================
install_package() {
    local package="$1"
    shift
    local files=("$@")

    local target="$WORKDIR/$package"
    mkdir -p "$target"

    log "Установка пакета: $package"

    for file in "${files[@]}"; do
        local url="$REPO_RAW_BASE/repo/$package/$file"
        log "Скачивание $file"
        curl -fL "$url" -o "$target/$file" \
            || error "Не удалось скачать $file"
    done

    chmod +x "$target/install.sh"
    (cd "$target" && ./install.sh)

    log "Пакет $package установлен"
}

# =================================================
#              PACKAGE DEFINITIONS
# =================================================
install_telegram() {
    install_package "ro-telegram" \
        "install.sh" \
        "icon.png" \
        "Telegram.desktop"
}

install_max() {
    install_package "ro-max" \
        "install.sh"
}

# =================================================
#                     MENU
# =================================================
show_menu() {
    clear
    echo "=========================================="
    echo "   Kcioko Interactive Installer"
    echo "=========================================="
    echo "1) Установить Telegram"
    echo "2) Установить MAX"
    echo "0) Выход"
    echo "=========================================="
}

# =================================================
#                     MAIN
# =================================================
require_root

while true; do
    show_menu
    read -rp "Выберите пункт: " choice

    case "$choice" in
        1)
            install_telegram
            pause
            ;;
        2)
            install_max
            pause
            ;;
        0)
            echo "Выход"
            exit 0
            ;;
        *)
            warn "Неверный пункт меню"
            pause
            ;;
    esac
done
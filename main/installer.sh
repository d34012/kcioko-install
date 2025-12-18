#!/usr/bin/env bash
set -Eeuo pipefail

# ================== НАСТРОЙКИ ==================
APP_NAME="Telegram Installer"
APP_VERSION="1.0"

TELEGRAM_URL="http://172.32.140.20/images/CFGRepo/apps/ro-telegram.tar.gz"
WORKDIR="/tmp/ro-telegram-install"
ARCHIVE_NAME="ro-telegram.tar.gz"
INSTALL_DIR_NAME="ro-telegram"
# ==============================================

# ================== ЦВЕТА ======================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
# ==============================================

log() {
    echo -e "${GREEN}[+]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

error() {
    echo -e "${RED}[x]${NC} $1"
    exit 1
}

header() {
    clear
    echo "=========================================="
    echo " $APP_NAME v$APP_VERSION"
    echo "=========================================="
    echo
}

check_requirements() {
    command -v curl >/dev/null || error "curl не установлен"
    command -v tar >/dev/null || error "tar не установлен"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        warn "Требуются права root, перезапуск через sudo"
        exec sudo bash "$0" "$@"
    fi
}

cleanup() {
    if [ -d "$WORKDIR" ]; then
        log "Очистка временных файлов"
        rm -rf "$WORKDIR"
    fi
}

install_telegram() {
    log "Установка Telegram"

    cleanup
    mkdir -p "$WORKDIR"
    cd "$WORKDIR" || error "Не удалось перейти в $WORKDIR"

    log "Скачивание архива"
    curl -fL "$TELEGRAM_URL" -o "$ARCHIVE_NAME" \
        || error "Ошибка загрузки архива"

    log "Распаковка архива"
    tar -xzf "$ARCHIVE_NAME" \
        || error "Ошибка распаковки"

    if [ ! -d "$INSTALL_DIR_NAME" ]; then
        error "Папка $INSTALL_DIR_NAME не найдена"
    fi

    if [ ! -f "$INSTALL_DIR_NAME/install.sh" ]; then
        error "Файл install.sh не найден"
    fi

    log "Запуск install.sh"
    cd "$INSTALL_DIR_NAME" || error "Не удалось перейти в каталог установки"
    chmod +x install.sh
    ./install.sh || error "Ошибка выполнения install.sh"

    cd /
    cleanup

    log "Telegram успешно установлен"
    echo
    read -rp "Нажмите Enter для возврата в меню..."
}

menu() {
    while true; do
        header
        echo "1) Установить Telegram"
        echo "0) Выход"
        echo
        read -rp "Выберите пункт: " choice

        case "$choice" in
            1) install_telegram ;;
            0) exit 0 ;;
            *) warn "Неверный пункт меню" ;;
        esac
    done
}

main() {
    header
    check_requirements
    check_root "$@"
    menu
}

main "$@"

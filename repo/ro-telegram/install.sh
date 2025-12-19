#!/usr/bin/env bash
set -Eeuo pipefail

# ================= НАСТРОЙКИ =================
TELEGRAM_URL="http://172.32.140.20/images/LOCALRepo/telegram/tsetup.6.3.9.tar.xz"

INSTALL_DIR="/opt"
APP_DIR="/opt/Telegram"
DESKTOP_FILE="/usr/local/share/applications/Telegram.desktop"
# ============================================

log() {
    echo "[+] $1"
}

error() {
    echo "[x] $1"
    exit 1
}

# Проверка root
if [ "$EUID" -ne 0 ]; then
    echo "Требуются права root"
    exec sudo bash "$0" "$@"
fi

# Директория, где лежит install.sh, icon.png, Telegram.desktop
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Временная директория
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

cd "$WORKDIR"

log "Скачивание Telegram из локального репозитория"
curl -fL "$TELEGRAM_URL" -o telegram.tar.xz \
    || error "Не удалось скачать архив Telegram"

log "Распаковка в /opt"
tar -xf telegram.tar.xz -C "$INSTALL_DIR" \
    || error "Ошибка распаковки архива"

# Проверка
[ -d "$APP_DIR" ] || error "Каталог /opt/Telegram не найден"

log "Копирование icon.png"
cp "$SCRIPT_DIR/icon.png" "$APP_DIR/" \
    || error "icon.png не найден"

log "Копирование Telegram.desktop"
cp "$SCRIPT_DIR/Telegram.desktop" "$DESKTOP_FILE" \
    || error "Telegram.desktop не найден"

log "Установка прав доступа"
chmod 0755 "$DESKTOP_FILE"
chmod -R 0755 "$APP_DIR"

log "Telegram успешно установлен"

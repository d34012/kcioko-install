#!/usr/bin/env bash
set -Eeuo pipefail

# ================= НАСТРОЙКИ =================
ASSISTANT_URL="https://мойассистент.рф/скачать/Download/1376"
TMP_DIR="/tmp/ro-assistant"
PACKAGE_NAME="assistant-fstek.x86_64"
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
    echo "[!] Требуются права root"
    exec sudo bash "$0" "$@"
fi

log "Подготовка временной директории"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

log "Проверка установленного ассистента"
if dnf list installed 2>/dev/null | grep -q "^${PACKAGE_NAME}"; then
    log "Найден установленный ассистент — удаление"
    dnf remove -y "$PACKAGE_NAME" \
        || error "Не удалось удалить установленный ассистент"
else
    log "Установленный ассистент не найден"
fi

log "Скачивание ассистента"
curl -fL -o assistant.rpm "$ASSISTANT_URL" \
    || error "Ошибка загрузки ассистента"

log "Установка ассистента"
rpm -i assistant*.rpm \
    || error "Ошибка установки ассистента"

log "Очистка временных файлов"
cd /
rm -rf "$TMP_DIR"

log "Ассистент успешно установлен"
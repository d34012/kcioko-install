#!/usr/bin/env bash
set -Eeuo pipefail

# ================= НАСТРОЙКИ =================
ASSISTANT_URL="https://мойассистент.рф/скачать/Download/1376"
TMP_DIR="/tmp/ro-assistant"
PACKAGE_PREFIX="assistant-fstek"
# ============================================

log()   { echo "[+] $1"; }
error() { echo "[x] $1"; exit 1; }

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
INSTALLED_PACKAGES=$(dnf list installed 2>/dev/null | awk '{print $1}' | grep "^${PACKAGE_PREFIX}-")
if [[ -n "$INSTALLED_PACKAGES" ]]; then
    log "Найдено установленных пакетов $PACKAGE_PREFIX: $INSTALLED_PACKAGES"
    dnf remove -y $INSTALLED_PACKAGES \
        || error "Не удалось удалить старый ассистент"
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
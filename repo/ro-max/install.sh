#!/usr/bin/env bash
set -Eeuo pipefail

# ================= НАСТРОЙКИ =================
REPO_FILE="/etc/yum.repos.d/max.repo"
REPO_NAME="MAX Desktop"
GPG_KEY_URL="https://download.max.ru/linux/rpm/public.asc"
BASEURL="http://172.32.140.20/images/REDOS7MAX/"
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

log "Удаление старой установки MAX (если есть)"
rm -rf /opt/MAX || true

log "Создание репозитория MAX"
tee "$REPO_FILE" >/dev/null <<EOF
[max]
name=$REPO_NAME
baseurl=$BASEURL
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=$GPG_KEY_URL
sslverify=0
metadata_expire=300
EOF

log "Импорт GPG-ключа"
rpm --import "$GPG_KEY_URL" \
    || error "Не удалось импортировать GPG-ключ"

log "Очистка кэша dnf"
dnf clean all

log "Установка пакета MAX"
dnf install -y MAX \
    || error "Ошибка установки MAX"

log "MAX успешно установлен"
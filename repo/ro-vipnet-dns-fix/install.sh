#!/usr/bin/env bash
set -Eeuo pipefail

# =================================================
# НАСТРОЙКИ
# =================================================

SERVICE_NAME="vipnet-dns-fix.service"

SCRIPT_PATH="/usr/local/bin/vipnet-dns-fix.sh"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"

# =================================================
# ФУНКЦИИ
# =================================================

log() {
    echo "[+] $1"
}

warn() {
    echo "[!] $1"
}

error() {
    echo "[x] $1"
    exit 1
}

# =================================================
# ROOT
# =================================================

if [ "$EUID" -ne 0 ]; then
    echo "[!] Требуются права root"
    exec sudo bash "$0" "$@"
fi

# =================================================
# ПРОВЕРКА IPTABLES
# =================================================

command -v iptables >/dev/null 2>&1 \
    || error "Не найден iptables"

# =================================================
# ПРОВЕРКА ПРЕДЫДУЩЕЙ УСТАНОВКИ
# =================================================

if systemctl list-unit-files --type=service | grep -q "^${SERVICE_NAME}"; then

    log "Обнаружена предыдущая установка"

    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log "Остановка сервиса"
        systemctl stop "$SERVICE_NAME"
    fi

else
    log "Предыдущая установка не обнаружена"
fi

# =================================================
# УДАЛЕНИЕ СТАРЫХ ФАЙЛОВ
# =================================================

log "Удаление старых файлов"

rm -f "$SCRIPT_PATH"
rm -f "$SERVICE_PATH"

# =================================================
# СОЗДАНИЕ СКРИПТА
# =================================================

log "Создание $SCRIPT_PATH"

cat > "$SCRIPT_PATH" << 'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

command -v iptables >/dev/null 2>&1 || exit 1

while true
do
    if iptables -t nat -D PREROUTING -p udp --dport 53 -j VIPNETCLIENT 2>/dev/null; then
        echo "$(date '+%F %T') - Удалено правило PREROUTING VIPNETCLIENT"
    fi

    if iptables -t nat -D OUTPUT -p udp --dport 53 -j VIPNETCLIENT 2>/dev/null; then
        echo "$(date '+%F %T') - Удалено правило OUTPUT VIPNETCLIENT"
    fi

    sleep 5
done
EOF

chmod 755 "$SCRIPT_PATH"

# =================================================
# СОЗДАНИЕ SYSTEMD SERVICE
# =================================================

log "Создание systemd сервиса"

cat > "$SERVICE_PATH" << EOF
[Unit]
Description=Fix VIPNet DNS hijacking
After=network.target vipnetclient.service
Wants=vipnetclient.service

[Service]
Type=simple
ExecStart=${SCRIPT_PATH}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# =================================================
# SYSTEMD
# =================================================

log "Обновление конфигурации systemd"

systemctl daemon-reload

# =================================================
# ВКЛЮЧЕНИЕ И ЗАПУСК
# =================================================

log "Включение автозапуска"

systemctl enable --now "$SERVICE_NAME"

# =================================================
# ПРОВЕРКА
# =================================================

if systemctl is-active --quiet "$SERVICE_NAME"; then
    log "Сервис успешно запущен"
else
    error "Не удалось запустить сервис"
fi

echo
systemctl --no-pager --full status "$SERVICE_NAME"

echo
log "Установка завершена"
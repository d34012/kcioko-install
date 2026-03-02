#!/usr/bin/env bash
set -Eeuo pipefail

log()   { echo "[+] $1"; }
warn()  { echo "[!] $1"; }
error() { echo "[x] $1"; exit 1; }

# root
if [ "$EUID" -ne 0 ]; then
    exec sudo bash "$0" "$@"
fi

# =================================================
# 1. ВЫБОР ОРГАНИЗАЦИИ
# =================================================
echo "Выберите организацию:"
select ORG in "КЦИОКО" "МИНОБР"; do
    [[ -n "$ORG" ]] && break
    echo "Неверный выбор"
done

# =================================================
# 2. ВЫБОР ПОЛЬЗОВАТЕЛЯ
# =================================================
mapfile -t USERS < <(
    awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd
)

[ "${#USERS[@]}" -gt 0 ] || error "Пользователи не найдены"

echo
echo "Выберите пользователя:"
select USERNAME in "${USERS[@]}"; do
    [[ -n "$USERNAME" ]] && break
    echo "Неверный выбор"
done

# =================================================
# 3. СОЗДАНИЕ ДИРЕКТОРИЙ
# =================================================
if [[ "$ORG" == "КЦИОКО" ]]; then
    BASE_DIR="/mnt/kcioko"
    mkdir -p /mnt/kcioko/{inform,obmen,otdel}
    CRED_FILE="/root/.smbuser"
    SERVER="172.32.120.50"
    DOMAIN="kcioko"
    DEFAULT_PASS="123qwe!@#"
else
    BASE_DIR="/mnt/minobr"
    mkdir -p /mnt/minobr
    CRED_FILE="/root/.smbuser_minobr"
    SERVER="10.164.216.9"
    DOMAIN="minobr"
    DEFAULT_PASS="111111Qq"
fi

log "Каталоги созданы"

# =================================================
# 4-5. СОЗДАНИЕ ФАЙЛА УЧЕТНЫХ ДАННЫХ
# =================================================
echo
read -rp "Использовать пароль по умолчанию? (y/n): " USE_DEFAULT

if [[ "$USE_DEFAULT" =~ ^[Yy]$ ]]; then
    PASSWORD="$DEFAULT_PASS"
else
    read -rsp "Введите пароль: " PASSWORD
    echo
fi

cat > "$CRED_FILE" <<EOF
username=$USERNAME
password=$PASSWORD
domain=$DOMAIN
EOF

chmod 400 "$CRED_FILE"
log "Файл учетных данных создан: $CRED_FILE"

# =================================================
# 6. ДОБАВЛЕНИЕ В FSTAB (без дублей)
# =================================================
add_fstab_entry() {
    local ENTRY="$1"
    grep -qF "$ENTRY" /etc/fstab || echo "$ENTRY" >> /etc/fstab
}

if [[ "$ORG" == "КЦИОКО" ]]; then
    add_fstab_entry "//172.32.120.50/inform  /mnt/kcioko/inform  cifs  credentials=/root/.smbuser,iocharset=utf8,file_mode=0777,dir_mode=0777,noperm  0 0"
    add_fstab_entry "//172.32.120.50/obmen   /mnt/kcioko/obmen   cifs  credentials=/root/.smbuser,iocharset=utf8,file_mode=0777,dir_mode=0777,noperm  0 0"
    add_fstab_entry "//172.32.120.50/otdel   /mnt/kcioko/otdel   cifs  credentials=/root/.smbuser,iocharset=utf8,file_mode=0777,dir_mode=0777,noperm  0 0"
else
    add_fstab_entry "//10.164.216.9/public  /mnt/minobr  cifs  credentials=/root/.smbuser_minobr,iocharset=utf8,file_mode=0777,dir_mode=0777,noperm  0 0"
fi

log "Записи в /etc/fstab добавлены"

# =================================================
# 7. СОЗДАНИЕ SYSTEMD SERVICE
# =================================================
SERVICE_FILE="/etc/systemd/system/mount-a.service"

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Run mount -a after network is up
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/mount -a
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable mount-a.service

log "Service создан и включен"

# =================================================
# 8. ПРОВЕРКА MOUNT
# =================================================
while true; do
    if systemctl start mount-a.service; then
        log "Сетевые папки успешно подключены"
        break
    else
        warn "Ошибка подключения. Возможно неверный пароль или нет доступа."
        echo "1) Попробовать снова"
        echo "2) Завершить"
        read -rp "Выбор: " RETRY

        if [[ "$RETRY" == "1" ]]; then
            read -rsp "Введите новый пароль: " PASSWORD
            echo
            sed -i "s/^password=.*/password=$PASSWORD/" "$CRED_FILE"
        else
            error "Процедура завершена"
        fi
    fi
done

log "Готово."
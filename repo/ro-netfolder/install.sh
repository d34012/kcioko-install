#!/usr/bin/env bash
set -Eeuo pipefail

log()   { echo "[+] $1"; }
warn()  { echo "[!] $1"; }
error() { echo "[x] $1"; exit 1; }

# =================================================
# ROOT CHECK
# =================================================
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

USER_HOME="$(getent passwd "$USERNAME" | cut -d: -f6)"
[ -d "$USER_HOME" ] || error "Домашний каталог пользователя не найден"

# =================================================
# ОПРЕДЕЛЕНИЕ РАБОЧЕГО СТОЛА
# =================================================
if [ -d "$USER_HOME/Desktop" ]; then
    DESKTOP_DIR="$USER_HOME/Desktop"
elif [ -d "$USER_HOME/Рабочий стол" ]; then
    DESKTOP_DIR="$USER_HOME/Рабочий стол"
else
    DESKTOP_DIR="$USER_HOME/Desktop"
    mkdir -p "$DESKTOP_DIR"
    chown "$USERNAME:$USERNAME" "$DESKTOP_DIR"
fi

# =================================================
# 3. СОЗДАНИЕ ДИРЕКТОРИЙ
# =================================================
if [[ "$ORG" == "КЦИОКО" ]]; then
    mkdir -p /mnt/kcioko/{inform,obmen,otdel}
    CRED_FILE="/root/.smbuser"
    DOMAIN="kcioko"
    DEFAULT_PASS="123qwe!@#"
else
    mkdir -p /mnt/minobr
    CRED_FILE="/root/.smbuser_minobr"
    DOMAIN="minobr"
    DEFAULT_PASS="111111Qq"

    # Исправление username для МИНОБР
    if [[ "$USERNAME" =~ ^([0-9]+-user)-[0-9]+$ ]]; then
        USERNAME_CRED="${BASH_REMATCH[1]}"
    else
        USERNAME_CRED="$USERNAME"
    fi
fi

log "Каталоги созданы"

# =================================================
# 4. СОЗДАНИЕ ФАЙЛА УЧЕТНЫХ ДАННЫХ
# =================================================
echo
read -rp "Использовать пароль по умолчанию? (y/n): " USE_DEFAULT

if [[ "$USE_DEFAULT" =~ ^[Yy]$ ]]; then
    PASSWORD="$DEFAULT_PASS"
else
    read -rsp "Введите пароль: " PASSWORD
    echo
fi

# Для КЦИОКО username обычный
if [[ "$ORG" == "КЦИОКО" ]]; then
    USERNAME_CRED="$USERNAME"
fi

cat > "$CRED_FILE" <<EOF
username=$USERNAME_CRED
password=$PASSWORD
domain=$DOMAIN
EOF

chmod 400 "$CRED_FILE"
log "Файл учетных данных создан: $CRED_FILE"

# =================================================
# 5. ДОБАВЛЕНИЕ В /etc/fstab
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
# 6. SYSTEMD SERVICE
# =================================================
cat > /etc/systemd/system/mount-a.service <<EOF
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

# =================================================
# 7. ПРОВЕРКА MOUNT
# =================================================
while true; do
    if systemctl start mount-a.service; then
        log "Сетевые папки успешно подключены"
        break
    else
        warn "Ошибка подключения. Возможно неверный пароль."
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

# =================================================
# 8. СОЗДАНИЕ ССЫЛОК НА РАБОЧЕМ СТОЛЕ
# =================================================
create_link() {
    local TARGET="$1"
    local NAME="$2"
    local LINK_PATH="$DESKTOP_DIR/$NAME"

    if [ -L "$LINK_PATH" ] || [ -e "$LINK_PATH" ]; then
        rm -rf "$LINK_PATH"
    fi

    ln -s "$TARGET" "$LINK_PATH"
    chown -h "$USERNAME:$USERNAME" "$LINK_PATH"

    log "Создана ссылка: $NAME"
}

if [[ "$ORG" == "КЦИОКО" ]]; then
    create_link "/mnt/kcioko/inform" "КЦИОКО_Информ"
    create_link "/mnt/kcioko/obmen"  "КЦИОКО_Обмен"
    create_link "/mnt/kcioko/otdel"  "КЦИОКО_Отдел"
else
    create_link "/mnt/minobr" "МИНОБР_Public"
fi

log "Ссылки созданы на рабочем столе пользователя"
log "Готово."
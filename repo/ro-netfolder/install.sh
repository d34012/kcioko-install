#!/usr/bin/env bash
set -Eeuo pipefail

log(){ echo "[+] $1"; }
warn(){ echo "[!] $1"; }
error(){ echo "[x] $1"; exit 1; }

if [ "$EUID" -ne 0 ]; then
    exec sudo bash "$0" "$@"
fi

############################################
# 1. ВЫБОР СЕТИ
############################################

echo "Выберите сеть:"
echo "1) КЦИОКО"
echo "2) МИНОБР"

read -rp "Выбор: " NET

case "$NET" in
1)
    TYPE="kcioko"
    ;;
2)
    TYPE="minobr"
    ;;
*)
    error "Неверный выбор"
;;
esac

############################################
# 2. ВЫБОР ПОЛЬЗОВАТЕЛЯ
############################################

mapfile -t USERS < <(
awk -F: '$3>=1000 && $3<65534 {print $1}' /etc/passwd
)

echo
echo "Выберите пользователя:"
select USERNAME in "${USERS[@]}"; do
    [[ -n "$USERNAME" ]] && break
done

USER_HOME=$(getent passwd "$USERNAME" | cut -d: -f6)

############################################
# DESKTOP
############################################

if [ -d "$USER_HOME/Desktop" ]; then
    DESKTOP="$USER_HOME/Desktop"
elif [ -d "$USER_HOME/Рабочий стол" ]; then
    DESKTOP="$USER_HOME/Рабочий стол"
else
    DESKTOP="$USER_HOME/Desktop"
    mkdir -p "$DESKTOP"
    chown "$USERNAME:$USERNAME" "$DESKTOP"
fi

############################################
# USERNAME FIX FOR MINOBR
############################################

SMB_USER="$USERNAME"

if [[ "$TYPE" == "minobr" ]]; then
    if [[ "$USERNAME" =~ ^([0-9]+-user)-[0-9]+$ ]]; then
        SMB_USER="${BASH_REMATCH[1]}"
    fi
fi

############################################
# 3. СОЗДАНИЕ ПАПОК
############################################

if [[ "$TYPE" == "kcioko" ]]; then
    log "Создание папок КЦИОКО"

    mkdir -p /mnt/kcioko/{inform,obmen,otdel}

else
    log "Создание папки МИНОБР"

    mkdir -p /mnt/minobr
fi

############################################
# 4. SMB USER FILE
############################################

if [[ "$TYPE" == "kcioko" ]]; then

SMBFILE="/root/.smbuser"

cat > "$SMBFILE" <<EOF
username=$SMB_USER
password=123456
domain=kcioko
EOF

chmod 400 "$SMBFILE"

else

SMBFILE="/root/.smbuser_minobr"

cat > "$SMBFILE" <<EOF
username=$SMB_USER
password=111111Qq
domain=minobr
EOF

chmod 400 "$SMBFILE"

fi

############################################
# 5. FSTAB
############################################

log "Добавление записей в fstab"

if [[ "$TYPE" == "kcioko" ]]; then

grep -q "172.32.120.50/inform" /etc/fstab || \
echo "//172.32.120.50/inform /mnt/kcioko/inform cifs credentials=/root/.smbuser,iocharset=utf8,file_mode=0777,dir_mode=0777,noperm 0 0" >> /etc/fstab

grep -q "172.32.120.50/obmen" /etc/fstab || \
echo "//172.32.120.50/obmen /mnt/kcioko/obmen cifs credentials=/root/.smbuser,iocharset=utf8,file_mode=0777,dir_mode=0777,noperm 0 0" >> /etc/fstab

grep -q "172.32.120.50/otdel" /etc/fstab || \
echo "//172.32.120.50/otdel /mnt/kcioko/otdel cifs credentials=/root/.smbuser,iocharset=utf8,file_mode=0777,dir_mode=0777,noperm 0 0" >> /etc/fstab

else

grep -q "10.164.216.9/public" /etc/fstab || \
echo "//10.164.216.9/public /mnt/minobr cifs credentials=/root/.smbuser_minobr,iocharset=utf8,file_mode=0777,dir_mode=0777,noperm 0 0" >> /etc/fstab

fi

############################################
# 6. MOUNT RETRY SCRIPT
############################################

log "Создание mount-retry.sh"

cat > /usr/local/bin/mount-retry.sh <<'EOF'
#!/usr/bin/env bash

while true
do
    mount -a

    if [ $? -eq 0 ]; then
        echo "Mount success"
        exit 0
    fi

    echo "Mount failed. Retry in 10 seconds..."
    sleep 10
done
EOF

chmod +x /usr/local/bin/mount-retry.sh

############################################
# 7. SYSTEMD SERVICE
############################################

log "Создание systemd сервиса"

cat > /etc/systemd/system/mount-a.service <<EOF
[Unit]
Description=Auto mount network shares until success
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/mount-retry.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable mount-a.service

############################################
# 8. ЗАПУСК
############################################

if systemctl start mount-a.service; then
    log "Сервис запущен"
else
    warn "Ошибка монтирования. Возможно неверный пароль."
fi

############################################
# 9. СИМЛИНКИ НА РАБОЧИЙ СТОЛ
############################################

log "Создание ссылок на рабочем столе"

if [[ "$TYPE" == "kcioko" ]]; then

ln -sf /mnt/kcioko/inform "$DESKTOP/inform"
ln -sf /mnt/kcioko/obmen "$DESKTOP/obmen"
ln -sf /mnt/kcioko/otdel "$DESKTOP/otdel"

chown "$USERNAME:$USERNAME" "$DESKTOP"/inform
chown "$USERNAME:$USERNAME" "$DESKTOP"/obmen
chown "$USERNAME:$USERNAME" "$DESKTOP"/otdel

else

ln -sf /mnt/minobr "$DESKTOP/minobr"
chown "$USERNAME:$USERNAME" "$DESKTOP/minobr"

fi

log "Готово"
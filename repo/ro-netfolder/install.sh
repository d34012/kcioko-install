#!/usr/bin/env bash
set -Eeuo pipefail

# =================================================
#                 НАСТРОЙКИ
# =================================================
ICON_NAME="caja-actions"

# Описание сетевых папок
# format: NAME|SHARE|HOST|PATH
NETFOLDERS=(
    "Сетевая папка (Кциоко)|kcioko|172.32.120.50|"
    "Сетевая папка (Минобр)|minobr|10.164.216.9|/public"
)
# =================================================

log()   { echo "[+] $1"; }
error() { echo "[x] $1"; exit 1; }

# Проверка root
if [ "$EUID" -ne 0 ]; then
    exec sudo bash "$0" "$@"
fi

# =================================================
#          ВЫБОР ПОЛЬЗОВАТЕЛЯ
# =================================================
mapfile -t USERS < <(
    awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd
)

[ "${#USERS[@]}" -gt 0 ] || error "Пользователи не найдены"

echo "Выберите пользователя:"
select USERNAME in "${USERS[@]}"; do
    [[ -n "$USERNAME" ]] && break
    echo "Неверный выбор"
done

USER_HOME="$(getent passwd "$USERNAME" | cut -d: -f6)"

# Определение Desktop
if [ -d "$USER_HOME/Desktop" ]; then
    DESKTOP_DIR="$USER_HOME/Desktop"
elif [ -d "$USER_HOME/Рабочий стол" ]; then
    DESKTOP_DIR="$USER_HOME/Рабочий стол"
else
    error "Не найден рабочий стол пользователя $USERNAME"
fi

# =================================================
#          ВЫБОР СЕТЕВОЙ ПАПКИ
# =================================================
echo
echo "Выберите сетевую папку:"
echo "0) Установить ВСЕ"
select ITEM in "${NETFOLDERS[@]}"; do
    if [[ "$REPLY" == "0" ]]; then
        MODE="all"
        break
    elif [[ -n "$ITEM" ]]; then
        MODE="one"
        SELECTED="$ITEM"
        break
    else
        echo "Неверный выбор"
    fi
done

# =================================================
#         ФУНКЦИЯ СОЗДАНИЯ ЯРЛЫКА
# =================================================
create_shortcut() {
    local entry="$1"

    IFS="|" read -r NAME SHARE HOST PATH <<<"$entry"

    local FILE_NAME="${NAME}.desktop"
    local FILE_PATH="${DESKTOP_DIR}/${FILE_NAME}"

    local URL="smb://${SHARE};${USERNAME}@${HOST}${PATH}"

    log "Создание ярлыка: $NAME"

    cat > "$FILE_PATH" <<EOF
[Desktop Entry]
Name=${NAME}
Type=Application
Exec=caja ${URL}
Icon=${ICON_NAME}
Terminal=false
Categories=Network;FileManager;
StartupNotify=true
EOF

    chmod 755 "$FILE_PATH"
    chown "$USERNAME:$USERNAME" "$FILE_PATH"
}

# =================================================
#                   УСТАНОВКА
# =================================================
if [[ "$MODE" == "all" ]]; then
    for entry in "${NETFOLDERS[@]}"; do
        create_shortcut "$entry"
    done
else
    create_shortcut "$SELECTED"
fi

log "Готово. Ярлыки созданы для пользователя $USERNAME"

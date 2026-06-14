#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../config.sh
source "$(dirname "$0")/../config.sh"

lock="󰌾  Lock"
logout="󰍃  Log out"
reboot="󰜉  Reboot"
shutdown="󰐥  Shutdown"
firmware="󰍛  Reboot into UEFI"
killall="󱚡  Kill open Apps"

chosen=$(printf '%s\n' "$lock" "$logout" "$reboot" "$firmware" "$shutdown" "$killall" \
    | rofi -dmenu -p "Power" -theme "$ROFI_THEME_POWER") || exit 0

case "$chosen" in
    "$lock")      hyprlock ;;
    "$logout")    hyprshutdown -vt 2;;
    "$reboot")    systemctl reboot ;;
    "$firmware")  systemctl reboot --firmware-setup ;;
    "$shutdown")  systemctl poweroff ;;
    "$killall")   hyprctl -j clients | grep -o '"pid": [0-9]*' | grep -o '[0-9]*' | xargs kill ;;
esac

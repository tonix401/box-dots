#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../config.sh
source "$(dirname "$0")/../config.sh"

command -v cliphist &>/dev/null || { notify-send "Clipboard" "cliphist is not installed"; exit 1; }

cliphist list \
    | rofi -dmenu -p "Clipboard" -theme "$ROFI_THEME_CLIPBOARD" \
    | cliphist decode \
    | wtype -

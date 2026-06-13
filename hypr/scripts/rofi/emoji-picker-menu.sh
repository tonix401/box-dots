#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../config.sh
source "$(dirname "$0")/../config.sh"

command -v rofimoji &>/dev/null || { notify-send "Emoji" "rofimoji is not installed"; exit 1; }

rofimoji \
    --action clipboard \
    --skin-tone neutral \
    --prompt "Emoji " --selector-args "-theme $ROFI_THEME_EMOJI"

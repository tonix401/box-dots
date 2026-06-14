#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../config.sh
source "$(dirname "$0")/../config.sh"

command -v cliphist &>/dev/null || { notify-send "Clipboard" "cliphist is not installed"; exit 1; }

THUMB_DIR="${XDG_RUNTIME_DIR:-/tmp}/cliphist-thumbs"
mkdir -p "$THUMB_DIR"
HELPER_DIR="$(dirname "$0")/../helpers"

ENTRIES=$(mktemp)
trap "rm -f '$ENTRIES'" EXIT

cliphist list > "$ENTRIES"

# Generate thumbnails for image entries in parallel
"$HELPER_DIR/generate-thumbs.py" "$THUMB_DIR" < "$ENTRIES"

# Build rofi input: image entries get icon paths, text entries get color formatting
{
    while IFS=$'\t' read -r id rest; do
        if [[ "$rest" == *"[[ binary data"* ]]; then
            thumb="$THUMB_DIR/$id.png"
            if [[ -f "$thumb" ]]; then
                printf '%s\t%s\0icon\x1f%s\n' "$id" "$rest" "$thumb"
            else
                printf '%s\t%s\n' "$id" "$rest"
            fi
        else
            printf '%s\t%s\n' "$id" "$rest"
        fi
    done < "$ENTRIES"
} | "$HELPER_DIR/format-clipboard.py" \
  | rofi -dmenu -p "Clipboard" -theme "$ROFI_THEME_CLIPBOARD" -markup-rows \
  | cliphist decode \
  | wl-copy

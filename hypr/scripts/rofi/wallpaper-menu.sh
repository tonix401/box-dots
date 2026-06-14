#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../config.sh
source "$(dirname "$0")/../config.sh"

mapfile -d '' paths < <(find "$WALLPAPERS_DIR" -maxdepth 1 -type f \
    \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \
       -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.bmp" -o -iname "*.tiff" \) \
    -print0 | sort -z)

[ ${#paths[@]} -eq 0 ] && { notify-send "Wallpaper" "No images found in $WALLPAPERS_DIR"; exit 1; }

"$(dirname "$0")/../helpers/prepare-wallpaper-files.py" > /dev/null || true

gen_entries() {
    for src in "${paths[@]}"; do
        base=$(basename "$src")
        name="${base%.*}"
        thumb="$WALLPAPERS_THUMB_DIR/${name}.png"
        printf '%s\0icon\x1f%s\n' "$name" "$thumb"
    done
}

idx=$(gen_entries | rofi -dmenu -p "Wallpaper" -show-icons -theme "$ROFI_THEME_WALLPAPER" -format i) || exit 0

src="${paths[$idx]}"
base=$(basename "$src")
name="${base%.*}"
dest="$WALLPAPERS_OUT_DIR/${name}.png"
IMAGE=$([[ -f "$dest" ]] && echo "$dest" || echo "$src")

matugen image "$IMAGE" --prefer saturation

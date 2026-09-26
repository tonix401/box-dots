#!/usr/bin/env bash
SRC="$HOME/Pictures/waybar-gifs"
DST="$HOME/.cache/box-dots"

mkdir -p "$SRC"

# Process any GIFs already in source dir on startup
for f in "$SRC"/*.gif "$SRC"/*.GIF; do
  [ -f "$f" ] || continue
  name="$(basename "$f")"
  magick "$f" -coalesce -resize x30 "$DST/$name"
done

# Watch for new GIFs dropped into the source folder
/usr/bin/inotifywait -m -e close_write,moved_to --format "%f" "$SRC" | while read -r name; do
  case "$name" in
    *.gif|*.GIF)
      magick "$SRC/$name" -coalesce -resize x30 "$DST/$name"
      ;;
  esac
done

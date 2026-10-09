#!/bin/sh
# Installs Kitty Cam's launcher for wherever this folder is: a desktop entry and its icon, under
# $XDG_DATA_HOME (~/.local/share). Run it again after moving the folder.
#
#   ./install.sh                  the launcher runs kitty-cam as it is
#   ./install.sh --theme FILE     ... with --theme FILE (colours from a matugen palette, see README.md)
#   ./install.sh --uninstall      remove the launcher and the icon again
set -eu

here=$(cd "$(dirname "$0")" && pwd)
data=${XDG_DATA_HOME:-$HOME/.local/share}
entry=$data/applications/kitty-cam.desktop
icon=$data/icons/hicolor/scalable/apps/kitty-cam.svg

theme=
case "${1:-}" in
    "") ;;
    --theme) [ $# -eq 2 ] && [ -f "$2" ] || { echo "install.sh: --theme needs an existing file" >&2; exit 2; }
             theme=$(realpath "$2") ;;
    --uninstall) rm -f "$entry" "$icon"; echo "removed $entry and $icon"; exit 0 ;;
    *) echo "usage: install.sh [--theme FILE | --uninstall]" >&2; exit 2 ;;
esac

case "$here$theme" in
    *[\"\`\$\\]*) echo "install.sh: the paths can't contain \" \` \$ or \\ (desktop entry quoting)" >&2; exit 1 ;;
esac
run="\"$here/kitty-cam\"${theme:+ --theme \"$theme\"}"

mkdir -p "$(dirname "$entry")" "$(dirname "$icon")"
cp "$here/web/icon.svg" "$icon"
cat > "$entry" <<EOF
[Desktop Entry]
Type=Application
Name=Kitty Cam
GenericName=Virtual Webcam
Comment=The cat avatar as a face-tracked webcam for video calls
Exec=$run
Icon=kitty-cam
Terminal=false
Categories=AudioVideo;Video;
Keywords=cat;avatar;webcam;camera;vtuber;pipewire;
Actions=headless;stop;

[Desktop Action headless]
Name=Start without a window
Exec=$run --headless

[Desktop Action stop]
Name=Stop
Exec="$here/kitty-cam" --stop
EOF
echo "installed $entry (runs $here/kitty-cam${theme:+ --theme $theme}) and $icon"

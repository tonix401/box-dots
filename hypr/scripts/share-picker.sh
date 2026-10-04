#!/bin/sh
# Screen-share picker for xdg-desktop-portal-hyprland (custom_picker_binary in hypr/xdph.conf).
# Hands the request to the Quickshell share menu (quickshell/Share.qml) and prints its answer: one
# `[SELECTION]…` line, or an empty one to cancel. Falls back to hyprland-share-picker when the shell
# doesn't take the request.
fifo="${XDG_RUNTIME_DIR:-/tmp}/share-picker.$$"
mkfifo -m 600 "$fifo" || exec hyprland-share-picker "$@"
trap 'rm -f "$fifo"' EXIT

allow=false
for arg in "$@"; do [ "$arg" = --allow-token ] && allow=true; done

if [ "$(qs ipc call share pick "$fifo" "$XDPH_WINDOW_SHARING_LIST" "$allow" 2>/dev/null)" != ok ]; then
    rm -f "$fifo"
    exec hyprland-share-picker "$@"
fi

# The menu always answers, also when closed some other way; the timeout only guards against a crashed shell.
timeout 600 head -n 1 "$fifo"

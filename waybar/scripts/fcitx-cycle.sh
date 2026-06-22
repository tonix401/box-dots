#!/usr/bin/env bash
current=$(fcitx5-remote -n 2>/dev/null)
case "$current" in
    keyboard-us) fcitx5-remote -s mozc ;;
    mozc)        fcitx5-remote -s pinyin ;;
    *)           fcitx5-remote -s keyboard-us ;;
esac
pkill -RTMIN+8 waybar

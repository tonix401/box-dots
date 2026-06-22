#!/usr/bin/env bash
im=$(fcitx5-remote -n 2>/dev/null)
case "$im" in
  mozc)   echo "日本語" ;;
  pinyin) echo "中文" ;;
  *)      echo "Eng" ;;
esac

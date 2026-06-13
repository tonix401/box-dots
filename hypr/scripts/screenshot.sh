#!/usr/bin/env bash

# shellcheck source=./config.sh
source "$(dirname "$0")/config.sh"

mkdir -p "$SCREENSHOTS_DIR"

WIN=$(hyprctl activewindow -j | jq -r '.class // "unknown"' | tr ' /\\' '_')
FILE="$SCREENSHOTS_DIR/$(date +%Y-%m-%d_%H-%M-%S)_${WIN}.png"

grimblast copysave area "$FILE"

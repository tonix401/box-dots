#!/usr/bin/env bash

# shellcheck source=../config.sh
source "$(dirname "$0")/../config.sh"

rofi -show drun -theme "$ROFI_THEME_LAUNCHER"

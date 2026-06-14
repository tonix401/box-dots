from pathlib import Path

HOME = Path.home()

WALLPAPERS_DIR       = HOME / "Pictures/Wallpapers"
WALLPAPERS_OUT_DIR   = HOME / ".cache/box-dots/wallpapers"
WALLPAPERS_THUMB_DIR = HOME / ".cache/box-dots/wallpaper-thumbnails"

SCREENSHOTS_DIR = HOME / "Pictures/Screenshots"

ROFI_THEME_LAUNCHER  = HOME / ".config/rofi/launcher.rasi"
ROFI_THEME_CLIPBOARD = HOME / ".config/rofi/clipboard.rasi"
ROFI_THEME_EMOJI     = HOME / ".config/rofi/emoji.rasi"
ROFI_THEME_POWER     = HOME / ".config/rofi/powermenu.rasi"
ROFI_THEME_WALLPAPER = HOME / ".config/rofi/wallpapermenu.rasi"
ROFI_THEME_KEYBINDS  = HOME / ".config/rofi/keybindsmenu.rasi"

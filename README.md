# Packages that need to be installed for these configs to work (maybe not complete)

sudo pacman -S \
    power-profiles-daemon \
    rofi \
    rofimoji \
    waybar \
    kitty \
    awww \
    grimblast \
    cliphist \
    wtype \
    matugen \

### Wallpapers and theme generation flow with matugen and rofi

- in /hypr/keybinds.lua and hypr/scripts/
- 

### Clipboard with history

- /hypr/exec.lua: Initialize cliphist and wcopy
- /hypr/keybinds.lua: menu key bind
- /hypr/scripts/clipboard-history-menu.sh: run the clipboard history menu
- /rofi/clipboard.rasi: layout for the 
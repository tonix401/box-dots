# Auto start Hyprland on tty1
if test -z "$DISPLAY" ;and test "$XDG_VTNR" -eq 1
    mkdir -p ~/.cache/hypr
    exec start-hyprland > ~/.cache/hypr/hyprland.log 2>&1
end

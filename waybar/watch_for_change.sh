while inotifywait -e modify,move,create ~/.config/waybar/style.css; do
    killall -SIGUSR2 waybar
    echo "Reloaded Waybar"
done
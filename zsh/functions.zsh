# Same as fish/custom/functions.fish (the kitty cat's hooks are in cat.zsh). Sourced after
# aliases.zsh: zsh expands aliases in a function when it's defined, so `cd` and `ls` here are z and eza.

cow() {
    fortune -s | cowsay -f small | lolcat
}

cl() {
    cd "$@"
    ls
}

# first arg is tree level (default 2), remaining args are paths/options
lt() {
    local level=${1:-2}
    eza --no-quotes --icons --group-directories-first --tree --level=$level --hyperlink "${@:2}"
}

# Picked like fish's `alias greeting`: tmux over kitty over VS Code over the plain one
greeting() {
    if [[ -n $TMUX ]]; then
        tmux_greeting
    elif [[ $TERM == xterm-kitty ]]; then
        kitty_greeting
    elif [[ -n $VSCODE_INJECTION ]]; then
        vscode_greeting
    else
        print 'Wazzup!'
    fi
}

vscode_greeting() {
    # Color definitions
    local d=$'\e[38;2;0;117;183m'  # #0075B7
    local m=$'\e[38;2;0;136;210m'  # #0088D2
    local l=$'\e[38;2;34;164;231m' # #22A4E7
    local b=$'\e[1m'               # bold
    local r=$'\e[0m'               # reset

    # System information
    local os_name=$(uname -o) platform=$(uname -s) host_name=$(uname -n) user=$USER
    local architecture=$(uname -m)

    # CPU usage (load average)
    local cpu_usage=$(awk -v cpus="$(nproc)" '{printf "%.2f", ($1 / cpus) * 100}' /proc/loadavg)

    # Memory info (in GB)
    local totalmem=$(awk '/MemTotal/ {printf "%.2fGB", $2/1024/1024}' /proc/meminfo)
    local freemem=$(awk '/MemAvailable/ {printf "%.2fGB", $2/1024/1024}' /proc/meminfo)

    # Uptime
    local -i uptime_seconds=${${=$(</proc/uptime)}[1]%%.*}
    local uptime="$(( uptime_seconds / 3600 )) h, $(( uptime_seconds % 3600 / 60 )) m, $(( uptime_seconds % 60 )) s"

    print -r -- ""
    print -r -- "                 $d▟█$l█▙$r"
    print -r -- "               $d▟███$l████▙$r       Welcome to$m$b Visual Studio Code$r!"
    print -r -- "             $d▟█████$l█████$r       OS:   $b$os_name ($platform $architecture)$r"
    print -r -- "    $m▜██▙   $d▟█████▛ $l█████$r       User: $b$user$r@$b$host_name$r"
    print -r -- "     $m▜███▙$d████▛    $l█████$r       Dir:  $b$PWD$r"
    print -r -- "       $m▜████▙      $l█████$r"
    print -r -- "     $d▟███$m▜████▙    $l█████$r       RAM: $b$freemem / $totalmem$r"
    print -r -- "    $d▟██▛   $m▜█████▙ $l█████$r       CPU: $b$cpu_usage%$r avg"
    print -r -- "             $m▜█████$l█████$r"
    print -r -- "               $m▜███$l████▛$r       Uptime: $b$uptime$r"
    print -r -- "                 $m▜█$l█▛$r"
    print -r -- ""
}

# Nothing to print in kitty: the animated cat in the window's top right corner
# (~/.config/quickshell/KittyCat.qml) greets instead of the static cat pictures. For a picture
# again, the penguin is still rendered:
#   kitten icat --place 19x3@4x0 --align left ~/.config/fish/images/penguin.png; printf "\n\n\n"
kitty_greeting() {
}

tmux_greeting() {
    local bold=$'\e[1m' reset=$'\e[0m'
    print -r -- ""
    print -r -- "$primary$bold          ▄▄▄▄▄▄ ▄▄   ▄▄ ▄▄ ▄▄ ▄▄ ▄▄$reset"
    print -r -- "$primary$bold            ██   ██▀▄▀██ ██ ██ ▀█▄█▀$reset"
    print -r -- "$primary$bold            ██   ██   ██ ▀███▀ ██ ██$reset"
    print -r -- ""
}

hello() {
    print -r -- "Hello, $USER!"
}

# matugen rewrites colors.zsh on a wallpaper change (fish gets told with a universal variable; zsh
# has none, so each prompt checks the file's mtime instead)
zmodload -F zsh/stat b:zstat
typeset -g __colors_mtime
__colors_reload() {
    local -a mtime
    zstat -A mtime +mtime -- $ZDOTDIR/colors.zsh 2>/dev/null || return 0
    [[ $mtime[1] == $__colors_mtime ]] && return 0
    __colors_mtime=$mtime[1]
    source $ZDOTDIR/colors.zsh
}

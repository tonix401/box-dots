source ~/.config/fish/colors.fish

function fish_greeting
end

function cow
    fortune -s | cowsay -f small | lolcat
end

function cl
    cd $argv
    ls
end

function lt
    # first arg is tree level (default 2), remaining args are paths/options
    set level 2
    if test (count $argv) -ge 1
        set level $argv[1]
    end
    set rest
    if test (count $argv) -ge 2
        set rest $argv[2..-1]
    end

    eza --no-quotes --icons --group-directories-first --tree --level=$level --hyperlink $rest
end

function vscode_greeting
    # Color definitions
    set d '\x1b[38;2;0;117;183m'  # #0075B7
    set m '\x1b[38;2;0;136;210m'  # #0088D2
    set l '\x1b[38;2;34;164;231m' # #22A4E7
    set b '\x1b[1m'                # bold
    set r '\x1b[0m'                # reset

    # System information
    set os_name (uname -o)
    set platform (uname -s)
    set host_name (uname -n)
    set user $USER
    set architecture (uname -m)
    
    # CPU usage (load average)
    set cpu_count (nproc)
    set cpu_usage (awk -v cpus="$cpu_count" '{printf "%.2f", ($1 / cpus) * 100}' /proc/loadavg)
    
    # Memory info (in GB)
    set totalmem (awk '/MemTotal/ {printf "%.2fGB", $2/1024/1024}' /proc/meminfo)
    set freemem (awk '/MemAvailable/ {printf "%.2fGB", $2/1024/1024}' /proc/meminfo)
    
    # Uptime
    set uptime_seconds (string split ' ' < /proc/uptime)[1]
    set uptime_seconds (math "floor($uptime_seconds)")
    set hours (math "floor($uptime_seconds / 3600)")
    set minutes (math "floor(($uptime_seconds % 3600) / 60)")
    set seconds (math "floor($uptime_seconds % 60)")
    set uptime "$hours h, $minutes m, $seconds s"
    
    # Current directory
    set directory (pwd)

    printf "\n"
    printf "                 $d▟█$l█▙$r\n"
    printf "               $d▟███$l████▙$r       Welcome to$m$b Visual Studio Code$r!\n"
    printf "             $d▟█████$l█████$r       OS:   $b$os_name ($platform $architecture)$r\n"
    printf "    $m▜██▙   $d▟█████▛ $l█████$r       User: $b$user$r@$b$host_name$r\n"
    printf "     $m▜███▙$d████▛    $l█████$r       Dir:  $b$directory$r\n"
    printf "       $m▜████▙      $l█████$r\n"
    printf "     $d▟███$m▜████▙    $l█████$r       RAM: $b$freemem / $totalmem$r\n"
    printf "    $d▟██▛   $m▜█████▙ $l█████$r       CPU: $b$cpu_usage%%$r avg\n"
    printf "             $m▜█████$l█████$r\n"
    printf "               $m▜███$l████▛$r       Uptime: $b$uptime$r\n"
    printf "                 $m▜█$l█▛$r\n"
    printf "\n"
end

function kitty_greeting
    set bold "\e[1m"
    set reset "\e[0m"

    printf "$primary$bold  _._     _,-'\"\"`-._       $reset\n"
    printf "$primary$bold (,-.`._,'(       |\\`-/|    $reset\n"
    printf "$primary$bold     `-.-' \ )-` (, o o)     $reset\n"
    printf "$primary$bold            `-   \`_`\"'-    $reset\n"
end

function tmux_greeting
    set bold "\e[1m"
    set reset "\e[0m"          
    printf "\n$primary$bold          ▄▄▄▄▄▄ ▄▄   ▄▄ ▄▄ ▄▄ ▄▄ ▄▄$reset\n"
    printf "$primary$bold            ██   ██▀▄▀██ ██ ██ ▀█▄█▀$reset\n"
    printf "$primary$bold            ██   ██   ██ ▀███▀ ██ ██$reset\n\n"
end

function on_theme_change --on-variable theme_changed
    # This function will be called after the colors.fish file is regenerated
    # You can add any commands here that should run after the theme changes
    # For example, you could clear the terminal to see the new colors immediately:
    source ~/.config/fish/colors.fish
end
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

# Nothing to print in kitty: the animated cat in the window's top right corner
# (~/.config/quickshell/KittyCat.qml) greets instead of the static cat pictures. For a picture
# again, the penguin is still rendered:
#   kitten icat --place 19x10@4x0 --align left ~/.config/fish/images/penguin.png; printf "\n\n\n"
function kitty_greeting
end

function tmux_greeting
    set bold "\e[1m"
    set reset "\e[0m"          
    printf "\n$primary$bold          ▄▄▄▄▄▄ ▄▄   ▄▄ ▄▄ ▄▄ ▄▄ ▄▄$reset\n"
    printf "$primary$bold            ██   ██▀▄▀██ ██ ██ ▀█▄█▀$reset\n"
    printf "$primary$bold            ██   ██   ██ ▀███▀ ██ ██$reset\n\n"
end

function on_theme_change --on-variable theme_changed
    source ~/.config/fish/colors.fish
end

function hello
    printf "Hello, $USER!\n"
end
# The cat on this kitty window (~/.config/quickshell/KittyCat.qml, Pet.qml) reacts to commands:
# startled when one fails, impressed by fastfetch (or its alias ff), happy when one over 10 s
# succeeds. Only this window's cat: kitty's $KITTY_PID tells Quickshell which window that is (outside
# kitty there is no cat, so nothing is sent). Ctrl-C (130) and empty lines don't count. setsid -f so
# the prompt never waits for qs and no job notice is printed.
#
# While a command runs the cat strains, squished flat, and boings back when it finishes. Each command
# has an id, so the "busy" and "finished" calls (separate qs processes) can't be mixed up when they
# race: a "busy" arriving after its "finished" is ignored. Interactive programs (in any part of a
# pipeline, past sudo/env/VAR=value) never squish it: they run the whole time you use them. Shells and
# REPLs only count as interactive when started bare (`python`, not `python train.py`). An ssh or mosh
# session doesn't squish it either: the cat turns red and puts on sunglasses until it ends. Aliases are
# expanded first, so `mre` (ssh tom@mre) counts as ssh.
set -g __cat_ignore nvim vim vi nano micro hx less more man fzf htop btop top claude tmux zellij \
    lazygit yazi ranger termusic watch exit
set -g __cat_ignore_bare fish bash zsh sh python python3 ipython node
set -g __cat_seq 0

function __cat_segments --description 'Each part of a command line: aliases expanded, sudo/env/VAR=value dropped'
    # $argv[2]: how deep in aliases expanding to a pipeline we are (an alias using itself can't loop).
    set -l depth 0
    set -q argv[2]; and set depth $argv[2]
    for segment in (string split '|' -- $argv[1])
        set -l words (string split -n ' ' -- (string trim -- $segment))
        for i in 1 2 3 4 5
            while set -q words[1]
                if contains -- $words[1] sudo doas env time command builtin exec
                    set -e words[1]
                else if string match -qr -- '^-|=' $words[1] # their flags, VAR=value
                    set -e words[1]
                else
                    break
                end
            end
            set -q words[1]; and functions -q -- $words[1]; or break
            # An alias's function is described as "alias NAME BODY" (fish 4; older: "alias NAME=BODY").
            set -l body (string match -rg '^alias [^ =]+[ =](.*)$' -- (functions -Dv -- $words[1])[5]); or break
            set -e words[1]
            set words (string split -n ' ' -- $body) $words
        end
        set -q words[1]; or continue
        set -l line (string join ' ' -- $words)
        if string match -q '*|*' -- $line # an alias for a pipeline
            test $depth -lt 3; and __cat_segments $line (math $depth + 1)
        else
            echo $line
        end
    end
end

function __cat_ignored --description 'Is any of these segments interactive (the cat does not squish)?'
    for segment in $argv
        set -l words (string split -n ' ' -- $segment)
        contains -- $words[1] $__cat_ignore; and return 0
        test (count $words) -eq 1; and contains -- $words[1] $__cat_ignore_bare; and return 0
    end
    return 1
end

function __cat_remote --description 'Is any of these segments an ssh/mosh session (the cat is cool)?'
    for segment in $argv
        set -l words (string split -n ' ' -- $segment)
        contains -- $words[1] ssh mosh; and return 0
        test "$words[1]" = kitten -a "$words[2]" = ssh; and return 0
    end
    return 1
end

function __cat_busy --on-event fish_preexec
    set -e __cat_id
    test -n "$KITTY_PID" -a -n "$argv[1]"; or return
    set -l segments (__cat_segments $argv[1])
    set -l call busyPid
    if __cat_remote $segments
        set call remotePid
    else if __cat_ignored $segments
        return
    end
    set __cat_seq (math $__cat_seq + 1)
    set -g __cat_id "$fish_pid-$__cat_seq"
    setsid -f qs ipc call cat $call $KITTY_PID $__cat_id >/dev/null 2>&1
end

function __cat_react --on-event fish_postexec
    set -l code $status
    set -l id $__cat_id
    set -e __cat_id
    test -n "$argv[1]" -a -n "$KITTY_PID"; or return
    # `exit` reports the status of the command before it: no reaction to closing the shell.
    set -l cmd (string split -f1 ' ' -- (string trim -- $argv[1]))
    test "$cmd" = exit; and return
    set -l event none
    if test $code -ne 0 -a $code -ne 130
        set event error
    else if test $code -eq 0; and contains -- $cmd fastfetch ff
        set event impressed
    else if test $code -eq 0 -a "$CMD_DURATION" -gt 10000
        set event ok
    end
    if test -n "$id" # it squished the cat (or made it cool): let go, with the reaction in the same call
        setsid -f qs ipc call cat finishedPid $KITTY_PID $id $event >/dev/null 2>&1
    else if test $event != none
        setsid -f qs ipc call cat reactPid $event $KITTY_PID >/dev/null 2>&1
    end
end

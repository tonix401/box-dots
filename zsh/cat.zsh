# The kitty cat's hooks, ported from the end of fish/custom/functions.fish (see there for what the
# cat does). fish_preexec is preexec here, fish_postexec the first precmd hook (.zshrc puts it in
# front, so $? is still the command's), and CMD_DURATION is timed with $EPOCHREALTIME.

zmodload zsh/datetime

typeset -ga __cat_ignore=(nvim vim vi nano micro hx less more man fzf htop btop top claude tmux zellij
    lazygit yazi ranger termusic watch exit)
typeset -ga __cat_ignore_bare=(fish bash zsh sh python python3 ipython node)
typeset -ga __cat_wrappers=(sudo doas env time command builtin exec)
typeset -gi __cat_seq=0
typeset -g __cat_id __cat_cmd
typeset -gF __cat_start

# Each part of a command line, one per line: aliases expanded, sudo/env/VAR=value dropped.
# $2: how deep in aliases expanding to a pipeline we are (an alias using itself can't loop).
__cat_segments() {
    local depth=${2:-0} segment i
    local -a words
    for segment in "${(@s:|:)1}"; do
        words=(${=segment})
        for i in {1..5}; do
            while (( $#words )); do
                if (( ${__cat_wrappers[(Ie)$words[1]]} )); then
                    shift words
                elif [[ $words[1] == -* || $words[1] == *=* ]]; then # their flags, VAR=value
                    shift words
                else
                    break
                fi
            done
            (( $#words )) && (( ${+aliases[$words[1]]} )) || break
            words=(${=aliases[$words[1]]} "${(@)words[2,-1]}")
        done
        (( $#words )) || continue
        local line=${(j: :)words}
        if [[ $line == *'|'* ]]; then # an alias for a pipeline
            (( depth < 3 )) && __cat_segments $line $(( depth + 1 ))
        else
            print -r -- $line
        fi
    done
}

# Is any of these segments interactive (the cat does not squish)?
__cat_ignored() {
    local segment
    local -a words
    for segment in "$@"; do
        words=(${=segment})
        (( ${__cat_ignore[(Ie)$words[1]]} )) && return 0
        (( $#words == 1 && ${__cat_ignore_bare[(Ie)$words[1]]} )) && return 0
    done
    return 1
}

# Is any of these segments an ssh/mosh session (the cat is cool)?
__cat_remote() {
    local segment
    local -a words
    for segment in "$@"; do
        words=(${=segment})
        [[ $words[1] == (ssh|mosh) ]] && return 0
        [[ "$words[1] $words[2]" == 'kitten ssh' ]] && return 0
    done
    return 1
}

__cat_busy() {
    __cat_id=
    __cat_cmd=$1
    __cat_start=$EPOCHREALTIME
    [[ -n $KITTY_PID && -n $1 ]] || return 0
    local -a segments=(${(f)"$(__cat_segments "$1")"})
    local call=busyPid
    if __cat_remote $segments; then
        call=remotePid
    elif __cat_ignored $segments; then
        return 0
    fi
    (( ++__cat_seq ))
    __cat_id="$$-$__cat_seq"
    setsid -f qs ipc call cat $call $KITTY_PID $__cat_id &>/dev/null
}

__cat_react() {
    local -i code=$?
    local cmd=$__cat_cmd id=$__cat_id
    __cat_cmd= __cat_id=
    [[ -n $cmd && -n $KITTY_PID ]] || return 0 # an empty line: preexec didn't run
    # `exit` reports the status of the command before it: no reaction to closing the shell.
    local first=${${=cmd}[1]}
    [[ $first == exit ]] && return 0
    local -i duration=$(( (EPOCHREALTIME - __cat_start) * 1000 ))
    local event=none
    if (( code != 0 && code != 130 )); then
        event=error
    elif (( code == 0 )) && [[ $first == (fastfetch|ff) ]]; then
        event=impressed
    elif (( code == 0 && duration > 10000 )); then
        event=ok
    fi
    if [[ -n $id ]]; then # it squished the cat (or made it cool): let go, with the reaction in the same call
        setsid -f qs ipc call cat finishedPid $KITTY_PID $id $event &>/dev/null
    elif [[ $event != none ]]; then
        setsid -f qs ipc call cat reactPid $event $KITTY_PID &>/dev/null
    fi
    return 0
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec __cat_busy

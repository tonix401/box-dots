if status is-interactive # Commands to run in interactive sessions can go here
    zoxide init fish | source
    starship init fish | source

    if test -f ~/.local/state/quickshell/user/generated/terminal/sequences.txt
        cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt
    end

    for file in ~/.config/fish/conf.d/*.fish 
        source $file
    end
    
    for file in ~/.config/fish/custom/*.fish 
	    source $file
    end

    alias greeting 'echo "Wazzup!"'

    if test -n "$VSCODE_INJECTION"
        alias greeting 'vscode_greeting'
    end

    if test "$TERM" = "xterm-kitty"
        alias greeting 'kitty_greeting'
    end

    if test -n "$TMUX"
        alias greeting 'tmux_greeting'
    end

    greeting
end

fish_add_path ~/.local/bin

# The standard GOPATH is $HOME/go, but I prefer to keep it in .go because it trashes my home directory less
export GOPATH="$HOME/.go"

# Aliases for ranger in kitty
alias icat 'kitten icat'
alias s 'kitten ssh'

# set -gx RANGER_LOAD_DEFAULT_RC false

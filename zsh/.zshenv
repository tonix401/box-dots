# Every zsh, scripts too (like fish's config.fish outside its `status is-interactive` block).
# ~/.zshenv points ZDOTDIR here and sources this; a zsh started with ZDOTDIR already set (from a zsh)
# reads it directly.

typeset -U path
path=(~/.local/bin $path)

# The standard GOPATH is $HOME/go, but I prefer to keep it in .go because it trashes my home directory less
export GOPATH="$HOME/.go"

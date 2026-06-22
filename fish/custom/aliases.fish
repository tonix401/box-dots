alias cd 'z'
alias c 'clear && greeting'
alias ls 'eza --long --no-quotes --icons --header --git --group-directories-first'
alias la 'eza   -all --no-quotes --icons --header --git --group-directories-first'
alias p pkg
alias pkg packages
alias packages 'pacman -Q | fzf --preview "pacman -Qi {1}"'
alias clean 'sudo pacman -Rns $(pacman -Qtdq) && sudo paccache -r'
alias .. 'cd ..'
alias ... 'cd ../..'
alias .... 'cd ../../..'
alias update 'sudo pacman -Syu && hyprpm update && hyprpm reload'
alias 'back' 'cd -'
alias ff fastfetch
alias mre 'kitten ssh mre.fritz.box'

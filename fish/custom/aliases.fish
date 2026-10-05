alias cd 'z'
alias c 'clear && greeting'
alias ls 'eza --long --no-quotes --icons --header --git --group-directories-first'
alias la 'eza   -all --no-quotes --icons --header --git --group-directories-first'
alias p pkg
alias pkg packages
if test -e /etc/NIXOS
    alias packages 'nix-store -q --requisites /run/current-system /etc/profiles/per-user/$USER | fzf'
    alias clean 'sudo nix-collect-garbage -d && sudo nixos-rebuild boot'
    alias update 'sudo nix-channel --update && sudo nixos-rebuild switch'
else
    alias packages 'pacman -Q | fzf --preview "pacman -Qi {1}"'
    alias clean 'sudo pacman -Rns $(pacman -Qtdq) && sudo paccache -r'
    alias update 'sudo pacman -Syu && hyprpm update && hyprpm reload'
end
alias .. 'cd ..'
alias ... 'cd ../..'
alias .... 'cd ../../..'
alias 'back' 'cd -'
alias ff fastfetch
alias mre 'kitten ssh mre.fritz.box'

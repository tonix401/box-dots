# Interactive zsh, set up to feel like the fish config next to it (fish/). fish stays the login
# shell: run `zsh` from fish to try this one, `exit` to get back.
#
# Plugins (fish has these built in): zsh-autosuggestions, zsh-syntax-highlighting,
# zsh-history-substring-search, zsh-abbr and fzf-tab, found in ~/.local/share/zsh/plugins (linked
# by home.nix) or /usr/share/zsh/plugins (the Arch packages).

# fzf-tab instead of the menu: completions in fzf, filtered as you type. The menu is closer to fish.
zsh_fzf_tab=0

# History: a long one, without duplicates, written as commands run (like fish). Not shared live
# between open shells either: fish only reads it on start.
HISTFILE=${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history
HISTSIZE=256000
SAVEHIST=256000
setopt EXTENDED_HISTORY INC_APPEND_HISTORY_TIME HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE \
    HIST_REDUCE_BLANKS HIST_VERIFY
unsetopt SHARE_HISTORY # NixOS's /etc/zshrc sets it

# The first start takes over fish's history, so autosuggestions and up arrow have something to go
# on. Multi-line commands are skipped. Run again with `import_fish_history` (it appends).
import_fish_history() {
    local fish_history=${XDG_DATA_HOME:-$HOME/.local/share}/fish/fish_history
    [[ -r $fish_history ]] || return 1
    mkdir -p ${HISTFILE:h}
    # fish escapes \ as \\ and a newline as \n
    awk '
        function flush() { if (cmd != "") printf ": %d:0;%s\n", when, cmd; cmd = "" }
        /^- cmd: / {
            flush()
            cmd = substr($0, 8); when = 0
            gsub(/\\\\/, "\001", cmd)
            if (cmd ~ /\\n/) { cmd = ""; next }
            gsub(/\001/, "\\", cmd)
        }
        /^  when: / { when = $2 }
        END { flush() }
    ' $fish_history >>$HISTFILE
    fc -R $HISTFILE
}
[[ -e $HISTFILE ]] || import_fish_history

setopt AUTO_CD              # a directory alone cds into it, like fish
setopt INTERACTIVE_COMMENTS # `# ...` at the prompt
setopt AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_SILENT # `cd -<TAB>` lists recent directories, like fish's dirh
setopt NO_BEEP

# Completion: a menu to move through with the arrows or tab, case-insensitive, with descriptions
zmodload zsh/complist
autoload -Uz compinit
mkdir -p ${XDG_CACHE_HOME:-$HOME/.cache}/zsh
compinit -d ${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-$ZSH_VERSION
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' group-name ''
zstyle ':completion:*' verbose yes
zstyle ':completion:*:descriptions' format '%F{yellow}%B%d%b%f'
zstyle ':completion:*:warnings' format '%F{red}no matches%f'
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ${XDG_CACHE_HOME:-$HOME/.cache}/zsh/compcache

__plugin() {
    local dir
    for dir in ${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins /usr/share/zsh/plugins; do
        [[ -r $dir/$1/$1.zsh ]] && { source $dir/$1/$1.zsh; return }
    done
    print -u2 "zsh: plugin $1 not found"
}

# fzf-tab has to come right after compinit, before the widget-wrapping plugins
if (( zsh_fzf_tab )); then
    __plugin fzf-tab
    zstyle ':completion:*' menu no
    zstyle ':fzf-tab:*' switch-group '<' '>'
fi

# fish's abbreviations: `abbr gco='git checkout'` expands as you type space
__plugin zsh-abbr

# Suggestions from history (then from completions) in gray; → or End takes all of it, Ctrl-→ or
# Alt-→ one word, like fish
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#555555'
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=200
__plugin zsh-autosuggestions

# Highlighting in fish's colors (fish/conf.d/fish_frozen_theme.fish)
__plugin zsh-syntax-highlighting
ZSH_HIGHLIGHT_STYLES[default]='fg=cyan'                 # fish_color_param
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=9'              # fish_color_error brred
for style in command builtin alias suffix-alias global-alias function hashed-command precommand \
    reserved-word arg0; do
    ZSH_HIGHLIGHT_STYLES[$style]='fg=blue'              # fish_color_command
done
unset style
ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=green'       # fish_color_end
ZSH_HIGHLIGHT_STYLES[comment]='fg=red'                  # fish_color_comment
ZSH_HIGHLIGHT_STYLES[redirection]='fg=cyan,bold'        # fish_color_redirection
ZSH_HIGHLIGHT_STYLES[path]='fg=cyan,underline'          # fish_color_valid_path
ZSH_HIGHLIGHT_STYLES[path_prefix]='fg=cyan,underline'
ZSH_HIGHLIGHT_STYLES[autodirectory]='fg=blue,underline'
for style in single-quoted-argument double-quoted-argument dollar-quoted-argument \
    back-quoted-argument; do
    ZSH_HIGHLIGHT_STYLES[$style]='fg=yellow'            # fish_color_quote
done
unset style
for style in globbing history-expansion back-double-quoted-argument back-dollar-quoted-argument \
    dollar-double-quoted-argument; do
    ZSH_HIGHLIGHT_STYLES[$style]='fg=14'                # fish_color_escape/operator brcyan
done
unset style
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=cyan'    # options are params in fish
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=cyan'

# ↑/↓ search history for what's typed so far (anywhere in the command), like fish
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND='bg=#111111,bold' # fish_color_search_match
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND='none'
HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE=1
__plugin zsh-history-substring-search

# Keys: emacs-style like fish, with fish's extras
bindkey -e
WORDCHARS='' # word motions and deletes stop at / . - _ like fish's
__bind() { local widget=$1 key; shift; for key; do bindkey -- $key $widget; done }
__bind history-substring-search-up   '^[[A' '^[OA' '^P'
__bind history-substring-search-down '^[[B' '^[OB' '^N'
__bind beginning-of-line '^[[H' '^[OH' '^[[1~'
__bind end-of-line       '^[[F' '^[OF' '^[[4~'
__bind delete-char       '^[[3~'
__bind forward-word      '^[[1;5C' '^[[1;3C' # Ctrl-→, Alt-→
__bind backward-word     '^[[1;5D' '^[[1;3D'
__bind backward-kill-word '^H' '^[^?'        # Ctrl-Backspace, Alt-Backspace
__bind kill-word         '^[[3;5~' '^[d'      # Ctrl-Delete, Alt-D
bindkey -M menuselect '^[[Z' reverse-menu-complete # Shift-Tab goes back in the menu
bindkey '^[[Z' reverse-menu-complete
# Alt-E / Alt-V: edit the command line in $EDITOR
autoload -Uz edit-command-line
zle -N edit-command-line
__bind edit-command-line '^[e' '^[v'
# Alt-H: man page of the command being typed
__bind run-help '^[h'
# Alt-S: put sudo in front (or take it off again)
__toggle_sudo() {
    [[ -z $BUFFER ]] && BUFFER=$history[$((HISTCMD - 1))]
    if [[ $BUFFER == 'sudo '* ]]; then
        BUFFER=${BUFFER#sudo }
        (( CURSOR = CURSOR > 5 ? CURSOR - 5 : 0 ))
    else
        BUFFER="sudo $BUFFER"
        (( CURSOR += 5 ))
    fi
}
zle -N __toggle_sudo
__bind __toggle_sudo '^[s'
# Ctrl-V pastes the clipboard, Ctrl-X copies the command line, like fish (zsh's Ctrl-V is
# quoted-insert). Ctrl-C copying a selection is kitty's copy_or_interrupt, the same in any shell.
__clipboard_paste() {
    local clip
    clip=$(wl-paste --no-newline 2>/dev/null) || return
    LBUFFER+=$clip
}
__clipboard_copy() {
    local text=$BUFFER
    if (( REGION_ACTIVE )); then # the selection (Shift + arrows), else the whole line
        text=${BUFFER[$(( (MARK < CURSOR ? MARK : CURSOR) + 1 )),$(( MARK > CURSOR ? MARK : CURSOR ))]}
        REGION_ACTIVE=0
    fi
    [[ -n $text ]] && print -rn -- $text | wl-copy
}

# Selecting with Shift (+ Ctrl for words) and the arrows / Home / End, like fish: each select-*
# widget starts a selection where the cursor is (or extends the current one) and moves; the
# arrows without Shift drop it. Typing or deleting replaces it.
for __w in backward-char forward-char backward-word forward-word beginning-of-line end-of-line; do
    eval "select-$__w() { (( REGION_ACTIVE )) || { MARK=\$CURSOR; REGION_ACTIVE=1 }; zle $__w }
        deselect-$__w() { REGION_ACTIVE=0; zle $__w }"
    zle -N select-$__w
    zle -N deselect-$__w
done
unset __w
zle_highlight=(region:bg=#44475a paste:none) # the selection, visible next to the highlighting
__bind select-backward-char   '^[[1;2D'
__bind select-forward-char    '^[[1;2C'
__bind select-backward-word   '^[[1;6D'
__bind select-forward-word    '^[[1;6C'
__bind select-beginning-of-line '^[[1;2H'
__bind select-end-of-line     '^[[1;2F'
__bind deselect-backward-char '^[[D' '^[OD'
__bind deselect-forward-char  '^[[C' '^[OC'
__bind deselect-backward-word '^[[1;5D' '^[[1;3D'
__bind deselect-forward-word  '^[[1;5C' '^[[1;3C'
__bind deselect-beginning-of-line '^[[H' '^[OH' '^[[1~'
__bind deselect-end-of-line   '^[[F' '^[OF' '^[[4~'
# The arrows now run these instead of forward-char & co: tell zsh-autosuggestions they accept the
# suggestion (→, End) or a word of it (Ctrl-→, Alt-→)
ZSH_AUTOSUGGEST_ACCEPT_WIDGETS+=(deselect-forward-char deselect-end-of-line)
ZSH_AUTOSUGGEST_PARTIAL_ACCEPT_WIDGETS+=(deselect-forward-word)
# Typing, Backspace or Delete over a selection replaces it
# (named per widget: $WIDGET is the outermost one, e.g. zsh-abbr's on space, which calls self-insert)
__kill_selection() {
    (( REGION_ACTIVE )) || return 1
    zle kill-region
    REGION_ACTIVE=0
}
__replace_self_insert() { __kill_selection; zle .self-insert }
__replace_backward_delete_char() { __kill_selection || zle .backward-delete-char }
__replace_delete_char() { __kill_selection || zle .delete-char }
zle -N self-insert __replace_self_insert
zle -N backward-delete-char __replace_backward_delete_char
zle -N delete-char __replace_delete_char
zle -N __clipboard_paste
zle -N __clipboard_copy
__bind __clipboard_paste '^V'
__bind __clipboard_copy '^X'

# Ctrl-R: search history in fzf (fish's Ctrl-R pager); fzf's Ctrl-T and Alt-C are left off
FZF_CTRL_T_COMMAND= FZF_ALT_C_COMMAND= source <(fzf --zsh)

source $ZDOTDIR/aliases.zsh
source $ZDOTDIR/functions.zsh
source $ZDOTDIR/cat.zsh
__colors_reload

eval "$(starship init zsh)"
eval "$(zoxide init zsh)"

# kitty integrates with the shell it starts (fish), not with a zsh started from fish: load it here
# (prompt marks, titles, cursor shape). A no-op when it's already loaded.
if [[ -n $KITTY_INSTALLATION_DIR && -n $KITTY_SHELL_INTEGRATION ]]; then
    autoload -Uz -- $KITTY_INSTALLATION_DIR/shell-integration/zsh/kitty-integration
    kitty-integration
    unfunction kitty-integration
fi

# The cat's reaction first, while $? is still the command's
precmd_functions=(__cat_react __colors_reload ${precmd_functions:#(__cat_react|__colors_reload)})

greeting

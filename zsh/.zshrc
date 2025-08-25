source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh

# File system
alias ls='eza -lh --group-directories-first --icons=auto'
alias lsa='ls -a'
alias lt='eza --tree --level=2 --long --icons --git'
alias lta='lt -a'
alias ff="fzf --preview 'batcat --style=numbers --color=always {}'"
alias fd='fdfind'
alias cd='z'

# Directories
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Tools
alias n='nvim'
alias g='git'
alias d='docker'
alias c='claude'
alias bat='batcat'
alias lzg='lazygit'
alias lzd='lazydocker'
alias zj='zellij'

# Git
alias gcm='git commit -m'
alias gcam='git commit -a -m'
alias gcad='git commit -a --amend'

eval "$(zoxide init zsh)"
eval "$(starship init zsh)"
eval "$(mise activate zsh)"

# History
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_REDUCE_BLANKS
setopt APPEND_HISTORY
export PATH="/home/jojo/.config/herd-lite/bin:$PATH"
export PHP_INI_SCAN_DIR="/home/jojo/.config/herd-lite/bin:$PHP_INI_SCAN_DIR"

alias claude="/home/jojo/.claude/local/claude"

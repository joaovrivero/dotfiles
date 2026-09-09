# Keep PATH entries unique while preserving their order.
typeset -U path PATH

# Support both Arch packages and plugins installed under ~/.zsh.
for plugin in \
  /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh \
  "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"; do
  [[ -r "$plugin" ]] && source "$plugin" && break
done

[[ -d "$HOME/.zsh/zsh-completions/src" ]] && fpath=("$HOME/.zsh/zsh-completions/src" $fpath)
[[ -d "$HOME/.grok/completions/zsh" ]] && fpath=("$HOME/.grok/completions/zsh" $fpath)
autoload -Uz compinit && compinit -C

# pinacoteca:begin
# Pinacoteca colours for fzf. Palette and provenance: theme/pinacoteca/colors.toml
export FZF_DEFAULT_OPTS="--color=bg+:#211c17,bg:-1,fg:#b19a80,fg+:#e6ccaf,hl:#799dbb,hl+:#d7a447,info:#d7a447,prompt:#d7a447,pointer:#d7a447,marker:#d67066,spinner:#d7a447,header:#799dbb,border:#453b32,gutter:-1"
# pinacoteca:end

# File system
alias ls='eza -l --group-directories-first --icons=auto'
alias lsa='ls -a'
alias lt='eza --tree --level=2 --long --icons --git'
alias lta='lt -a'
alias ff="fzf --preview 'bat --style=numbers --color=always {}'"

# Directories
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Tools
alias n='nvim'
alias g='git'
alias d='docker'
alias t='tmux'
alias cc='claude'
alias oc='opencode'
alias lzg='lazygit'
alias lzd='lazydocker'
alias syu='sudo pacman -Syu'

# Git
alias gcm='git commit -m'
alias gcam='git commit -a -m'
alias gcad='git commit -a --amend'
alias gp='git push'

command -v zoxide >/dev/null && eval "$(zoxide init zsh)"
command -v starship >/dev/null && eval "$(starship init zsh)"
command -v mise >/dev/null && eval "$(mise activate zsh)"

# History
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_REDUCE_BLANKS

unsetopt BEEP

path=(
  "$HOME/.local/bin"
  "$HOME/.bun/bin"
  "$HOME/.opencode/bin"
  "$HOME/.grok/bin"
  "$HOME/.config/herd-lite/bin"
  "${GOPATH:-$HOME/go}/bin"
  $path
)

export PHP_INI_SCAN_DIR="$HOME/.config/herd-lite/bin${PHP_INI_SCAN_DIR:+:$PHP_INI_SCAN_DIR}"

# bun completions
[[ -r "$HOME/.bun/_bun" ]] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
path=("$PNPM_HOME" $path)
# pnpm end

# Generated for envman. Do not edit.
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"

[[ -r "$HOME/.atuin/bin/env" ]] && source "$HOME/.atuin/bin/env"
command -v atuin >/dev/null && eval "$(atuin init zsh)"

# >>> grok installer >>>
# <<< grok installer <<<

# Machine-specific settings that should not live in the repository.
[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

# Syntax highlighting must be sourced after other interactive shell setup.
for plugin in \
  /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  "$HOME/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"; do
  [[ -r "$plugin" ]] && source "$plugin" && break
done

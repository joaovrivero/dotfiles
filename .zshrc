source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh

alias ls='eza -lh --group-directories-first --icons'
alias lsa='ls -a'
alias lt='eza --tree --level=2 --long --icons --git'
alias lta='lt -a'
alias ..='z ..'
alias ...='z ../..'
alias ....='z ../../..'

eval "$(zoxide init zsh)"
eval "$(starship init zsh)"
eval "$(mise activate zsh)"

[ -z "$ZELLIJ" ] && exec zellij

if command -v fastfetch &> /dev/null; then

	fastfetch

fi

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_REDUCE_BLANKS
setopt INC_APPEND_HISTORY

export PATH="/home/jojo/.config/herd-lite/bin:$PATH"
export PHP_INI_SCAN_DIR="/home/jojo/.config/herd-lite/bin:$PHP_INI_SCAN_DIR"

function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}
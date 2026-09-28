#!/bin/sh
# Git segment of the Pinacoteca tmux status line, after tokyo-night-tmux's git and
# web-based git widgets.
# tmux runs it with the pane's directory. Rendered from theme/pinacoteca/templates/tmux-git.sh.
# Unlike the original it never fetches, so "behind" reflects the last fetch you ran.

cd "$1" 2>/dev/null || exit 0
branch=$(git branch --show-current 2>/dev/null) || exit 0
[ -n "$branch" ] || branch=$(git rev-parse --short HEAD 2>/dev/null) || exit 0
if [ "${#branch}" -gt 25 ]; then
    branch="$(printf '%s' "$branch" | cut -c1-25)…"
fi

# shellcheck disable=SC2046 # word splitting is how the three counts are read
set -- $(git diff --numstat HEAD 2>/dev/null |
    awk 'NF == 3 { files++; added += $1; deleted += $2 } END { printf "%d %d %d", files, added, deleted }')
files=${1:-0} added=${2:-0} deleted=${3:-0}
untracked=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')

ahead=0 behind=0
if counts=$(git rev-list --left-right --count 'HEAD...@{upstream}' 2>/dev/null); then
    # shellcheck disable=SC2086 # split "ahead<TAB>behind" into two fields
    set -- $counts
    ahead=$1 behind=$2
fi

if [ "$files" -gt 0 ]; then
    sync="#[fg=#d77f47]▒ 󱓎"
elif [ "$ahead" -gt 0 ]; then
    sync="#[fg=#d67066]▒ 󰛃"
elif [ "$behind" -gt 0 ]; then
    sync="#[fg=#ad8ab6]▒ 󰛀"
else
    sync="#[fg=#88ab75]▒ "
fi

out="$sync #[fg=#e6ccaf]$branch #[bold]"
[ "$files" -gt 0 ] && out="$out#[fg=#d7a447] $files "
[ "$added" -gt 0 ] && out="$out#[fg=#88ab75] $added "
[ "$deleted" -gt 0 ] && out="$out#[fg=#d67066] $deleted "
[ "$untracked" -gt 0 ] && out="$out#[fg=#7d6b59] $untracked "
out="$out#[nobold]"

# Where origin lives: the remote marker, then the host's logo. Read from the local
# config, so it costs no network calls.
case "$(git config --get remote.origin.url 2>/dev/null)" in
    *github.com[:/]*) remote="#[fg=#e6ccaf]" ;;
    *gitlab.com[:/]*) remote="#[fg=#d77f47]" ;;
    ?*) remote="#[fg=#b19a80]󰊢" ;;
    *) remote="" ;;
esac
[ -n "$remote" ] && out="$out#[fg=#7d6b59] $remote "
printf '%s' "$out"

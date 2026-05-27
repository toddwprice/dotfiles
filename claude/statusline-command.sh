#!/usr/bin/env bash
# Claude Code status line
# Displays: cwd  git-branch  model  context%

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Shorten home directory to ~
home="$HOME"
short_cwd="${cwd/#$home/\~}"

# Git branch (skip optional lock so it never hangs)
branch=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git -C "$cwd" -c core.fsmonitor=false symbolic-ref --short HEAD 2>/dev/null \
           || git -C "$cwd" -c core.fsmonitor=false rev-parse --short HEAD 2>/dev/null)
fi
[ "${#branch}" -gt 30 ] && branch="${branch:0:29}…"

# Build pieces
loc_part="$short_cwd"
[ -n "$branch" ] && loc_part="$loc_part  $branch"

ctx_part=""
if [ -n "$used_pct" ]; then
  ctx_part=" | ctx:$(printf '%.0f' "$used_pct")%"
fi

model_part=""
[ -n "$model" ] && model_part=" | $model"

printf '%s%s%s' \
  "$loc_part" \
  "$model_part" \
  "$ctx_part"

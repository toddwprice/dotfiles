#!/usr/bin/env bash
# Claude Code status line
# Displays (left to right): model | ctx% | effort | worktree | PR#

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
# Effort level — check a few likely shapes since Claude Code's payload contract
# isn't pinned. Settings stores it as `effortLevel`; the input JSON may surface
# it under any of these.
effort=$(echo "$input" | jq -r '.effortLevel // .effort.level // .session.effortLevel // .effort // ""')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')

# Worktree name = leaf basename of cwd. This repo's worktree layout puts each
# branch under /Users/toddprice/dscout-wt/<branch-slug>/, so the basename IS
# the worktree.
worktree=""
[ -n "$cwd" ] && worktree=$(basename "$cwd")

# PR number — cached per-branch under ~/.claude/.statusline-pr-cache/ so the
# statusline doesn't spawn a gh subprocess on every prompt render. Cache is
# refreshed in the background when older than 5 minutes; the refresh never
# blocks the prompt.
PR_CACHE_DIR="$HOME/.claude/.statusline-pr-cache"
mkdir -p "$PR_CACHE_DIR" 2>/dev/null

pr_part=""
if [ -n "$cwd" ] && command -v git > /dev/null 2>&1; then
  branch=$(git -C "$cwd" -c core.fsmonitor=false symbolic-ref --short HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    cache_key=$(printf '%s' "$branch" | tr '/' '_' | tr -cd 'A-Za-z0-9._-')
    cache_file="$PR_CACHE_DIR/$cache_key"

    now=$(date +%s)
    cache_age=999999
    if [ -f "$cache_file" ]; then
      cache_mtime=$(stat -f '%m' "$cache_file" 2>/dev/null || stat -c '%Y' "$cache_file" 2>/dev/null)
      [ -n "$cache_mtime" ] && cache_age=$(( now - cache_mtime ))
    fi

    if [ "$cache_age" -ge 300 ] && command -v gh > /dev/null 2>&1; then
      (
        cd "$cwd" 2>/dev/null || exit 0
        pr_num=$(gh pr view --json number -q '.number' 2>/dev/null)
        printf '%s' "${pr_num:-}" > "$cache_file"
      ) &
      disown 2>/dev/null || true
    fi

    if [ -f "$cache_file" ]; then
      pr_num=$(cat "$cache_file" 2>/dev/null)
      [ -n "$pr_num" ] && pr_part="PR #$pr_num"
    fi
  fi
fi

# Assemble segments with " | " separator (matches the existing style).
sep=""
out=""

if [ -n "$model" ]; then
  out="${out}${sep}${model}"
  sep=" | "
fi

if [ -n "$used_pct" ]; then
  ctx=$(printf '%.0f' "$used_pct")
  out="${out}${sep}ctx:${ctx}%"
  sep=" | "
fi

if [ -n "$effort" ]; then
  out="${out}${sep}${effort}"
  sep=" | "
fi

if [ -n "$worktree" ]; then
  out="${out}${sep}${worktree}"
  sep=" | "
fi

if [ -n "$pr_part" ]; then
  out="${out}${sep}${pr_part}"
fi

printf '%s' "$out"

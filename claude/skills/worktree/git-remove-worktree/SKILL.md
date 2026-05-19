---
name: "git-remove-worktree"
description: Remove a git worktree and clean up stale references
allowed-tools: Bash(git worktree:*), Bash(git fetch:*), Bash(git branch:*), Bash(git remote:*)
---

Remove a git worktree and clean up stale references. Reference: https://www.notion.so/dscout/Git-Worktrees-2a917a66c83d8059b28ec73da66d9d43

$ARGUMENTS

The argument should be a worktree name or path, e.g.:
- `my-feature` — removes the worktree whose path ends with `my-feature`
- `../my-feature` — removes the worktree at that exact path

## Steps

1. Run `git worktree list` and display the current worktrees so the user can confirm which one to remove.

2. Match `$ARGUMENTS` against the listed worktrees:
   - If it's an exact path, use it directly.
   - If it's a name, collect all worktrees whose path ends with that name.
     - If exactly one match, use it.
     - If multiple matches, present a numbered list and ask the user to pick one before proceeding.
   - If no match is found, show the list and ask the user to clarify.

3. Remove the worktree:
   ```
   git worktree remove <path>
   ```
   If removal fails due to untracked or modified files, inform the user and ask whether to force with `--force`.

4. Prune stale worktree references:
   ```
   git worktree prune
   ```

5. Prune stale remote tracking references:
   ```
   git remote prune origin
   ```

6. Derive the branch name from the matched worktree's `git worktree list` output (the branch is shown in brackets, e.g. `[my-feature]`). If a local branch with that name exists, ask the user whether to delete it, then use `git branch -D <branch>` (force delete since we squash-merge PRs). If the branch name can't be determined, show available local branches and ask the user which to delete.

7. Confirm cleanup by running `git worktree list` and displaying the result.

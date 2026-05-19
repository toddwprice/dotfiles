---
name: "git-add-worktree"
description: Add a git worktree for a new or existing branch
allowed-tools: Bash(git worktree:*), Bash(git fetch:*), Bash(git branch:*)
---

Add a git worktree for the given branch. Reference: https://www.notion.so/dscout/Git-Worktrees-2a917a66c83d8059b28ec73da66d9d43

$ARGUMENTS

The arguments should be a branch name and an optional directory path, e.g.:
- `my-feature` — creates worktree at `../my-feature`
- `my-feature ../custom-dir` — creates worktree at `../custom-dir`

## Steps

1. Parse `$ARGUMENTS` into `<branch>` and optional `<dir>`. Default `<dir>` to `../<branch>` (sibling of the current repo root).

2. Determine whether the branch already exists on the remote:
   - Run `git fetch origin`
   - Check `git branch -r --list "origin/<branch>"`

3. If the branch **exists on the remote**:
   ```
   git worktree add <dir> <branch>
   ```

4. If the branch **does not exist** (new branch):
   ```
   git worktree add -b <branch> <dir> main
   ```

5. Confirm by running `git worktree list` and displaying the result.

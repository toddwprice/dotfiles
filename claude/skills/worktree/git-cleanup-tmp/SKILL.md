---
name: "git-cleanup-tmp"
description: Clean up stale tmp directories for merged branches
allowed-tools: Bash(git:*), Bash(ls), Bash(trash)
---

Clean up stale temporary directories in `.claude/tmp/` by checking if branches have been merged into main and moving those directories to the OS trash.

$ARGUMENTS

For each directory in `.claude/tmp/` that follows the `<branch-name>_<date>` naming convention:

1. Extract the branch name from the directory name
2. Check if the branch has been merged into main using `git branch --merged main | grep <branch-name>`
3. If the branch has been merged (or no longer exists), move the entire directory to the OS trash using the `mv <file_path> ~/.Trash/` command (or `rm -rf` as fallback if trash is not available)
4. Provide a summary of directories moved and any errors encountered

Skip directories that don't follow the expected naming convention and provide a warning about them.

Example usage:
- `/cleanup-tmp` - Clean up all stale directories
- `/cleanup-tmp --dry-run` - Show what would be cleaned up without actually moving files

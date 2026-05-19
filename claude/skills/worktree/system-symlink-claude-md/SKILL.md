---
name: system-symlink-claude-md
description: Convert CLAUDE.md files to AGENTS.md with symlinks, then commit and push
allowed-tools: Bash(*), Read(*), Glob(*)
---

Convert all CLAUDE.md files in the repository to AGENTS.md files with CLAUDE.md symlinks pointing to them.

Steps to complete:
1. Run the rename script: `./bin/rename_files.sh -r . CLAUDE.md AGENTS.md`
2. Run the symlink script: `./bin/symlink_files.sh -r . AGENTS.md CLAUDE.md`
3. Stage ONLY CLAUDE.md and AGENTS.md files using: `git add '**/*CLAUDE.md' '**/*AGENTS.md' '*CLAUDE.md' '*AGENTS.md'`
4. Check if there are staged changes with `git diff --staged --quiet`
5. If there are NO staged changes, stop here and report that no changes were needed
6. If there ARE staged changes:
   - Commit with message: "Convert CLAUDE.md to AGENTS.md with symlinks"
   - Push the changes to the current branch

After completing, confirm what files were converted and whether changes were committed and pushed.

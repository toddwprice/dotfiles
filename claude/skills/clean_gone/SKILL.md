---
name: todd:clean-gone
description: Cleans up all git branches marked as [gone] (branches that have been deleted on the remote but still exist locally), including removing associated worktrees.
---

## Your Task

You need to execute the following bash commands to clean up stale local branches that have been deleted from the remote repository.

## Commands to Execute

1. **Prune stale remote-tracking refs FIRST, then list branches with `[gone]` status.**
   This step is essential: a branch only shows `[gone]` *after* its deleted `origin/...` ref is
   pruned. Skip the prune and a not-recently-fetched repo shows nothing, so the skill silently
   no-ops even when gone branches exist.
   ```bash
   git fetch --prune
   git branch -vv | grep ': gone]'
   ```
   Use `git branch -vv` (double-v) and match the tracking field `': gone]'` — this anchors on the
   upstream relationship, so it won't false-match a branch whose commit *subject* contains the text
   "[gone]". Branches with a `+` prefix have associated worktrees and must have their worktrees
   removed before deletion.

2. **Next, identify worktrees that need to be removed for [gone] branches**
   Execute this command:
   ```bash
   git worktree list
   ```

3. **Finally, remove worktrees and delete [gone] branches (handles both regular and worktree branches)**
   Execute this command:
   ```bash
   # Process all [gone] branches (git fetch --prune already run in step 1), removing '+'/'*' prefix if present
   git branch -vv | grep ': gone]' | sed 's/^[+* ]*//' | awk '{print $1}' | while read branch; do
     echo "Processing branch: $branch"
     # Find and remove worktree if it exists
     worktree=$(git worktree list | grep "\\[$branch\\]" | awk '{print $1}')
     if [ ! -z "$worktree" ] && [ "$worktree" != "$(git rev-parse --show-toplevel)" ]; then
       echo "  Removing worktree: $worktree"
       git worktree remove --force "$worktree"
     fi
     # Delete the branch
     echo "  Deleting branch: $branch"
     git branch -D "$branch"
   done
   ```

## Expected Behavior

After executing these commands, you will:

- See a list of all local branches with their status
- Identify and remove any worktrees associated with [gone] branches
- Delete all branches marked as [gone]
- Provide feedback on which worktrees and branches were removed

If no branches are marked as [gone], report that no cleanup was needed.

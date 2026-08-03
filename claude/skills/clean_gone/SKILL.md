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

3. **Then clean up one branch at a time — never in a loop.**

   ⚠️ **Do not write a `while read` loop here.** The permission classifier denies blind
   delete loops and denies `git worktree remove --force` outright. A loop that works when
   you paste it by hand will be refused in auto mode, and the skill stalls halfway through.
   Verified 2026-07-31. Budget ~12 Bash calls for a 5-branch cleanup — that's the cost of
   this working at all.

   For **each** branch from step 1, in this order:

   **a. Confirm the PR actually merged.** Ancestry checks are useless here: dscout
   squash-merges, so the branch's commits never appear in `main` by SHA, and the `.bare`
   store is shallow which breaks reachability independently. `git branch --merged` will
   under-report and tempt you to keep a branch that's long dead. Ask GitHub instead:
   ```bash
   gh pr list --head <branch> --state all --json number,state,mergedAt
   ```
   Merged → safe to remove. Open → leave it alone. No PR at all → stop and ask Todd.

   **b. Check the worktree for real work before touching it.**
   ```bash
   git -C <worktree-path> status --porcelain
   ```
   Any output means uncommitted or untracked files. Show them to Todd and stop — do not
   discard someone's work to finish a cleanup.

   **c. Clear the tree, then remove the worktree without `--force`.** If `status` showed
   only junk Todd agrees to drop, delete those specific paths (`rm <path>` /
   `git -C <worktree-path> restore <file>`) rather than reaching for `--force`. Explicit
   per-file discards are both allowed by the classifier and safer, because each one is
   visible. Then, **from outside the target worktree** (cd to `main` first — `git worktree
   remove` refuses to run from inside the tree it's removing):
   ```bash
   git worktree remove <worktree-path>
   ```

   **d. Delete the branch — one branch per Bash call.**
   ```bash
   git branch -D <branch>
   ```

   If a call comes back with `temporarily unavailable` or a "Stage 2 classifier error",
   that's a transient flake, not a denial. Retry the identical command and it goes through.

## Expected Behavior

After executing these commands, you will:

- See a list of all local branches with their status
- Confirm via `gh` that each branch's PR actually merged before removing anything
- Remove the associated worktrees (non-force, from outside each tree)
- Delete the merged, gone branches one at a time
- Report which worktrees and branches were removed, and name anything you skipped and why

If no branches are marked as `[gone]`, report that no cleanup was needed — after confirming
step 1's `git fetch --prune` actually ran, since without it the list is empty by construction.

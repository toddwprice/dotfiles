---
name: "git-optimize-git"
description: Analyze and optimize Git repository performance
allowed-tools: Bash(*), Read(*), Write(*)
---

Perform a comprehensive Git repository health check and optimization. This command diagnoses performance issues and applies proven fixes to improve daily Git operations.

## Your Task

You are a Git performance optimization expert. Follow these steps systematically:

### Phase 0: Pre-Flight Checks

**Validate environment before analysis:**
```bash
# Check Git version (need 2.23+ for best features)
git --version

# Detect worktree setup
cat .git 2>/dev/null | grep "gitdir:" && echo "WORKTREE DETECTED"

# Check available disk space
df -h .

# Check for active Git operations
ls .git/*.lock 2>/dev/null && echo "⚠️ Git operation in progress - ABORT"

# Verify repo integrity
git fsck --no-progress --no-dangling 2>&1 | head -20
```

**Decision Point:**
- If worktree detected: **ANALYSIS ONLY** - skip all Phase 2 optimizations
- If locks exist: **ABORT** - Git operation in progress
- If Git < 2.23: **WARN** - Some features may not be available
- If disk space < 2x repo size: **WARN** - Skip repack step

### Phase 1: Establish Baseline Metrics

1. **Capture current performance:**
   ```bash
   # Repository size
   du -sh .git

   # Pack file count and size
   git count-objects -vH

   # Time common operations
   time git status
   time git log --oneline -n 100
   time git fetch --dry-run
   ```

2. **Identify issues:**
   - Check pack file count (should be 1-2, flag if >5)
   - Count remote refs: `git for-each-ref refs/remotes/ | wc -l`
   - Count local branches: `git for-each-ref refs/heads/ | wc -l`
   - Count tags: `git tag | wc -l` (flag if >1000, CRITICAL if >5000)
   - Find largest blobs: `git rev-list --objects --all | git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' | awk '/^blob/ {print substr($0,6)}' | sort -nr -k2 | head -10`
   - Check Git configs for missing performance settings
   - Look for dangling objects: `git fsck --no-progress 2>&1 | grep "dangling" | wc -l`

3. **Severity Assessment:**
   - **CRITICAL**: Pack count >10, Tags >5000, Single blob >100MB, Status >2s
   - **HIGH**: Pack count >5, Tags >1000, Stale refs >100, Status >1s
   - **MEDIUM**: Pack count >2, Tags >500, Missing perf configs
   - **LOW**: Everything else

4. **Document findings** in a clear baseline report with severity levels

### Phase 2: Apply Optimizations (in order)

**IMPORTANT SAFETY CHECKS:**
1. Check if this is a worktree: `cat .git` - if it shows `gitdir:`, only proceed with read-only analysis
2. Check for active operations: `ls .git/*.lock 2>/dev/null` - abort if any exist
3. Verify disk space: Ensure at least 2x repo size available before repack
4. Warn user: Optimizations will modify repository state - confirm before proceeding

**Step 1: Pack Consolidation**
```bash
# ⚠️ ONLY if pack count > 5 (skip if 1-5 packs)
# ⚠️ Requires 2x disk space and 5-30 minutes
# ⚠️ Will block other Git operations

# Check available disk space first
df -h .git

# Use moderate settings for safety (not aggressive)
git repack -a -d --depth=100 --window=100
```
**Gotchas:**
- Needs ~2x repo size in free disk space temporarily
- CPU-intensive, can take 5-30 minutes on large repos
- Blocks other Git operations while running
- Don't run on CI/CD or during active development

- **Measure**: Re-run `time git status` and `git count-objects -vH`
- **Report**: Pack count change and timing improvement

**Step 2: Prune Stale Remote Branches (NOT auto-prune)**
```bash
# ⚠️ MANUAL PRUNING ONLY - do NOT enable fetch.prune
# Show what would be pruned first
git remote prune origin --dry-run

# Ask user to confirm before pruning
# Then prune if confirmed
git remote prune origin
```
**Gotchas:**
- **DO NOT** enable `fetch.prune` globally - it auto-deletes tracking branches
- If upstream force-pushes or deletes branches, local refs disappear
- Can break scripts that depend on `origin/branch-name` existing
- Can't easily recover deleted tracking branches

- **Measure**: Count remote refs before/after, re-time `git fetch --dry-run`
- **Report**: Number of refs pruned and fetch time improvement

**Step 3: Performance Configs**
```bash
# Only set if not already configured
# Check each before setting
git config core.preloadindex true      # Parallel index loading
git config core.fscache true           # Filesystem caching (Mac/Windows only, no-op on Linux)
git config feature.manyFiles true      # Optimize for large repos (Git 2.32+)
git config pack.threads 0              # Use all CPU cores for pack ops
```
**Gotchas:**
- `core.fscache`: Mac/Windows only, ignored on Linux
- `core.preloadindex`: Can cause issues on network filesystems (NFS/SMB)
- `feature.manyFiles`: Requires Git 2.32+, gracefully ignored on older versions
- `pack.threads 0`: Uses ALL CPUs - can make system unresponsive during pack operations

- **Measure**: Re-run `time git status`
- **Report**: Status time improvement

**Step 4: Conservative Garbage Collection**
```bash
# ⚠️ Use conservative 90-day expiry to preserve recovery options
# ⚠️ This PERMANENTLY deletes old commits that aren't reachable

# Ask user if they want aggressive (30d) or conservative (90d) cleanup
# Default to conservative

# Conservative (recommended):
git reflog expire --expire=90.days.ago --all
git gc --prune=90.days.ago

# Aggressive (only if user confirms):
# git reflog expire --expire=30.days.ago --all
# git gc --prune=30.days.ago
```
**Gotchas:**
- **IRREVERSIBLE**: Permanently deletes unreachable commits and expired reflog entries
- Can't recover from accidental `git reset --hard` or deleted branches after gc
- Can't undo `git commit --amend` or `git rebase` if old commits are pruned
- In team repos, someone might need commits you delete
- Recommend 90-day expiry minimum for safety

- **Measure**: Final `du -sh .git` and `git count-objects -vH`
- **Report**: Size reduction and final pack count

### Phase 3: Final Report

Create a summary table showing:

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| git status | Xs | Xs | X% faster |
| git log (100) | Xs | Xs | X% faster |
| git fetch | Xs | Xs | X% faster |
| Pack files | N | N | Change |
| Pack size | X MB | X MB | X% smaller |
| Remote refs | N | N | N pruned |
| .git directory | X GB | X GB | X% smaller |

### Phase 4: Post-Optimization Validation

**Verify repository health after changes:**
```bash
# Run integrity check
git fsck --no-progress --no-dangling

# Verify pack files are healthy
git verify-pack -v .git/objects/pack/*.idx 2>&1 | head -5

# Test basic operations
git status
git log -1
```

**If any errors occur:**
- Document the error
- Suggest: `git gc --auto` for automatic cleanup
- Recommend user verify with: `git clone` to fresh directory

### Phase 5: Recommendations & Long-Term Strategy

**Based on findings, provide specific recommendations:**

**If excessive tags detected (>1000):**
- Recommend tag cleanup strategy
- Suggest: Archive old tags to separate repo
- Consider: Only fetch tags when needed with `git fetch --no-tags`

**If large binary files found (>50MB each):**
- Identify the files and their history impact
- Recommend: Git LFS migration for future commits
- Suggest: BFG Repo-Cleaner or git-filter-repo to rewrite history (DANGEROUS)
- Provide commands:
  ```bash
  # See which commits contain large file
  git log --all --pretty=format:%H -- path/to/large/file.pkl

  # If safe to remove from history (team coordination required)
  # git filter-repo --strip-blobs-bigger-than 10M --force
  ```

**If many stale branches (>50):**
- Recommend regular cleanup schedule
- Suggest: `git branch --merged | xargs git branch -d`
- Consider: GitHub/GitLab branch protection + auto-delete

**Monitoring commands for future:**
```bash
# Weekly health check
git count-objects -vH
time git status

# Monthly deep check
git fsck --no-progress
git gc --auto

# Before major operations
df -h .git
git for-each-ref refs/remotes/ | wc -l
```

**Maintenance schedule suggestion:**
- **Daily**: `git status` timing check
- **Weekly**: Check pack count, run `git gc --auto` if needed
- **Monthly**: Full optimization run (this command)
- **Quarterly**: Review tags, large files, branch cleanup

## Important Notes

- **Always measure before and after each step** to show incremental improvements
- **Explain what each optimization does** and why it helps
- **Use timeouts** for long operations (git repack can take 5-30 minutes)
- **Be cautious**: Always preview destructive operations (--dry-run first)
- **Get user confirmation** before any destructive operation (prune, gc)
- **Focus on impact**: Highlight the changes with biggest performance gains
- **Safety first**: Use conservative settings by default (90-day gc, moderate repack depth)

## Critical Safety Rules

1. **Worktrees**: If `.git` is a file (worktree), skip all write operations - only run diagnostics
2. **Disk Space**: Verify 2x repo size available before running `git repack`
3. **No Auto-Prune**: Never enable `git config fetch.prune` - manual pruning only
4. **Conservative GC**: Default to 90-day expiry, only use 30-day if user explicitly requests
5. **Lock Files**: Check for `.git/*.lock` files - abort if any Git operation is running
6. **User Confirmation**: Ask before pruning refs or running gc - explain what will be deleted
7. **Validation**: Always run `git fsck` after gc/repack to verify integrity
8. **Rollback Awareness**: No rollback possible after gc - warn users to backup if nervous

## Error Recovery

**If repack fails mid-operation:**
```bash
# Remove incomplete pack files
rm .git/objects/pack/tmp_pack_*

# Run auto-gc to clean up
git gc --auto
```

**If gc corrupts repository (rare):**
```bash
# Verify corruption
git fsck --full

# If corrupted, clone fresh copy
git clone <original-url> <new-directory>
cd <new-directory>
git remote add old-repo <path-to-old-repo>
git fetch old-repo
```

**If you regret pruning refs:**
```bash
# Check reflog (if still within expiry)
git reflog show --all

# Re-fetch from remote
git fetch origin <branch-name>
```

## Expected Outcomes

- Consolidated pack files (1-2 packs)
- Faster status/diff/log operations (30-80% improvement)
- Reduced .git size (typically 2-10% smaller)
- Cleaner ref structure (stale branches pruned)
- Optimized Git configuration for daily use

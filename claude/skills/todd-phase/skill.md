---
name: todd:phase
description: Use when the user runs /todd:phase to automatically implement remaining tickets in the earliest phase with open work. Implements tickets in parallel git worktrees, then assembles them into a single linear stack of PRs (each PR's base is the previous PR's branch). Requires git and gh CLI, and a Linear project name as the first argument unless one is explicitly defined in the repository's CLAUDE.md.
---

# Todd Phase

## Overview

Automatically implements the remaining open tickets in the earliest phase of a Linear project that still has work to do. **Produces a single linear stack of PRs** (one PR per ticket, each stacked on the previous) using git worktrees for the parallel-implementation and stack-assembly workflow.

The skill runs in four phases:

1. **Resolve & plan** — read project, find earliest open phase, topologically order tickets.
2. **Parallel implementation** — one git worktree per ticket, all branched off `main`, dispatched in parallel.
3. **Stack assembly** — `git rebase` walks the success list and produces a linear chain.
4. **PR creation** — bottom-up, push branches and open PRs with stacked bases.

This skill implements a stacked-PR workflow using plain git worktrees (no jj required).

## Workflow Note

This skill uses **git worktrees** as the isolation primitive. Each ticket gets its own working copy at `.worktrees/{TICKET_ID}/` with its own branch, created from `main`. Git worktrees work with any repo layout — including a bare repo at `.bare/` with a top-level `.git` gitfile pointer — so no special jj setup is required.

Branches are created directly at worktree-add time (`git worktree add -b <BRANCH_NAME> .worktrees/{TICKET_ID} main`). Stack assembly is done by rebasing each branch onto its predecessor via `git rebase`.

## Naming

Two distinct names per ticket — keep them straight:

- **`{TICKET_ID}`** — the Linear ticket identifier exactly as shown in the UI (uppercase, e.g., `CNVS-583`, `DEV-77`). Used for the **worktree directory**: `.worktrees/{TICKET_ID}/`. Short, predictable, matches what the user sees in Linear.

- **`{BRANCH_NAME}`** — the value Linear exposes as **"copy git branch name"** in its UI. Fetch this from Linear's API (the `gitBranchName` GraphQL field; surfaced by `linctl issue get <ID> --json` as the `.branchName` key, and by `mcp__claude_ai_Linear__get_issue` under its equivalent field). Used as the actual git branch pushed to origin and referenced in PRs. Example for CNVS-583: `cnvs-583-add-rule_manifest-column-typed-schema-to-study_templates`. Do **not** slugify locally — Linear is the source of truth for this exact string (underscores, hyphens, and all).

If `branchName` is missing/empty for a ticket, halt with a clear error rather than inventing a name. (The user can add one in Linear and re-run.)

## Usage

```
/todd:phase [PROJECT_NAME] [--max-parallel N] [--skip-reviews] [--reviewers user1,user2]
```

**Arguments:**
- `PROJECT_NAME` (required, unless defined in repo's CLAUDE.md): The Linear project name or ID.
- `--max-parallel N` (optional, default 3): Maximum concurrent worktrees during parallel implementation.
- `--skip-reviews` (optional): All PRs open as ready-for-review with no reviewers requested. For solo / unattended runs.
- `--reviewers user1,user2` (optional): Override auto-detected reviewer set. Ignored if `--skip-reviews` also passed.

**Examples:**
```
/todd:phase "Glazing 2"                          # Reviews on, max 3 parallel
/todd:phase "Glazing 2" --skip-reviews           # Solo / unattended mode
/todd:phase "Glazing 2" --max-parallel 5         # Up to 5 parallel worktrees
/todd:phase "Glazing 2" --reviewers alice,bob    # Override reviewer set
/todd:phase                                       # Only valid if CLAUDE.md defines a Linear project
```

## Implementation Steps

### Step 0: Resolve Project Name

1. **If `PROJECT_NAME` was supplied**, use it directly and skip to Step 0.5.

2. **If no argument was supplied**, read the repository's `CLAUDE.md` and search for an explicit Linear project reference. Recognized forms:
   - A "Linear Project" or "Linear project" entry with a `linear.app/<org>/project/<slug-or-id>` URL
   - A bold/labeled field such as `**Linear Project**:` followed by a project name, URL, or ID
   - A `linear_project:` or `linear-project:` key in a frontmatter/config block

3. **If CLAUDE.md does not exist or has no Linear project reference**, halt:
   ```
   Error: PROJECT_NAME is required. Supply it as an argument (e.g. /todd:phase "Glazing 2"),
   or add a "Linear Project" reference to this repo's CLAUDE.md.
   ```

4. **Parse flags**: `--max-parallel N` (default 3), `--skip-reviews` (default false), `--reviewers` (default auto-detect).

5. **Report**: resolved `PROJECT_NAME`, source (argument vs. CLAUDE.md), and flag values.

### Step 0.5: Git Precheck

Run from the repo root (a dir git recognizes — including a container dir with a `.git` gitfile pointing at a bare repo):

```bash
git rev-parse --show-toplevel >/dev/null   # confirm we're in a git repo
git rev-parse --verify --quiet main        # confirm `main` exists as a local branch
```

If either fails, halt:

```
Error: this directory isn't inside a git repo, or the branch `main` doesn't exist locally.

Ensure:
  - You run /todd:phase from a git work tree (including container dirs that use a .git gitfile → .bare pointer).
  - `main` is present locally, not just as `origin/main`. If needed: `git branch main origin/main`.
```

Also verify the working tree is clean:

```bash
test -z "$(git status --porcelain)"
```

If dirty, halt with: `Error: dirty working tree — commit or stash changes before running /todd:phase.`

### Step 1: Find Earliest Phase With Open Tickets

1. **Get project milestones**: Use `mcp__claude_ai_Linear__list_milestones` with `project` set to `PROJECT_NAME`. Sort by `sortOrder` ascending.

2. **Get all project issues**: Use `mcp__claude_ai_Linear__list_issues` with `project` set to `PROJECT_NAME`, including `includeRelations=true`.

3. **Determine open tickets per phase**: For each milestone, count issues where `projectMilestone.name` matches AND status is NOT "Done", "Canceled", or "Archived".

4. **Pick target phase**: First milestone (smallest `sortOrder`) with open count > 0.

5. **Halt if none found**: Report "All phases complete — no open tickets found" and stop.

6. **Report**: which phase, open count, and whether resuming a partial phase.

### Step 2: Compute Stack Order

1. **Filter** the issue list from Step 1 to the chosen phase, excluding terminal statuses.

2. **Build dependency graph** from `blockedBy` / `blocks` relations.

3. **Sort**:
   - Primary: topological order from `blockedBy` edges (so X comes before Y if Y is blockedBy X)
   - Secondary: Linear priority ascending (1=Urgent → 4=Low) as tiebreaker among independent tickets

4. **Detect cycles**: if the dependency graph has a cycle, halt with the offending ticket IDs.

5. **Report**: the ordered list `[T₁, T₂, ..., Tₙ]` with each ticket's `TICKET_ID`, `BRANCH_NAME`, title, priority, and `blockedBy` set. (Fetching `BRANCH_NAME` from Linear happens here, once per ticket.)

### Step 3: Parallel Implementation in Git Worktrees

For each ticket Tᵢ, up to `--max-parallel` concurrently:

1. **Resume check**: if `.worktrees/{TICKET_ID}` exists AND the branch `{BRANCH_NAME}` has commits beyond `main` (`git rev-list --count main..{BRANCH_NAME}` > 0), skip (already implemented). Move Tᵢ to `completed`.

2. **Create worktree** (from the repo root):
   ```bash
   mkdir -p .worktrees
   git worktree add .worktrees/{TICKET_ID} -b {BRANCH_NAME} main
   ```

3. **Implement** inside the worktree:
   ```bash
   cd .worktrees/{TICKET_ID}
   /todd:coder plan {TICKET_ID}    # only if plan doesn't exist yet
   /todd:coder impl {TICKET_ID}
   ```

4. **Commit shape**: `/todd:coder` should produce one or more commits on the branch. If multiple commits should logically be one, squash them:
   ```bash
   # inside the worktree
   git reset --soft main
   git commit -m "<single squashed message>"
   ```

5. **Track**: move Tᵢ to `completed` (success) or `failed` (impl error). Failed worktrees are left in place for inspection.

### Step 4: Stack Assembly

Walk the `completed` list in order. For each i ≥ 2, rebase Tᵢ's branch onto Tᵢ₋₁'s branch:

```bash
cd .worktrees/{TICKET_IDᵢ}
git rebase {BRANCH_NAMEᵢ₋₁}
```

**On rebase conflict**: `git rebase` halts with conflict markers. Abort the rebase and mark Tᵢ `not-stackable`:
```bash
git rebase --abort
# Tᵢ stays on its original branch (based on main), intact but not in the stack.
# Tᵢ₊₁ rebases onto Tᵢ₋₁ instead.
```

**On main moving**: if `origin/main` advanced during the run, fast-forward main first, then rebase the bottom of the stack onto it:
```bash
git fetch origin main --quiet
git branch --force main origin/main   # safe — working copy is in a worktree, not on main
cd .worktrees/{TICKET_ID_bottom}
git rebase main
```

The result is a clean linear chain of branches, each rebased onto the previous one.

### Step 5: Push and PR Creation

For each branch in the assembled stack, **bottom-up**:

1. **Push** (from within the worktree):
   ```bash
   cd .worktrees/{TICKET_ID}
   git push -u origin {BRANCH_NAME}
   ```

2. **Resolve reviewers** (skip if `--skip-reviews`):
   - Explicit `--reviewers` flag → use those
   - Else `.github/CODEOWNERS` → let GitHub auto-request CODEOWNERS (pass no `--reviewer` flag)
   - Else `Reviewers:` field in `CLAUDE.md` → use that
   - Else no reviewers requested

3. **Create PR**. Bottom of stack (i == 0): always ready, request review unless `--skip-reviews`.
   ```bash
   gh pr create \
     --base main \
     --head {BRANCH_NAME} \
     --title "$TITLE" --body "$BODY" \
     [--reviewer $REVIEWERS]
   ```
   Capture the returned PR number as `PREV_PR_NUMBER`.

   Upper layers (i ≥ 1): draft by default, ready if `--skip-reviews`. Labelled with `stacked-on:<PREV_PR_NUMBER>` to record the stack order (and to key any future draft→ready promotion Action); today promotion is manual — `gh pr ready` as each prior PR merges (see "Draft→ready promotion").
   ```bash
   # Idempotently ensure the label exists in the repo.
   gh label create "stacked-on:$PREV_PR_NUMBER" --force \
     --description "Flip to ready when PR #$PREV_PR_NUMBER merges" \
     --color ededed

   gh pr create \
     --base {BRANCH_NAMEᵢ₋₁} \
     --head {BRANCH_NAMEᵢ} \
     --title "$TITLE" --body "$BODY" \
     --label "stacked-on:$PREV_PR_NUMBER" \
     [--draft]
   ```
   Capture the newly-created PR's number as the next iteration's `PREV_PR_NUMBER`.

4. **Resume check**: before pushing, check if a PR already exists for the branch (`gh pr view {BRANCH_NAME} --json number,isDraft,labels`). If yes, skip push + create, but **do** capture its number as `PREV_PR_NUMBER` for the next iteration. If the existing upper-layer PR is missing its `stacked-on:<prev-PR-number>` label (e.g., created by an older version of this skill), add it now via `gh pr edit --add-label` so the stack order stays recorded.

5. **Capture URLs** for the final summary.

### Step 6: Cleanup & Summary

1. **Remove successful worktrees**:
   ```bash
   git worktree remove .worktrees/{TICKET_ID}
   ```
   (The branch stays — it's needed for the PR. Only the working-copy dir is cleaned up.)

2. **Leave failed-implementation worktrees** in `.worktrees/` for inspection. Print their paths.

3. **Print stack diagram** with each ticket's status and PR URL:
   ```
   ✅ Stack assembled for phase {PHASE_NAME}:

      ┌─ #125 dev-79-... (draft)  Resolves DEV-79
      │
      ├─ #124 dev-78-... (draft)  Resolves DEV-78
      │
      └─ #123 dev-77-... (ready)  Resolves DEV-77 ◀ review here

   ⚠️  Not stackable (rebase conflict): DEV-66 — worktree at .worktrees/DEV-66
   ❌ Failed: DEV-80 — implementation error, worktree at .worktrees/DEV-80
   ⏭️  Skipped (already done from prior run): DEV-65
   ```

## Worktree Management

- **Location**: `.worktrees/` in the repository root (next to `.git` or `.git` gitfile).
- **Naming**: `.worktrees/{TICKET_ID}` — the Linear identifier exactly as shown in the UI (e.g., `.worktrees/CNVS-583`).
- **Cleanup**: `git worktree remove` after successful PR creation. Failed worktrees are preserved.
- **Manual cleanup hints**: provide `git worktree list` and `git worktree remove {path}` in the summary. Use `--force` if a worktree has uncommitted state the user wants discarded.

## Commit Message Template

```
feat: {ticket_title} ({TICKET_ID})

{implementation_summary_from_todd_coder}

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
```

## PR Body Template

```markdown
## Summary
{summary from ticket description}

## Changes
{changes from implementation summary}

## Testing
{test plan from implementation summary}

## Stack
1. #{N} ◀ this PR
2. #{N+1} (draft, blocked on #{N})
3. #{N+2} (draft, blocked on #{N+1})

This PR is part of a stack created by `/todd:phase` for phase {PHASE_NAME}.
Merge bottom-up. When this PR merges, GitHub's built-in auto-base-change
retargets the next PR's base to `main`; then mark that PR ready for review
(`gh pr ready <number>` — see "Draft→ready promotion").

Resolves {TICKET_ID}
```

## Failure & Resume Semantics

Re-running `/todd:phase` after an interruption is safe and idempotent. State lives in git branches plus GitHub PRs.

| Failure | Behavior |
|---|---|
| `/todd:coder impl` errors | Mark Tᵢ failed, leave worktree, continue. |
| `git rebase` conflict during assembly | `git rebase --abort`, mark Tᵢ not-stackable, continue with Tᵢ₊₁ rebased onto Tᵢ₋₁. |
| `git push` fails | Halt PR creation, report state. Resume reruns cleanly. |
| `gh pr create` fails | Mark Tᵢ as missing-PR. Resume retries. |
| `main` moved during run | After parallel impl, before assembly: `git fetch origin main && git branch --force main origin/main`, then rebase the bottom branch onto main. |
| Dirty working tree at start | Halt with instructions. Refuse to run. |
| `branchName` missing on a ticket | Halt with instructions to set the Linear branch name, then resume. |

Final summary distinguishes four ticket states: `merged-ready` (in stack with PR), `not-stackable` (implemented but conflicted on rebase), `failed` (implementation broke), `skipped` (already done from prior run).

## Draft→ready promotion

Upper PRs in the stack are opened as drafts blocked on the one below. dscout has **no
`promote-next-stacked-pr` automation**, so promote manually: as each PR merges, GitHub retargets the
next PR's base to `main` (built-in auto-base-change) — then mark that next PR ready for review
(`gh pr ready <number>`). The skill prints this reminder at the end of the summary:

```
ℹ️  As each PR merges, run `gh pr ready <next-PR-number>` to un-draft the next PR in the stack.
```

(If a repo you run this in later adds a promotion Action keyed on the `stacked-on:{N}` labels this
skill applies, that step becomes automatic.)

## Configuration

- **Project**: arg or repo `CLAUDE.md`
- **Base branch**: `main`
- **Team**: derived from project
- **Max parallel**: default 3, override with `--max-parallel N`
- **Worktree directory**: `.worktrees/{TICKET_ID}` under the repo root
- **Branch name source**: Linear `gitBranchName` / `branchName` field — never locally generated
- **Reviewers**: `.github/CODEOWNERS` (via GitHub auto-request) → `Reviewers:` in `CLAUDE.md` → none

## Dependency Analysis

Dependencies extracted from Linear's `blockedBy` / `blocks` edges:

- A ticket with `blockedBy: [DEV-65, DEV-66]` cannot be ordered before either of them in the stack.
- A ticket with empty `blockedBy` is ordered by Linear priority among its peers.

**Example:**
```
DEV-65 (no deps, P1) ─┐
                      ├─→ DEV-77 (blockedBy: [DEV-65, DEV-66])
DEV-66 (no deps, P2) ─┘
                      └─→ DEV-78 (blockedBy: [DEV-77])
```

Stack order: `DEV-65 → DEV-66 → DEV-77 → DEV-78` (DEV-65 first by priority, DEV-66 next, then dependents in order).

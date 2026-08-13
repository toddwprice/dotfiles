---
name: todd:phase
description: Use when the user runs /todd:phase to automatically implement remaining tickets in the earliest phase with open work. Implements tickets in parallel git worktrees, then assembles them into a single linear stack of PRs (each PR's base is the previous PR's branch). Requires git and gh CLI, and a Linear project name as the first argument unless one is explicitly defined in the repository's CLAUDE.md.
---

# Todd Phase

## Overview

Automatically implements the remaining open tickets in the earliest phase of a Linear project that still has work to do. **Produces a single linear stack of PRs** (one PR per ticket, each stacked on the previous) using git worktrees for the parallel-implementation and stack-assembly workflow.

The skill runs in four phases:

1. **Resolve & plan** — read project, find earliest open phase, topologically order tickets. The Linear fetch + ordering is delegated to a subagent so the raw whole-project payload never lands in the orchestrator's context.
2. **Delegated implementation** — one git worktree per ticket; each ticket's plan+impl runs in its **own dispatched subagent**, which returns only a compact summary. The orchestrator keeps the summaries, not the implementation transcripts — that's what stops a phase of N tickets from stacking N full implementations into one context window. Independent tickets branch off `main` and run in parallel (up to `--max-parallel`); a ticket blocked by another in the batch branches off the blocker's branch and runs in a later wave.
3. **Stack assembly** — `git rebase` linearizes any independent branches into a single chain (dependent branches are already based correctly, so they need no rebase).
4. **PR creation** — bottom-up, push branches and open PRs with stacked bases.

This skill implements a stacked-PR workflow using plain git worktrees (no jj required). The design principle: **heavy per-ticket work lives in subagents; the orchestrator only coordinates** — dispatch, collect compact summaries, assemble the stack, open PRs. Keeping the orchestrator lean is what lets a multi-ticket phase run to completion without context compaction.

## Workflow Note

This skill uses **git worktrees** as the isolation primitive. Each ticket gets its own working copy at `.worktrees/{TICKET_ID}/` with its own branch, created from `main` — or, for a ticket blocked by another in the same batch, from the blocker's branch (see Step 3 waves). Git worktrees work with any repo layout — including a bare repo at `.bare/` with a top-level `.git` gitfile pointer — so no special jj setup is required.

Branches are created directly at worktree-add time (`git worktree add -b <BRANCH_NAME> .worktrees/{TICKET_ID} <BASE>`). Stack assembly then rebases any main-based branches onto their predecessor via `git rebase`.

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

> **Delegate the fetch + ordering (Steps 1–2) to a subagent.** The whole-project issue list with relations is a large payload you don't want sitting in the orchestrator. Dispatch one subagent that runs Steps 1 and 2 below and returns **only** the compact result: the chosen phase name, and the ordered ticket list — each entry with `TICKET_ID`, `BRANCH_NAME`, title, priority, and `blockedBy`. The raw Linear JSON stays in the subagent's context; the steps below are that subagent's instructions.

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

### Step 3: Delegated Implementation in Git Worktrees

Each ticket's plan+impl runs in its **own dispatched subagent**, never inline. This is the heart of the skill's context budget: the orchestrator must not carry any ticket's exploration, red-green-refactor, or test output — only the compact summary the subagent returns. Running `/todd:coder` inline here would stack every ticket's full implementation into one context and blow the window on a multi-ticket phase. Delegation is also the *only* way the `--max-parallel` concurrency is real — a single agent runs tool calls sequentially; parallelism comes from dispatching multiple subagents in one message. (See `superpowers:dispatching-parallel-agents` for the pattern and prompt structure.)

**Order tickets into dependency waves.** From the `blockedBy` edges (within this batch only), build topological layers: wave 0 = tickets with no in-batch blocker; wave 1 = tickets blocked only by wave-0 tickets; and so on. Independent tickets share a wave and run in parallel; a dependent ticket waits for its blocker's branch to exist, because it needs the blocker's *code* present to implement against (an off-`main` worktree wouldn't have it). Process waves in order; within a wave, dispatch up to `--max-parallel` subagents in a single message, batching if the wave is larger than `--max-parallel`.

For each ticket Tᵢ in the current wave:

1. **Resume check**: if `.worktrees/{TICKET_ID}` exists AND `git rev-list --count {BASE}..{BRANCH_NAME}` > 0, it's already implemented — skip, move Tᵢ to `completed`, and capture its head commit for later. (`{BASE}` defined next.)

2. **Pick the base branch** `{BASE}`: `main` if Tᵢ has no in-batch blocker; otherwise the `{BRANCH_NAME}` of its (already-completed) blocker.

3. **Create the worktree and seed env** (from the repo root):
   ```bash
   mkdir -p .worktrees
   git worktree add .worktrees/{TICKET_ID} -b {BRANCH_NAME} {BASE}

   # Fresh worktrees don't inherit gitignored env files, so the subagent's
   # tests/tooling would fail without them (a real trip-up from past runs).
   # Copy any gitignored .env* files into the new worktree at the same paths:
   ROOT="$(git rev-parse --show-toplevel)"
   git -C "$ROOT" ls-files --others --ignored --exclude-standard \
       -- ':(glob)**/.env' ':(glob)**/.env.*' '.env' 2>/dev/null | while read -r f; do
     mkdir -p ".worktrees/{TICKET_ID}/$(dirname "$f")"
     cp "$ROOT/$f" ".worktrees/{TICKET_ID}/$f"
   done
   ```

4. **Dispatch a subagent** (general-purpose) for Tᵢ. Give it a **self-contained** prompt — it must not inherit this session's history, so construct exactly the context it needs:
   - Work **only** inside `.worktrees/{TICKET_ID}` (cd there first). Never touch other worktrees; never push.
   - **Plan-staleness guard**: if a plan already exists on the ticket, verify the files/paths it names still exist before trusting it. If the plan is stale (renamed or deleted paths — a real failure mode from past runs), re-plan against current code rather than following it blindly.
   - Run `/todd:coder plan {TICKET_ID} --orchestrated` (only if no usable plan exists).
   - **Check the plan before implementing it.** If `/todd:coder plan` just ran, **always** run `/todd:plan-check {TICKET_ID} --strict` — that path always leaves the plan unstamped, so it always needs checking. If you reused an existing plan instead, read its stamp: `/todd:plan-check` writes one line as the last line of the plan comment, after a `---`. Take the last line containing `Plan check:` and classify it:
     - `❌` → **failed**. A `**🔴 Open blockers**` block below the stamp line carries each finding in full prose — put those in `BLOCKERS`, not a code list. (Stamps written before 2026-08-13 may instead end in a bare `see C1, E11, B5`, and those codes are all there is.)
     - `⚠️ passed (ungrounded)` → **passed, but grounding was never checked** (the anchor file was missing). Proceed, and say grounding went unchecked.
     - `✅ passed with N advisories` → **passed under the default regime, but not under yours.** `--strict` admits no advisories, so a stamp like this was written by `/todd:plan` phase 7 and hasn't faced your bar. Re-run `/todd:plan-check {TICKET_ID} --strict` and classify what that returns.
     - `✅ passed` → **passed**.
     - No `Plan check:` line anywhere → **unchecked** — not the same as failed. Run `/todd:plan-check {TICKET_ID} --strict`.

     `❌` → **do not dispatch impl for this ticket.** Under `--strict` that includes any open judgement call *and* any advisory. Return `STATUS: recoverable` with each blocker's prose in `BLOCKERS` — not its check id, which tells whoever picks this up nothing about what to fix — so step 5 marks the ticket failed and the phase carries on. If the stamp says `pass 3`, say so: the plan↔check loop is out of laps and a re-plan won't clear it. **Not `plan-required`** — that status re-dispatches a `plan` step, which would post a second plan comment and walk straight into the duplicate case named next. Running plan-check here also catches the duplicate-plan case (its A4 check) — `/todd:coder plan` posts a new plan comment every time without looking for an existing one, and this path has produced duplicates before.
   - Then run `/todd:coder impl {TICKET_ID} --orchestrated`.
   - Squash to one logical commit on `{BRANCH_NAME}` if impl produced several: `git reset --soft {BASE} && git commit`.
   - Return **only** the `/todd:coder` structured status block (STATUS / TICKET / COMMIT / FILES / TESTS / BLOCKERS / PR_TITLE / PR_BODY) — nothing else.

5. **Track** from each returned status: move Tᵢ to `completed` (STATUS: success) or `failed` (recoverable/fatal). Keep the returned `COMMIT`, `PR_TITLE`, and `PR_BODY` — Steps 4–5 use them without re-reading anything. Failed worktrees are left in place for inspection. A ticket whose in-batch blocker failed is marked `skipped` (there's no branch to base it on).

### Step 4: Stack Assembly

Goal: a single linear chain of branches for the PR stack. Dependent tickets are **already** based on their blocker's branch (Step 3 wave logic), so they need no rebasing. Independent tickets were based on `main` and must be rebased onto the branch below them to form the chain. Walk the `completed` list in stack order; for each i ≥ 2 whose branch is not already based on Tᵢ₋₁, rebase it:

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
- **Env seeding**: gitignored `.env*` files are copied into each new worktree at creation (Step 3) so the subagent's tests/tooling can run — fresh worktrees don't inherit them.
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
| Ticket subagent returns `STATUS: recoverable` or `fatal` | Mark Tᵢ failed, leave worktree, continue. |
| A ticket's in-batch blocker failed | Mark Tᵢ `skipped` — there's no branch to base it on; continue. |
| Ticket subagent returns `STATUS: plan-required` | Re-dispatch with a `plan` step first, then `impl`. |
| `git rebase` conflict during assembly | `git rebase --abort`, mark Tᵢ not-stackable, continue with Tᵢ₊₁ rebased onto Tᵢ₋₁. |
| `git push` fails | Halt PR creation, report state. Resume reruns cleanly. |
| `gh pr create` fails | Mark Tᵢ as missing-PR. Resume retries. |
| `main` moved during run | After delegated impl, before assembly: `git fetch origin main && git branch --force main origin/main`, then rebase the bottom branch onto main. |
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

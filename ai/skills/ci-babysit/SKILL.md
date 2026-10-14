---
name: ci-babysit
description: Monitor a PR's RWX run until all tasks pass. Polls run status (or streams via `rwx run --loop`), diagnoses failures, applies fixes, pushes, and re-monitors. Does not stop until the whole run is green or you intervene.
disable-model-invocation: true
allowed-tools: Bash(rwx *), Bash(git:*), Bash(gh:*)
---

# CI Babysit

Monitor a PR's **RWX** run from start to finish. When a task fails, diagnose it, fix it, push the
fix, and keep watching. Do not stop until every task in the run is green.

> dscout runs CI on **RWX** (https://cloud.rwx.com/mint/dscout/runs), not CircleCI. RWX runs are a
> DAG of **tasks** (not "jobs"/"workflows"). Config lives in `.rwx/*.yml`. If the `rwx` CLI is
> deferred/absent, install it (`brew install rwx-cloud/tap/rwx`) and confirm sign-in with
> `rwx whoami`. When unsure of a subcommand's flags, check `rwx <cmd> -h` or
> `rwx docs pull /migrating/rwx-reference`.

## Getting Started

Determine what to monitor:
- `$ARGUMENTS` has a PR number/URL → resolve its branch, monitor that branch's run.
- `$ARGUMENTS` has an RWX run URL (`cloud.rwx.com/mint/dscout/runs/...`) → monitor that run.
- `$ARGUMENTS` empty → detect from the current branch:

```bash
git branch --show-current
git remote get-url origin
```

Use `gh pr view` to find the PR for the current branch. If no PR exists, monitor the branch run directly.

## Step 1 — Identify the Run

```bash
rwx results            # current status of runs for this repo/branch (see `rwx results -h`)
rwx whoami             # confirm signed in first if results errors on auth
```

Record the run id/URL, the task DAG, and initial task statuses. If no run exists yet (e.g. just
pushed), wait and re-check — RWX may take a moment to create it.

**Fast path — the native babysit primitive:** `rwx run --loop` streams task logs live *and*
re-triggers a run on every push. For an interactive session where you'll be pushing fixes, prefer:

```bash
rwx run --loop
```

Fall back to the polling loop below when running headless or when `--loop` isn't appropriate.

## Step 2 — The Monitor Loop

```
LOOP (until all tasks pass or user interrupts):
  1. CHECK   — `rwx results` (or read the `--loop` stream) for current task statuses
  2. ASSESS  — Categorize each task: running, queued, success, failed, cancelled
  3. DECIDE  —
     - All tasks passed  → EXIT with success summary
     - Tasks running     → WAIT and re-check
     - Task failed       → DIAGNOSE and FIX
  4. REPORT  — Brief status update
```

### Wait Strategy

- Poll every ~90 seconds — never exceed 2 minutes between checks (`--loop` streams, so no polling needed there).
- Brief status update every ~2 checks (~3 min): which tasks are running and for how long.
- A task running unusually long (>30 min without progress) → flag it, keep waiting.

## Step 3 — Diagnose Failures

When a task fails, pull its logs (and artifacts, which matter a lot for E2E):

```bash
rwx logs <run-or-task ref>          # failure logs for the task (see `rwx logs -h`)
rwx artifacts <run-or-task ref>     # e.g. Playwright trace/video/screenshots on E2E failures
```

### Classify the Failure

| Category | Signals | Action |
|----------|---------|--------|
| **Test failure** | Failed test names, assertion errors | Fix the failing test or the code it tests |
| **Compile/build error** | Syntax/type errors, missing imports, module not found | Fix the build error |
| **Lint/format failure** | Linter output, formatter diff | Run the linter/formatter locally and fix |
| **Dependency issue** | Missing package, version conflict, lockfile mismatch | Fix dependency resolution |
| **Infra/flaky** | Timeout, network error, image pull failure, OOM, agent lost | Rerun the task — not a code issue |
| **Migration failure** | DB errors, migration conflicts | Fix the migration |
| **Unknown** | Unclear logs, no obvious pattern | Present the logs to the user and ask for guidance |

### Flaky Test Detection

RWX has no flaky-test API. Detect heuristically: a task that fails on a timeout/race/network signal
with no relevant diff is likely flaky. For the **Playwright/RWX E2E suite specifically**, defer to
the `flaky-e2e` skill (timeout-widen / artifact-retention / fixture-scoping remedies); for the Elixir
suite, `axon-flaky-test`. On a suspected flake, rerun once before investigating (see Step 4), and
note it in the status update so it can be addressed separately.

## Step 4 — Fix and Push

### For Code Fixes

1. **Read the failing code and tests** — understand what's broken before changing anything.
2. **Make the minimal fix** — fix only what's failing.
3. **Reproduce locally first if possible** — run the specific failing test / linter / build locally
   (see CLAUDE.md pre-push checklist per app). RWX can also run a step in a sandbox:
   `rwx sandbox exec -- <command>`.
4. **Commit** with a clear message: `Fix CI: <what was fixed>`.
5. **Push** (`git push`). If you started `rwx run --loop`, the push auto-triggers a fresh run and the
   stream resumes; otherwise return to Step 2.

### For Infra/Flaky Failures

Rerun **from the failed task** rather than the whole run when possible:
- Re-run from the RWX run page (top-right **Re-run**, or the per-task kebab → re-run just that task).
- Or re-invoke locally: `rwx run .rwx/<file>.yml --wait` (RWX patches the clone with local contents,
  so no push is needed to retry).

Then resume monitoring.

### Fix Limits

- **Max 3 fix attempts per task** — if the same task fails 3× after fixes, stop and escalate with
  what you tried and the current failure.
- **Max 2 flaky reruns per task** — if it still fails after 2 no-diff reruns, it's not flaky; investigate.
- **Never force-push** — always add new commits.
- **Never modify the RWX config** (`.rwx/*.yml`) to make a failure pass. If the config itself is
  wrong, `rwx lint .rwx/<file>.yml` to confirm and flag it for the user.

## Step 5 — Status Reporting

### During Monitoring
```
[HH:MM] Run <id> — 5/8 tasks passed, 2 running (axon-exunit: 4m, e2e: 7m), 1 queued
```

### On Failure Detection
```
[HH:MM] FAILED: task `axon-exunit`
Failure: 2 tests failed in test/accounts/user_test.exs
- test_create_user_with_invalid_email (line 42): expected {:error, changeset}, got {:ok, user}
Diagnosing...
```

### On Fix Applied
```
[HH:MM] Fix pushed (abc1234): Fix email validation in User changeset
New run triggered — resuming monitoring...
```

### On Completion
```
## CI Complete — All Green

Run <id> — all 8 tasks passed
Fixes applied: 2 commits
- abc1234: Fix email validation in User changeset
- def5678: Fix missing preload in permissions test
Flaky reruns: 1 (e2e — timeout, retried clean)
```

## Constraints

- **Rerun from the failed task, not the whole run** — avoid re-running tasks that already passed
  unless a failure suggests earlier tasks produced bad artifacts.
- **Never stop monitoring until every task is green** — running tasks mean keep waiting; failed tasks
  mean fix and retry. The only exits are: all green, user interrupts, or fix limit reached.
- **Never modify RWX configuration** — `.rwx/*.yml` is off-limits as a way to force green. If the
  config is the problem, `rwx lint` it and tell the user.
- **Never force-push** — always add new commits on top.
- **Never skip hooks** — if a pre-commit hook fails on your fix, fix the hook issue too.
- **Minimal fixes only** — fix exactly what's failing; no refactors or cleanup.
- **Ask when stuck** — if you can't determine why something failed or how to fix it, present the
  failure to the user rather than guessing.
```

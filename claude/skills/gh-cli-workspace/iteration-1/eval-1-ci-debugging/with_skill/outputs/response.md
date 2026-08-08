# Debugging CI Failures on PR #247

## Exact Sequence of gh Commands

### Step 1: Get a high-level overview of all checks on the PR

```bash
gh pr checks 247
```

This shows every CI check associated with the PR: name, status (pass/fail/pending), and a link. It gives you the full picture at a glance -- which checks passed, which failed, and which are still running.

### Step 2: Get structured check data for deeper analysis

```bash
gh pr view 247 --json statusCheckRollup \
  --jq '.statusCheckRollup[] | [.name, .status, .conclusion] | @tsv'
```

This retrieves the same information as JSON and formats it as tab-separated values. The structured output makes it easier to identify exactly which checks failed by their conclusion field (`failure`, `cancelled`, `timed_out`, etc.) versus checks that show `success`.

### Step 3: List the workflow runs associated with the PR's branch to get run IDs

```bash
gh run list --branch cnvs-540-screen-recording-loop-android --limit 10
```

The `gh run list` command filtered by the PR's branch returns recent workflow runs with their **run IDs** (databaseId). You need these IDs to drill into the logs. The output includes the run ID, workflow name, status, conclusion, branch, and when it ran.

### Step 4: View the summary of a specific failed run

```bash
gh run view <run-id>
```

Replace `<run-id>` with the actual ID from step 3. This shows the run summary: which jobs ran, their individual statuses, and duration. It breaks down the workflow into its constituent jobs so you can see exactly which job(s) within the workflow failed.

### Step 5: View the logs for only the failed jobs

```bash
gh run view <run-id> --log-failed
```

This is the key command. The `--log-failed` flag filters the (often massive) CI logs down to just the output from failed steps. This is where you will find the actual error messages, stack traces, test failures, or compilation errors that caused CI to break.

### Step 6 (if needed): View logs for a specific job within the run

```bash
gh run view <run-id> --job <job-id>
```

If the `--log-failed` output is still too broad (e.g., multiple jobs failed across different workflows), you can target a specific job. The job ID comes from the output of step 4.

### Step 7 (if needed): View full logs for deeper context

```bash
gh run view <run-id> --log
```

If the failed-only logs do not provide enough context (e.g., you need to see what happened right before the failure), the `--log` flag shows the complete log output for every step in the run.

---

## Debugging Workflow and Why Each Step Matters

### Phase 1: Triage (Steps 1-2)

**Goal:** Understand the scope of the problem.

- `gh pr checks 247` answers the immediate question: "What is failing?" You might see one check failed, or five, or all of them. The answer shapes your entire debugging strategy.
- The JSON variant in step 2 gives you machine-parseable data. If there are many checks, you can quickly filter to just the failures rather than scanning a long list visually.

**Decision point after this phase:**
- If only one check failed, proceed directly to its logs.
- If multiple checks failed, look for a pattern (e.g., all are the same workflow, or they share a common dependency like "build" failing which cascades to "test").
- If checks are still running, you might wait: `gh pr checks 247 --watch`.

### Phase 2: Identify Runs (Step 3)

**Goal:** Map failing check names to actionable run IDs.

- `gh pr checks` shows check names and links, but to use `gh run view` you need the numeric run ID. Listing runs by branch bridges this gap.
- You also get temporal context: was this the latest run, or did a previous run also fail? If the previous run passed, the current commit likely introduced the breakage.

**Decision point after this phase:**
- If the most recent run failed but an earlier one passed, the issue is in the latest commit(s).
- If multiple consecutive runs failed, the issue may be older or environmental (flaky test, expired secret, infrastructure issue).

### Phase 3: Diagnose (Steps 4-5)

**Goal:** Find the actual error.

- `gh run view <run-id>` shows the job-level breakdown. A workflow might have jobs like "lint", "test", "build", "deploy". Knowing which job failed narrows the scope significantly.
- `gh run view <run-id> --log-failed` delivers the actual error output. This is where you find:
  - **Compilation errors** (syntax mistakes, missing imports, type errors)
  - **Test failures** (assertion mismatches, timeouts, missing fixtures)
  - **Linting violations** (formatting, style rules, type checking)
  - **Infrastructure issues** (dependency install failures, Docker build errors, out of disk space)
  - **Timeout errors** (jobs that exceeded their time limit)

**Decision point after this phase:**
- If the error is a clear code issue (test failure, compile error), you know what to fix.
- If the error is environmental (network timeout, flaky test, resource limit), you might try `gh run rerun <run-id> --failed` to rerun just the failed jobs.
- If the logs are truncated or unclear, use `--log` for full context or `--job <job-id>` to isolate a specific job.

### Phase 4: Deep Dive (Steps 6-7, if needed)

**Goal:** Get additional context when the failure is not immediately obvious.

- Viewing a specific job's logs isolates noise from other jobs.
- Full logs (`--log`) show setup steps, environment variable loading, and earlier successful steps that might reveal configuration drift or version mismatches.

---

## How to Interpret Output at Each Step

### Interpreting `gh pr checks 247`

The output is a table with columns: check name, status, and link. Look for:

| What You See | What It Means |
|---|---|
| All checks show `pass` | CI is actually green; the PR page might be stale. Refresh. |
| One check shows `fail` | A specific workflow or external check failed. Note its name. |
| Multiple `fail` entries with different names | Could be independent failures or a cascade (build fails, so test and deploy also fail). |
| A check shows `pending` | Still running. Wait or watch with `--watch`. |
| A check shows `cancelled` | Someone or something cancelled it, or a prior job in the workflow failed and this job was skipped. |

### Interpreting `gh run list` output

Look at the `STATUS` and `CONCLUSION` columns:

- `completed / failure` -- This run has finished and failed. Grab its ID.
- `completed / success` -- This run passed. Useful to compare against the failing run.
- `in_progress / ` -- Still running. You can `gh run watch <id>` to monitor.
- `completed / cancelled` -- Someone cancelled it or it was auto-cancelled (e.g., superseded by a newer push).

### Interpreting `gh run view <run-id>`

The output lists each job in the workflow with its status. Look for:

- Which specific job(s) show `X` (failed) vs `check` (passed).
- Job names often tell you the category: "lint", "test-unit", "test-integration", "build", "deploy".
- If a "build" job failed, downstream jobs (test, deploy) were likely skipped, not independently broken.

### Interpreting `gh run view <run-id> --log-failed`

This is the raw log output. Common patterns to look for:

- **`FAIL` or `FAILED` lines** -- Direct test failure indicators.
- **`Error:` or `error[E...]`** -- Compiler/linter errors with file and line references.
- **`exit code 1` (or non-zero)** -- The step's command returned an error.
- **`timeout`** -- A step exceeded its time limit.
- **`ModuleNotFoundError`, `cannot find module`, `undefined reference`** -- Missing dependency.
- **`permission denied`** -- File or network permission issue.
- **Stack traces** -- Follow the trace to the originating file and line.

### What to Do Next Based on Findings

| Finding | Next Action |
|---|---|
| A specific test assertion failed | Read the test file locally, understand the assertion, fix the code or update the test. |
| Compilation/type error | Fix the code at the referenced file and line. |
| Linting failure | Run the linter locally (`mix lint`, `yarn lint`, etc.) and fix. |
| Flaky test (passes locally, fails in CI) | Rerun with `gh run rerun <id> --failed`. If it fails again, investigate timing/environment differences. |
| Dependency install failure | Check lock files, registry availability, or version constraints. |
| Timeout | Optimize the slow step, or increase the timeout in the workflow YAML. |
| Secret or environment variable missing | Check `gh secret list` and ensure required secrets are configured. |

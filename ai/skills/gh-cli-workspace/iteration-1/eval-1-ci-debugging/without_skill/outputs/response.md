# CI Debugging Workflow for PR #247

## Step-by-Step gh Commands

### Step 1: View the PR and its check status

```bash
gh pr checks 247
```

**Why:** This is the single most important first command. It lists every CI check associated with the PR -- their names, statuses (pass/fail/pending), and URLs. This gives you the full picture of what passed and what failed before diving into any logs.

**How to interpret:** Look for any row with a "fail" or "X" status. Note the exact check/job names that failed -- you will need these in subsequent steps. If all checks are passing or pending, the failure may have been transient (and a re-run might have fixed it).

---

### Step 2: View the PR details for context

```bash
gh pr view 247
```

**Why:** This shows the PR title, description, branch, base branch, labels, and review status. It provides context about what changes are in the PR, which helps you reason about which CI failures might be related to the code changes versus flaky tests or infrastructure issues.

**How to interpret:** Check the branch name and recent activity. If the PR was recently rebased or had commits pushed, a failure might be from a stale run.

---

### Step 3: List the workflow runs for the PR's branch

```bash
gh run list --branch cnvs-540-screen-recording-loop-android --limit 5
```

**Why:** This lists recent workflow runs on the PR's branch, showing run IDs, statuses, workflow names, and timestamps. You need the run ID of the failed run to drill into its logs. The `--limit 5` keeps output manageable while showing enough history to spot patterns (e.g., is this a new failure or has it been failing for multiple runs?).

**How to interpret:** Identify the most recent failed run(s). Note the run ID (a numeric identifier). If you see a pattern of repeated failures, that suggests a real code issue rather than a flaky test. If only the latest run failed, it might be transient.

---

### Step 4: View the specific failed run

```bash
gh run view <run-id>
```

Replace `<run-id>` with the numeric ID from Step 3.

**Why:** This shows the details of a specific workflow run, including all jobs within that run and their individual statuses. A single CI run often contains multiple jobs (e.g., lint, test, build, deploy), and you need to know exactly which job(s) failed.

**How to interpret:** Look at each job listed and its status. Focus on the failed jobs. Note their names -- you will use these to pull logs. If multiple jobs failed, they might share a common root cause (e.g., a compilation error that blocks both test and lint jobs).

---

### Step 5: View the logs for the failed job(s)

```bash
gh run view <run-id> --log-failed
```

**Why:** The `--log-failed` flag is the most efficient way to get logs -- it shows only the output from failed steps within the run, filtering out the noise from all the passing steps. This is where you find the actual error messages, stack traces, or test failures.

**How to interpret:** Read the log output carefully. Common patterns include:
- **Compilation errors**: Usually appear early, with file paths and line numbers
- **Test failures**: Look for assertion errors, expected vs. actual values, and the test file/name
- **Linting failures**: Format violations, unused variables, type errors
- **Timeout/infrastructure**: "timed out", connection refused, OOM killed

---

### Step 6 (if needed): View full logs for a specific job

```bash
gh run view <run-id> --log --job <job-id>
```

**Why:** Sometimes `--log-failed` does not provide enough context. The failure message might reference something that happened earlier in the job (e.g., a setup step that partially failed but was not marked as the failing step). The `--job` flag lets you isolate one job's complete log output.

**How to interpret:** Scroll through the full log looking for warnings or errors that preceded the final failure. Pay attention to setup steps (dependency installation, database setup, asset compilation) that may have set the stage for later failures.

---

### Step 7 (if needed): Re-run failed jobs

```bash
gh run rerun <run-id> --failed
```

**Why:** If the failure looks transient (network timeout, flaky test, infrastructure blip), re-running only the failed jobs saves time compared to re-running the entire workflow. Use this only after you have examined the logs and determined the failure is not caused by a real code issue.

**How to interpret:** After triggering the re-run, use `gh run watch <new-run-id>` to monitor it in real time, or check back with `gh run view` later.

---

## Debugging Workflow Summary

The workflow follows a **funnel pattern** -- start broad and narrow down:

1. **Broad overview** (`gh pr checks 247`): Which checks failed?
2. **Run-level context** (`gh run list`, `gh run view`): Which run and which jobs within it failed?
3. **Log-level detail** (`gh run view --log-failed`): What is the actual error?
4. **Deep dive if needed** (`gh run view --log --job`): What context surrounds the error?
5. **Action** (fix the code, or `gh run rerun --failed` if transient)

This approach avoids the common mistake of immediately dumping all logs (which can be thousands of lines) and instead progressively narrows focus to the specific failure point.

## Decision Tree at Each Step

```
gh pr checks 247
  |
  +--> All passing? --> CI may have recovered. Check if checks are stale.
  |
  +--> Some failing? --> Note the check names
         |
         gh run list --branch <branch>
           |
           +--> Get the failed run ID
                  |
                  gh run view <run-id>
                    |
                    +--> Identify failed job(s)
                           |
                           gh run view <run-id> --log-failed
                             |
                             +--> Compilation error? --> Fix the code
                             +--> Test failure? --> Read assertion, fix test or code
                             +--> Lint failure? --> Run local linter, fix violations
                             +--> Timeout/flaky? --> gh run rerun <run-id> --failed
                             +--> Unclear? --> gh run view <run-id> --log --job <id>
```

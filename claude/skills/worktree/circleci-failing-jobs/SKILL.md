---
name: "circleci-failing-jobs"
allowed-tools: Bash(ops/platform/aws/dscops/scripts/circleci-diagnose.sh:*), Bash(git branch:*)
description: Find failing jobs for a branch or across recent pipelines.
---

## Context

You are a CI/CD diagnostic assistant. Your task is to find failing
jobs and provide actionable information about CI failures.

The diagnostic script is at:
`ops/platform/aws/dscops/scripts/circleci-diagnose.sh`

## Your Task

1. **Determine the branch**: Use `$ARGUMENTS` if provided, otherwise
   detect the current branch:
   ```bash
   git branch --show-current
   ```

2. **Diagnose the branch**: Run the full diagnosis:
   ```bash
   ops/platform/aws/dscops/scripts/circleci-diagnose.sh diagnose <branch>
   ```
   This shows: latest pipeline status, failed workflow, failed jobs,
   failed steps, and step output (last 50 lines).

3. **Get job-level trend data**:
   ```bash
   ops/platform/aws/dscops/scripts/circleci-diagnose.sh job-metrics
   ```
   This shows per-job success rates over the last 7 days.

4. **Present a summary** including:
   - Which jobs failed and their error output
   - Job-level success rates from insights
   - Links to failed jobs in CircleCI UI (the diagnose command
     prints the URL)
   - Whether the failure looks like a flaky test vs. a real failure
   - Suggested next steps

## Known Workflows

- `lint-test-deploy` — Primary CI/CD (all branches except staging-\*)
- `stage-deploy` — Staging deployment (staging-\d+ branches)
- `daily-glia` — Scheduled daily glia tests (main only)

---
name: "circleci-troubleshoot"
allowed-tools: Bash(ops/platform/aws/dscops/scripts/circleci-diagnose.sh:*), Bash(git branch:*), Glob(*), Grep(*), Read(*)
description: Diagnose a specific CI failure with logs and test results.
---

## Context

You are a CI/CD diagnostic expert. Your task is to deeply investigate
a specific CI failure — drill into test results, step logs, and
artifacts to identify the root cause and suggest fixes.

The diagnostic script is at:
`ops/platform/aws/dscops/scripts/circleci-diagnose.sh`

## Your Task

1. **Determine what to diagnose** from `$ARGUMENTS`:
   - If it looks like a number → treat as a job number
   - If it looks like a branch name → diagnose that branch
   - If empty → detect current branch with
     `git branch --show-current`

2. **If starting from a branch**, find the failed job:
   ```bash
   ops/platform/aws/dscops/scripts/circleci-diagnose.sh diagnose <branch>
   ```
   Extract the failed job number from the output.

3. **Get test results** for the failed job:
   ```bash
   ops/platform/aws/dscops/scripts/circleci-diagnose.sh test-results <job-number>
   ```

4. **Get step output** for failed steps:
   ```bash
   ops/platform/aws/dscops/scripts/circleci-diagnose.sh step-output <job-number> <step-name>
   ```
   Get the failed step name from the `diagnose` output or `job`
   command, then fetch its log output.

5. **Get artifacts**:
   ```bash
   ops/platform/aws/dscops/scripts/circleci-diagnose.sh artifacts <job-number>
   ```

6. **Cross-reference flaky tests**:
   ```bash
   ops/platform/aws/dscops/scripts/circleci-diagnose.sh flaky-tests
   ```
   Check if any of the failed tests appear in the flaky list.

7. **Investigate locally**: Use Glob, Grep, and Read to examine the
   relevant source and test files identified in the failure output.

8. **Present a comprehensive diagnosis**:
   - What failed: job name, step name, test names
   - The actual error output (key lines, not everything)
   - Whether this is a known flaky test
   - Root cause analysis if identifiable
   - File paths involved so the developer can investigate
   - Suggested next steps: rerun, fix, or investigate further

## Important Notes

- v1.1 `output_url` values are pre-signed S3 URLs — fetch with
  plain `curl`, no auth needed
- Test metadata may be empty if >250MB of test data on the job
- Insights data refreshes daily; may not include last 24 hours

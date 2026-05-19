---
name: "circleci-flaky-tests"
allowed-tools: Bash(ops/platform/aws/dscops/scripts/circleci-diagnose.sh:*)
description: Find flaky tests across the project using CircleCI Insights.
---

## Context

You are a CI/CD diagnostic assistant. Your task is to find and report
on flaky tests in the dscout CircleCI project.

The diagnostic script is at:
`ops/platform/aws/dscops/scripts/circleci-diagnose.sh`

## Your Task

1. **Get flaky tests**: Run the diagnostic script:
   ```bash
   ops/platform/aws/dscops/scripts/circleci-diagnose.sh flaky-tests $ARGUMENTS
   ```

3. **Get test metrics** for additional context:
   ```bash
   ops/platform/aws/dscops/scripts/circleci-diagnose.sh test-metrics
   ```

4. **Analyze and present results**:
   - For each flaky test, identify which app it belongs to based on
     the `file` or `job_name` field:
     - `test-axon` / `apps/axon/` → Axon (Elixir)
     - `test-dendra` / `apps/dendra/` → Dendra (React/TypeScript)
     - `test-astro` / `apps/astro/` → Astro (Python)
     - `test-glia` → Glia (integration tests)
     - `test-ai-mod` → AI Mod (Python)
   - Sort by times flaked (worst first)
   - Cross-reference with most-failed tests from test-metrics
   - Present a summary table and actionable recommendations

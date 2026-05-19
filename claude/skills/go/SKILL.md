---
name: go
description: End-to-end finishing workflow after building a feature. Tests what was built, runs the code-simplifier, runs /review_pr_todd against the local diff, addresses important feedback, then opens a PR via /commit-commands:commit-push-pr. Invoked explicitly via /go.
disable-model-invocation: true
allowed-tools: Agent, Skill, Bash, Read, Edit, Write, Glob, Grep
---

# /go — End-to-end finishing workflow

Take freshly built work through a consistent closing pipeline: test → simplify → review → address → open PR. The point is to catch problems locally — not after a reviewer has to ask.

Run the steps **in order**. Each step assumes the previous one happened. If a step surfaces something that can't be cleanly handled, stop and report to the user rather than charging ahead.

Create a TodoWrite item for each step below so progress is visible as the workflow runs.

## Step 1 — Test end to end

The goal is functional verification of the change the user just built, not a full regression sweep. Choose the testing tool by what was changed:

- **Backend / library / CLI changes** → `bash`. Run the script, exercise the function in `iex`/`pry`/REPL, or curl the endpoint. For this repo: Axon GraphQL via `curl localhost:5000/graphql`, Phoenix via `iex -S mix phx.server`, Dendra dev server via the appropriate `yarn` script.
- **Web UI / frontend changes** → browser tools (Claude-in-Chrome or Playwright). Load the affected page, click through the changed flow, watch the console and network panels.
- **Visual behavior the browser can't reach** (native menus, OS dialogs, screenshots of an external app) → computer use.

If the change spans surfaces (e.g., a GraphQL field added and consumed in the frontend) or there's no obvious user-visible surface (pure refactor, typed-config change), **ask the user** which testing path they want before proceeding. Guessing burns time and often misses the thing they actually cared about verifying.

When testing:

1. Exercise the **golden path** — the primary thing the change enables.
2. Exercise at least one **edge case** when it's cheap (empty input, unauthorized user, error response, etc.).
3. Watch for **regressions** in adjacent features that share touched code.
4. If the change genuinely can't be exercised (no local data, missing credentials, feature-flagged off), **say so explicitly** — don't claim success for an untested change. Ask the user whether to proceed anyway.

Before continuing to Step 2, report what you tested and what you saw. If something is broken, fix it and re-test — don't advance with a known defect.

## Step 2 — Simplify

Invoke the `simplify` skill via the Skill tool. It reviews recently changed code for reuse, quality, and efficiency and fixes what it finds, applying project conventions from CLAUDE.md without changing behavior.

After it returns, briefly summarize what (if anything) it changed.

If the simplifier touched a meaningful amount of code (multiple files, or restructured logic rather than renames), **re-run the relevant subset of Step 1 tests** to confirm nothing regressed. A one-line rename doesn't need a full re-test; a restructured function does.

## Step 3 — Review with /review_pr_todd

Invoke `/review_pr_todd` via the Skill tool to review the local diff (uncommitted/unpushed changes — the command is set up to handle pre-PR review, not just existing PRs). Let the review run to completion and capture the full output.

Don't paraphrase or re-implement the review yourself — the command encodes dscout team conventions from hundreds of real reviews, and paraphrasing loses that signal.

## Step 4 — Address important feedback

The review comes back grouped by severity. Apply this filter so scope doesn't balloon:

- **Address**: anything marked `Bug:`, security concerns, cross-service contract mismatches, or a `Request Changes` verdict. These are never optional.
- **Usually address**: `Question:` items where the honest answer is "yes I should change this" (not "intentional"), and `Suggestion (non-blocking):` items that are small and clearly right.
- **Skip by default**: `Nit:`, `Non-blocking quibble:`, style preferences in flagged-off code, and anything the reviewer themselves framed as low-stakes. List them to the user so they can decide, but don't auto-fix.

For gray-area items, **list them to the user briefly and ask** before fixing. The user typed `/go` to ship the change they built — silently expanding scope is the opposite of that intent.

After making changes, report what you addressed and what you skipped (one line of reasoning each). If the fixes were non-trivial, re-run the most relevant Step 1 tests.

## Step 5 — Open the PR

Invoke `/commit-commands:commit-push-pr` via the Skill tool. That command handles branch creation (if on main), a single commit with an appropriate message, push to origin, and `gh pr create`.

Don't pre-stage or pre-commit before invoking — the command expects the working state as-is.

When the PR is open, report the URL to the user.

## Stopping conditions

Stop the pipeline and hand control back to the user (do not continue) when:

- Step 1 reveals a real bug that isn't a quick fix
- The simplifier in Step 2 produces output that breaks the Step 1 tests and the fix isn't obvious
- Step 3 returns blocking issues that involve a genuine design question rather than a mechanical fix
- The user pushes back at any step, even implicitly (e.g., "wait", "hold on", "let me think")

The value of `/go` is in finishing strong — barreling through a real problem to get to the PR step defeats the point.

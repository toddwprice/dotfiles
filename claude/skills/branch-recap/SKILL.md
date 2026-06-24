---
name: branch-recap
description: Use when asked for the latest/last work completed on a specific branch, ticket, or PR — "what's the latest on this branch", "where did I leave off", "recap this branch/PR", "any updates on this ticket/PR", "catch me up on this ticket", "look at progress this past week on this Linear project". NOT the comms-inbox sweep (todd-catchup) and NOT single-DYS-session diagnosis (todd:trace-dys).
---

# branch-recap

## Overview

Recap the work state of ONE branch/ticket/PR from three sources: git, the GitHub PR, and the Linear issue. Read-only.

**This is NOT:**
- `todd-catchup` — that sweeps Slack/email/notification inboxes. branch-recap ignores comms entirely.
- `todd:trace-dys` — that diagnoses one DYS/Braintrust session. branch-recap is about branch/PR/ticket progress, not a trace.

**READ-ONLY.** Never push, commit, comment, edit an issue, resolve a thread, or post to GitHub/Linear. Only run read commands below.

## Steps

Run from the worktree/branch in question (default base branch = `main`).

### 1. git — commits since branch point
```bash
git rev-parse --abbrev-ref HEAD                 # current branch
git merge-base main HEAD                         # branch point
git log --oneline --stat main..HEAD              # commits + files since branch point
git log -1 --pretty='%an | %ar | %s'            # last commit author/time/subject
git status --short                               # uncommitted work
```

### 2. PR — state, CI, review threads
```bash
gh pr view --json number,title,state,reviewDecision,statusCheckRollup,url,updatedAt
gh pr checks            # CI pass/fail per check
gh pr view --comments   # review threads + comments
```
If `gh pr view` errors with "no pull requests found", say "no PR yet" and skip the PR section.

### 3. Linear — issue + recent comments
Extract the ticket id from the branch name or PR title (regex `[A-Za-z]+-[0-9]+`, e.g. `frg-861`/`FRG-861`); uppercase it. If none found, say so and skip Linear.
```bash
linctl whoami                          # validate auth first
linctl issue get FRG-861 --json        # .title .state.name .url .updatedAt .assignee
linctl comment list FRG-861 --json     # JSON array; newest activity
```

## Output

A tight recap:
- **Branch + ticket** (id, title)
- **N commits since main**, with the headline changes (not every file)
- **Last activity time**
- **PR** #, state, review decision, CI pass/fail, any open review threads
- **Linear** status (`.state.name`) + latest comment
- **Where you left off / next step** — one line

## Common Mistakes
- Reaching for comms — wrong skill (`todd-catchup`).
- Diffing against `origin/main` when local `main` is stale — `main..HEAD` is fine; only fetch if explicitly asked.
- Dumping the full `--stat` — summarize headline changes.
- Posting or resolving anything — this skill only reads.

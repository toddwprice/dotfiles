---
name: todd-open-prs
allowed-tools: Bash(gh search prs:*), Bash(gh pr view:*), Bash(gh pr checks:*), Bash(git remote:*), Bash(git -C:*), Bash(ls:*), Bash(find:*), Bash(date:*), AskUserQuestion, Agent, Read
description: Pull the PRs awaiting my review (review requested of me, not yet reviewed), show a triaged list with CI status / diff size / files changed / author / brief summary, let me pick which to review, then fan out a background `/todd-pr-review` subagent per pick — generating HTML+JSON artifacts and STOPPING before posting. Use when Todd wants to see "what PRs need my review", "my review queue", "open PRs assigned to me", "what's waiting on me", or wants to batch-review the PRs requesting his review. Takes an optional time window arg (e.g. `7d`, `14d`, `all`); defaults to the last 7 days.
---

You are running Todd's open-PR review-queue routine. The goal: pull the PRs awaiting Todd's review, present a triaged list, let Todd select which to review, then dispatch one background `/todd-pr-review` subagent per selected PR — each producing review artifacts and stopping **before** posting anything to GitHub.

`$ARGUMENTS` is an optional time window: `7d`, `5d`, `14d`, `30d`, a bare number of days (`10`), or `all` (no date limit). **Default is `7d`** when `$ARGUMENTS` is empty.

## What "awaiting my review" means

Use `--review-requested @me`. This is the self-cleaning "not yet reviewed" queue: GitHub removes Todd from the requested-reviewers list the moment he submits any review, so everything returned is genuinely still pending his input. Do **not** use `--assignee` or `--author` — those are different concepts (DRI / authorship), not the review queue.

## Step 1 — Resolve the window and pull the queue

Compute the cutoff date from `$ARGUMENTS` (default `7d`). macOS/BSD `date`:

```bash
# N = number of days from the window arg (default 7); for "all", skip the --created filter entirely
CUTOFF=$(date -v-7d +%Y-%m-%d)   # adjust -7d to the requested window
```

Then pull, filtering to **open only** (merged/closed PRs are not actionable and otherwise leak in), newest-first:

```bash
gh search prs --review-requested @me --state open --created ">=$CUTOFF" \
  --json number,title,repository,author,createdAt,url --limit 50
```

For `all`, drop `--created ">=$CUTOFF"`.

If the result is empty: tell Todd his review queue is clear for the window and **stop** — nothing else to do.

## Step 2 — Enrich each PR

For every PR returned, fetch the detail Todd wants to see. The repo may not be the current one, so always pass `--repo <owner/repo>` (from the search result's `repository.nameWithOwner`):

```bash
gh pr view <number> --repo <owner/repo> \
  --json number,title,state,author,additions,deletions,changedFiles,files,statusCheckRollup,url,body
```

Derive per PR:
- **CI status** — group `statusCheckRollup[]` by `(.conclusion // .state // .status)` into counts (e.g. `SUCCESS=19 SKIPPED=14`, or `FAILURE=2 PENDING=2 ...`). Flag anything with `FAILURE` (red — investigate) or `PENDING` (still running).
- **Diff size** — `+additions / -deletions`.
- **Files changed** — `changedFiles` count.
- **Brief summary** — 1–3 sentences distilled from `body` (what the PR does + the review's main risk surface). Do not paste the whole body.

## Step 3 — Present the list

Show a compact table, **including the author's GitHub username (`@login`)** for every row, plus CI flag, diff size, and file count:

| PR | Repo | Author | CI | Diff | Files | Title |
|----|------|--------|----|------|-------|-------|
| #NNNNN | repo | @login | ✅ / ⚠️ / 🟡 | +A/-D | N | … |

Use ✅ for all-green, ⚠️ for any `FAILURE`, 🟡 for `PENDING`-but-no-failures. Under the table, give each PR a 1–3 sentence summary and call out CI failures explicitly (note whether they look substantive vs. transient if you can tell). Order newest-first.

## Step 4 — Let Todd select

Ask via `AskUserQuestion` (multiSelect) which PRs to review now. Each option label = `#NNNNN <short title>`; description = author + CI flag + diff size. **`AskUserQuestion` caps at 4 options per question**, so when there are more than 4 PRs, split across multiple questions (group logically — e.g. by author or repo). If Todd selects none, acknowledge and stop.

## Step 5 — Resolve repo context per selected PR

`/todd-pr-review` reads local files and runs `gh` against the current repo, so each subagent must operate in the right checkout:

- **PRs in `dscout/dscout`** run in the current working directory (the monorepo) — no special handling.
- **PRs in another repo** (e.g. `dscout/claude-plugins`): find the local checkout and have the subagent `cd` into it first, so `gh pr view <n>` resolves the correct repo (NOT a same-numbered PR in the monorepo) and file reads hit the right tree. Locate it:

```bash
find ~ -maxdepth 4 -type d -name "<repo-name>" 2>/dev/null   # then verify its remote
git -C <candidate> remote -v
```

- If **no local checkout exists**, tell the subagent to target `--repo <owner/repo>` via `gh` and note in your relay that the review ran without a local tree (diff-only). Flag this to Todd rather than guessing.

## Step 6 — Fan out (background, parallel, no-post)

Spawn **one background `general-purpose` Agent per selected PR**, all in a single message so they run concurrently. Each agent prompt MUST:

1. State the repo context: the working directory / checkout path, and which `owner/repo` the PR lives in (so `gh` resolves correctly). For non-monorepo PRs, instruct it to `cd` into the local checkout first and verify `gh pr view <n>` shows the expected PR.
2. Invoke the skill named `todd-pr-review` via the Skill tool, passing **`<N> --html`** as the argument. The `--html` flag is required, not decorative — `/todd-pr-review`'s *default* mode posts the review to GitHub itself, and `--html` is what puts it in render-and-hold mode. Drop the flag and this command starts firing unreviewed verdicts at teammates' PRs.
3. **Do NOT post anything to GitHub.** Stop at artifact generation (HTML + JSON). Do not run `gh api .../reviews`. Todd reviews the artifacts first.
4. Include the PR's title/author and the main risk surface (from Step 2) as context, and — if CI was red — instruct it to assess whether the failures are substantive vs. transient and fold that into the verdict.
5. Report back concisely: (a) the VERDICT, (b) absolute paths to the HTML and JSON artifacts, (c) top 3–5 findings (severity + one line each), (d) the exact `gh api` submit command the skill generated (printed, NOT executed).

This mirrors the no-post, human-in-the-loop contract: posting a review is an outward-facing action, so artifacts are generated first and Todd decides per PR what (if anything) to submit.

## Step 7 — Relay results

As each background agent completes, relay its verdict to Todd: the verdict, a tight findings summary, artifact paths, and the ready-to-run `gh api` submit command. After all complete, give a final scorecard (PR · repo · verdict · CI) and offer next steps:
- post the Request-Changes reviews (actionable feedback),
- post the approvals,
- post everything, or
- hold while Todd reads the HTML reports.

**Never post a review automatically.** Wait for Todd to say which to fire.

### Notes / edge cases
- A PR that **merged between listing and selection** → still worth reviewing, but note that posting is now after-the-fact (record-keeping, not a gate).
- Keep the author `@username` visible in every list and in each relayed verdict header — Todd asked for it.
- Don't read a subagent's raw output transcript file via shell; rely on the completion notification.

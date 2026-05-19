---
allowed-tools: Bash(gh:*), Bash(git log:*), Bash(open:*), Bash(mkdir:*), WebFetch, Agent, Write, Read
description: Diagnose a Datadog or Slack alert end-to-end — pivots from the alert URL through logs/spans, recent deploys, and repo code, then writes a root-cause summary. Pass the monitor or Slack thread URL as $ARGUMENTS; append `--html` to also emit a browser-ready report.
---

You are diagnosing a production alert in the dscout monorepo. Your job is to take a single URL (Datadog monitor or Slack alert thread) and produce a clear root-cause writeup in Todd's voice — clear, terse, kind, honest about uncertainty.

**This command is autonomous. Do NOT ask the user clarifying questions.** Make the reasonable call and continue; Todd will redirect if needed.

Arguments: `$ARGUMENTS` — a URL plus optional flags. Recognized flags:
- `--html` — also render the writeup as a self-contained HTML page and `open` it
- `--window <minutes>` — investigation window before the alert fired (default: 30)

## Step 1 — Identify the alert

Classify the URL:

- `app.datadoghq.com/monitors/...` or `/event/...` → **Datadog**. Use the `datadog-mcp` server (run `mcp__datadog-mcp__authenticate` if not yet connected).
- `dscout.slack.com/...` → **Slack**. Use the Slack MCP (`mcp__plugin_slack_slack__slack_read_thread`) to read the thread. Extract any monitor URL, service name, error message, or timestamp from the thread, then fall through to Datadog with that context.
- Anything else: read it with WebFetch and continue best-effort.

Capture: monitor name, impacted service/host, alert timestamp (the fire event, not now), error signature.

## Step 2 — Pivot to logs + traces

For the impacted service in the window `[alert_time - window, alert_time + 5min]`:

- Pull error-level logs. Look for the first new signature — the alert often fires on a *new* error, not the most common one.
- Pull related traces/spans if APM is wired up. Focus on the slowest span or the one where the error originates.
- Note the host, container, and (if available) git commit SHA from the log tags.

## Step 3 — Correlate with recent deploys

Run these in parallel:

- `gh search prs --repo dscout/monorepo --merged --search "merged:>$(date -v-2d +%Y-%m-%d)"` — PRs landed in the last 48h
- `git log --all --since="2 days ago" --oneline` (in `/Users/toddprice/dscout-wt`)

Match by: file path mentioned in the error stack, service name, or PR title keywords. List the 1–3 most plausible suspects.

## Step 4 — Read the suspect code

For each candidate PR or commit, `gh pr view <num> --json files,title,body` and read the touched files at the lines the error stack references. Look for: new error paths, removed null checks, changed contracts between services, expanded scope.

If the alert is for a service you don't recognize, consult `~/dscout-knowledge` for the terraform/topology context.

## Step 5 — Parallel deep dives (when needed)

If steps 2–4 leave 2+ plausible causes, dispatch sub-agents (Agent tool, in parallel) — one per hypothesis — each instructed to either confirm or rule out their candidate using code + logs evidence. Aggregate before writing the verdict.

## Step 6 — Write the verdict

Produce a markdown writeup with these sections (terse, prose, not bullet soup):

```
# <alert name> — diagnosis

**Status:** <Active / Recovered / Flapping>
**Window:** <ISO timestamp range>
**Impact:** <one sentence: what users/systems see>

## Timeline
<3–6 line narrative: what fired, what changed before it, how it recovered if it did>

## Root cause (confidence: <high|medium|low>)
<the call, 2–4 sentences. If low confidence: "leaning X because Y" — don't fabricate certainty>

## Evidence
- <log signature + count>
- <PR / commit link>
- <code reference: path:line>

## Recommended next steps
1. <action — who / what / why>
2. ...
```

## Step 7 — Optional HTML render

If `$ARGUMENTS` contains `--html`, also write the same content to `.claude/tmp/alert-<slug>-YYYY-MM-DD-HHMM.html` using the standup HTML shell (system font, max-width 700px, monospace for log signatures and code paths). Wrap code refs in `<code>` and link Linear IDs / PR numbers. After writing, `mkdir -p .claude/tmp` if needed and `open <path>`.

## Voice

Use Todd's voice for the writeup. Defer to the `speak-as-todd` skill if available. Key rules:
- State the call directly. No "perhaps", "maybe consider".
- 1–4 sentence paragraphs. No throat-clearing.
- Honest about uncertainty: "can't tell from the logs alone — leaning X because Y" is better than fabricated confidence.

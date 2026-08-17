---
name: todd-diagnose-alert
allowed-tools: Bash(gh:*), Bash(git log:*), Bash(open:*), Bash(mkdir:*), WebFetch, Agent, Write, Read
description: >
  Diagnose a Datadog or Slack alert/monitor/incident end-to-end — pivots from the URL through
  logs/spans, recent deploys, and repo code, then writes a root-cause summary. Use WHENEVER Todd
  points at a Datadog monitor or Slack alert thread and wants to know what's wrong — phrasings like
  "look at this issue in datadog and diagnose possible causes" with a monitor URL, "investigate this
  monitor", "look into this alert/incident", "why is this monitor firing", "diagnose this Datadog
  alert", or "review this alert and recommend next steps". Trigger even when Todd says
  "issue"/"look into"/"diagnose" rather than the literal word "alert", as long as there's a Datadog
  monitor or Slack alert URL in the request. Pass the monitor or Slack thread URL as $ARGUMENTS;
  append `--html` to also emit a browser-ready report.
---

You are diagnosing a production alert in the dscout monorepo. Your job is to take a single URL (Datadog monitor or Slack alert thread) and produce a clear root-cause writeup in Todd's voice — clear, terse, kind, honest about uncertainty.

**This command is autonomous. Do NOT ask the user clarifying questions.** Make the reasonable call and continue; Todd will redirect if needed.

Arguments: `$ARGUMENTS` — a URL plus optional flags. Recognized flags:
- `--html` — also render the writeup as a self-contained HTML page and `open` it
- `--window <minutes>` — investigation window before the alert fired (default: 30)

## Step 1 — Identify the alert

Classify the URL:

- `app.datadoghq.com/monitors/...` or `/event/...` → **Datadog**. Datadog's MCP tool name varies by project scope (sometimes a local `datadog-mcp` server, sometimes a `claude_ai_Datadog`-style connector). Don't guess a hardcoded tool name — run one `ToolSearch` with query `"datadog logs spans monitor"` and batch-load every Datadog tool you'll need for Steps 1–2 in that single call.
- `dscout.slack.com/...` → **Slack**. Use the Slack MCP (`mcp__plugin_slack_slack__slack_read_thread`) to read the thread. Extract any monitor URL, service name, error message, or timestamp from the thread, then fall through to Datadog with that context.
- Anything else: read it with WebFetch and continue best-effort.

Capture: monitor name, impacted service/host, alert timestamp (the fire event, not now), error signature.

## Step 2 — Gather evidence (two independent tracks — run both in the same turn)

Everything below depends only on what Step 1 captured, not on each other. Fire it all off as one batch of parallel tool calls rather than working through it serially.

**Logs + traces**, for the impacted service in the window `[alert_time - window, alert_time + 5min]`:

- Pull error-level logs and pull related traces/spans (if APM is wired up) as parallel calls — they don't depend on each other. Look for the first new signature — the alert often fires on a *new* error, not the most common one. For traces, focus on the slowest span or the one where the error originates.
- For logs specifically, the **`pup` CLI** is often faster/cleaner than the DD MCP for a scoped query (it's what the `datadog-error-hunter` agent uses) — reach for it when the MCP is slow or you want a quick `service:<svc> status:error` window pull. Either path is fine; don't block on the MCP if `pup` gets you the signature faster.
- Note the host, container, and (if available) git commit SHA from the log tags.

**Recent deploys** — run both of these as parallel Bash calls:

- `gh search prs --repo dscout/dscout --merged --merged-at ">$(date -v-2d +%Y-%m-%d)"` — PRs merged in the last 48h
- `git log --all --since="2 days ago" --oneline` (run from `/Users/toddprice/dscout-wt`, the bare-repo root — that sees commits across every worktree/branch, not just whichever one you're in)

## Step 3 — Correlate and read suspect code

Match by: file path mentioned in the error stack, service name, or PR title keywords. List the 1–3 most plausible suspects.

For each candidate, batch the lookups instead of looping one at a time: fire `gh pr view <num> --json files,title,body` for every candidate in parallel, then Read the touched files at the lines the error stack references — also in parallel. Look for: new error paths, removed null checks, changed contracts between services, expanded scope.

If the alert is for a service you don't recognize, read `~/dscout-knowledge` for the terraform/topology context — fold that into the same parallel batch, it doesn't depend on the PR lookups either.

## Step 4 — Parallel deep dives (when needed)

If Steps 2–3 leave 2+ plausible causes, dispatch sub-agents to confirm or rule out each hypothesis against code + logs evidence — issue all of them in a single message (multiple Agent tool calls together) so they actually run concurrently instead of one after another.

- Use `subagent_type: general-purpose`, `model: sonnet`, `run_in_background: false` — Step 5 needs their verdicts before it can write anything, and confirming/ruling out one hypothesis against evidence already gathered is a bounded, mechanical check, not open-ended synthesis. Sonnet 5 is fast and plenty accurate for that; save your own higher-effort reasoning for the top-level write-up.
- Don't reach for sub-agents in Steps 1–3 — the MCP/gh/git calls there are cheap enough that direct parallel tool calls beat the spin-up and message-passing overhead of an agent. Sub-agents earn their cost here because each hypothesis needs its own multi-step investigation.
- Aggregate their findings before writing the verdict.

## Step 5 — Write the verdict

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

## Step 6 — Optional HTML render

If `$ARGUMENTS` contains `--html`, also write the same content to `.claude/tmp/alert-<slug>-YYYY-MM-DD-HHMM.html` using the shared base shell at `~/.claude/skills/_shared/report-shell.html` (the single source of truth for the common look — system font, GitHub-ish palette, monospace `code`/`pre`); a narrower `max-width` is fine for an alert writeup. Wrap code refs and log signatures in `<code>` and link Linear IDs / PR numbers. After writing, `mkdir -p .claude/tmp` if needed and `open <path>`.

## Voice

Use Todd's voice for the writeup. Defer to the `speak-as-todd` skill if available. Key rules:
- State the call directly. No "perhaps", "maybe consider".
- 1–4 sentence paragraphs. No throat-clearing.
- Honest about uncertainty: "can't tell from the logs alone — leaning X because Y" is better than fabricated confidence.

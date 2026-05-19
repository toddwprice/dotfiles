---
allowed-tools: Bash(docker:*), Bash(docker compose:*), Bash(dscout-up:*), Bash(ls:*), Bash(grep:*), Bash(curl:*), Bash(date:*), Read, Agent
description: Diagnose a bug on the locally-running dscout stack. Pass a URL, screenshot path, or symptom description as $ARGUMENTS. Discovers the right container via `docker compose ps`, pulls logs, optionally reproduces the bug in Claude-in-Chrome, and writes up the root cause. Knows the container→app mapping (axon=Elixir, astro=Python, dendra=React, soma=Rails).
---

You are diagnosing a local-environment bug in the dscout stack. The user is running the app via `dscout-up`; something is broken; your job is to find out what and why.

**This command is autonomous. Do NOT ask clarifying questions** — make the reasonable call from context and continue.

Arguments: `$ARGUMENTS` is one of:
- A localhost URL (`http://localhost:5000/dscript?state=...`)
- A path to a screenshot (`Pasted--<hash>.png` or similar)
- A free-form symptom (*"axon container won't start"*, *"client-side error when picking a DYS template"*)
- Any combination of the above

## Step 1 — Read the symptom

If a screenshot path is given, Read it. If a URL is given, note the path/query. If only prose, parse for: which app, which user flow, what error message appears.

## Step 2 — Discover the running stack

Run these in parallel and merge results:

```
docker compose ps --format json
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}'
```

Identify which containers are running, which port each maps to, and which are unhealthy / restarting. **Do not assume port numbers** — read them from `docker ps` output. The container-name → app convention in this monorepo:

| Container name prefix | App | Language | Where its code lives |
|---|---|---|---|
| `axon-*` | Axon | Elixir / Phoenix | `apps/axon` |
| `astro-*` | Astro | Python (AI services) | `apps/astro` |
| `dendra-*` | Dendra | React / TypeScript (UI) | `apps/dendra` or web client packages |
| `soma-*` | Soma | Ruby on Rails | `apps/soma` |

If you see other containers (postgres, redis, kafka, etc.), treat them as infra — check their logs only if the symptom suggests a connectivity issue.

## Step 3 — Pick the suspect container

Use the URL's port (matched against `docker ps`) when present. Otherwise, infer from the symptom:

- *"client-side error"* / browser console errors → most likely **dendra** (UI), but the failing request inside could point to axon/astro/soma. Check both.
- *"Failed to fetch"* / 4xx/5xx → server-side. Match the request path against the apps' routes.
- *"dscout-up failed to start the X container"* → just check that one container's logs.
- AI / draft / DYS / DScript flows → typically **astro**.
- Mission, study, screener, template CRUD → typically **soma** or **axon** depending on era; check both.
- Real-time / behavior / observation → typically **axon**.

If the symptom doesn't point clearly to one, dispatch sub-agents (Agent tool, in parallel) — one per candidate — to skim that container's recent logs and report findings. Merge.

## Step 4 — Pull logs

For each suspect container, pull the last 200 lines, filtered for errors and the request timeframe:

```
docker logs --tail 200 --timestamps <container>
```

Look for:
- The first ERROR/FATAL/Exception within the symptom's timeframe (not the most recent — the *first* in the failure window is usually the real cause)
- Stack traces and the file:line they reference
- Failed migrations or boot-time errors if the container is restarting

For container-start failures (`dscout-up` errors), also check `docker compose ps` output for the failing service's exit code and last health-check status.

## Step 5 — Reproduce in Claude-in-Chrome (when useful)

If the symptom is interactive (a URL the user can hit) **and** the logs alone don't conclusively explain it, reproduce in the browser:

1. Use `mcp__claude-in-chrome__tabs_context_mcp` to see existing tabs (do this first per the browser-automation guidance in your system prompt).
2. Create a new tab and navigate to the URL (`mcp__claude-in-chrome__navigate`).
3. Read console messages (`mcp__claude-in-chrome__read_console_messages`) and network requests (`mcp__claude-in-chrome__read_network_requests`).
4. Match the failed network request back to the right container's logs from Step 4.

**Do not** trigger JS dialogs (alerts/confirms). If a button might trigger one, skip clicking it.

## Step 6 — Read the suspect code

Once you have a failing route + file:line from the logs, Read that source. Confirm the failure mode. If the bug is obvious and local, propose a fix in the writeup — but **do not edit code** unless Todd explicitly asks; this command is diagnostic.

## Step 7 — Write the verdict

Output a short markdown writeup directly in the conversation (no HTML file unless Todd asks). Sections:

```
**Symptom:** <one line — what Todd sees>
**Suspect container:** <name> (<app>)
**Root cause (confidence: <high|medium|low>):** <2–4 sentences>

**Evidence:**
- Log line: `<timestamp> <signature>` (`docker logs <container> --tail …`)
- Code: `<path:line>`
- (Browser, if used): `<console message or failed request>`

**Fix suggestion:** <1–3 lines; only if cause is clear. Otherwise: "next step is X to confirm Y.">
```

## Voice

Use Todd's voice — clear, terse, kind, honest about uncertainty. Defer to `speak-as-todd` if available. "Leaning X because Y" beats fabricated certainty. State the call directly; no throat-clearing.

## When to bail

Per the in-chrome guidance: if browser tool calls fail 2–3 times, or the page won't load, or you've made multiple unrelated attempts — stop and tell Todd what you tried and where you're stuck rather than spelunking further.

---
allowed-tools: Bash(docker:*), Bash(docker compose:*), Bash(ls:*), Bash(grep:*), Bash(curl:*), Bash(date:*), Read, Agent
description: Diagnose a bug on the locally-running dscout stack. Pass a URL, screenshot path, or symptom description as $ARGUMENTS. Discovers the right container via `docker compose ps`, pulls logs, optionally reproduces the bug in Claude-in-Chrome, and writes up the root cause. Knows the container→app mapping (axon=Elixir, astro/contour/ai-mod=Python, dendra=React).
---

You are diagnosing a local-environment bug in the dscout stack. The user is running the app via `docker compose -f compose.yaml --profile dev up` (deps come up under `--profile deps`); something is broken; your job is to find out what and why.

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

Identify which containers are running, which port each maps to, and which are unhealthy / restarting. **Do not assume port numbers** — read them from `docker ps` output. The `compose.yaml` service → app map for this monorepo (dev profile):

| Service | App | Language | Code | Default port |
|---|---|---|---|---|
| `axon` | Axon | Elixir / Phoenix (primary API, websockets, Oban jobs) | `apps/axon` | 5000 |
| `astro` | Astro | Python (ML/AI HTTP service, incl. DYS/dscript) | `apps/astro` | 8000 |
| `astro-worker` | Astro worker | Python (Redis `ml:analyze`/`ml:sync` queues) | `apps/astro` | — (no HTTP) |
| `dendra` | Dendra | React / TypeScript (UI) | `apps/dendra` | 3035 |
| `contour` | Contour | Python service | `apps/contour` | 8002 |
| `contour-worker` | Contour worker | Python (taskiq worker) | `apps/contour` | — |
| `contour-scheduler` | Contour scheduler | Python (scheduled jobs) | `apps/contour` | — |
| `ai-mod` | AI Mod | Python (Pipecat AI moderation) | `apps/ai_mod` | 8001 |

Infra services: `database` (PostgreSQL 5432), `redis` (6379), `s3` (MinIO 9000/9001), `s3-setup` (one-shot). Treat these as infra — check their logs only if the symptom suggests a connectivity issue. (There is **no** `soma`/Rails service — that app doesn't exist in this monorepo.)

## Step 3 — Pick the suspect container

Use the URL's port (matched against `docker ps`) when present. Otherwise, infer from the symptom:

- *"client-side error"* / browser console errors → most likely **dendra** (UI), but the failing request inside could point to axon/astro. Check both.
- *"Failed to fetch"* / 4xx/5xx → server-side. Match the request path against the apps' routes.
- *"the X container failed to start"* → just check that one container's logs.
- AI / draft / DYS / dscript flows → typically **astro** (and `astro-worker` for async ML). AI moderation → **ai-mod**.
- Mission, study, screener, template CRUD → typically **axon** (GraphQL API + Oban).
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

For container-start failures, also check `docker compose ps` output for the failing service's exit code and last health-check status.

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

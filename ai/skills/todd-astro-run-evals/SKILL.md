---
name: todd-astro-run-evals
description: >
  Run the Astro offline Braintrust evals (or a scoped subset) and summarize the results. Use this
  WHENEVER Todd wants to run dscript/supervisor or other Astro evals — phrasings like "run all
  offline evals", "re-run the eval", "run the supervisor evals", "run eval_cnvs_421", "let's re-run
  the eval for this", "kick off the offline evals", or "what command runs the evals — I want to run
  it myself". It resolves the right `braintrust eval` glob, preflights the required env vars, ALWAYS
  prints the exact command before running, and can stop at print-only when Todd wants to run it
  himself. After a run it summarizes pass/fail per experiment with Braintrust links.
allowed-tools: Bash(uv:*), Bash(ls:*), Bash(cat:*), Bash(printenv:*), Bash(find:*), Read, Glob, Bash(cd:*)
---

# Run Astro Offline Evals

Todd re-runs offline evals constantly while iterating on prompts, and he's twice asked "what command
did you run? I want to do it myself." So this skill optimizes for two things: **run the right scope
without him remembering the glob**, and **always surface the exact command** so he can copy it.

## Step 1 — Resolve scope from `$ARGUMENTS`

The canonical runner (per `apps/astro/AGENTS.md`) is `uv run braintrust eval <glob>`, run from
`apps/astro/`. Map Todd's intent to a glob:

| Todd says | Glob |
|-----------|------|
| (nothing) / "all" / "all offline evals" | `app/domain/**/offline_evals/eval_*.py` |
| "dscript" / "all dscript evals" | `app/domain/dscript/**/offline_evals/eval_*.py` |
| "supervisor" / "supervisor-select" | `app/domain/dscript/agents/supervisor_agent/offline_evals/eval_*.py` |
| "study drafter" / "drafter" | `app/domain/dscript/agents/study_drafter/offline_evals/eval_*.py` |
| "screener drafter" | `app/domain/dscript/agents/screener_drafter/offline_evals/eval_*.py` |
| "target attribute(s)" | `app/domain/dscript/agents/target_attribute/offline_evals/eval_*.py` |
| "templates" (dscript) | `app/domain/dscript/templates/offline_evals/eval_*.py` |
| a module name (e.g. "pii detector") | `app/domain/<module>/offline_evals/eval_*.py` |
| a specific file (e.g. "eval_cnvs_421" / "eval_governed_template_nudge_forced") | the matching `…/offline_evals/eval_*.py` path (use `find apps/astro -name 'eval_*<hint>*.py'` to locate it) |

**"dscript" means all 5 dscript eval dirs, not just the supervisor.** dscript evals live under
`supervisor_agent/` (the bulk), `study_drafter/` (voice/drafting — e.g. FRG-916), `screener_drafter/`,
`target_attribute/`, and `templates/`. The old glob only hit `supervisor_agent/`, so "run the dscript
evals" silently skipped drafter regressions — always use the `dscript/**/` glob for the whole surface.

**Exclude hosted evals from "all".** The `**/offline_evals/` glob deliberately skips
`app/domain/insights/remote_evals/` — those are hosted-scorer EYD evals with a different runner and
dataset requirements; don't sweep them into a local `braintrust eval` run.

If the hint is ambiguous (matches several files), list the candidates and ask which.

**Gotcha — `max_concurrency=1` for dscript/DYS graph evals.** These tasks use `asyncio.run()` and
**deadlock** when run concurrently (you'll see a hang with no output, not an error). Each dscript
eval script should set `max_concurrency=1` in its `Eval()`/`create_eval()` call. If a dscript eval
hangs, that's almost always the cause — check the script sets it before assuming the harness is broken.

## Step 2 — Preflight

Evals hit Braintrust + the LLM, so a missing key fails the whole run unhelpfully. Before running:

- Confirm you can `cd` to `apps/astro` (find it relative to the repo root if not in cwd).
- Check the required env is present (don't print values, just presence):
  `BRAINTRUST_API_KEY`, `OPENAI_API_KEY`, and `MODEL_ENV` (defaults to `staging` if unset).
- If a key is missing, **stop and tell Todd exactly what to set** rather than running blind. These
  live in `apps/astro/.env` — `uv run` loads it, so usually they're already there; the check is a
  guard against the silent-empty-run failure mode.

## Step 3 — Always print the command, then run

Print the exact command in a copyable block first — this is non-negotiable, it's the thing Todd asks
for:

```bash
cd apps/astro && uv run braintrust eval app/domain/dscript/agents/supervisor_agent/offline_evals/eval_*.py
```

Then:

- **Default:** run it.
- **Print-only:** if Todd's request is "what command…" / "I want to run it myself" / "just give me
  the command" / "dry run", print the block and **stop** — don't run.

Running evals is a read-mostly action (it creates Braintrust experiments, not prompt edits), so it's
fine to run by default. Note: this is distinct from `bt-prompt create/edit`, which writes prompt
state — never auto-run those; that's a separate, surfaced-and-wait flow.

## Step 4 — Summarize

When the run finishes, give Todd a tight readout:

- Per experiment: name, scores (pass/avg), and the Braintrust experiment URL the runner prints.
- Call out regressions vs. the prior run if he mentions a baseline or the output shows one.
- If any eval errored (vs. scored low), separate "errored" from "failed scoring" — they mean
  different things (broken harness vs. real regression).

Keep it to the signal: what passed, what regressed, and the links to dig in.

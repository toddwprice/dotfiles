---
name: flaky-e2e
description: >
  Triage and fix a flaky Playwright/RWX E2E test in the dscout `apps/e2e` suite. Use WHENEVER Todd
  points at a flaky or intermittently-failing end-to-end test — phrasings like "this e2e test is
  flaky", "the e2e run failed again on RWX", "fix this timeout flake", "why is templates_edit
  intermittently failing", "de-flake this playwright test", "the e2e suite is red but passes
  locally", or points at a failed `.rwx/e2e.yml` run. Pulls the failed RWX task's logs + retained
  Playwright artifacts (trace/video/screenshots), classifies the flake, and proposes the remedy
  matching that class. This is the E2E counterpart to `axon-flaky-test` (Elixir) — reach for that one
  for `mix test` flakes, this one for the Playwright suite.
allowed-tools: Bash(rwx *), Bash(npx playwright:*), Bash(npm:*), Bash(gh:*), Bash(git:*), Bash(cat:*), Read, Grep, Glob, Agent
disable-model-invocation: true
---

# Fix a flaky E2E test

dscout's E2E suite is **Playwright + TypeScript** in `apps/e2e`, run against **staging** via
`BASE_E2E_URL` with webhook-based data seeding and multi-role auth (researcher / scout). It runs on
**RWX** (`.rwx/e2e.yml`), dispatched *after* the staging deploy. `playwright.config.ts` today: test
timeout 60s, `expect` timeout 15s, `navigationTimeout` 30s, `actionTimeout` 10s, **`retries: 0`**, and
`trace`/`video`/`screenshot` = `retain-on-failure`. Because retries are 0, a single flake reds the
whole run — so a real fix (not a rerun) matters.

`$ARGUMENTS` may be an RWX run/URL, a failing spec path, a pasted failure, or a symptom. If empty,
find the latest failed E2E run for the branch (`rwx results`; see the `rwx` skill).

## Step 1 — Pull the failure evidence

For an RWX E2E failure, get logs **and the retained Playwright artifacts** — the trace is where the
truth is:

```bash
rwx results                       # locate the failed e2e run/task for this branch
rwx logs <run-or-task ref>        # the failing spec + assertion + stack
rwx artifacts <run-or-task ref>   # download trace.zip / video / screenshots for the failed test
```

Open the trace (`npx playwright show-trace <trace.zip>`) when the log alone doesn't explain it —
timeline + network + DOM snapshots usually pinpoint what the test was waiting on.

## Step 2 — Classify the flake

Map the evidence to one class. These are the families that actually recur in this suite (ENA-403/
434/437/438/440/441):

| Class | Signals | Fix direction |
|-------|---------|---------------|
| **Timeout** | `Timeout Ns exceeded`, waiting for a locator/`expect` that eventually would pass | Widen the *specific* timeout, **scoped** to the slow step — not a global bump |
| **Race / ordering** | Passes locally, fails in CI; acts on state that isn't ready; a poll reads global (cross-account) data | `await` the right signal; **scope the query to the target account/entity**, not "most recent" globally |
| **Fixture cleanup** | State bleed between tests; a teardown deleted more than it created | Scope cleanup to the entity the test made (e.g. by `mission_id`), never a scout-wide/global delete |
| **Selector** | `strict mode violation`, matched N elements, or a brittle text/nth locator | Use a stable locator per `apps/e2e/docs/selector-strategy.md` (role/test-id over text/nth) |
| **CI orchestration** | Whole suite flaps regardless of test; run raced the deploy | Fix the pipeline ordering in `.rwx/e2e.yml` (dispatch e2e *after* deploy), not the test |
| **Genuine bug** | Fails deterministically once you look; not timing | It's not flaky — fix the product code / assertion |

Read `apps/e2e/docs/golden-rules.md` and `test-patterns.md` before rewriting — the suite has
non-negotiable conventions and documented anti-patterns.

## Step 3 — Reproduce the flakiness

Confirm it's flaky (and later, confirm the fix) by running the one spec repeatedly against staging:

```bash
cd apps/e2e
npx playwright test <spec> --project=<researcher|scout> --repeat-each=10   # surface the flake
# or --headed / npm run test:debug to watch it fail
```

A test that fails a few times in 10 is flaky; 10/10 pass after the fix is the bar. `retries: 0` means
you can't lean on retries to hide it.

## Step 4 — Apply the remedy (match the class)

Prefer the **narrowest** change that removes the non-determinism. The patterns Todd has actually
shipped:

- **Timeout** → widen the *specific* wait, scoped to the block: e.g. a poll `20s → 40s`, a
  describe-block to `90s`, a single assertion to `30s` — never bump the global `timeout`.
- **Race** → scope the poll/query to the **target account** (don't read `MOST_RECENT_TEAMS`-style
  global state that another test's data can win); `await` the specific element/response, not a sleep.
- **Fixture cleanup** → scope the fixture's teardown to what it created (`mission_id`), not a
  scout-wide delete that nukes sibling tests' data.
- **Selector** → replace text/nth locators with role or `data-testid` per the selector-strategy doc.
- **CI orchestration** → fix `.rwx/e2e.yml` ordering (run after deploy), not the spec.

Keep the change minimal and deterministic; don't add `retries` to paper over a real race.

## Step 5 — Verify and report

- `cd apps/e2e && ./bin/validate-test <spec>` (single-spec validate) and `npm run lint` (zero
  warnings) and `npm run typecheck`.
- Re-run Step 3's `--repeat-each=10` → must be green every time.
- Report tightly: **which class**, the **root cause** (with the trace/log evidence), the **scoped
  fix**, and the repeat-run result. If it's actually a product bug or a CI-ordering issue, say so —
  don't disguise it as a test tweak.

Compose with the `rwx` skill for run/log/artifact retrieval. If the same spec keeps flaking after a
fix, escalate with the trace rather than widening timeouts indefinitely.

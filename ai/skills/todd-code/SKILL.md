---
name: todd-code
description: Implement a planned Linear ticket via red/green TDD, run the local automated code review, and open a draft PR — attended, so it pauses to ask when a real question comes up, and it never drives a browser or brings up the local stack itself. Use when Todd says "/todd-code FRG-1234", "code up this ticket", "implement this plan", or wants a planned ticket turned into a draft PR while he stays reachable for questions. Requires an existing plan posted by `/todd-plan` (a Linear comment with a Gherkin Behavior Spec) — `/todd-coder plan`'s older prose-plus-Manual-Test-Plan format still works. Replaces the retired `/todd-loop` and `/todd-coder`. Takes `--resume PHASE`.
---

# Todd Code

You are running Todd's attended ticket-to-draft-PR flow. One planned ticket in, one draft PR out, plus a printed list of what to run once the local stack is up — this command never brings the stack up or clicks through it itself.

**No `allowed-tools` is declared on purpose** — same reason as `/todd-bug-next`. Implementation runs whatever the touched app needs (`mix test`, `yarn lint`, `uv run pytest`), and an allow-list would strangle exactly the part that matters. It inherits the session's permission mode.

This command **replaces `/todd-loop` and `/todd-coder`**, both retired. What it keeps from `/todd-loop`: the subagent-per-phase discipline, the plan gate, the plan-check stamp handling, the Behavior-Spec-driven TDD engine. What it drops: the unattended posture, the browser-driven Manual Test Plan run, and the ready-for-review flip. If you want any of those, run this, then flip the PR to ready and drive verification yourself — this command hands you the exact steps to do that in its final report.

## The two rules that shape everything

**1. Try to resolve questions yourself before asking.** When implementation hits something the plan doesn't settle, check two things before stopping: does the plan say it elsewhere (a Behavior Spec Scenario, an EARS invariant, a "Risks & considerations" note), and does the existing codebase already answer it by convention (an established pattern for this exact case, a sibling implementation to match)? Only stop and ask when neither resolves it — a genuine two-way design call, or a fact only Todd has. Batch questions into one `AskUserQuestion` (max 4 per call; loop if there are more) rather than dribbling them out.

**2. Every phase runs in a dispatched subagent.** A command can't call `/clear`, so a fresh subagent is the real way to start a phase cold. The orchestrator (you) holds almost nothing: `TICKET`, `WT` (absolute worktree path), `BRANCH`, `PR`, and each phase's compact return. Never pull a diff, a review payload, or a full plan comment into your own context — a subagent fetches those itself and hands back a summary. Re-fetch fresh state after any wait.

## Arguments

`$ARGUMENTS` starts with a Linear ticket id (e.g. `FRG-1234`), then optional flags:

| Flag | Meaning |
|---|---|
| `--resume PHASE` | Re-enter mid-flow at `impl`, `review`, or `pr`. |

No ticket id → show usage and stop.

## Two environment facts that will bite you

**`cd` does not stick.** In the `dscout-wt` layout the shell cwd resets between Bash calls. Use `git -C "$WT"`, `gh -R dscout/dscout`, or a single compound `cd "$WT" && …` — never a bare `cd` in one call expecting the next to inherit it. This also means `EnterWorktree` is unusable here: it validates against `git -C .bare worktree list`, which returns only `.bare` itself, so every real path gets rejected.

**`.bare` is often shallow.** Run `git -C "$WT" rev-parse --is-shallow-repository` in phase 0 and say so if it's `true`. A shallow store makes `git log` lie about history. Don't `--deepen` to fix it — that has run away before. Just avoid rebasing; this flow never needs to.

---

## Phase 0 — Resolve, gate, isolate

Do this inline (it's small) and report a one-line summary.

**Read the ticket.** `linctl issue get $TICKET --json` gives `.branchName`, `.title`, `.state`, `.description`. Linear is the source of truth for the branch name — do not slugify it yourself. If `branchName` is empty, stop and tell Todd to set one.

**Gate on the plan. This command assumes one exists; verify rather than trust.** Check both places:

1. Use the `linctl` skill and run `linctl comment list $TICKET --json` for a comment starting `## 📋 Implementation Plan`.
2. A `notion.so` URL in the ticket body or its attachments — both are in the payload you already fetched. `attachments` is a GraphQL connection (`{nodes: [...]}`), **not** a flat array; `.attachments[].url` errors out:
   ```bash
   linctl issue get $TICKET --json \
     | jq -r '[.description, (.attachments.nodes[]?.url)] | .[] | select(.)' \
     | grep -o 'https://[^ )]*notion\.so[^ )]*'
   ```
   Fetch any hit with `mcp__claude_ai_Notion__notion-fetch`.

Then branch on what you found:

- **Linear comment** → phase 1 reads it itself. Note in your phase-0 line whether it carries a `## 🥒 Behavior Spec` and how many Scenarios — that's the implementer's checklist and gives you a real completion number to report at the end; a prose-only plan (the older `/todd-coder plan` shape) means "done" is the implementer's judgement call.

  **Then read its plan-check stamp.** `/todd-plan-check` writes one line as the last line of the plan comment, after a `---`. Take the last line containing `Plan check:` and classify it:

  - `❌` → **failed**. A `**🔴 Open blockers**` block below the stamp line carries each finding in full prose — that's what you report, not a code list.
  - `⚠️ passed (ungrounded)` → **passed, but grounding was never checked** (the anchor file was missing). Proceed, and say grounding went unchecked.
  - `✅ passed with N advisories` → **passed.** A `**⚪ Advisories**` block carries N impl-time notes — gaps the checker judged too thin to fail the plan over. Proceed, and carry them into phase 1 verbatim (see below).
  - `✅ passed` → **passed**.
  - No `Plan check:` line anywhere → **unchecked**. Not the same as failed.

  **`❌` → stop.** Report the blockers from the stamp — the prose, not the codes — and tell Todd to run `/todd-plan $TICKET`. Don't attempt the fix here; this command has no planning context loaded, and a plan is the one input it must not improvise.

  **Unchecked → run `/todd-plan-check $TICKET --strict` inline**, then read the stamp it just wrote. `❌` → stop as above; passes → continue.

  **`⚠️` or `✅` → continue.**

  **Carry any advisories into the phase-1 prompt, verbatim.** A `[E9]` advisory means the plan has a Scenario whose falsification nobody worked out — the implementer has to derive it before writing that test, and if they can't, the Scenario needs saying so rather than a test that asserts nothing.
- **Notion doc only** → **you must carry the plan forward yourself.** Extract the plan text and paste it into the phase 1 subagent prompt. A Notion-only plan can't be stamp-checked, so this path proceeds on an unchecked plan — say so in the phase-0 line.
- **Neither** → stop. Say this command needs a plan and to run `/todd-plan $TICKET` first. Don't offer to plan it here — planning wants Todd's eyes, and that's the whole reason this command takes a *planned* ticket.

**Find or make the worktree.** `WT_ROOT=$HOME/dscout-wt`, and the conventional path is `$WT_ROOT/<ticket-lowercased>`.

```bash
git -C "$WT_ROOT/main" worktree list --porcelain    # is BRANCH already checked out somewhere?
```

- Branch already checked out in a worktree → use that path, whatever it's called.
- Otherwise → `cd "$WT_ROOT/main" && "$WT_ROOT/start-ticket.sh" $TICKET`. It creates `../<ticket>` off the current HEAD and sets the ticket In Progress + assigned to Todd in Linear. It must run from inside an existing worktree for the relative path to resolve.
- Already sitting in the right worktree → say so and move on.

Set `WT` to the absolute path. Every later command uses it explicitly.

**Check the tree is clean.** Uncommitted changes that aren't from a prior attempt on *this* ticket → stop and report. Don't stash someone's work.

---

## Phase 1 — Implement (red/green TDD)

**REQUIRED: Use superpowers:test-driven-development** as the inner loop this phase drives.

**Use dependency injection in every test. Do not monkey-patch functions, classes, module attributes, globals, or environment lookups to control test behavior.** Pass dependencies through function arguments, constructors, or an explicit configuration boundary. Use test doubles only through those injected dependencies. If the code has no injection point, add the smallest clear dependency boundary before writing the test. Keep production defaults unchanged. This rule applies to new tests and to tests changed during implementation or review fixes.

Dispatch one subagent. Model: inherit (this is the highest-judgement phase — don't downgrade it).

Its prompt needs to work cold:

- Absolute `WT` path, the ticket id, and the branch.
- *"Read the ticket (`linctl issue get`) and its plan comment (`linctl comment list`, the one starting `## 📋 Implementation Plan`). Implement it via strict red/green TDD."*
- Any plan-check advisories phase 0 found, verbatim.
- The Notion plan text, if phase 0 found one there.
- The cwd-resets warning — it will be running git commands.
- The rules below.

**If the plan carries a `## 🥒 Behavior Spec`, it drives the loop:**
- **Each Scenario is one RED test.** Write it failing before the code that satisfies it. Don't batch several scenarios into one test because they're adjacent.
- **`@slice-N` tags give the order.** A slice is done when every Scenario tagged with it is green — not when the code looks finished.
- **`# target:` names the test file.** Put it there. If that file doesn't exist or genuinely doesn't fit, put it where it belongs and say which you did and why.
- **`# falsifies:` is a mutation check, not a note.** Once the test is green, confirm it would go red *for that reason* — revert the change behind it, or assert against the pre-change value, and watch it fail. A test that passes with and without your change cost you time and bought nothing.
- **An EARS-style invariant is a constraint, not a Scenario.** It doesn't get its own RED test the way a Scenario does — satisfy it in the implementation and verify it by inspection or a targeted assertion where one is cheap.
- **Never skip a Scenario silently.** If one turns out wrong, unimplementable, or already covered by an existing test, name it in the return with the reason.
- **`Not covered` is a boundary.** Behavior the spec deliberately excludes isn't yours to build. Note it, don't fix it.

**Prose-only plan (no Behavior Spec) — the same shape as `/todd-coder`'s straightforward path:** strict red-green-refactor, one commit if single-file/low-risk; thin vertical slices (RED → GREEN → REFACTOR → verify → commit, then the next slice) for anything multi-file. Simplest thing that works first — no abstraction before its third use; touch only what the task needs; keep the tree green between slices.

**Verify per slice** with the dscout checks for the app touched, and only those:
- axon: `mix format --check-formatted && mix compile --warnings-as-errors && mix test`
- dendra: `yarn lint && yarn test:ci`
- astro: `uv run ruff check . && uv run pytest`
- anything else: use the plan's `### Verification` block if it has one; otherwise say in the return that this surface has no standard check.

**Before stopping on a question, check the plan and the codebase first** (rule 1 above) — the subagent should try both, name what it checked, and only then return `needs-input` if neither settled it.

**Commit each verified slice** (or the one commit on the fast path). Never push — that happens in phase 3.

End with a structured status block:

```
STATUS: success | needs-input | recoverable | fatal
COMMIT: {branch-tip sha, or "none"}
FILES: {count} changed
TESTS: {e.g. "42 passed" or "3 failed: <names>"}
SCENARIOS: {e.g. "11/11 green" or "9/11 green, 2 skipped", or "none" if no Behavior Spec}
QUESTION: {the blocking question(s), what you checked first and why it didn't settle it — only when STATUS is needs-input}
BLOCKERS: {one line, or "none"}
PR_TITLE: {suggested PR title}
PR_BODY: |
  {summary / changes / test-plan for the PR}
```

Read `STATUS` and act:

| STATUS | Do |
|---|---|
| `success` | Continue to phase 2. Keep `COMMIT`, `PR_TITLE`, `PR_BODY`. |
| `needs-input` | Put `QUESTION` in one `AskUserQuestion` (max 4; loop if more). Then dispatch a **continuation subagent** — same prompt shape, plus Todd's answers, plus "resume from the branch tip; `git log` shows what's already committed." Repeat this phase's loop until `success`, `recoverable`, or `fatal`. |
| `recoverable` | Re-dispatch once. Still recoverable → stop and report. |
| `fatal` | Stop and report `BLOCKERS` verbatim. |

If `TESTS` shows failures, treat it as `fatal` regardless of what `STATUS` claims. A red tree does not get a PR.

---

## Phase 2 — Local automated code review, then fix

**Dispatch a review subagent:**

> Run `/dscout-automated-code-review $TICKET` against the working tree in `<WT>`. That resolves as Local Mode with the ticket — dev-flow artifacts load, but there's no PR yet so nothing gets published; the findings come back in the response body. Return the Verdict and every finding (title, `file:line`, one-line fix note, and the label — `Bug:` / `Suggestion (non-blocking):` / `Non-blocking quibble:` / `Nit:` / `Question:`).

This is deliberately a different step than the old `/todd-loop` self-review — that ran `/todd-pr-review --json-only` against an open PR and needed a separate fact-check pass because the input was raw. `/dscout-automated-code-review` already runs its own adversarial-challenge and importance-filter pass before it returns, so what comes back here is closer to vetted. It also has no JSON contract, so this phase doesn't hand off to `/todd-address-comments` — the triage below is inline instead.

**If there are no findings (or the Verdict is `APPROVE` with nothing to fix)** → skip straight to phase 3, and say so.

**Otherwise, triage inline (you, the orchestrator):**
- A `Bug:`, `Nit:`, or `Non-blocking quibble:` with a concrete fix already implied → **fix bucket**.
- A `Question:`, or anything where two designs are defensible, or the fix reaches past what the ticket asked for → **judgement bucket**.

Put every judgement-bucket item in one `AskUserQuestion` (max 4; loop if more). If there are none, say "no judgement calls" and skip straight to the apply step.

**Dispatch an apply subagent** with the fix bucket, the judgement bucket, and Todd's answers: implement the agreed fixes in `<WT>`, run the CLAUDE.md pre-push checks for **each app the diff touches**, and commit. There's nothing to reply to or resolve on GitHub — this ran before the PR existed.

If any check comes back red, **stop before phase 3** and report it. A red tree does not get a PR.

---

## Phase 3 — Draft PR

Inline; it's three commands.

```bash
git -C "$WT" push -u origin "$BRANCH"
gh pr list -R dscout/dscout --head "$BRANCH" --json number -q '.[0].number // empty'   # idempotent for --resume
```

If no PR exists, create it **from inside the worktree** — `gh pr create` infers the repo and head from the checkout, and running it from elsewhere with `-R` is the version that surprises you:

```bash
cd "$WT" && gh pr create --draft --base main \
  --title "<PR_TITLE> [$TICKET]" --body-file <tmpfile>
```

- **Title ends with the ticket in brackets** — `[FRG-1234]`. If phase 1's `PR_TITLE` already carries it, don't double it up.
- **Body** is phase 1's `PR_BODY`, plus a line linking the Linear ticket and a line noting `/dscout-automated-code-review` already ran locally.
- **Always draft.** This command doesn't drive a browser or wait for a bot review, so there's no basis here to call the PR ready — that flip is Todd's, once he's skimmed the diff and worked through the report below.

Keep `PR`. Report the URL.

---

## Final report

Dispatch one more subagent to produce the "what to do next" section below — it needs to re-read the plan's Behavior Spec, and that's exactly the kind of bulky fetch the orchestrator shouldn't hold (rule 2).

> Read the ticket's plan comment and the diff (`git -C <WT> diff main...HEAD --name-only`). Produce:
> 1. **Local verification steps** — one numbered list, to run *after* Todd brings the stack up himself. Derive it from the Behavior Spec's UI-observable Scenarios: one step per Scenario, naming the route, the setup state needed, and the expected result. If the plan has no Behavior Spec, or none of it has a visible surface, say `_No user-observable surface; nothing to verify by hand._` instead of inventing steps. Don't include the stack-startup or sign-in commands here — those go in step 2.
> 2. **Lint / test / format commands** — for each app the diff touches, the exact block from the repo's `CLAUDE.md` Pre-Push Checklist (axon / dendra / astro), verbatim. Note any app touched that isn't one of those three, and that it has no standard block.
>
> Return both as plain markdown. Do not run any of it.

Prepend to what that subagent returns:

```bash
cd "$WT" && ../reset-stack.sh   # brings up *this* worktree's stack; stops every other running stack first
```

then sign in at `/auth/sign_in` with the seeded dev credentials, confirmed against `bin/dscout-compose status` for this worktree's base URL — never assume `localhost:5000`, since every worktree pins the same ports.

Then give Todd:

- Ticket, PR URL (draft), branch, current tree state (green / red).
- One line per phase: what changed, Scenario coverage from phase 1, review findings fixed vs. sent to judgement.
- **The local verification steps and the lint/test/format commands**, verbatim from the subagent above.
- **Anything still open** — a `needs-input` question that got answered, a dropped Scenario and why, a review finding punted to a judgement call, anything phase 2's checks flagged but didn't fix.
- A one-line reminder: once he's happy and flips the PR to ready, human reviewers can see it — mention `@claude` in a PR comment or run `/dscout-automated-code-review` against the PR for another automated pass — and `/todd-address-comments` handles whatever anyone posts.

### Outcome record

Before the final report, append one record for the run's actual terminal state. This is telemetry only: do not leave a PR or shared environment in a worse state because recording failed.

```bash
~/.dotfiles/ai/skills/_shared/record-skill-outcome.sh \
  --skill todd-code --target "<TICKET>" --head-sha "<current SHA or empty>" \
  --phase "<resolve|impl|review|pr>" \
  --tests "<green/red; include the failing command when red>" \
  --manual-verification "not run — steps printed in report" \
  --posted-url "<PR URL or empty>" --outcome "<completed|awaiting-user|blocked|failed>" \
  --stop-reason "<opened-draft|awaiting-judgement|red-check|missing-plan|phase-error>"
```

For a resume, record the phase that stopped this invocation.

---

## Hard rules

- Never force-push, never push to `main`, never merge, never `git add -A`.
- Never flip the PR to ready — that's Todd's call, made after reading the report.
- Never bring up the local stack, open a browser, or run anything against a running app. This command's whole output there is the printed steps, not an executed check.
- Never post `/dscout-automated-code-review`'s local-mode findings to GitHub. There's no PR to anchor them to yet, and the skill itself skips publishing in Local Mode.
- One ticket per invocation. Multiple tickets with stacked PRs isn't supported — say so and stop.
- If a phase fails twice, stop and report. Don't improvise around a broken phase.

## Failure handling

| Failure | Do |
|---|---|
| No plan found | Stop. Point at `/todd-plan $TICKET`. |
| `start-ticket.sh` fails | Stop with its stderr — usually `linctl` auth or a branch that already exists. |
| Impl returns `fatal` | Stop, report `BLOCKERS`. Worktree and commits survive for a `--resume impl`. |
| Impl returns `needs-input` repeatedly on the same question | Ask again is wrong — re-read the answer you got and check you actually passed it to the continuation subagent before assuming it's unresolved twice. |
| Push rejected | Someone else moved the branch. Stop — don't force. |
| `gh pr create` fails | Stop with the error; the branch is already pushed, so `--resume pr` retries just this. |
| `/dscout-automated-code-review` returns nothing usable | Re-dispatch once, then report and skip to phase 3 rather than blocking the whole run on a review that won't run. |
| Per-app check red (phase 1 or phase 2) | Stop before the next phase. Report the failing command and output. |

Now run this for $ARGUMENTS.

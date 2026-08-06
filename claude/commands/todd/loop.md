---
description: Take a planned Linear ticket all the way to a reviewed, ready-for-review PR without supervision — implement it via `/todd:coder impl --orchestrated`, open a draft PR, self-review it with `/todd:pr_review --json-only`, address its own findings, flip to ready, then wait for baz and address that too, looping until baz is quiet. Use when Todd says "run the loop on FRG-1234", "/todd:loop FRG-1234", "take this ticket to a reviewed PR", or wants a planned ticket driven end to end while he's away. Requires an existing plan (Linear comment or linked Notion doc). Takes `--baz-timeout N`, `--max-rounds N`, `--no-ready`, `--resume PHASE`.
---

You are running Todd's unattended ticket-to-reviewed-PR loop. One planned ticket in, one ready-for-review PR out, with as few interruptions as the work honestly allows.

**No `allowed-tools` is declared on purpose** — same reason as `/todd:bug-next`. The implementation and fix phases run whatever the touched app needs (`mix test`, `yarn lint`, `uv run pytest`, docker), and an allow-list would strangle exactly the part that matters. It inherits the session's permission mode.

## The two rules that shape everything

**1. Ask almost never — but ask properly when you do.** Phases 1–3 and 5 are fully autonomous: no prompts, safe defaults, keep going. Phases 4 and 6 stop for *judgement calls only* — a finding where fact-checking couldn't settle it, two defensible designs, or a fix that reaches past what the ticket asked for. A nit with an obvious fix is not a judgement call. Batch questions into one `AskUserQuestion` (max 4 per call; loop if there are more) rather than dribbling them out.

**2. Every phase runs in a dispatched subagent.** This is what "clear context between phases" means here — a command can't call `/clear`, and a fresh subagent is the only real way to start a phase cold. The orchestrator (you) holds almost nothing: `TICKET`, `WT` (absolute worktree path), `BRANCH`, `PR`, `JSON`, and each phase's compact return. Never pull a diff, a review payload, or an implementation transcript into your own context — a subagent fetches those itself and hands back a summary. A loop that compacts halfway through phase 6 has lost the thread.

## Arguments

`$ARGUMENTS` starts with a Linear ticket id (e.g. `FRG-1234`), then optional flags:

| Flag | Default | Meaning |
|---|---|---|
| `--baz-timeout N` | `20` | Minutes to wait for baz after flipping to ready. |
| `--max-rounds N` | `3` | Cap on baz review rounds in phase 6. |
| `--no-ready` | off | Stop after phase 4. Leaves a self-reviewed draft; never flips it or waits for baz. |
| `--resume PHASE` | — | Re-enter mid-flow at `impl`, `pr`, `review`, `address`, `ready`, or `baz`. |

No ticket id → show usage and stop.

## Two environment facts that will bite you

**`cd` does not stick.** In the `dscout-wt` layout the shell cwd resets between Bash calls. Use `git -C "$WT"`, `gh -R dscout/dscout`, or a single compound `cd "$WT" && …` — never a bare `cd` in one call expecting the next to inherit it. This also means `EnterWorktree` is unusable here: it validates against `git -C .bare worktree list`, which returns only `.bare` itself, so every real path gets rejected.

**`.bare` is often shallow.** Run `git -C "$WT" rev-parse --is-shallow-repository` in phase 0 and say so if it's `true`. A shallow store makes `git log` lie about history. Don't `--deepen` to fix it — that has run away before. Just avoid rebasing; this loop never needs to.

---

## Phase 0 — Resolve, gate, isolate

Do this inline (it's small) and report a one-line summary.

**Read the ticket.** `linctl issue get $TICKET --json` gives `.branchName`, `.title`, `.state`, `.description`. Linear is the source of truth for the branch name — do not slugify it yourself. If `branchName` is empty, stop and tell Todd to set one.

**Gate on the plan. This command assumes one exists; verify rather than trust.** Check both places:

1. `mcp__claude_ai_Linear__list_comments` for a comment starting `## 📋 Implementation Plan`.
2. A `notion.so` URL in the ticket body or its attachments — both are in the payload you already fetched. Note `attachments` is a GraphQL connection (`{nodes: [...]}`), **not** a flat array; `.attachments[].url` errors out:
   ```bash
   linctl issue get $TICKET --json \
     | jq -r '[.description, (.attachments.nodes[]?.url)] | .[] | select(.)' \
     | grep -o 'https://[^ )]*notion\.so[^ )]*'
   ```
   Fetch any hit with `mcp__claude_ai_Notion__notion-fetch`.

Then branch on what you found:

- **Linear comment** → nothing more to do. `/todd:coder impl` finds it on its own. Note in your phase-0 line whether it carries a `## 🥒 Behavior Spec` and how many Scenarios — a spec'd plan gives phase 1 a hard checklist and gives you a real completion number to report at the end; a prose-only plan means "done" is the impl agent's judgement call. Worth knowing which kind of run this is before it starts.
- **Notion doc only** → **you must carry the plan forward yourself.** `/todd:coder impl` only looks for that Linear comment; a Notion-only plan is invisible to it, and it will quietly grade the ticket "straightforward" and improvise. Extract the plan text and paste it into the phase 1 subagent prompt.
- **Neither** → stop. Say the loop needs a plan and to run `/todd:plan $TICKET` first — an unattended run is exactly the case its Behavior Spec is for, since there's nobody around to resolve an ambiguous "handle the edge case". `/todd:coder plan $TICKET` or a linked Notion doc also work. Don't offer to plan it here — planning wants Todd's eyes, and that's the whole reason this command takes a *planned* ticket.

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

## Phase 1 — Implement

Dispatch one subagent. Model: inherit (this is the highest-judgement phase — don't downgrade it).

Its prompt needs to work cold:

- Absolute `WT` path, the ticket id, and the branch.
- *"Read `~/.claude/skills/todd-coder/SKILL.md` and execute Impl Mode for `$TICKET` in `--orchestrated` mode."*
- The Notion plan text, if phase 0 found one there.
- The cwd-resets warning — it will be running git commands.

`--orchestrated` is what makes this unattended: it never blocks on a prompt, still posts the `## ✅ Implementation Summary` to Linear, commits each verified slice, and never pushes. It ends with a parseable status block. Read `STATUS` and act:

| STATUS | Do |
|---|---|
| `success` | Continue to phase 2. Keep `COMMIT`, `PR_TITLE`, `PR_BODY`. |
| `recoverable` | Re-dispatch once. Still recoverable → stop and report. |
| `plan-required` | Stop. Phase 0's gate should have caught this — say which plan it rejected and why. |
| `fatal` | Stop and report `BLOCKERS` verbatim. |

If `TESTS` shows failures, treat it as `fatal` regardless of what `STATUS` claims. A red tree does not get a PR.

If the plan had a Behavior Spec, `SCENARIOS` says how many landed. A skipped scenario isn't fatal on its own — the impl agent has to give a reason for each — but carry the count and the reasons into the final report. "11/11 green" and "9/11, two skipped as already-covered" describe very different PRs, and only one of them is finished.

---

## Phase 2 — Draft PR

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

- **Title ends with the ticket in brackets** — `[FRG-1234]`. If coder's `PR_TITLE` already carries it, don't double it up.
- **Body** is coder's `PR_BODY`, plus a line linking the Linear ticket.
- **Draft is not optional here.** baz doesn't review drafts (confirmed: it reviewed #27579 but left nothing on drafts #27582/#27584). That's exactly what the loop wants — the draft window is where the self-review happens, uncontested.

Keep `PR`. Report the URL.

---

## Phase 3 — Self-review, JSON only

Dispatch a subagent:

> Read `~/.claude/commands/todd/pr_review.md` and execute it for PR `<PR>` with `--json-only`.

It returns four lines: `JSON:`, `VERDICT:`, `INLINE:`, `BODY_NOTES:`. Keep the path and the verdict. **Nothing else from this phase enters your context** — the findings live in the file, and phase 4's subagent reads them from there.

If `INLINE` and `BODY_NOTES` are both `0`, skip phase 4 and go straight to phase 5. Say so.

---

## Phase 4 — Address the self-review (asks questions)

Two subagents with a question stop between them.

**4a — Triage.** Dispatch:

> Read `~/.claude/skills/todd-address-comments/SKILL.md`. Run **Local findings mode** for `<JSON>` against PR `<PR>`, working in `<WT>`. Stop at Step 4. Return the triage table, the one-line fix plan per item, and any judgement calls.

Fact-checking is not ceremony here. These findings came from a review that couldn't run the tests, so some fraction of them are confidently wrong. Step 3 of that skill is what catches them, and dropping a bad finding is as good an outcome as fixing a real one.

**4b — Ask.** Show Todd the triage table. If there are judgement calls, put them in one `AskUserQuestion` (≤4; loop if more). If there are none, say "no judgement calls" and go straight to 4c without waiting.

**4c — Apply.** Dispatch a second subagent with the table plus Todd's answers: implement the agreed fixes in `<WT>`, run the CLAUDE.md pre-push checks for **each app the diff touches**, and commit. Local findings mode posts no replies — nothing was published, so there's nothing to reply to.

If any check comes back red, **stop before pushing** and report it. A red loop is a stopped loop.

---

## Phase 5 — Ready for review

```bash
git -C "$WT" push
gh pr ready -R dscout/dscout <PR>
```

This is the outward-facing step — the PR becomes visible work and starts pinging reviewers. It's authorized as part of the loop, so don't stop to re-confirm, but do announce it plainly with the URL.

`--no-ready` stops here with a self-reviewed draft.

---

## Phase 6 — baz rounds (up to `--max-rounds`, default 3)

**Poll.** baz is `baz-reviewer[bot]` (a GitHub App, `type: Bot`). Take a baseline count right before flipping to ready — it should be 0, since baz skips drafts.

```bash
gh api repos/dscout/dscout/pulls/<PR>/reviews  --jq '[.[]|select(.user.login=="baz-reviewer[bot]")]|length'
gh api repos/dscout/dscout/pulls/<PR>/comments --jq '[.[]|select(.user.login=="baz-reviewer[bot]")]|length'
```

Poll every 60s. **Settled** = the total went above baseline *and* one further poll adds nothing — baz posts its review and its inline comments as separate events, so acting on the first sighting can catch it mid-write.

Run the wait as a `sleep`/poll bash loop inside **one** Bash call, not sixty separate calls. The Bash tool caps at 600s, so each call covers at most 9 minutes — repeat the call until settled or the `--baz-timeout` budget is spent.

**Timed out with nothing from baz** → report "no baz review after N minutes, PR is ready at `<url>`" and stop. Don't run address-comments against an empty set.

**Settled** → dispatch a triage subagent (normal **GitHub mode** this time, just the PR number, stop at Step 4), ask Todd any judgement calls exactly as in 4b, then dispatch an apply subagent to fix, reply per thread, resolve what's fully addressed, and push.

Then poll again for the next round. Stop when a poll comes back clean or `--max-rounds` is spent. Say which of the two ended it — "baz quiet after round 2" and "hit the 3-round cap with 4 threads open" mean very different things to whoever reads this next.

---

## Final report

Keep it short:

- Ticket, PR URL, current state (ready / draft), and whether CI is green.
- One line per phase: what changed. Self-review findings fixed vs dropped, baz rounds run, threads addressed vs declined.
- **Anything still open** — unanswered threads, skipped findings, skipped Behavior Spec scenarios and why, a red check, the round cap. This is the part Todd actually reads.

---

## Hard rules

- Never force-push, never push to `main`, never merge, never `git add -A`.
- Never post the self-review JSON to GitHub. It's scaffolding; the fixes are the output.
- Never flip a PR to ready with a red check.
- One ticket per invocation. Multiple tickets with stacked PRs is `/todd:phase` — say so and stop.
- If a phase fails twice, stop and report. Don't improvise around a broken phase.

## Failure handling

| Failure | Do |
|---|---|
| No plan found | Stop. Point at `/todd:plan $TICKET` (or `/todd:coder plan` for something small). |
| `start-ticket.sh` fails | Stop with its stderr — usually `linctl` auth or a branch that already exists. |
| Impl returns `fatal` | Stop, report `BLOCKERS`. Worktree and commits survive for a `--resume impl`. |
| Push rejected | Someone else moved the branch. Stop — don't force. |
| `gh pr create` fails | Stop with the error; the branch is already pushed, so `--resume pr` retries just this. |
| pr_review returns no JSON | Re-dispatch once, then stop. |
| Per-app check red | Stop before pushing. Report the failing command and output. |
| baz never appears | Report and stop after `--baz-timeout`. The PR is still ready and reviewable. |

Now run the loop for $ARGUMENTS.

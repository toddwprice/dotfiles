---
name: todd-address-comments
description: >
  Pull, triage, fact-check, and respond to PR review comments end-to-end. Use this WHENEVER Todd
  wants to deal with comments on a pull request — phrasings like "pull comments for the PR and
  propose how to address them", "address the baz comments", "resolve the comments on PR 25840",
  "respond to sam's comments on PR 25834", "process PR comments for 25834", "look at the feedback
  baz left on PR 25834 and resolve it", "reply to the low-severity comments on PR 25834", or "what
  needs to be done to satisfy the comments on PR 25834". A pull request number (or a PR URL / review
  filename that contains one) is required; do not infer one from the current branch or an open-PR list.
  Trigger even when Todd doesn't say the word "skill" and when he names a specific reviewer (baz, sam,
  mbrashid62) together with a PR reference.
  This skill fetches the threads itself (you do NOT need them pasted in), fact-checks each claim
  against the actual code, and by default PROPOSES a plan + draft replies and waits for approval
  before changing code or pushing. It also accepts a local self-review JSON produced by
  `todd-pr-review --json-only` against Todd's OWN PR ("address the self-review at
  ~/reviews/pr-27600-review.json") — see Local findings mode in Step 1.
allowed-tools: Bash(gh:*), Bash(git:*), Bash(mix:*), Bash(yarn:*), Bash(uv:*), Bash(cat:*), Bash(mktemp:*), Read, Grep, Glob, Agent
---

# Address PR Review Comments

Todd's most-repeated manual loop. He kept re-typing "pull the comments and propose how to address
them" because the skill he owned (`git-address-comments`) made him paste the comments in by hand —
the part worth automating is the **pulling + triage + fact-check + per-thread reply**, not the
addressing. This skill does the whole loop and **stops to get his OK before it writes code or
pushes** (his chosen default — see the question he answered when this was built).

## The contract

**Default mode is propose-first.** Pull → fact-check → present a triage table with draft replies and
a fix plan → **wait**. Only after Todd says go do you implement, reply, run CI, and push.

If Todd's request clearly says "just do it" / "resolve them for me and push" / "full auto", you may
run straight through — but still show the triage table first so he can abort, then proceed without a
second prompt.

## Disposition — fix it here, push back, or (rarely) file a ticket

Every comment resolves to one of three dispositions. **A follow-up ticket is the last resort, not
the polite default.**

1. **Fix it in this PR.** The default. Todd owns this branch, so a slightly wider PR is nearly
   always cheaper than a ticket that sits in a backlog. Small fix, in code the diff already
   touches → just do it.
2. **Push back.** The comment is a nit, is wrong about the code, or asks for something the repo
   already accepts elsewhere. One-line reply with the reason. No fix, no ticket.
3. **File a ticket.** For **true scope creep** only — one of these five must hold:
   - it needs a product or design decision that isn't Todd's alone to make
   - it touches an app or subsystem this diff doesn't already touch
   - it needs its own migration, backfill, feature flag, rollout, or eval
   - the branch's existing test surface can't cover it — new fixtures or a new harness required
   - it's big enough to change how the PR gets reviewed: a new file, or well past a few dozen lines

Trips none of the five? Then it isn't a ticket. Fix it, or push back.

### Pushing back on a nit is the expected behavior, not rudeness

A nit is a comment whose fix changes no behavior and no failure mode: naming, ordering, a style the
linter doesn't enforce, a preference between two working forms, "this reads nicer". Test it by
finishing *"if I don't change this, ___ breaks / misleads a reader into believing ___ / costs ___."*
If the honest completion is "nothing," say so in one line and move on:

> Leaving this — both forms behave identically here, and `<file>` already does it this way.

Two things that reply must **not** do: comply anyway to be agreeable, or convert the nit into a
ticket. Those are how a nit ends up costing more than the code it was about. baz's low-severity
comments are the common case, and a human's nit gets the same one-line decline — just warmer.

Guard against the inverse too. "Nit" is not a label for anything inconvenient: a comment about a
docstring or comment that states something **false** has a real failure mode (the wrong belief it
plants in the next reader), and so does anything naming a reachable crash, a wrong result, or a
contract mismatch. Those get fixed.

**The asymmetry with `todd-pr-review` is deliberate.** There, Todd is reviewing *someone else's* PR,
where "won't fix in this PR" is the author's call and he accepts it in one round. Here the PR is his,
so no one else's scope is at stake and the ticket has nothing to hide behind.

## Step 1 — Require the PR number and pick a mode

`$ARGUMENTS` must contain a pull request reference: a PR number, a PR URL, or a review artifact path
whose filename contains the PR number (for example, `~/reviews/pr-27600-review.json`). A reviewer name
alone, an empty argument list, "this PR", and "my open PRs" are not enough.

- PR reference → resolve and use that PR number.
- No PR reference → stop before making any GitHub calls and ask Todd for the PR number. Do not use
  `gh pr view` to infer the current branch's PR and do not enumerate open or drafted PRs.

Resolve `{owner}/{repo}` once: `gh repo view --json nameWithOwner -q .nameWithOwner`.

### Which mode?

**GitHub mode (the default).** Comments live on the PR. Pull them in Step 2, reply to the threads in
Step 6. This is everything below unless a path says otherwise.

**Local findings mode.** `$ARGUMENTS` contains a path to a review JSON — typically
`~/reviews/pr-<N>-review.json` from `todd-pr-review --json-only`. Before doing anything with it,
check who owns the PR:

```bash
gh pr view <N> --json author,isDraft,headRefName -q '{a:.author.login,d:.isDraft,b:.headRefName}'
```

- **PR author is Todd (`@me`)** → this is a *self-review he has not posted*, and it's inbound work.
  Use Local findings mode (next section). This is the `/todd-loop` path: review your own draft, fix
  what you find, never publish the nitpicking.
- **PR author is anyone else** → this is Todd's review of *their* PR, waiting to be published. Wrong
  skill — hand off to `todd-sync-review` and say so. (Same rule for a `.html`/`.md` artifact
  regardless of author: those are outbound by construction.)

### Local findings mode — build pseudo-threads instead of Step 2

Read the JSON. Its shape is the GitHub review-payload schema (canonical spec:
`~/.claude/skills/_shared/review-payload.md`) — a top-level `body`, an `event`, and a `comments[]`
array of `{path, line, side, body}`.

Convert it into the same thread records the rest of this skill expects:

- **Each `comments[]` entry → one pseudo-thread**: `path`, `line`, `body`, reviewer `self-review`,
  `isResolved: false`, no root comment id (there is no GitHub thread — nothing was posted).
- **The top-level `body`** → split on its markdown headings. The `## VERDICT:` line is context, not
  a finding; skip it. Each non-blocking note / PR-wide observation under the other headings becomes a
  pseudo-thread with path `(general)` and no line.
- **Severity**: the JSON carries no severity field. Infer it from the verdict tier language the
  review already used — `requires changes` → high, `requires clarification` → medium, everything
  else → low. Don't invent a severity the review didn't imply.

Then **rejoin the normal flow at Step 3** and fact-check every one of them. Yes, even though a
previous pass of yours wrote them: a review generated without the ability to run the tests is
exactly the kind of thing that produces confident, wrong findings, and Step 3 is the check that
catches it. Treat `self-review` with the same skepticism as baz, not the deference given a human.

Two things differ downstream, both flagged where they land: the triage table's Reviewer column reads
`self-review`, and Step 6 posts **no replies** — there are no threads to reply to.

## Step 2 — Pull every thread (this is the part Todd hates doing by hand)

Get the three comment surfaces in parallel:

```bash
# Inline review comments (the threads on specific lines)
gh api repos/{owner}/{repo}/pulls/<N>/comments --paginate \
  --jq '.[] | {id, in_reply_to_id, path, line, original_line, user:.user.login, body, created_at}'

# Top-level PR conversation comments
gh api repos/{owner}/{repo}/issues/<N>/comments --paginate \
  --jq '.[] | {id, user:.user.login, body, created_at}'

# Review summaries (APPROVE / REQUEST_CHANGES / COMMENT bodies)
gh api repos/{owner}/{repo}/pulls/<N>/reviews --paginate \
  --jq '.[] | {id, user:.user.login, state, body, submitted_at}'
```

**Find what's actually unaddressed.** GitHub's "resolved" state isn't in the REST payload — use
GraphQL to get `isResolved` per thread so you don't re-litigate settled discussions:

```bash
gh api graphql -f query='
  query($owner:String!,$repo:String!,$num:Int!){
    repository(owner:$owner,name:$repo){
      pullRequest(number:$num){
        reviewThreads(first:100){ nodes {
          isResolved isOutdated
          comments(first:50){ nodes { databaseId author{login} path line body } }
        }}
      }
    }
  }' -f owner={owner} -f repo={repo} -F num=<N> \
  --jq '.data.repository.pullRequest.reviewThreads.nodes'
```

Group inline comments into threads by their root (`in_reply_to_id == null` is a root; replies hang
off it). For each thread record: root comment id, path, line, author, full body, `isResolved`, and
whether the **last** reply is from Todd (i.e. already answered).

**Skip** threads that are `isResolved` or already answered by Todd unless he explicitly asks to
revisit them. Report how many you skipped and why.

### Reviewer awareness

- **baz** is the AI reviewer (a GitHub App) and is the dominant commenter on Todd's PRs. Its
  comments often carry a severity and an embedded `<details>Instructions for AI Agents</details>`
  block. Weight baz comments by their stated severity, and **decline low-severity baz nits by
  default** — a one-line rationale, no fix and no ticket. "It's only one line, may as well" is how a
  review of 12 nits becomes 12 commits; run the Gate 4 sentence from Disposition on each one.
- **Humans** (e.g. `sam`, `mbrashid62`, `snkutkoski`) are authoritative — fact-check, but lean
  toward addressing or explicitly explaining. A human nit still gets declined, just warmer; what
  changes is the tone and the amount of evidence you show, not the disposition.

## Step 3 — Fact-check each comment against the code

Don't take any comment at face value, including baz's. For each unaddressed thread:

1. Fetch the file from the PR head branch: `git show origin/<headRef>:<path>` (run
   `git fetch origin <headRef>` first if needed). Read the lines the comment references.
2. Verify the claim: does the code actually do what the comment says? Are the named functions /
   behaviors / edge cases described accurately?
3. Check codebase patterns with a `dev-flow:codebase-pattern-finder` (or `codebase-pattern-finder`)
   sub-agent — is the suggestion consistent with how the rest of the repo handles this, or does the
   repo already accept the flagged pattern elsewhere? Run these in parallel across independent
   threads.
4. Assess each as one of:
   - **Accurate & actionable** — correct and aligns with conventions → fix it, here, in this PR.
   - **Accurate but a nit** — correct, and nothing breaks either way → **one-line decline**. Not a
     fix, not a ticket. Run the Gate 4 sentence from Disposition before anything lands in this
     bucket, and again before anything lands in *Accurate & actionable* that only sounds substantive.
   - **Accurate but non-actionable** — correct but the repo already accepts this pattern → reply
     explaining why we're keeping it.
   - **Partially accurate** — has a real kernel but overreaches → fix the real part, clarify the rest.
   - **Inaccurate** — wrong about the code → reply with the evidence that refutes it.
   - **True scope creep** — correct, worth doing, and trips one of Disposition's five conditions →
     this is the only bucket that earns `todd-followup-ticket`. Name which of the five it trips in the
     triage table; if you can't name one, it belongs in a bucket above.

## Step 4 — Present the triage table and WAIT

Show Todd a compact table, then the draft replies and the fix plan. Stop here in propose-first mode.

```
| # | Thread (file:line)        | Reviewer | Severity | Verdict            | Disposition          |
|---|---------------------------|----------|----------|--------------------|----------------------|
| 1 | errorhandling.ts:42       | baz      | medium   | Accurate&actionable| fix here + reply     |
| 2 | study_setup.py:1283       | baz      | low      | Accurate but a nit | decline (1-line)     |
| 3 | screener_pair.ex:88       | sam      | —        | Partially accurate | fix part             |
| 4 | quota_config.ex:210       | sam      | —        | True scope creep   | ticket (needs a flag)|
```

The **Disposition** column takes exactly one of: `fix here`, `decline`, `ticket`. A `ticket` row must
name the scope-creep condition it trips, in parentheses, like row 4 — an unnamed one is a `fix here`
you haven't admitted to yet. Report the counts in one line under the table (`4 threads: 2 fix here,
1 decline, 1 ticket`) so the balance is visible; mostly-`ticket` is the shape this skill exists to
prevent.

Under the table, for each thread give: the **draft reply** (Todd's voice — clear, terse, kind; lead
with the answer; cite `file:line` evidence) and, for the ones you'll fix, a one-line **what you'll
change**. Then ask Todd to confirm, edit, or drop any before you proceed.

Use `~/.claude/skills/_shared/voice-brief.md` for reply wording — that's the review-scoped
voice reference. Don't load the full `speak-as-todd` skill here; it's the Slack/standup guide
and costs ~6x the tokens for material a PR reply never uses.

**In Local findings mode** the Reviewer column reads `self-review` and there are no draft replies to
write — nothing was ever posted, so there's nothing to reply to. Show the table, the one-line *what
you'll change* per fix, and the rationale for anything you're declining. Then call out **judgement
calls separately**: a finding is a judgement call when fact-checking couldn't settle it — two
defensible designs, or a fix big enough to trip one of Disposition's five scope-creep conditions.
List those explicitly and ask about them before implementing — they're the reason this mode stops
here rather than running straight through.

A *small* fix reaching past what the ticket asked for is **not** a judgement call and doesn't earn a
prompt: do it. Neither is a nit — drop it. Asking Todd about either is how this mode turns a clean
run into a questionnaire.

## Step 5 — Implement (after approval)

**Work in the PR's checkout, not wherever you happen to be.** Todd works in git worktrees, so the
CWD is often a *different* branch's tree. Before editing: confirm you're on the PR's branch
(`git branch --show-current` == `<headRef>`); if not, switch to that branch's worktree
(`git worktree list` to find it) or check it out. Never edit/commit against the wrong tree.

- Make the agreed code changes. If the change has behavioral surface, follow the repo's TDD norm
  (write/extend the failing test first). Keep edits scoped to the comments **plus any small fix you'd
  otherwise have left behind as a ticket** — widening the PR slightly is the point, per Disposition.
  What stays out is work that trips one of the five scope-creep conditions; that's a ticket, and
  everything short of it belongs in this commit.
- Commit with a clear message. End commit messages with the repo trailer:
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- **Checks are mandatory before pushing** — this is a hard rule for Todd's branches. There is **no
  runnable `./bin/ci`** (`bin/ci/` is a *directory* of per-task CI scripts, not an aggregate
  command). Run the CLAUDE.md pre-push checklist for **each app the diff touches**:
  - **Axon** (`apps/axon`): `mix format --check-formatted && mix compile --warnings-as-errors` (and
    `mix test` if behavior changed; `mix lint` for the fuller pass).
  - **Dendra** (`apps/dendra`): `yarn lint && yarn test`.
  - **Astro** (`apps/astro`): `uv run ruff check . && uv run pytest`.
  - **Axon SPAs** (`apps/axon/assets`): `npm run lint && npm run test`.
  Make them green before pushing. To mirror a specific CI task locally, the individual scripts live
  in `bin/ci/*.sh` (e.g. `bin/ci/axon-exunit.sh`).

## Step 6 — Reply to each thread, then push

> Posting mechanics + the Answer-only rule (no `<details>Instructions for AI Agents</details>` block
> on Todd's replies) are the shared canonical spec at `~/.claude/skills/_shared/review-payload.md`.

**In Local findings mode, skip the replies entirely** — there are no threads, and posting the
self-review to the PR after the fact would publish nitpicks Todd already fixed. Commit, push, and
report. Don't post the review JSON to GitHub as a consolation prize.

Reply on the **comments** endpoint (thread replies are NOT the reviews endpoint):

```bash
gh api repos/{owner}/{repo}/pulls/<N>/comments -f body="<reply>" -F in_reply_to=<root_comment_id>
```

- One reply per thread, explaining how it was addressed (or why it wasn't). Thread replies are
  follow-ups to a discussion — do **not** wrap them in `<details>Instructions for AI Agents</details>`.
- Publish each reply individually; if one fails, report it and continue with the rest.
- Optionally resolve the threads you fully addressed:
  ```bash
  gh api graphql -f query='mutation($id:ID!){resolveReviewThread(input:{threadId:$id}){thread{isResolved}}}' -f id=<threadNodeId>
  ```
- Push the branch. Report a one-line summary: threads addressed / replied-only / skipped, the commit
  sha, and the PR URL.

## Notes

## Outcome record

Before every terminal handoff, append one record. It is observational only; a write failure must not prevent the requested PR work from completing.

```bash
~/.dotfiles/ai/skills/_shared/record-skill-outcome.sh \
  --skill todd-address-comments --target "PR-<N>" --head-sha "<current SHA or empty>" \
  --phase "<resolve|triage|implement|reply|push>" \
  --tests "<commands and result, or not-run>" \
  --manual-verification not-applicable --posted-url "<PR URL or empty>" \
  --outcome "<completed|awaiting-user|blocked|failed>" \
  --stop-reason "<pushed|awaiting-approval|no-pr-reference|no-actionable-threads|test-failure|error>"
```

At the propose-first checkpoint, record `awaiting-user` / `awaiting-approval`; after implementation, record the actual terminal result.

- Never push without showing the triage table first.
- A local review file (`~/reviews/pr-XXXX-review.{md,json,html}`) is ambiguous on its face — resolve
  it by PR authorship, per Step 1. Someone else's PR means Todd is *publishing* his review and
  `todd-sync-review` is the right skill; say so and hand off. His own PR plus a `.json` means it's a
  self-review to act on — Local findings mode, stay here. An `.html`/`.md` artifact is outbound
  either way; those are hand-edited for publishing, not machine-generated for consumption.
- If a comment says "filed for later" or implies a follow-up ticket, **first check whether it's small
  enough to just do here** — that's the default now (Disposition). Only when it trips one of the five
  scope-creep conditions do you check whether a ticket already exists and offer
  `todd-followup-ticket`. A ticket that duplicates a ten-line fix in an open branch is worse than
  either doing it or dropping it.

# Canonical: GitHub review payload + posting (Todd's review convention)

**Single source of truth** for how Todd's review skills build and post a PR review. Consumed by
`todd:pr_review`, `todd:sync-review`, and `todd:address-comments`. If you change the schema, the
line-anchoring rules, the posting commands, or the Answer-only rule, change them **here** — the
skills should point at this file, not re-derive it (they drifted before this existed).

## Publish schema (GitHub reviews API)

```json
{
  "body": "Overall summary in markdown (the narrative / verdict, Todd's voice)",
  "event": "APPROVE | REQUEST_CHANGES | COMMENT",
  "comments": [
    { "path": "relative/path/from/repo/root.py", "line": 42, "side": "RIGHT",
      "body": "Human-readable finding or question." }
  ]
}
```

## Placement & anchoring

- **Placement — the inline test.** An inline comment is a **request for a change**. It obligates the
  author to write a reply *and* resolve a thread; a body bullet obligates nothing. So placement is
  decided by *"do I want something changed here?"* — **not** by whether the finding has a file+line.
  - **Inline** — a specific file+line *and* something you want changed or answered.
  - **Body**, carrying a `path/file.ext:L##` reference — everything else: positive callouts (all of
    them, however precise the anchor), PR-wide observations (`file: "(general)"`), and any finding
    whose own conclusion is "no action needed" / "leaving this as-is" / "just so you know" / "this is
    correct" / "unreachable today" / "not a bug".
  - **Dropped** — a preference with no failure mode. Finish the sentence *"if this isn't changed,
    ___ breaks / misleads a reader into believing ___ / costs ___."* If the honest completion is
    "nothing, it would just be nicer," it goes nowhere: not inline, not the body, not a ticket. The
    tell is the vocabulary of gratuitous improvement — *free, strictly cheaper, free precision,
    nicer, tidier, saves the next reader, for symmetry, no functional change*. (Measured: **none**
    of these comments used the word "nit," so don't screen for it.)
  - **Budget: at most 8 inline comments.** Past 8, rank by whether a reply could plausibly change the
    code and demote the rest into the body. **Demote, never delete** — shedding a finding to get under
    budget is worse than a long review. *The one exception is the Dropped branch above:* demotion
    protects a finding that has a failure mode but lost the budget race, and a nit never had one, so
    relocating it to the body just moves the noise (the body reached 682 words average that way).
- **Scope — prefer widening the PR slightly over routing work to a ticket.** When the fix is small
  and lands in code the diff already touches, ask for it in this PR. A ticket is for **true scope
  creep** only: it needs a product/design decision that isn't the author's alone, or touches an app
  the diff doesn't, or needs its own migration/backfill/flag/rollout/eval, or can't be covered by the
  PR's existing test surface, or is big enough to change how the PR gets reviewed. Trips none of
  those → ask here, or drop it. For genuine scope creep, name the boundary in one body line and leave
  the ticket decision unstated — it's the author's.

  > **Measured, 42 payloads / 83 inline comments:** 15 closed with `Your call whether it's worth a
  > ticket — don't block the merge on it.` because `pr_review.md` listed that as an approved close.
  > Not one of the 15 named a real scope boundary; each was either a small fix to ask for or a nit to
  > drop. That close is **retired** — don't reintroduce it here or anywhere else.

  > **This replaced a "severity → placement" rule** that routed every file-anchored `non-blocking` and
  > `positive` finding inline. Measured over 425 posted comments, that criterion produced 46%
  > non-blocking against 2.4% blocking, 41 threads that drew a "no change needed" reply, and 23% that
  > drew no reply at all. A later audit (2026-08-13, 80 comments) found the old rule still live *here*
  > after being fixed in `todd:pr_review`, which is why 39% of comments were still non-blocking.
  > **Don't restore it, and if you change the rule, change it in `commands/todd/pr_review.md` and
  > `skills/todd-sync-review/SKILL.md` in the same edit** — those are the other two copies.
  >
  > This applies to the Dropped and Scope rules below just as much. `pr_review.md` states them
  > **twice** (the Step 4 triage gates *and* the Step 7a comment-structure list), `todd-sync-review`
  > restates placement, and `todd-address-comments` applies the inbound half. A prose rule in this
  > family has never held on its own: the only reason routing improved was the `jq` gate in
  > `pr_review.md` Step 7c, so a change here without a matching check there will not take effect.
  > Checks **(i)** ticket-deferral and **(j)** no-failure-mode are the gates for these two rules.
- **`event`:** blocking findings → usually `REQUEST_CHANGES`; otherwise `COMMENT`; clean approval →
  `APPROVE`. If ambiguous, ask Todd.
- **`side`:** `RIGHT` for added/changed (head) lines — the common case; `LEFT` for deleted lines.
  Use head-commit line numbers (the `+` side of the diff).
- **Line validity:** every `line` must exist in the PR diff. Cross-check against
  `gh api repos/{owner}/{repo}/pulls/<N>/comments` / the diff; warn on any that won't attach and
  demote them into the `body`.

## The Answer-only rule (Todd's convention — the one that kept drifting)

Todd's posted review comments are **clean human prose**. Grounded in what he actually posts (e.g.
PR #26728): open with the observation or question; no bold title/`Bug:`/`Nit:` prefix; keep it short
(his real comments rarely exceed ~120 words).

- **No "How I checked" / evidence appendix in the posted body.** The file:line citations and
  mechanism tracing belong in the HTML review artifact for Todd's own verification, **not** in the
  comment the author reads. Cite a symbol inline only when it's load-bearing for the point itself.
- **No `<details>Instructions for AI Agents</details>` block on Todd's review comments.** That block
  is the *AI reviewer* (baz) convention; Todd's human reviews don't carry it. Default = omit it on
  line comments **and** on thread replies. (Only add it if Todd explicitly asks to post
  agent-actionable instructions.)
- **Non-blocking status**, when stated, is a trailing plain caveat — `NON-BLOCKING.` on its own line
  with a soft close — not a bolded prefix tag.

Use `_shared/voice-brief.md` for any wording generated — the review-scoped voice reference,
not the full `speak-as-todd` Slack guide.

## Posting

```bash
# Main review (body + event + inline comments)
gh api repos/{owner}/{repo}/pulls/<N>/reviews --input /path/to/review.json

# Thread replies — the COMMENTS endpoint, not reviews (one per existing thread; no AI-agent block)
gh api repos/{owner}/{repo}/pulls/<N>/comments -f body="<reply>" -F in_reply_to=<root_comment_id>
```

### Who is allowed to post without asking

Posting a review is outbound and public, so the default across these skills is: **show the full
payload and wait for Todd's confirmation** first. Post replies individually; if one fails, report it
and continue.

**One standing exception: `todd:pr_review` in its default (Post) mode.** Todd asked for that command
to publish the review itself rather than hand him a command to copy — so it runs the `POST` without
confirming, under the preflight gates in its Step 7c. That exception is scoped to that command's
default mode and nothing else: `todd:pr_review --html`, `todd:sync-review`, and
`todd:address-comments` all still show the payload and wait.

### Event constraints GitHub enforces (all consumers)

- **You cannot `APPROVE` or `REQUEST_CHANGES` your own PR** — GitHub returns `422`. When the PR
  author is the authenticated user (`gh api user -q .login`), the only valid event is `COMMENT`.
- **A merged or closed PR** should only ever get `COMMENT`. A blocking verdict on merged code is
  noise; an approval is inaccurate.
- The payload posts atomically — one bad inline anchor rejects the whole request, so you never land
  a half-posted review. Demote rejected anchors into the `body` rather than dropping the findings.

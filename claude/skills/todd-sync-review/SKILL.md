---
name: todd-sync-review
description: >
  Sync a hand-edited PR-review HTML/MD artifact into a postable review JSON and publish it inline to
  GitHub. Use this WHENEVER Todd has edited one of his review files and wants it posted — phrasings
  like "I edited the review html, sync the json and post it", "update the .json to match my new
  comments", "make my comments inline where appropriate", "convert the md review to json so the
  comments post inline", "post my review from ~/Downloads/pr-25964-review.html", or "update the json
  to match the html so the comments are inline". It reads the edited artifact (HTML, MD, or JSON),
  reconciles it against any original JSON, rebuilds the review payload in the publish schema
  (body + event + inline file:line comments + thread replies), shows it, and on approval posts via
  `gh api`. This is the OUTBOUND companion to `todd-describe-pr` / `todd-pr-review` (which generate
  the artifact) — distinct from `todd-address-comments`, which is for INBOUND comments others left.
allowed-tools: Bash(gh:*), Bash(git:*), Bash(cat:*), Bash(mktemp:*), Bash(ls:*), Read, Write, Grep, Glob
---

# Sync & Post an Edited PR Review

Todd's review flow ends with a `describe_pr` / `pr_review` artifact (an HTML page, sometimes a
sidecar `.json` or `.md`) in `~/Downloads` or `.claude/tmp/`. He hand-edits the HTML — adds an
annotation, softens a finding, deletes one — and then needs the postable JSON regenerated to match
**his edits**, with the line-level findings posted **inline**. He's asked for exactly this several
times ("if I update the html, can you update the json to match my new comments?"). The HTML is the
source of truth; the JSON is derived.

## Step 1 — Locate the artifacts and PR

`$ARGUMENTS` may give a path and/or PR number. Otherwise:

- Find the edited artifact: look in `~/Downloads` and `.claude/tmp/` for the most recent
  `pr-<N>-review.{html,md,json}` (and `report-pr-<N>-*.html`). If several, prefer the
  most-recently-modified HTML and confirm with Todd which file is the edited one.
- Find any **original JSON** sidecar for the same PR — that's the prior payload to reconcile against.
- PR number: from the filename, `$ARGUMENTS`, or `gh pr view --json number -q .number`.
- Resolve `{owner}/{repo}` via `gh repo view --json nameWithOwner -q .nameWithOwner`.

## Step 2 — Extract findings from the edited artifact

The `describe_pr` HTML encodes findings as **annotation cards** beneath each file's diff: a severity
chip (`blocking` / `non-blocking` / `positive` / `context` / `clean`), a file, a bold title, and a
body. Parse those cards out. For each finding capture: `file`, `line` (often referenced in the body
as `path.py:NNN` — pull it from there or a data attribute), `severity`, `title`, `body`.

- **MD source:** parse the same fields from the markdown structure.
- **JSON source:** it's already structured — treat it as the desired payload and just validate it.

Treat the edited artifact as authoritative: if it dropped a finding the original JSON had, the
finding is gone; if it added one, include it.

## Step 3 — Build the review payload (publish schema)

> **Canonical spec:** `~/.claude/skills/_shared/review-payload.md` — the schema, anchoring rules, the
> Answer-only rule, and the posting commands live there and are shared with `todd-pr-review` and
> `todd-address-comments`. Follow it; the summary below must stay in sync with it.

Map findings to the GitHub reviews schema:

```json
{
  "body": "Overall summary in markdown (the narrative / verdict, Todd's voice)",
  "event": "APPROVE | REQUEST_CHANGES | COMMENT",
  "comments": [
    {
      "path": "relative/path/from/repo/root.py",
      "line": 42,
      "side": "RIGHT",
      "body": "Human-readable finding.\n\n<details>\n<summary>Instructions for AI Agents</summary>\n\nActionable fix instructions.\n\n</details>\n"
    }
  ]
}
```

Rules that keep GitHub happy and the review clean:

- **Placement — the inline test.** An inline comment is a **request for a change**; it obligates the
  author to reply *and* resolve a thread, where a body bullet obligates nothing. Decide placement by
  *"do I want something changed here?"* — **not** by whether the finding has a file+line. Inline gets
  a file+line *plus* something you want changed or answered; everything else goes in the `body` with a
  `path/file.ext:L##` reference — positive callouts (all of them), PR-wide observations
  (`file: "(general)"`), and any finding whose own conclusion is "no action needed" / "leaving this
  as-is" / "unreachable today" / "not a bug". **Cap inline at 8**, demoting the rest — never deleting.
  (Full rule + the measurements behind it: `_shared/review-payload.md`. This file previously carried a
  "severity → placement" rule that routed every file-anchored non-blocking finding inline; don't
  restore it.)
- **A nit is dropped, not demoted, and a small fix isn't a ticket.** If you can't finish *"if this
  isn't changed, ___ breaks"* about a finding, it goes nowhere — not inline, not the body. That's the
  one carve-out from never-deleting: demotion protects a finding with a failure mode that lost the
  budget race, and a nit never had one. And when a fix is small and sits in code the diff already
  touches, the artifact should ask for it in this PR rather than defer it; a ticket is for true scope
  creep only (five conditions in `_shared/review-payload.md`). The close `Your call whether it's worth
  a ticket — don't block the merge on it.` is **retired** — if the edited HTML still carries it, that's
  a stale artifact, and the finding needs re-routing rather than syncing through verbatim.
- **Event:** derive from the artifact's verdict banner if present — blocking findings → usually
  `REQUEST_CHANGES`; otherwise `COMMENT`; clean approval → `APPROVE`. If ambiguous, ask Todd.
- **Answer-only (default):** Todd's review comments are clean human prose — **no**
  `<details>Instructions for AI Agents</details>` block and no "How I checked" evidence appendix, on
  line comments *or* thread replies. That block is the AI-reviewer (baz) convention, not Todd's;
  only include it if Todd explicitly asks. (See the Answer-only rule in the canonical reference —
  this matches what he actually posts, e.g. #26728.)
- **`side`:** `RIGHT` for added/changed lines (the common case), `LEFT` for deleted lines.
- **Thread replies:** if the artifact marks any item as a reply to an existing thread (a `[REPLY]`
  tag + comment id), separate those out — they post to the comments endpoint, not the reviews
  endpoint.
- **Line validity:** lines must exist in the PR diff. Cross-check against
  `gh api repos/{owner}/{repo}/pulls/<N>/comments` / the diff; warn on any that won't attach and
  offer to demote them into the `body`.

Write the rebuilt payload back to the sidecar JSON (next to the HTML) so Todd has the synced file,
and use `~/.claude/skills/_shared/voice-brief.md` for any wording you generate — the
review-scoped voice reference, not the full `speak-as-todd` Slack guide.

## Step 4 — Show, confirm, post

Show Todd the full payload: the `event`, the `body`, the inline comments (path:line + text), and any
thread replies listed separately. **Wait for confirmation** — posting a review is outbound and
public.

After approval:

```bash
# Main review (body + event + new inline comments)
gh api repos/{owner}/{repo}/pulls/<N>/reviews --input /path/to/review.json

# Thread replies (one per existing thread)
gh api repos/{owner}/{repo}/pulls/<N>/comments -f body="<reply>" -F in_reply_to=<comment_id>
```

Post replies individually; if one fails, report it and continue. Report the published review URL and
the synced JSON path.

## Notes

- HTML is the source of truth — never silently re-introduce a finding Todd deleted.
- If Todd only wants the JSON regenerated (not posted), stop after Step 3 and hand him the file.
- If the artifact doesn't exist yet, that's `todd-describe-pr`'s job first — point him there.

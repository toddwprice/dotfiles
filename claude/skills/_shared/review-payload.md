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

- **Severity → placement:** `blocking` / `non-blocking` / `positive` / `context` findings tied to a
  specific file+line become inline `comments`. PR-wide observations (`file: "(general)"`) fold into
  the `body`, not inline.
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

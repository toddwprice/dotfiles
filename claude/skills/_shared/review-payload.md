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

Use `speak-as-todd` for any wording generated.

## Posting

```bash
# Main review (body + event + inline comments)
gh api repos/{owner}/{repo}/pulls/<N>/reviews --input /path/to/review.json

# Thread replies — the COMMENTS endpoint, not reviews (one per existing thread; no AI-agent block)
gh api repos/{owner}/{repo}/pulls/<N>/comments -f body="<reply>" -F in_reply_to=<root_comment_id>
```

Posting a review is outbound and public — **show the full payload and wait for Todd's confirmation**
first. Post replies individually; if one fails, report it and continue.

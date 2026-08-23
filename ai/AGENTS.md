# Personal instructions (Todd)

These apply to **every** Claude Code session — all projects, all machines that
sync my dotfiles. They sit on top of any repo's own `CLAUDE.md`.

## How to talk to me

### Style
Use /speak-as-todd in your prompt replies, questions, summaries, and plans. Any text you write, use my voice.

### Banned phrases

Do not use these words or phrases. Say the concrete thing instead.

| Don't say | Say instead |
|-----------|-------------|
| load-bearing | name what actually depends on it — "the auth check gates every request" |
| seam / seams | name the actual boundary — "the function / module / API boundary" |
| belt-and-suspenders | describe the two safeguards directly |
| footgun | say what breaks and how — "easy to pass the wrong arg and silently skip the check" |

This applies everywhere: chat replies, plans, commit messages, PR text, review
comments, code comments.

### Reference decisions by behavior, with the identifier in parentheses

- Lead with **what changed** or **what was decided**, described in terms of
  functionality. Then include the Linear ticket and/or PR ID **in parentheses**.
  - Not: "shipped in PR #27070 (FRG-993)" — identifier leads.
  - Yes: "the screener now stays locked when a combined template omits it
    (FRG-993, PR #27070)" — behavior leads, identifier rides along in parens.
- Don't open a sentence with a bare identifier, and don't use a number as the
  primary name for a change. The functional description carries the meaning; the
  identifier in parentheses is the pointer for traceability.
- Applies whenever referencing prior work, a past decision, or an existing
  feature — carry the ID along so I can trace it.

---
allowed-tools: Bash(git log:*), Bash(gh pr list:*), Bash(gh pr view:*), Bash(gh search prs:*), Bash(linctl:*), Bash(mkdir:*), Bash(open:*), Write
description: Generate a brief, narrative-form standup as HTML and open it in the browser.
---

Generate a brief, narrative-style standup covering **Yesterday** and **Today**, then render it as HTML and open it.

## Research

Gather the raw material first — keep it tight, you'll be compressing this into prose:

- **Yesterday's commits:** `git log --all --author="Todd" --since="yesterday 00:00" --until="yesterday 23:59" --oneline` across the relevant worktrees
- **PRs authored:** `gh search prs --author=@me --updated="yesterday"`
- **PRs reviewed:** `gh search prs --reviewed-by=@me --updated="yesterday"`
- **Linear (yesterday):** issues I moved, commented on, or had assigned. Note current status for each.
- **Linear (today):** `linctl issue list --assignee me --newer-than all_time --json` — keep only "In Progress" / "Todo" states.

For PRs I reviewed, attribute them to the Linear ticket on the PR (not my own backlog).

## Narrative form

Write two short paragraphs — not bullet lists.

- **Yesterday:** 2–4 sentences. Lead with the headline (what landed or moved). Group related work by Linear ID. Mention reviews briefly ("reviewed Bill's FRG-XYZ for…"). Reference Linear IDs and PR numbers inline as natural prose, e.g. "wrapped FRG-660 (PR #25411, merged) and pushed FRG-661 through review."
- **Today:** 1–3 sentences. What I'm picking up next and why. Mention blockers if any.

Tone: terse, first-person, conversational — how I'd actually say it out loud. No corporate-speak, no "I will be working on." Active voice. Drop articles where it sounds natural.

If `speak-as-todd` is available, defer to that skill's voice rules for phrasing.

## Render as HTML

Write the report to `.claude/tmp/standup-YYYY-MM-DD.html` (use today's date). Use a clean, readable layout — system font stack, comfortable line-height, max-width around 700px, Linear IDs and PR numbers as inline links where the URL is known:

- Linear: `https://linear.app/dscout/issue/<ID>`
- GitHub PR: `https://github.com/dscout/monorepo/pull/<num>` (or whichever repo the PR is in — infer from `gh` output)

Structure the HTML as:

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Standup — <date></title>
  <style>
    body { font: 16px/1.55 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
           max-width: 700px; margin: 3rem auto; padding: 0 1.25rem; color: #1f2328; }
    h1 { font-size: 1.1rem; color: #57606a; font-weight: 500; margin-bottom: 2rem; }
    h2 { font-size: 0.95rem; text-transform: uppercase; letter-spacing: 0.05em;
         color: #57606a; margin: 1.75rem 0 0.5rem; }
    p  { margin: 0 0 1rem; }
    a  { color: #0969da; text-decoration: none; }
    a:hover { text-decoration: underline; }
  </style>
</head>
<body>
  <h1>Standup — <weekday, Month D, YYYY></h1>
  <h2>Yesterday</h2>
  <p><!-- narrative paragraph --></p>
  <h2>Today</h2>
  <p><!-- narrative paragraph --></p>
</body>
</html>
```

Create the `.claude/tmp/` directory if it doesn't exist. After writing the file, open it with `open <path>` so it loads in the default browser. Report the file path when done.

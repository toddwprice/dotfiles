---
allowed-tools: Bash(git log:*), Bash(gh pr list:*), Bash(gh pr view:*), Bash(gh search prs:*), Bash(linctl:*), Bash(mkdir:*), Bash(open:*), Write
description: Generate a brief standup grouped by workstream as HTML and open it in the browser.
---

Generate a brief standup covering **Yesterday** and **Today**, grouped by workstream, then render it as HTML and open it.

## Research

Gather the raw material first — keep it tight, you'll be compressing this into a handful of lines per workstream:

- **Yesterday's commits:** `git log --all --author="Todd" --since="yesterday 00:00" --until="yesterday 23:59" --oneline` across the relevant worktrees
- **PRs authored:** `gh search prs --author=@me --updated="yesterday"`
- **PRs reviewed:** `gh search prs --reviewed-by=@me --updated="yesterday"`
- **Linear (yesterday):** issues I moved, commented on, or had assigned. Note current status for each.
- **Linear (today):** `linctl issue list --assignee me --newer-than all_time --json` — keep only "In Progress" / "Todo" states.

For PRs I reviewed, attribute them to the Linear ticket on the PR (not my own backlog).

## Format

**Yesterday** and **Today** are the two top-level sections. Under each, group work by **workstream** (the Linear team behind it), one sub-group per workstream with a short uppercase label, then terse first-person lines as a bullet list.

Workstream labels come from the Linear team / ticket prefix:

- `FRG-*` → **FORGE**
- `DEVOPS-*` → **DEVOPS**
- any other prefix → that team's short name

Order the workstreams the same way in both sections: **DEVOPS first, then FORGE** (then any other workstream). Within a workstream, lead with the headline (what landed or moved). Skip a workstream's sub-header entirely if there's nothing under it that day.

Each line is one sentence:

- **Yesterday** lines are past-tense and concrete — what landed or moved, with the why. Start with a verb: "Pushed…", "Split…", "Kept moving…", "Reviewed…", "Got…".
- **Today** lines are forward-looking — what I'm picking up next and why, including ordering and blockers: "Land FRG-900 (#26558) first so FRG-885 (#26572) can go in behind it — they're stacked, order matters."
- Reference Linear IDs and PR numbers inline, with status in parens: `(PR #26572, open)`, `(PR #26558, baz approved)`, `(#26131)`.
- For PRs I reviewed, attribute them to the Linear ticket on the PR (not my own backlog), e.g. "Reviewed Chris's new Stroma ECS cluster PR (#26131) for DEVOPS-2014."

Keep it tight — a handful of lines per workstream, not an exhaustive log.

Tone: terse, first-person, conversational — how I'd actually say it out loud. No corporate-speak, no "I will be working on." Active voice. Drop articles where it sounds natural.

If `speak-as-todd` is available, defer to that skill's voice rules for phrasing.

## Render as HTML

Write the report to `.claude/tmp/standup-YYYY-MM-DD.html` (use today's date). Use a clean, readable layout — system font stack, comfortable line-height, max-width around 700px, Linear IDs and PR numbers as inline links where the URL is known:

- Linear: `https://linear.app/dscout/issue/<ID>`
- GitHub PR: `https://github.com/dscout/monorepo/pull/<num>` (or whichever repo the PR is in — infer from `gh` output)

Structure: `Yesterday` and `Today` as the two top-level sections (`h2`); each workstream as a sub-header (`h3`, rendered uppercase) with its lines in a `<ul>`. Within each section, **DEVOPS comes first, then FORGE** (then any other workstream).

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
    h2 { font-size: 1.05rem; font-weight: 600; color: #1f2328;
         margin: 2rem 0 0.75rem; padding-bottom: 0.3rem; border-bottom: 1px solid #d0d7de; }
    h3 { font-size: 0.8rem; text-transform: uppercase; letter-spacing: 0.06em;
         color: #57606a; font-weight: 600; margin: 1.25rem 0 0.4rem; }
    ul { margin: 0 0 0.5rem; padding-left: 1.25rem; }
    li { margin: 0 0 0.4rem; }
    a  { color: #0969da; text-decoration: none; }
    a:hover { text-decoration: underline; }
  </style>
</head>
<body>
  <h1>Standup — <weekday, Month D, YYYY></h1>

  <h2>Yesterday</h2>
  <h3>DevOps</h3>
  <ul>
    <li><!-- line --></li>
  </ul>
  <h3>Forge</h3>
  <ul>
    <li><!-- line --></li>
    <li><!-- line --></li>
  </ul>

  <h2>Today</h2>
  <h3>DevOps</h3>
  <ul>
    <li><!-- line --></li>
  </ul>
  <h3>Forge</h3>
  <ul>
    <li><!-- line --></li>
  </ul>
</body>
</html>
```

Create the `.claude/tmp/` directory if it doesn't exist. After writing the file, open it with `open <path>` so it loads in the default browser. Report the file path when done.

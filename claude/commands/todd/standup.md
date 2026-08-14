---
allowed-tools: Bash(git log:*), Bash(gh pr list:*), Bash(gh pr view:*), Bash(gh search prs:*), Bash(linctl:*), Bash(date:*), Bash(mkdir:*), Bash(open:*), Write, mcp__plugin_slack_slack__slack_send_message
description: Generate a brief standup grouped by workstream as HTML, open it in the browser, and post it to my Slack DM.
---

Generate a lean standup covering **Yesterday** and **Today**, grouped by workstream, render it as HTML and open it, then post it to my Slack DM.

## Research

Gather raw material, then compress hard — you're distilling this to a couple of lines per workstream.

**First compute the window as real dates.** Do NOT pass the word `"yesterday"` to `gh search
--updated` — that flag wants a date (or `>=`/range), and the literal `"yesterday"` silently matches
nothing. On Monday, widen "yesterday" back to Friday so the weekend gap doesn't blank the standup:

```bash
if [ "$(date +%u)" -eq 1 ]; then SINCE=$(date -v-3d +%Y-%m-%d); else SINCE=$(date -v-1d +%Y-%m-%d); fi
TODAY=$(date +%Y-%m-%d)
```

Then gather. **Reuse the `branch-recap` skill as the per-branch primitive** instead of re-deriving
git/PR/Linear state by hand — it already does the careful `main..HEAD` + `gh pr view` + Linear-issue
gather for one branch, so let it own that and just fan it over my active branches:

- **My active branches** → the per-workstream "Yesterday landed / Today next" material:
  `git worktree list` (and/or `git branch --sort=-committerdate`) to find branches I touched since
  `$SINCE`; for each, run the `branch-recap` gather (git `main..HEAD`, PR state, Linear issue) and
  scope "landed" to commits since `$SINCE`.
- **PRs I reviewed** — branch-recap does NOT cover these (they're other people's branches):
  `gh search prs --reviewed-by=@me --updated=">=$SINCE"` → the **Reviews** subsection, attributed to
  the ticket on each PR, not my backlog.
- **Linear (today):** `linctl issue list --assignee me --newer-than all_time --json` — keep only
  "In Progress" / "Todo" for anything not already surfaced via a branch above.

## Format

> **Canonical shape + voice:** `speak-as-todd` → "Standup updates" is the single source of truth for
> the standup form (two date headers, ALL-CAPS area labels incl. `REVIEWS`, link-dense one-clause
> bullets, no greeting/sign-off). Follow it; the rules below are the standup-command specifics
> (workstream ordering, brevity ceilings) that layer on top — don't re-litigate the voice here.
> One carve-out: the **TL;DR** section below is this command's own addition. `speak-as-todd` doesn't
> describe it, and that absence is not a reason to drop it.

Two top-level sections, **Yesterday** and **Today**. Under each, group by **workstream** (Linear team / prefix): `FRG-*` → **FORGE**, `DEVOPS-*` → **DEVOPS**, any other prefix → that team's short name. Order **FORGE first, DEVOPS last**, others between — same order in both sections. Skip a workstream with nothing that day.

Brevity rules — this is the point:

- **≤4 lines per workstream, aim for 2–3.** Collapse related items into one line (e.g. several reviews for one person, a stack of PRs).
- One short line each: ID/PR + status + what it is. Plain verb, no flourish, no verb-variety.
- **Cut the "why"** unless it's a blocker or genuinely non-obvious. No process breadcrumbs, no step-by-step asides, no parenthetical sub-detail.
- Yesterday = what landed/moved, past tense. Today = next action + blocker if any, forward, one clause. E.g. "Land FRG-900 (#26558) before FRG-885 (#26572) — stacked."
- Inline IDs with status in parens: `(#26886, merged)`, `(#26933, draft)`, `(#26533, open)`.
- **Reviews subsection** — under *Yesterday* only, after the workstreams: one line per PR I reviewed, attributed to the PR's ticket ("Reviewed Chris's Stroma cluster PR (#26131) for DEVOPS-2014."). Collapse several reviews for one person/stack into one line. Skip the subsection entirely if I reviewed nothing that day. Keep reviews here — first-class, not folded into my own workstreams (matches `speak-as-todd`).

Tone: terse, first-person, plain — how I'd say it out loud. No corporate-speak, no rationale padding. If `speak-as-todd` is available, defer to its voice.

## TL;DR (experimental)

Last section, after `Today`, in **both** the HTML and the Slack post. Mark it experimental so it reads
as a trial: drop the tag if it graduates, delete this section if it doesn't.

What it's for: someone who doesn't know my tickets reads only this and comes away knowing what I did
and what I'm doing. Two sentences, no bookkeeping.

**Build it from the bullets already written above — don't re-research anything.** Take each line, keep
the behavior clause, drop the parenthetical, then merge everything sharing a theme into one sentence:

> `FRG-1240` (`#28026`, merged) — an over-length scale anchor refuses before it 400s the DYS export
> → *an over-length scale anchor now refuses instead of failing the export*

The shape:

- Two labels, `Yesterday` and `Today`, in that order.
- **One sentence each, three clauses at most, ~30 words.** Bullets only when a day genuinely splits into
  unrelated threads — **3 max**, and 3 should be rare.
- **Select, don't concatenate.** Name the two or three threads that actually mattered and let the rest
  go — every workstream is already itemized directly above, so a TL;DR that lists all of them is just
  the standup again with the links removed. Dropping a real workstream from this section is correct.
- **Name things in words, not identifiers**: "the DYS export", "the astro workers", "the shared dev env
  lock". No ticket IDs, no PR numbers, no links, no status parens. The traceable version is the section
  directly above this one — dropping the identifiers here is the entire point, and the deliberate
  exception to my usual "carry the ID along in parens" rule.
- Reviews collapse into one clause of the `Yesterday` sentence — area or count, never names and PRs. Use
  a count only if you actually counted the lines above.
- Past tense for `Yesterday`, plain intent for `Today`. Same voice, just zoomed out.

Worked example — a real five-workstream day with eleven reviews, compressed:

> **TL;DR** *(experimental)*
> **Yesterday** — Landed export and validation fixes so agent-authored studies survive export, gated the
> template picker to paid seats, and reviewed eleven PRs across the front-end, dscript and infra pods.
> **Today** — Carry the scale-length fix into the remaining export paths, land the approved question
> guard, and get the dev-env lock, bulk transport and worker-memory branches out of draft.

## Render as HTML

Write to `.claude/tmp/standup-YYYY-MM-DD.html` (today's date). The base typography + palette come from
the shared shell at `~/.claude/skills/_shared/report-shell.html` (single source of truth for the
look) — the standup-specific bits below (narrower `max-width`, muted `h1`, uppercased `h3`) layer on
top of those tokens; keep them in sync with the shell rather than re-inventing colors. Structure:
`Yesterday`/`Today` as `h2`; each workstream an `h3` (uppercased via CSS) with lines in a `<ul>`. Link
Linear IDs (`https://linear.app/dscout/issue/<ID>`) and PRs (`https://github.com/dscout/dscout/pull/<num>` — infer repo from `gh`). FORGE first, DEVOPS last.
The `TL;DR` is the last `h2`, with its own `Yesterday`/`Today` `h3`s and plain unlinked text — it's the
one part of the page with no anchors in it.

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
    /* TL;DR (experimental) — muted gray matches h1/h3 rather than adding a color */
    .tldr { margin-top: 2.5rem; }
    .tldr p { margin: 0 0 0.6rem; }
    .tag { font-size: 0.7rem; text-transform: uppercase; letter-spacing: 0.06em;
           color: #57606a; font-weight: 500; }
    a:hover { text-decoration: underline; }
  </style>
</head>
<body>
  <h1>Standup — <weekday, Month D, YYYY></h1>

  <h2>Yesterday</h2>
  <h3>Forge</h3>
  <ul>
    <li><!-- line --></li>
    <li><!-- line --></li>
  </ul>
  <h3>DevOps</h3>
  <ul>
    <li><!-- line --></li>
  </ul>
  <!-- Reviews subsection (Yesterday only) — omit if no reviews that day -->
  <h3>Reviews</h3>
  <ul>
    <li><!-- Reviewed X's PR (#NNNNN) for TICKET --></li>
  </ul>

  <h2>Today</h2>
  <h3>Forge</h3>
  <ul>
    <li><!-- line --></li>
  </ul>
  <h3>DevOps</h3>
  <ul>
    <li><!-- line --></li>
  </ul>

  <section class="tldr">
    <h2>TL;DR <span class="tag">experimental</span></h2>
    <h3>Yesterday</h3>
    <p><!-- one sentence, no IDs, no links --></p>
    <h3>Today</h3>
    <p><!-- one sentence, no IDs, no links --></p>
  </section>
</body>
</html>
```

Create `.claude/tmp/` if needed, then `open <path>` so it loads in the browser.

## Post to Slack (always)

After opening the HTML, **always** post the same standup as a Slack DM via `mcp__plugin_slack_slack__slack_send_message`, `channel_id` = `U0AD41CLFC1` (self-DM). Send directly — no draft, no confirmation. Author in standard markdown (the tool converts to mrkdwn):

- Title: `**Standup — <weekday, Month D, YYYY>**`
- Section headers (`Yesterday`/`Today`): `**bold**` on their own line.
- Workstream labels: `_italic_` on their own line (`_Forge_`, `_DevOps_`) — not bold. Under *Yesterday*, add a `_Reviews_` label after the workstreams when I reviewed anything (same content as the HTML Reviews subsection); omit it when there were none.
- Lines: `-` bullets. Same ordering as the HTML.
- Links: `[FRG-957](https://linear.app/dscout/issue/FRG-957)`, `[#26887](https://github.com/dscout/dscout/pull/26887)`.
- **TL;DR last**, after `Today`: `**TL;DR** _(experimental)_` on its own line, then `**Yesterday** — …`
  and `**Today** — …`, one sentence each, as plain text. No bullets, no links, no IDs — same words as
  the HTML section.

**Spacing guard:** keep a real space on both sides of every link and inline-`code` token so nothing glues together when flattened (`Shipped [FRG-957](…) (…)`, not `Shipped[FRG-957](…)`).

Report the file path and the Slack message link when done.

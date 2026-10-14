---
name: todd-standup
allowed-tools: Bash(git log:*), Bash(gh pr list:*), Bash(gh pr view:*), Bash(gh search prs:*), Bash(linctl:*), Bash(date:*), Bash(mkdir:*), Bash(open:*), Write
description: >
  Use when Todd explicitly asks for his standup — "write my standup", "my standup", "generate my
  standup", "standup for today", "post my standup". Gathers yesterday's landed work and today's next
  steps from his branches, the PRs he reviewed, and Linear; groups it by workstream; renders it as HTML
  and opens it. Requires an explicit standup request — do NOT trigger it from a general "what did I work
  on" or "catch me up" question; use `branch-recap` or `todd-catchup` for those.
---

Generate a lean standup covering **Yesterday** and **Today**, grouped by workstream, render it as HTML and open it. Do not post or send a Slack version.

## Research

Gather raw material, then compress hard — you're distilling this to a couple of cards per workstream.

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

> **Canonical voice:** this command is the single source of truth for the standup shape
> (two date headers, ALL-CAPS area labels incl. `REVIEWS`, terse one-clause lines, the card
> shape below, no greeting/sign-off). Sentence-level style follows the `ste-writer` skill
> (STE), per AGENTS.md — don't re-litigate the voice here. The **TL;DR** section is this
> command's own addition — keep it regardless.

Two top-level sections, **Yesterday** and **Today**. Under each, group by **workstream** (Linear team / prefix): `FRG-*` → **FORGE**, `DEVOPS-*` → **DEVOPS**, any other prefix → that team's short name. Order **FORGE first, DEVOPS last**, others between — same order in both sections. Skip a workstream with nothing that day.

**Every entry is a card, never a bullet** — show the linked Linear ID and linked PR number together, followed by one concise description blended from the Linear ticket and PR descriptions. Do not show separate ticket and PR titles. Use this shape:

```
====================================================================
[LINEAR_ID](https://linear.app/dscout/issue/ID) [#PR_NUMBER](https://github.com/dscout/dscout/pull/N) BLENDED_DESCRIPTION
**Progress:** STEPS_TO_DATE
**Next:** NEXT_STEPS
```

Worked example:

```
====================================================================
[FRG-1438](https://linear.app/dscout/issue/FRG-1438) [#29947](https://github.com/dscout/dscout/pull/29947) Track if a smart template is used on the trace
**Progress:** Added template-change trace telemetry with mission and screener template IDs.
**Next:** Address review feedback and merge.
```

Other examples:

```
====================================================================
[FRG-1437](https://linear.app/dscout/issue/FRG-1437) [#29780](https://github.com/dscout/dscout/pull/29780) DYS standalone screener teaser and export
**Progress:** Typed the standalone screener teaser state values.
**Next:** Test the product flow when staging is free.

====================================================================
[DEVOPS-2517](https://linear.app/dscout/issue/DEVOPS-2517) [#29749](https://github.com/dscout/dscout/pull/29749) Provide global Ganglia installation for Pi and OpenCode
**Progress:** Tested Chris' work locally, updated to target OpenCode v2.
**Next:** Finish testing and update PR.
```

Card rules — this is the point:

- The `=` separator line precedes every card.
- **≤3 cards per workstream, aim for 2.** Collapse related items into one card (e.g. several reviews for one person, a stack of PRs).
- Put both linked identifiers on one line, then a single description that combines the useful meaning of the Linear ticket and PR descriptions; remove redundant or conflicting phrasing rather than repeating both titles. If the user supplies a blended description, use it. If there is no PR yet, show only the linked Linear ID and its concise description. Omit `**Next:**` when there is no next step.
- `**Progress:**` = what landed/moved (Yesterday, past tense) or where the work stands (Today). `**Next:**` = next action + blocker if any, forward, one clause.
- Do not add a separate PR title or a PR status label; the blended description is the only description shown.
- One clause per field. Plain verb, no flourish, no verb-variety. **Cut the "why"** unless it's a blocker or genuinely non-obvious. No process breadcrumbs, no step-by-step asides, no parenthetical sub-detail.
- **Reviews subsection** — under *Yesterday* only, after the workstreams: one card per PR I reviewed, attributed to the PR's ticket — put the linked ticket ID and linked PR number together, followed by one blended ticket/PR description; `**Progress:**` says what I reviewed; omit `**Next:**`. Collapse several reviews for one person/stack into one card. Skip the subsection entirely if I reviewed nothing that day. Keep reviews here — first-class, not folded into my own workstreams.

Tone: terse, first-person, plain — how I'd say it out loud. No corporate-speak, no rationale padding. Sentence-level style follows the `ste-writer` skill (STE), per AGENTS.md.

## TL;DR (experimental)

Last section, after `Today`, in the HTML. Mark it experimental so it reads as a trial: drop the tag if it graduates, delete this section if it doesn't.

What it's for: someone who doesn't know my tickets reads only this and comes away knowing what I did
and what I'm doing. Two sentences, no bookkeeping.

**Build it from the cards already written above — don't re-research anything.** Take each card's
`**Progress:**` clause, drop the identifiers, then merge everything sharing a theme into one sentence:

> `FRG-1240` / `#28026` (merged), **Progress:** an over-length scale anchor refuses before it 400s
> the DYS export → *an over-length scale anchor now refuses instead of failing the export*

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
  `Yesterday`/`Today` as `h2`; each workstream an `h3` (uppercased via CSS); under it one `.card` div
  per entry — the HTML rendering of the card shape above: an `<hr>` between cards stands in for the
  `=` separator, the linked Linear ID and linked PR number appear together before one blended
  description, and `**Progress:**`/`**Next:**` become `<strong>Progress:</strong>` /
  `<strong>Next:</strong>` lines.
Link Linear IDs (`https://linear.app/dscout/issue/<ID>`) and PRs
(`https://github.com/dscout/dscout/pull/<num>` — infer repo from `gh`). FORGE first, DEVOPS last.
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
    .card { margin: 0 0 0.5rem; }
    .card p { margin: 0 0 0.25rem; }
    .card .ids { font-weight: 600; }
    hr { border: 0; border-top: 1px solid #d0d7de; margin: 0.75rem 0; }
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
  <div class="card">
    <p class="ids"><a href="https://linear.app/dscout/issue/ID">ID</a> <a href="https://github.com/dscout/dscout/pull/N">#N</a> Blended description</p>
    <p><strong>Progress:</strong> <!-- one clause --></p>
    <p><strong>Next:</strong> <!-- one clause --></p>
  </div>
  <hr>
  <div class="card">
    <!-- next card — omit a missing PR link or Next line -->
  </div>
  <h3>DevOps</h3>
  <div class="card">
    <!-- ... -->
  </div>
  <!-- Reviews subsection (Yesterday only) — omit if no reviews that day -->
  <h3>Reviews</h3>
  <div class="card">
    <p class="ids"><a href="https://linear.app/dscout/issue/ID">ID</a> <a href="https://github.com/dscout/dscout/pull/N">#N</a> Blended description</p>
    <p><strong>Progress:</strong> <!-- Reviewed X's PR --></p>
  </div>

  <h2>Today</h2>
  <h3>Forge</h3>
  <div class="card">
    <!-- ... -->
  </div>
  <h3>DevOps</h3>
  <div class="card">
    <!-- ... -->
  </div>

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
Report the HTML file path when done. Do not send a Slack message.

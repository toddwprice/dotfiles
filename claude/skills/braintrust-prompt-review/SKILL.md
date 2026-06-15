---
name: braintrust-prompt-review
description: Detect Braintrust prompt pin (version) changes in a GitHub PR or the current branch and render an HTML diff of the FULL prompt text (system + user messages, every line, not just changed sections) between the old and new pinned versions. Use whenever the user wants to review what changed about a Braintrust prompt revision pinned in code — phrasings like "what prompt changes are in PR #X", "show me the prompt diff", "review the braintrust pins", "what changed in the supervisor-select prompt", "diff the new prompt against main", "render the prompt diff for this branch". Also trigger proactively when reviewing a PR that bumps any `BraintrustPrompt(..., version="...")` constructor in dscout code, because the code diff hides the prompt content itself — you need to fetch it from Braintrust to actually see what changed.
---

# braintrust-prompt-review

Render a side-by-side, full-prompt HTML diff for every Braintrust prompt pin that changed in a PR or branch.

## Why this skill exists

In dscout, production code pins a specific Braintrust prompt revision via
`BraintrustPrompt(slug="...", version="<xact_id>", ...)`. A code diff
shows the pin moving (e.g. `aabe674...` → `7619d38...`) but tells you
nothing about what actually changed in the prompt — the prompt text lives
in Braintrust, not in the repo. Reviewing those pin bumps blind is risky
because they materially alter LLM behavior in production.

This skill bridges that gap: given a PR or branch, it finds every pin
change, fetches both versions from the Braintrust API, and renders a
single HTML page per prompt (or an index when there are several) showing
the **entire prompt** as a unified diff. Unchanged lines are visible by
default so reviewers can read the change in context; a header button
hides them when only the deltas matter.

## When to use

Trigger on any of:

- The user asks about prompt diffs in a PR or branch.
- A PR being reviewed touches `BraintrustPrompt(..., version="...")` —
  even if the user didn't explicitly ask, surface the prompt diff so the
  review can be informed by what actually changed.
- The user wants to compare a current pin against `main` before merging.

## How to use

Run the script. It auto-detects the diff source and writes HTML to
`~/Downloads/` (filenames are prefixed with the scope slug so multiple
reviews don't collide; override with `--out`).

```bash
# Review a GitHub PR (uses `gh pr diff` under the hood):
python3 ~/.claude/skills/braintrust-prompt-review/scripts/review.py --pr 25654

# Review the current local branch vs main:
python3 ~/.claude/skills/braintrust-prompt-review/scripts/review.py

# Review a named local branch vs a non-main base:
python3 ~/.claude/skills/braintrust-prompt-review/scripts/review.py \
    --branch my-feature --base develop

# Don't auto-open in the browser:
python3 ~/.claude/skills/braintrust-prompt-review/scripts/review.py --pr 25654 --no-open
```

The script:

1. Acquires the diff (`gh pr diff N` for PRs, `git diff <base>...<branch>` otherwise).
2. Parses it for `version="<hex>"` lines inside `BraintrustPrompt(...)` constructors,
   walking back through the hunk to find the nearest `slug=`.
3. Resolves each slug's Braintrust prompt ID via `GET /v1/prompt?slug=&project_name=`.
4. Fetches both pinned versions via `GET /v1/prompt/{id}?version={xact_id}`.
5. Renders a per-prompt HTML page (or an index when multiple prompts changed).
6. Opens the result in the default browser unless `--no-open` is passed.

## Auth

Requires `BRAINTRUST_API_KEY` in the environment. The script exits
clearly if it's missing.

## Project resolution

`BraintrustPrompt(project=get_module_name())` resolves at runtime based
on where the call lives. The skill mirrors this with a path-prefix
mapping in `scripts/review.py` (`PROJECT_HINTS`):

| Path prefix | Braintrust project |
| --- | --- |
| `apps/astro/` | `dscript` |
| `apps/ai_mod/` | `ai_mod` |

If a new app starts pinning prompts, add a row to `PROJECT_HINTS`. When
no hint matches, the script falls back to a slug-only search across the
org and warns if the slug is ambiguous.

## Detection semantics

The diff parser handles three cases:

- **Modified**: `-version="A"` followed by `+version="B"` → fetch both, render a diff.
- **Added**: only a `+version="B"` line → fetch new only, render against an empty old.
- **Removed**: only a `-version="A"` line → fetch old only, render against an empty new.

It scans backward (within the current hunk) for `slug=` to associate a
version line with its prompt. Two unrelated pins in adjacent hunks are
resolved independently because hunk boundaries (`@@`) stop the scan.

## Output

All HTML is written to `~/Downloads/` by default. Filenames are
prefixed with the scope slug so reviews of different PRs/branches don't
collide:

- Single pin change: `~/Downloads/<scope>-<slug>.html`
  (e.g. `~/Downloads/pr-25654-supervisor-select.html`)
- Multiple pin changes: per-prompt files plus
  `~/Downloads/<scope>-index.html` listing them with
  kind/old-pin/new-pin/source-file columns.

Override the location with `--out DIR` if needed.

The diff view shows the entire prompt as context. The "Toggle unchanged
lines" button collapses to deltas-only for a quick scan.

## Reporting back to the user

After rendering, tell the user:

- Which prompts changed and their kind (modified/added/removed)
- A one-line shape summary per prompt (`+N/-M`) — this often reveals
  intent (pure-additive vs. rewrite vs. removal) before they open the file
- The path of the index (or single file) so they can click it

Don't paraphrase the prompt content itself — the HTML page is the
canonical artifact for reviewing what changed.

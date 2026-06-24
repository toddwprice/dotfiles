---
allowed-tools: Bash(mkdir:*), Bash(open:*), Bash(date:*), Bash(ls:*), Bash(cp:*), Bash(mv:*), Bash(/usr/bin/python3:*), Bash(/Applications/Google Chrome.app/Contents/MacOS/Google Chrome:*), Write, Read, Agent
description: Answer a question (diagram, SQL result, subsystem story, comparison) and render it as a self-contained HTML page in the shared `artifacts/` catalog, auto-refreshing an `index.html` table of every report, then open it. Pass the topic/question as $ARGUMENTS; append `--pdf` for a Mermaid-aware PDF sibling, or `--ingest <paths…>` to fold previously-created HTML reports into the catalog. Composes with dscout-knowledge, dscout-data-mcp:query-prod, and Mermaid for diagrams.
---

You are producing a self-contained HTML report that answers a question or tells a visual story. The report opens in a browser when done.

**This command is autonomous. Do NOT ask clarifying questions** — pick a reasonable shape and ship it; Todd will redirect if the shape is wrong.

Arguments: `$ARGUMENTS` is the question, topic, or instruction. Examples Todd has used in the past:
- *"high level network diagram of our infrastructure"*
- *"diagrams in HTML that tell the story of how media processing works in the platform"*
- *"run this sql against my localhost database and format the result as HTML"*
- *"comparison table of mission_drafts vs study_templates schemas"*

## Where output goes — the `artifacts/` catalog

**All HTML reports land in `/Users/toddprice/dscout-knowledge/artifacts/`** (the shared knowledge-base repo, a.k.a. `~/dscout-knowledge/artifacts/`). That directory holds:

- `report-<slug>-YYYY-MM-DD-HHMM.html` — the reports themselves (+ optional `.pdf` siblings).
- `index.html` — a generated catalog: a table of **date · name (link) · description** for every report. It is **regenerated** by `build_index.py`; never hand-edit it.
- `build_index.py` — the catalog builder. It scans the directory and reconstructs the index from each report's `<meta>` tags (with sensible fallbacks to `<title>`, the date in the filename, and file mtime). Run it any time with `/usr/bin/python3 ~/dscout-knowledge/artifacts/build_index.py`.
- `index.overrides.json` *(optional)* — per-file `{title, description, date}` overrides to curate any entry (handy for older files that lack meta tags) without editing the HTML.

Because the index is rebuilt by scanning, deleting a report and rebuilding simply drops its row — there is no manifest to keep in sync.

## Flags (scan `$ARGUMENTS` for these tokens, strip them, keep the rest as the question)

- `--pdf` — set `WANT_PDF=1`. Render a PDF sibling in Step 6 after the HTML is written.
- `--ingest` — switch to **Ingest mode** (see the section at the bottom): fold already-created HTML report(s) into the catalog instead of generating a new one. Skip Steps 1–3.
- `--move` — only meaningful with `--ingest`; move sources into `artifacts/` instead of copying.

## Step 1 — Classify the report shape

Decide which template fits. Most reports are one of:

- **Diagram** — system topology, sequence flow, data flow. Use **Mermaid** (`graph LR`, `sequenceDiagram`, `flowchart`). Load Mermaid from a CDN script tag.
- **Tabular** — SQL results, comparison matrices. Use a sortable `<table>` with sticky headers.
- **Narrative + diagrams** — "tell the story of X". A short intro paragraph, then 2–4 Mermaid diagrams with captions.
- **Dashboard** — multiple cards. Use CSS grid.

If the prompt mixes shapes, default to narrative + diagrams.

## Step 2 — Gather raw material

Pull only from the sources the prompt implies:

- **Terraform / topology / repo layout** → read from `~/dscout-knowledge` (the snapshot worktree). Don't grep the live repo unless the answer needs current code.
- **Production data** → use the `dscout-data-mcp:query-prod` skill. Don't write SQL by guesswork; derive schemas from the monorepo first.
- **Local database** → run `psql` against the local connection string (Todd's local DB env vars are already set). If the SQL is supplied in `$ARGUMENTS`, run it verbatim.
- **Codebase intel** → use Read/Glob/Grep against `/Users/toddprice/dscout-wt`.
- **External docs** → WebFetch when explicitly named.

If the report needs 2+ independent gathers, dispatch sub-agents (Agent tool, in parallel) — one per source — and merge.

## Step 3 — Render

Write the report to `/Users/toddprice/dscout-knowledge/artifacts/report-<slug>-YYYY-MM-DD-HHMM.html`. The slug is a kebab-case summary of `$ARGUMENTS` (≤40 chars). The directory already exists; `mkdir -p` it if not.

Use this base shell — same visual language as the standup so the look is consistent. **The three `report-*` meta tags are required** — they populate the `index.html` catalog. Keep the description to one tight line (≤140 chars) that says what the report answers, distinct from the title.

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title><report title></title>
  <!-- Required: these three tags feed the artifacts/index.html catalog. -->
  <meta name="report-title" content="<report title>">
  <meta name="report-description" content="<one tight line — what this report answers, ≤140 chars, distinct from the title>">
  <meta name="report-date" content="<YYYY-MM-DD>">
  <style>
    :root { color-scheme: light; }
    body { font: 16px/1.55 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
           max-width: 980px; margin: 2.5rem auto; padding: 0 1.25rem; color: #1f2328; }
    h1 { font-size: 1.4rem; margin: 0 0 0.25rem; }
    .meta { color: #57606a; font-size: 0.85rem; margin-bottom: 2rem; }
    h2 { font-size: 1rem; text-transform: uppercase; letter-spacing: 0.05em;
         color: #57606a; margin: 2rem 0 0.5rem; }
    p  { margin: 0 0 1rem; }
    a  { color: #0969da; text-decoration: none; }
    a:hover { text-decoration: underline; }
    code { font: 13px/1.4 ui-monospace, SFMono-Regular, Menlo, monospace;
           background: #f6f8fa; padding: 1px 4px; border-radius: 3px; }
    pre { background: #f6f8fa; padding: 1rem; border-radius: 6px; overflow-x: auto; }
    table { border-collapse: collapse; width: 100%; margin: 1rem 0; }
    th, td { text-align: left; padding: 0.5rem 0.75rem; border-bottom: 1px solid #d0d7de; }
    th { background: #f6f8fa; position: sticky; top: 0; font-weight: 600; }
    .mermaid { margin: 1.5rem 0; }
    .caption { color: #57606a; font-size: 0.85rem; margin-top: -0.5rem; margin-bottom: 1.5rem; }
  </style>
  <!-- Only include Mermaid if the report uses diagrams -->
  <script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
  <script>mermaid.initialize({ startOnLoad: true, theme: "default" });</script>
</head>
<body>
  <h1><report title></h1>
  <div class="meta">Generated <date> · <one-line context></div>
  <!-- content -->
</body>
</html>
```

Rules for content:
- Mermaid blocks go in `<div class="mermaid">...</div>`. Test mentally for syntax — Mermaid silently fails on bad arrows.
- For tables, include the SQL or source in a collapsed `<details>` block at the bottom so Todd can audit it.
- Hyperlink Linear IDs (`https://linear.app/dscout/issue/<ID>`) and PR numbers (`https://github.com/dscout/monorepo/pull/<num>`) when they appear.
- Drop the Mermaid `<script>` tag if there are no diagrams — keep the file lean.

## Step 4 — Refresh the catalog index

Rebuild `index.html` so the new report appears in the catalog:

```bash
/usr/bin/python3 ~/dscout-knowledge/artifacts/build_index.py
```

This rescans `artifacts/` and rewrites `index.html` from each report's meta tags — idempotent and fast. If the builder is somehow missing (e.g. a fresh clone that hasn't pulled), note it but don't fail; the report itself is already written.

## Step 5 — Open

Open the report you just wrote:

```bash
open /Users/toddprice/dscout-knowledge/artifacts/<report-file>.html
```

## Step 6 — Optional PDF (only if `WANT_PDF=1`)

Render the same file to a PDF sibling via headless Chrome. Use these exact flags — they earn their keep:

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless \
  --disable-gpu \
  --no-pdf-header-footer \
  --virtual-time-budget=10000 \
  --run-all-compositor-stages-before-draw \
  --print-to-pdf=<path-without-.html>.pdf \
  "file://<absolute-path-to-html>"
```

Why these flags matter (do not strip them):
- `--virtual-time-budget=10000` gives client-side JS up to 10s to finish before snapshot. Without it, **Mermaid diagrams print as blank `<div>`s** because Chrome captures before the CDN script renders.
- `--run-all-compositor-stages-before-draw` pairs with the time budget to ensure layout/paint finish before capture.
- `--no-pdf-header-footer` strips the page-edge URL/date chrome for cleaner shareable output.

Then `open <pdf-path>` so the PDF lands in Preview alongside the browser tab.

## Step 7 — Report

Tell Todd, in one line, where things landed and what shape you picked. Mention the PDF only if you produced one, and note the catalog was refreshed.

- HTML only: *"Wrote `artifacts/report-media-processing-2026-05-18-1432.html` — narrative + 3 Mermaid flow diagrams. Opened in browser; `index.html` catalog refreshed."*
- HTML + PDF: *"Wrote `artifacts/report-media-processing-2026-05-18-1432.html` + `.pdf` — narrative + 3 Mermaid flow diagrams. Both opened; catalog refreshed."*

## Ingest mode (`--ingest`)

Triggered when `$ARGUMENTS` contains `--ingest`. Instead of generating a new report, fold already-created HTML report(s) into the catalog. The remaining (non-flag) tokens in `$ARGUMENTS` are the source(s).

1. **Resolve sources:**
   - If one or more paths/globs are given, use those (e.g. `~/Downloads/foo.html`, `.claude/tmp/report-*.html`).
   - If no path is given, sweep the legacy temp location: `~/dscout-knowledge/.claude/tmp/report-*.html`.
2. **Bring them in:** `cp` each source into `/Users/toddprice/dscout-knowledge/artifacts/`, preserving its filename, plus any same-stem `.pdf` sibling. With `--move`, use `mv` instead.
   - Skip `index.html` and `build_index.py` if a glob catches them.
   - If a destination filename already exists, **don't clobber** — report the collision and skip it.
3. **Rebuild:** `/usr/bin/python3 ~/dscout-knowledge/artifacts/build_index.py`.
4. **Open the catalog:** `open /Users/toddprice/dscout-knowledge/artifacts/index.html`.
5. **Report** which files were ingested and how many reports the catalog now holds.

Ingested files keep their original markup — they don't need the `report-*` meta tags. The builder falls back to `<title>`, then the date in the filename, then file mtime. To give a legacy file a nicer title/description/date in the catalog, add an entry to `index.overrides.json` rather than editing the file.

## Voice for narrative sections

Use Todd's voice. Defer to `speak-as-todd` if available. Tight, declarative, no preamble. If something's a guess, mark it (`probably`, `from what I can tell`).

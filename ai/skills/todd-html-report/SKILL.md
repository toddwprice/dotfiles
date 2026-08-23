---
name: todd-html-report
allowed-tools: Bash(mkdir:*), Bash(open:*), Bash(date:*), Bash(ls:*), Bash(cp:*), Bash(mv:*), Bash(/usr/bin/python3:*), Bash(/Applications/Google Chrome.app/Contents/MacOS/Google Chrome:*), Write, Read, Agent
description: Answer a question (diagram, SQL result, subsystem story, comparison) and render it as a self-contained HTML page in the shared `artifacts/` catalog, auto-refreshing an `index.html` table of every report, then open it. Use when Todd wants a shareable visual artifact out of an answer, analysis, diagram, or query result — phrasings like "create an HTML doc for this so I can share it with colleagues", "make a shareable HTML page of this", "turn this into HTML I can send", "render this as HTML", or "update/refresh the existing HTML report/diagram". Pass the topic/question as $ARGUMENTS; append `--pdf` for a Mermaid-aware PDF sibling, or `--ingest <paths…>` to fold previously-created HTML reports into the catalog. Composes with dscout-knowledge, dscout-data-mcp:query-prod, and Mermaid for diagrams.
---

You are producing a self-contained HTML report that answers a question or tells a visual story. The report opens in a browser when done.

**This command is autonomous. Do NOT ask clarifying questions** — pick a reasonable shape and ship it; Todd will redirect if the shape is wrong.

**Work in parallel wherever steps don't depend on each other** — gather (Step 2) via concurrent subagents, and overlap the optional PDF render (Step 4) with the catalog refresh and opening the HTML. Keep synthesis, narrative voice, and Mermaid correctness with you, the primary model — only delegate bounded, mechanical retrieval to faster models or specialist agents. Parallelism should never change what ends up in the report, only how fast it lands.

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

- `--pdf` — set `WANT_PDF=1`. Render a PDF sibling in Step 4, overlapped with the catalog refresh rather than after it.
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

**One bounded source** (a named file, a supplied SQL query, a specific known path) → just gather it yourself inline. A subagent's spin-up cost isn't worth paying for a single direct lookup.

**Two or more independent sources** → dispatch one subagent per source, all in a **single message** (multiple Agent tool calls together — this is what makes them run concurrently instead of one after another). Match each subagent's agent type and model to how mechanical the task is:

- Bounded, mechanical retrieval (read a known file, run a given query verbatim, grep for a specific symbol, "where does X live") → a narrow specialist where one fits (`dev-flow:codebase-locator` for locating things, `dev-flow:codebase-analyzer` for tracing how something works, `dev-flow:docs-researcher` for external docs) or `general-purpose` otherwise, with `model: "haiku"`. This is extraction, not judgment — the fastest model is sufficient and costs nothing in quality.
- Open-ended or judgment-heavy gathers (interpreting ambiguous docs, exploring an unfamiliar subsystem, reconciling conflicting sources) → leave `model` unset so it inherits the parent's full-strength model.

Merge and synthesize the results yourself once every subagent returns — that judgment call, and the narrative voice built on top of it, stays with you.

## Step 3 — Render

Write the report to `/Users/toddprice/dscout-knowledge/artifacts/report-<slug>-YYYY-MM-DD-HHMM.html`. The slug is a kebab-case summary of `$ARGUMENTS` (≤40 chars). The directory already exists; `mkdir -p` it if not.

**Use the shared base shell — copy it verbatim, then add report-specific CSS in the marked slot:**

```
~/.claude/skills/_shared/report-shell.html
```

It carries the canonical typography + palette (the "same visual language" shared with the standup and
the other artifact skills, so a restyle lands in one place) and the doctype/head/body skeleton. On
top of the copied shell:

- Fill the `<title>` and **the three required `report-*` meta tags** — they populate the
  `index.html` catalog. Keep `report-description` to one tight line (≤140 chars, distinct from the title).
- Add any report-specific CSS (KPI tiles, cards, bar rows) below the `/* skill-specific */` marker.
- Drop the Mermaid `<script>` if the report has no diagrams.
- Body opens with `<h1>` + a `<div class="meta">Generated <date> · <one-line context></div>`.

Rules for content:
- Mermaid blocks go in `<div class="mermaid">...</div>`. Test mentally for syntax — Mermaid silently fails on bad arrows.
- For tables, include the SQL or source in a collapsed `<details>` block at the bottom so Todd can audit it.
- Hyperlink Linear IDs (`https://linear.app/dscout/issue/<ID>`) and PR numbers (`https://github.com/dscout/monorepo/pull/<num>`) when they appear.
- Drop the Mermaid `<script>` tag if there are no diagrams — keep the file lean.

## Step 4 — Refresh the catalog, open, and render PDF (concurrently)

None of these three depend on each other, so don't run them one after another. The PDF render is the slow part — Chrome needs its `--virtual-time-budget` just to let Mermaid finish drawing — so it should be rendering in the background while the rest wraps up, not blocking it.

1. **If `WANT_PDF=1`, start the PDF render first, as a background Bash call** (`run_in_background: true`), so it's already running while you do the catalog refresh and open below:

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

2. **Without waiting on the PDF job**, rebuild the catalog and open the HTML:

    ```bash
    /usr/bin/python3 ~/dscout-knowledge/artifacts/build_index.py
    open /Users/toddprice/dscout-knowledge/artifacts/<report-file>.html
    ```

    This rescans `artifacts/` and rewrites `index.html` from each report's meta tags — idempotent and fast. If the builder is somehow missing (e.g. a fresh clone that hasn't pulled), note it but don't fail; the report itself is already written.

3. **If you started a PDF job**, wait for it to finish, then `open <pdf-path>` so it lands in Preview alongside the browser tab.

## Step 5 — Report

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

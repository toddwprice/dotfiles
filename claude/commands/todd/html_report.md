---
allowed-tools: Bash(mkdir:*), Bash(open:*), Bash(date:*), Write, Read, Agent
description: Answer a question (diagram, SQL result, subsystem story, comparison) and render it as a self-contained HTML page in .claude/tmp/, then open it. Pass the topic/question as $ARGUMENTS. Composes with dscout-knowledge, dscout-data-mcp:query-prod, and Mermaid for diagrams.
---

You are producing a self-contained HTML report that answers a question or tells a visual story. The report opens in a browser when done.

**This command is autonomous. Do NOT ask clarifying questions** — pick a reasonable shape and ship it; Todd will redirect if the shape is wrong.

Arguments: `$ARGUMENTS` is the question, topic, or instruction. Examples Todd has used in the past:
- *"high level network diagram of our infrastructure"*
- *"diagrams in HTML that tell the story of how media processing works in the platform"*
- *"run this sql against my localhost database and format the result as HTML"*
- *"comparison table of mission_drafts vs study_templates schemas"*

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

Write the report to `.claude/tmp/report-<slug>-YYYY-MM-DD-HHMM.html`. The slug is a kebab-case summary of `$ARGUMENTS` (≤40 chars). Create the directory if missing.

Use this base shell — same visual language as the standup so the look is consistent:

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title><report title></title>
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

## Step 4 — Open and report

After writing the file:

```
open <path>
```

Then tell Todd, in one line, where it landed and what shape you picked. Example: *"Wrote `.claude/tmp/report-media-processing-2026-05-18-1432.html` — narrative + 3 Mermaid flow diagrams. Opened in browser."*

## Voice for narrative sections

Use Todd's voice. Defer to `speak-as-todd` if available. Tight, declarative, no preamble. If something's a guess, mark it (`probably`, `from what I can tell`).

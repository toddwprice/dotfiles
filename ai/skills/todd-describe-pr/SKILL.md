---
name: todd-describe-pr
allowed-tools: Bash(gh pr view:*), Bash(gh pr diff:*), Bash(gh pr checks:*), Bash(gh pr list:*), Bash(gh api:*), Bash(mkdir:*), Bash(open:*), Bash(date:*), Write, Read, Agent
description: Render a PR as a self-contained HTML artifact — verdict banner, key-numbers row, narrative summary, full diff, severity-coded annotation cards beneath each file, optional side-by-side prompt diff and comparison-table panels, and a Q&A section — to help Todd manually review or to compose with `/todd-pr-review`. Pass the PR number as $ARGUMENTS. Does NOT post anything to GitHub; this is a visualization to support a human review, not an autonomous verdict.
---

You are producing a self-contained HTML page that lets Todd review a pull request visually. The page renders the actual diff with **severity-coded annotation cards** placed beneath each file's diff, plus a verdict banner, an at-a-glance stat row, a narrative summary, and (when relevant) specialized panels for prompt diffs, term-list comparisons, and self-answered Q&A. It opens in the browser when done.

This command is **autonomous and visual** — its job is to *describe* the PR so Todd can review it, not to publish a verdict. If Todd wants the autonomous-verdict flow, that's `/todd-pr-review`. Do **not** post comments or reviews from this command.

Arguments: `$ARGUMENTS` is a PR number (e.g. `25604`). If empty, default to the PR for the current branch (`gh pr view --json number -q .number`).

## Step 1 — Gather

Run these in parallel:

```
gh pr view <N> --json number,title,body,author,baseRefName,headRefName,additions,deletions,changedFiles,files,labels,url,isDraft,state,createdAt
gh pr diff <N>
gh pr checks <N>
```

Also pull existing review threads:

```
gh api repos/{owner}/{repo}/pulls/<N>/comments --paginate \
  --jq '.[] | {id, in_reply_to_id, path, line, original_line, body: (.body[:240]), user: .user.login, created_at}'
```

Group comments into threads by root id. Note path + line for each thread.

If the diff is very large (>2000 lines or >25 files), dispatch sub-agents in parallel to analyze chunks of files, then merge findings.

## Step 2 — Annotate

> **Pre-supplied findings (composition seam).** If the caller has already done analysis and is supplying findings (this is how `/todd-pr-review` composes with this command — see its Step 7), **skip the fresh analysis below** and use the supplied findings directly. The schema is the same. Move straight to Step 3.

Walk the diff and attach findings to the **file** they relate to (annotations are placed beneath each file's diff, so per-line precision isn't required — the annotation body can reference a specific line by number for readers who want to look). Lean on the heuristics in `/todd-pr-review`'s checklist, but be **selective**: this is a visual review aid, not a comment dump.

Each finding has:

- **severity** — one of `blocking`, `non-blocking`, `positive`, `context`, `clean`
- **file** — the file the annotation belongs to (annotations render after that file's diff). For PR-wide observations that don't belong to one file, use `file: "(general)"` and they render in a "General notes" panel above the file diffs.
- **title** — 3–8 words; becomes the bold line after the tag chip
- **body** — 1–4 sentences in Todd's voice. Markdown allowed. Reference specific lines with `code` formatting (e.g. <code>document_extraction.py:186</code>).

### Severity vocabulary

| Severity      | Use for | Color |
|---------------|---------|-------|
| `blocking`    | Confirmed bug, security issue, cross-service contract mismatch, anything that should stop the merge | red |
| `non-blocking`| Observations worth surfacing but not gating the merge — nits, minor refactors, ambiguities | amber |
| `positive`    | Genuine craft worth calling out — clean shape, smart reuse, good blast-radius containment | green |
| `context`     | Verified-fact callouts that bound the change (e.g. "sole call site", "only two versions exist", "no other consumers") — color the diff with reassurance, not opinion | blue |
| `clean`       | Used in the legend chip row to indicate "no regression risk" zones; rarely a standalone annotation | gray |

**Hard rules:**

- **Don't re-annotate existing GitHub threads** on the same (file, line). Instead, mention the thread inline in the body of a `context` annotation: *"Existing thread on this line discusses X — see PR comments."*
- **Aim low for blocking, generous for context/positive.** A clean PR with 2 positives and 3 contexts is more useful than the same PR with 5 contrived non-blockings.
- **Don't flag scope violations.** Intentional subsets are normal.

## Step 3 — Render

Write to `.claude/tmp/pr-<N>-<slug>-YYYY-MM-DD-HHMM.html` where `<slug>` is a kebab-case of the PR title (≤40 chars). Create the directory if missing. (A composing skill may override this output dir — `todd-pr-review` writes review artifacts to `~/reviews/`; `todd-sync-review` looks in both `~/reviews` and `.claude/tmp`. When composed, honor the caller's chosen dir.)

### Section menu

The page is a single self-contained HTML file with these sections (in order). **All are optional except the PR header and at least one file diff** — pick what the PR justifies.

1. **PR header** — title, #num, author, branch, Linear ticket if findable, labels, file count, +/-, link to GitHub. (Required)
2. **Verdict banner** — only if the caller (or you) is making a verdict call. Color matches the verdict tier. Skip for standalone `describe_pr` runs unless you're confident; render it for `pr_review` composition.
3. **Stat row** — 3–5 KPI-style cards surfacing the most important numbers for *this* PR. These are bespoke — pick numbers the reader actually wants to see (e.g. "2 layers fixed", "3 session repros", "0 → 1 new prompt section", "15 / 13 term-list asymmetry"). Skip if nothing interesting to surface.
4. **Findings legend** — colored chip row showing severity counts. Always render if there are any findings.
5. **Narrative** — left-bordered callout box, 1–3 paragraphs, explaining what the PR fixes / does and how it does it. Use the PR body as raw material but rewrite in Todd's voice — preserve key terms, drop boilerplate. Required for any PR worth describing in detail.
6. **General notes** — for findings with `file: "(general)"`. Skip if none.
7. **Per-file sections** — for each changed file: file header → diff body → annotations beneath. (Required, at least one file.)
8. **Prompt diff panel** *(optional)* — side-by-side before/after when the PR changes a prompt. Use when a Braintrust prompt version, system prompt string, or tool docstring is the main thing changing.
9. **Comparison table** *(optional)* — when the PR creates an obvious comparison worth showing as a table (e.g. term-list asymmetry between two prompts, before/after config values, schema-vs-API field mismatch).
10. **Self-answered questions (Q&A)** *(optional)* — for `pr_review` composition. Each entry is a card with question + Answer + "How I checked" (the evidence/rationale layer — kept in the HTML artifact, not the posted comment).
11. **Positive callouts** *(optional)* — for `pr_review` composition or when there's genuinely standout work worth a separate section beyond the per-file `positive` annotations.
12. **Footer** — generation timestamp + one-line provenance.

### Template

Use this HTML shell. The CSS is the **deliverable look** — don't deviate without reason. Drop sections you're not using; keep the ones you are. Its base typography + palette match the shared shell at `~/.claude/skills/_shared/report-shell.html` (the single source of truth for the common look across Todd's artifacts); the diff-render / annotation-card / verdict-banner CSS below is describe_pr-specific and layers on top — keep the shared tokens aligned with that file rather than diverging the palette.

```html
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>PR #<N> — <title></title>
<style>
  :root { color-scheme: light; }
  * { box-sizing: border-box; }
  body {
    font: 15px/1.55 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    max-width: 1180px;
    margin: 2rem auto;
    padding: 0 1.25rem 4rem;
    color: #1f2328;
    background: #fff;
  }
  a { color: #0969da; text-decoration: none; }
  a:hover { text-decoration: underline; }

  /* PR header */
  .pr-header {
    border: 1px solid #d0d7de; border-radius: 8px;
    padding: 1.25rem 1.5rem; margin-bottom: 1.5rem;
    background: linear-gradient(180deg, #fff 0%, #f6f8fa 100%);
  }
  .pr-title { display: flex; align-items: baseline; gap: 0.5rem; flex-wrap: wrap; margin: 0 0 0.6rem; }
  .pr-title h1 { margin: 0; font-size: 1.35rem; font-weight: 600; line-height: 1.3; }
  .pr-num { color: #57606a; font-weight: 400; }
  .pr-meta { color: #57606a; font-size: 0.85rem; display: flex; flex-wrap: wrap;
             gap: 0.4rem 1rem; margin-bottom: 0.75rem; }
  .pr-meta strong { color: #1f2328; font-weight: 600; }
  .label-pill { display: inline-block; padding: 1px 8px; border-radius: 999px;
                background: #ededed; color: #1f2328; font-size: 0.75rem; }
  .pr-stats { display: flex; gap: 1.5rem; flex-wrap: wrap; padding-top: 0.75rem;
              border-top: 1px dashed #d0d7de; color: #57606a; font-size: 0.85rem; }
  .pr-stats .add { color: #1a7f37; font-weight: 600; }
  .pr-stats .rm { color: #cf222e; font-weight: 600; }

  /* Verdict banner */
  .verdict { display: flex; align-items: center; gap: 1rem;
             padding: 1rem 1.5rem; border-radius: 8px; margin-bottom: 2rem; }
  .verdict.approve         { border: 1px solid #6fdd8b; background: #dafbe1; }
  .verdict.changes         { border: 1px solid #ff8182; background: #ffebe9; }
  .verdict.clarification   { border: 1px solid #d4a72c; background: #fff8c5; }
  .verdict-icon { width: 38px; height: 38px; border-radius: 50%; color: #fff;
                  display: grid; place-items: center; font-size: 1.3rem; font-weight: 700;
                  flex-shrink: 0; }
  .verdict.approve       .verdict-icon { background: #1a7f37; }
  .verdict.changes       .verdict-icon { background: #cf222e; }
  .verdict.clarification .verdict-icon { background: #bf8700; }
  .verdict-text { font-weight: 600; font-size: 1.1rem; }
  .verdict-sub { color: #57606a; font-size: 0.85rem; margin-top: 0.1rem; }

  /* Stat row */
  .stat-row { display: grid; grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
              gap: 0.75rem; margin-bottom: 2rem; }
  .stat { border: 1px solid #d0d7de; border-radius: 6px; padding: 0.75rem 1rem; background: #fff; }
  .stat-value { font-size: 1.4rem; font-weight: 600; color: #1f2328; }
  .stat-label { color: #57606a; font-size: 0.78rem; text-transform: uppercase; letter-spacing: 0.04em; }

  /* Section headers */
  h2 { font-size: 0.85rem; text-transform: uppercase; letter-spacing: 0.06em;
       color: #57606a; margin: 2.25rem 0 0.75rem;
       border-bottom: 1px solid #d0d7de; padding-bottom: 0.4rem; }
  h3 { font-size: 1rem; margin: 1.5rem 0 0.5rem; color: #1f2328; }

  /* Legend chips */
  .legend { display: flex; flex-wrap: wrap; gap: 0.6rem; margin-bottom: 1.5rem; }
  .legend-chip { display: inline-flex; align-items: center; gap: 0.4rem;
                 padding: 0.25rem 0.7rem; border-radius: 999px; font-size: 0.78rem;
                 font-weight: 500; border: 1px solid; }
  .legend-chip .dot { width: 8px; height: 8px; border-radius: 50%; }
  .sev-blocking { background: #ffebe9; border-color: #ff8182; color: #82071e; }
  .sev-blocking .dot { background: #cf222e; }
  .sev-nonblock { background: #fff8c5; border-color: #d4a72c; color: #633c01; }
  .sev-nonblock .dot { background: #bf8700; }
  .sev-positive { background: #dafbe1; border-color: #6fdd8b; color: #0a3622; }
  .sev-positive .dot { background: #1a7f37; }
  .sev-context  { background: #ddf4ff; border-color: #54aeff; color: #0a3069; }
  .sev-context  .dot { background: #0969da; }
  .sev-clean    { background: #f6f8fa; border-color: #d0d7de; color: #57606a; }
  .sev-clean    .dot { background: #57606a; }

  /* Narrative box */
  .narrative { background: #f6f8fa; border-left: 4px solid #0969da;
               padding: 0.9rem 1.2rem; border-radius: 0 6px 6px 0; margin-bottom: 1.5rem; }
  .narrative p { margin: 0 0 0.5rem; }
  .narrative p:last-child { margin-bottom: 0; }

  /* Diff */
  .diff-file { border: 1px solid #d0d7de; border-radius: 6px; margin-bottom: 1.5rem; overflow: hidden; }
  .diff-filename { background: #f6f8fa; padding: 0.6rem 1rem;
                   border-bottom: 1px solid #d0d7de;
                   font: 13px/1.4 ui-monospace, SFMono-Regular, Menlo, monospace;
                   color: #1f2328; display: flex; justify-content: space-between; align-items: center; }
  .diff-filename .file-stats { color: #57606a; font-size: 0.78rem; }
  .diff-filename .file-stats .add { color: #1a7f37; font-weight: 600; }
  .diff-filename .file-stats .rm  { color: #cf222e; font-weight: 600; }
  .diff-body { font: 12.5px/1.5 ui-monospace, SFMono-Regular, Menlo, monospace; }
  .diff-row { display: grid; grid-template-columns: 50px 50px 1fr; border-bottom: 1px solid transparent; }
  .diff-row.hunk { background: #ddf4ff; color: #0a3069; padding: 0.15rem 0; }
  .diff-row.hunk .ln { color: #0a3069; }
  .diff-row.context { background: #fff; }
  .diff-row.added   { background: #e6ffec; }
  .diff-row.added   .ln { background: #ccffd8; color: #1a7f37; }
  .diff-row.removed { background: #ffebe9; }
  .diff-row.removed .ln { background: #ffdcd7; color: #cf222e; }
  .ln { text-align: right; padding: 0.05rem 0.6rem; color: #8c959f; user-select: none;
        border-right: 1px solid #d0d7de; font-size: 11.5px; }
  .code { padding: 0.05rem 0.75rem; white-space: pre; overflow-x: auto; }

  /* Annotation card (full-width, lives between diff blocks) */
  .annot { border-left: 4px solid; background: #fff;
           margin: 0.5rem 0 0.5rem 50px;
           padding: 0.85rem 1.15rem;
           font: 15px/1.65 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
           border-radius: 0 6px 6px 0; box-shadow: 0 1px 2px rgba(0,0,0,0.04); }
  .annot.blocking { background: #fff5f5; border-color: #cf222e; }
  .annot.nonblock { background: #fffbe6; border-color: #d4a72c; }
  .annot.positive { background: #ebfff0; border-color: #1a7f37; }
  .annot.context  { background: #f0f8ff; border-color: #0969da; }
  .annot-header { display: flex; align-items: center; gap: 0.5rem; font-weight: 600;
                  margin-bottom: 0.4rem; font-size: 1.02rem; }
  .annot-tag { padding: 2px 8px; border-radius: 3px; font-size: 0.78rem;
               font-weight: 600; text-transform: uppercase; letter-spacing: 0.03em; color: #fff; }
  .annot.blocking .annot-tag { background: #cf222e; }
  .annot.nonblock .annot-tag { background: #d4a72c; }
  .annot.positive .annot-tag { background: #1a7f37; }
  .annot.context  .annot-tag { background: #0969da; }
  .annot p { margin: 0 0 0.5rem; }
  .annot p:last-child { margin-bottom: 0; }
  .annot code { font: 13.5px/1.5 ui-monospace, SFMono-Regular, Menlo, monospace;
                background: rgba(0,0,0,0.06); padding: 1px 4px; border-radius: 3px; }
  .annot .label { color: #57606a; font-weight: 600; font-size: 0.82rem;
                  text-transform: uppercase; letter-spacing: 0.04em; margin-right: 0.4rem; }

  /* Prompt diff (side-by-side) */
  .prompt-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; margin: 1rem 0; }
  .prompt-card { border: 1px solid #d0d7de; border-radius: 6px; overflow: hidden; }
  .prompt-head { background: #f6f8fa; border-bottom: 1px solid #d0d7de;
                 padding: 0.5rem 0.85rem;
                 font: 12.5px/1.4 ui-monospace, SFMono-Regular, Menlo, monospace;
                 display: flex; justify-content: space-between; align-items: center; }
  .prompt-head .hash { color: #57606a; }
  .prompt-head.old { background: #ffeef0; border-bottom-color: #ffdcd7; }
  .prompt-head.new { background: #e6ffec; border-bottom-color: #ccffd8; }
  .prompt-body { padding: 0.75rem 0.85rem;
                 font: 12px/1.5 ui-monospace, SFMono-Regular, Menlo, monospace;
                 white-space: pre-wrap; color: #1f2328;
                 max-height: 560px; overflow-y: auto; }
  .prompt-body .hl-new { background: #ffeaa7; padding: 1px 0; border-radius: 2px;
                         display: block; border-left: 3px solid #d4a72c;
                         padding-left: 6px; margin: 2px -6px; }
  .prompt-body .hl-changed { background: #c8e6c9; padding: 1px 4px; border-radius: 2px; }
  .prompt-summary { border: 1px solid #d0d7de; border-radius: 6px;
                    padding: 1rem 1.25rem; background: #f6f8fa; margin: 1.25rem 0; }
  .prompt-summary ul { margin: 0.4rem 0 0; padding-left: 1.4rem; }
  .prompt-summary li { margin-bottom: 0.25rem; }
  .prompt-summary li .clean { color: #1a7f37; font-weight: 600; }
  .prompt-summary li .changed { color: #bf8700; font-weight: 600; }

  /* Comparison table */
  .cmp-table { width: 100%; border-collapse: separate; border-spacing: 0;
               border: 1px solid #d0d7de; border-radius: 6px; overflow: hidden;
               margin: 1rem 0; font-size: 0.92rem; }
  .cmp-table th, .cmp-table td { padding: 0.55rem 0.85rem; text-align: left;
                                  border-bottom: 1px solid #eaeef2; }
  .cmp-table th { background: #f6f8fa; font-weight: 600; color: #1f2328; font-size: 0.85rem; }
  .cmp-table tr:last-child td { border-bottom: none; }
  .cmp-table td.term { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 0.88rem; }
  .cmp-table tr.asymmetric { background: #fffbe6; }
  .cmp-table tr.asymmetric td.term { font-weight: 600; }
  .check { color: #1a7f37; font-weight: 700; }
  .cross { color: #cf222e; font-weight: 700; }
  .cmp-note { color: #57606a; font-size: 0.85rem; font-style: italic; }

  /* Q&A section */
  .qa { border: 1px solid #d0d7de; border-radius: 6px; margin-bottom: 1rem; overflow: hidden; }
  .qa-head { padding: 0.8rem 1.1rem; background: #f6f8fa;
             border-bottom: 1px solid #d0d7de;
             display: flex; align-items: center; gap: 0.6rem; font-weight: 600; }
  .qa-body { padding: 0.9rem 1.1rem; }
  .qa-body p { margin: 0 0 0.6rem; }
  .qa-body p:last-child { margin-bottom: 0; }
  .qa-body .label { color: #57606a; font-weight: 600; font-size: 0.82rem;
                    text-transform: uppercase; letter-spacing: 0.04em; margin-right: 0.4rem; }

  /* Footer */
  .footer { color: #57606a; font-size: 0.78rem; font-style: italic;
            margin-top: 3rem; padding-top: 1rem; border-top: 1px solid #d0d7de; text-align: center; }
</style>
</head>
<body>

<!-- PR HEADER (required) -->
<div class="pr-header">
  <div class="pr-title">
    <h1><PR title></h1>
    <span class="pr-num">#<N></span>
  </div>
  <div class="pr-meta">
    <span><strong>Author:</strong> <a href="https://github.com/<login>">@<login></a> (<display name if known>)</span>
    <span><strong>Branch:</strong> <code><head></code> → <code><base></code></span>
    <!-- optional, if Linear ticket discoverable from title or body: -->
    <span><strong>Linear:</strong> <a href="https://linear.app/dscout/issue/<ID>"><ID></a></span>
    <!-- labels: one .label-pill per label -->
    <span><strong>Label:</strong> <span class="label-pill"><label></span></span>
  </div>
  <div class="pr-stats">
    <span><strong>Files changed:</strong> <count></span>
    <span><span class="add">+<additions></span> / <span class="rm">−<deletions></span></span>
    <span><a href="<url>">View on GitHub →</a></span>
  </div>
</div>

<!-- VERDICT (optional) — class is one of: approve, changes, clarification -->
<div class="verdict approve">
  <div class="verdict-icon">✓</div>
  <div>
    <div class="verdict-text">Approve</div>
    <div class="verdict-sub"><one-line context: blocking/non-blocking count, key verification></div>
  </div>
</div>

<!-- STAT ROW (optional) — pick the actual numbers worth surfacing -->
<div class="stat-row">
  <div class="stat"><div class="stat-value"><n></div><div class="stat-label"><label></div></div>
  <!-- 2–5 cards total -->
</div>

<!-- LEGEND (render if findings > 0) -->
<h2>Findings legend</h2>
<div class="legend">
  <span class="legend-chip sev-blocking"><span class="dot"></span>Blocking · <count></span>
  <span class="legend-chip sev-nonblock"><span class="dot"></span>Non-blocking · <count></span>
  <span class="legend-chip sev-positive"><span class="dot"></span>Positive · <count></span>
  <span class="legend-chip sev-context"><span class="dot"></span>Context · <count></span>
  <!-- include sev-clean only when you want to call out a "no regression risk" zone -->
</div>

<!-- NARRATIVE -->
<h2>What this PR <fixes|does|adds></h2>
<div class="narrative">
  <p><1–3 paragraphs in Todd's voice. Tight. Preserve domain terms.></p>
</div>

<!-- GENERAL NOTES (optional) — for findings with file = "(general)" -->
<!-- Same .annot.* markup, placed before per-file sections -->

<!-- PER-FILE SECTION (repeat for each file) -->
<h2>File <i> · <code><basename></code></h2>
<div class="diff-file">
  <div class="diff-filename">
    <span><full path></span>
    <span class="file-stats"><span class="add">+<a></span> <span class="rm">−<d></span></span>
  </div>
  <div class="diff-body">
    <div class="diff-row hunk"><div class="ln">@@</div><div class="ln"></div><div class="code">@@ -<a>,<b> +<c>,<d> @@ <function context></div></div>
    <div class="diff-row context"><div class="ln"><old></div><div class="ln"><new></div><div class="code"><HTML-escaped line></div></div>
    <div class="diff-row removed"><div class="ln"><old></div><div class="ln">−</div><div class="code"><line></div></div>
    <div class="diff-row added"><div class="ln">+</div><div class="ln"><new></div><div class="code"><line></div></div>
    <!-- ... -->
  </div>
</div>

<!-- Annotations for this file, stacked beneath the diff -->
<div class="annot positive">
  <div class="annot-header"><span class="annot-tag">Positive</span> <title></div>
  <p><body — reference line numbers in <code> if useful></p>
</div>
<div class="annot context">
  <div class="annot-header"><span class="annot-tag">Context</span> <title></div>
  <p><body></p>
</div>
<!-- ... -->

<!-- PROMPT DIFF (optional) — when a prompt is the main thing changing -->
<h2>Prompt diff · <code><prompt-slug></code></h2>
<div class="prompt-summary">
  <strong>What changed</strong>
  <ul>
    <li><span class="changed">Section X added/changed</span> — <description></li>
    <li><span class="clean">Sections Y byte-identical</span> — <reassurance></li>
  </ul>
</div>
<div class="prompt-grid">
  <div class="prompt-card">
    <div class="prompt-head old"><span><strong>Before</strong></span><span class="hash"><version-hash></span></div>
    <div class="prompt-body"><before prompt text, HTML-escaped, with optional <span class="hl-changed"> on small inline edits></div>
  </div>
  <div class="prompt-card">
    <div class="prompt-head new"><span><strong>After (this PR)</strong></span><span class="hash"><version-hash></span></div>
    <div class="prompt-body"><after prompt text; use <span class="hl-new"> on block-level additions, <span class="hl-changed"> on small inline edits></div>
  </div>
</div>

<!-- COMPARISON TABLE (optional) -->
<h2><table topic></h2>
<p style="color:#57606a; font-size:0.9rem;"><one-sentence framing></p>
<table class="cmp-table">
  <thead><tr><th><col1></th><th style="text-align:center;"><col2></th><th style="text-align:center;"><col3></th><th>Notes</th></tr></thead>
  <tbody>
    <tr><td class="term"><term></td><td style="text-align:center;"><span class="check">✓</span></td><td style="text-align:center;"><span class="check">✓</span></td><td class="cmp-note">aligned</td></tr>
    <tr class="asymmetric"><td class="term"><term></td><td style="text-align:center;"><span class="check">✓</span></td><td style="text-align:center;"><span class="cross">✗</span></td><td class="cmp-note"><why it's asymmetric, what to do></td></tr>
  </tbody>
</table>

<!-- SELF-ANSWERED QUESTIONS (optional, for pr_review composition) -->
<h2>Self-answered questions</h2>
<div class="qa">
  <div class="qa-head">
    <span class="legend-chip sev-nonblock"><span class="dot"></span>Non-blocking</span>
    <span>Q<N> — <question text></span>
  </div>
  <div class="qa-body">
    <p><span class="label">Answer</span><sub-agent answer verbatim></p>
    <p><span class="label">How I checked</span><sub-agent rationale/evidence verbatim></p>
  </div>
</div>

<!-- POSITIVE CALLOUTS (optional) -->
<h2>Positive callouts</h2>
<div class="qa">
  <div class="qa-head">
    <span class="legend-chip sev-positive"><span class="dot"></span>Positive</span>
    <span><title></span>
  </div>
  <div class="qa-body"><p><body></p></div>
</div>

<div class="footer">
  Generated <YYYY-MM-DD> · <one-line provenance, e.g. "Visualization via /todd-describe-pr">
</div>

</body>
</html>
```

### Rendering rules

**Escape carefully.** HTML-escape every character of code (`<`, `>`, `&`, `"`) before placing it inside `<div class="code">` or `<div class="prompt-body">`. The example file does this. Inside `prompt-body` you may also wrap block additions in `<span class="hl-new">…</span>` and inline edits in `<span class="hl-changed">…</span>` — those need to remain literal tags, so only escape the *content* between them.

**Line numbers.** Use the diff's old/new line numbers. For added lines, put `+` in the old-line cell; for removed lines, put `−` in the new-line cell; for context lines, fill both. Hunk header rows put `@@` in *both* line cells and the hunk text in the code cell.

**Per-file structure.** One `<h2>File <i> · <code><basename></code></h2>` then one `<div class="diff-file">` then any number of `<div class="annot …">` cards for that file. The 50px left margin on `.annot` aligns the annotation's left edge with the start of the code column in the diff above — it's visual continuity.

**Hunk granularity.** For long files, render *all* hunks back-to-back inside the same `.diff-file`. Don't compress or summarize hunks; if the file is genuinely huge (>500 changed lines), collapse it inside `<details><summary>Diff (<n> lines)</summary>…</details>` and render annotations outside the `<details>` so they're always visible.

**Binary / generated files.** Render the filename header with a small note in the code area: *"Binary file · <size>"* or *"Generated · skipped"*. Don't try to render contents.

**Stat row is bespoke.** Don't render generic stats here (additions/deletions are already in the PR header). Pick numbers a reader *cares* about for this specific PR. If you can't think of any, drop the section.

**Verdict tier mapping** (for `.verdict` class):

| Verdict | Class | Icon |
|---|---|---|
| Approve | `approve` | `✓` |
| Request Changes | `changes` | `!` |
| Request Clarification | `clarification` | `?` |

**General notes panel.** For findings with `file: "(general)"`, render them as `<div class="annot …">` cards directly under the legend, with an `<h2>General notes</h2>` heading. Same markup as per-file annotations.

**When a section is empty, drop it entirely.** Don't render `<h2>Self-answered questions</h2>` followed by nothing — just skip the heading.

### Large PRs

If the diff has > 50 files or > 5000 changed lines, dispatch one sub-agent per ~10-file chunk to produce the per-file `<div class="diff-file">…</div>` plus its associated annotation cards. Headers, verdict, stat row, narrative, legend, and Q&A still get built centrally so they stay coherent. Concatenate the file chunks in the order they appear in `gh pr view --json files`.

## Step 4 — Open and report

After writing:

```
open <path>
```

Then tell Todd, in one line: where it landed, how many findings of each severity, and any standout call. Examples:

> Wrote `.claude/tmp/pr-25610-detect-oos-question-types-2026-05-19-1432.html` — 2 files, 4 non-blocking + 2 positive + 2 context findings. Approve. Opened in browser.

> Wrote `.claude/tmp/pr-25700-ai-mod-bridge-2026-05-19-0915.html` — 7 files, 1 blocking on `apps/ai_mod/bridge.py:142` worth checking. Opened in browser.

## Voice for annotations and narrative

Use Todd's voice. Defer to the `speak-as-todd` skill if available. Terse, declarative, mechanism-first. State the call directly — no hedging filler. If a finding is non-blocking, say so plainly. If you can't tell from the diff, say "can't tell from the diff — leaning X because Y" rather than fabricating certainty.

For the **narrative** block, the goal is to summarize what the PR does in the smallest number of words that still names every load-bearing piece. Domain terms (function names, file paths, methodology terms) should be preserved verbatim — generalizing them is the opposite of helpful.

For **annotations**, the title is the gist (3–8 words); the body is the mechanism. If a `context` annotation is grounding a fact ("only two versions exist", "sole call site"), name how you verified it (e.g. *"`grep -rn '<slug>'` confirms …"*).

## Boundaries

- **This command does not post to GitHub.** Don't run `gh pr review` or `gh pr comment`. The artifact is for Todd's eyes only.
- **Don't duplicate `/todd-pr-review`.** That command's job is to render a verdict and emit a `gh pr review …` command. This command's job is to *show* the PR in a form that supports review.
- **Don't add features the diff doesn't justify.** If a PR has zero noteworthy findings, render PR header + narrative + file diffs + a tiny "no findings — looks straightforward" line. That's a valid output. Don't manufacture annotations.
- **Don't add stat-row cards just to fill space.** Three real numbers beats five made-up ones. Skip the section if you can't think of three.

Now describe PR #$ARGUMENTS.

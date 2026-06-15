---
name: doc-convert
description: Use when converting documents between formats on macOS — HTML to PDF or PNG, Markdown to PDF, combining/merging PDFs, extracting or parsing text/fields from a PDF, or rendering/verifying Mermaid diagrams in an HTML file. Triggers on "print this html to pdf", "render to pdf and open it", "convert X.html to png at 2x", "markdown to pdf (prefer pandoc)", "combine these pdfs", "extract the text from this pdf so I can grep it", "parse the effective date from this contract pdf", "did the mermaid diagrams render".
---

# doc-convert

## Overview

Document-format conversion on macOS using the local toolchain. **Conversion mechanics only** — does not author new content (see guardrail).

Default output: a sibling next to the source file. For generated reports already in `.claude/tmp/`, write the sibling there. After producing a file, `open` it if Todd said "open it" / "and open it".

## When to use

Symptoms / keywords: html→pdf, html→png, 2x resolution, markdown→pdf, pandoc, combine/merge pdfs, extract text from pdf, grep a pdf, parse a field from a pdf, mermaid not rendering, "did the diagrams render".

## Quick Reference

| Source → Target | Command |
|---|---|
| HTML → PDF (Mermaid-aware) | Chrome headless `--print-to-pdf` (see example) |
| HTML → PNG @2x | Chrome headless `--screenshot --force-device-scale-factor=2 --window-size=W,H` |
| Markdown → PDF (preferred) | `pandoc in.md -o out.pdf` — **pandoc is NOT installed**; `brew install pandoc basictex` first, or fall back: write MD→HTML, then use the HTML→PDF recipe |
| Combine PDFs | `pdfunite a.pdf b.pdf out.pdf` |
| Extract text (to grep) | `pdftotext in.pdf - \| grep ...` (or `pdftotext in.pdf out.txt`) |
| Parse a field | `pdftotext -layout in.pdf -` then read/grep the text |
| Verify Mermaid rendered | render to PDF, then `pdftotext out.pdf -` — node labels present = it rendered |

Verified available: `pdftotext`, `pdfunite`, Google Chrome. NOT installed: `pandoc`, `qpdf`, `mmdc`.

## Worked example: HTML → PDF with Mermaid

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless --disable-gpu --no-pdf-header-footer \
  --virtual-time-budget=10000 \
  --run-all-compositor-stages-before-draw \
  --print-to-pdf="/abs/path/report.pdf" \
  "file:///abs/path/report.html"
# verify Mermaid actually rendered (not blank divs):
pdftotext "/abs/path/report.pdf" - | head
open "/abs/path/report.pdf"
```

This is the same recipe as the `todd:html_report --pdf` path. For PNG@2x, swap `--print-to-pdf=...` for `--screenshot=out.png --force-device-scale-factor=2 --window-size=1200,900`.

## Common mistakes

- **Mermaid prints as blank divs** — converter didn't run JS. You MUST keep `--virtual-time-budget=10000` and `--run-all-compositor-stages-before-draw`; they give the CDN Mermaid script time to render before Chrome snapshots. Never strip them.
- **Broken Mermaid block** — Mermaid fails silently on bad arrows/syntax. Open the HTML in Chrome, read the diagram, fix the syntax in the source, re-render.
- **Reaching for pandoc and erroring** — it isn't installed. Offer the install, or use the MD→HTML→Chrome fallback so the job ships now.
- **`file://` needs an absolute path** — `~` and relative paths won't load.

## When NOT to use / refuse (org policy)

This skill does CONVERSION only. Do **NOT** auto-generate customer-facing or product/feature/roadmap collateral (e.g. "make a pdf brochure / 1-pager describing the dscout id verification product"). For those: check Showpad / Figma slides for existing approved content first; if new collateral is truly needed, the author owns accuracy, completeness, and brand consistency. Redirect — don't generate the content — then convert whatever Todd supplies.

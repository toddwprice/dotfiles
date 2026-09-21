---
name: dscout-mcp-bug-report
description: "File a high-quality bug report or feedback ticket about the Dscout MCP alpha into the Linear \"MCP bug reporting project\" (or, for testers without Linear access, a Notion fallback database). Use this whenever a tester hits a problem, surprising behavior, or rough edge while using the Dscout MCP (in Claude or Figma Make) and wants to capture it — including phrasings like \"log this bug\", \"report this to the MCP team\", \"file this in Linear\", \"this MCP draft was wrong\", \"the dscout connector errored\", \"the study it built is off\", or \"give feedback on the dscout staging MCP\". Also use when a tester is wrapping up an MCP test session and wants to record their overall experience. Proactively offer to file a ticket whenever you notice the tester just hit a Dscout MCP error or expressed frustration with an MCP result, even if they didn't explicitly say \"file a bug\"."
---

# Dscout MCP — File a Bug Report

## Purpose

Dscout is running an internal alpha of its MCP (which lets people draft studies
and pull/analyze data from Dscout inside AI tools like Claude and Figma Make).
The product team learns fastest when testers report what breaks — but only if
reporting is nearly frictionless. People skip filing bugs when it means leaving
their tool, remembering a template, and formatting everything by hand.

This skill removes that friction: you assemble a complete, well-structured
ticket **from the conversation you're already in**, confirm it with the tester,
and file it to Linear for them. The goal is that a tester can just say "log
that" and a good ticket appears.

## Where tickets go

Gather and assemble the report identically in every case — **only the
destination changes.** Route in this order (full logic in Step 4):

1. **Linear (preferred).** Team `MCP Researcher Pod`, project
   `MCP bug reporting project`, via the Linear MCP `save_issue` tool.
   Project URL: https://linear.app/dscout/project/mcp-bug-reporting-project-ea74f3a55822
2. **Notion fallback** — for testers without Linear (mostly CS & Support).
   File the same report as a page in the **MCP Bug Reports (CS/Support
   fallback)** database via the Notion MCP `notion-create-pages` tool.
   Data source: `collection://71b88ac4-de25-4d19-88fe-c281bea3d4a1`
   Database URL: https://app.notion.com/p/7aafb70a011d415fa5c7113b05327d70

The detail captured is exactly the same in both — Notion is not a lighter
report, just a different home for people who can't reach Linear.

## Step 1 — Gather the details (infer first, ask only for gaps)

The single most important behavior: **pull as much as you can from the current
conversation instead of interrogating the tester.** If you just watched the
Dscout MCP throw an error or produce a questionable study, you already know the
client, the prompt, and what happened. Asking the tester to re-type all of that
is exactly the friction that stops bugs from being reported.

Infer from context wherever possible:

- **AI client + model** — e.g. *Claude Desktop · Sonnet 4.6*, *Claude Code*,
  *Figma Make*. You usually know your own client/model; state it. If you truly
  can't tell, ask.
- **What the tester was doing** — the prompt or the step they were on. Quote it.
- **What actually happened** — the error message, the surprising output, or the
  questionable study/screener the MCP produced.
- **Study / mission link** — any `app.dscout.com` URL already in the thread.

Ask the tester only for what you genuinely cannot infer, and ask in one short
batch rather than one question at a time:

- **Expected vs. actual** — if the gap isn't already obvious from context.
- **Severity** — `blocker` / `annoying` / `nice-to-have`.
- **Study link** — only if it's relevant and not already present.

## Step 2 — Capture chat history, a screenshot, and a summary

Three things make these tickets genuinely useful, and the team wants **all
three**:

1. **Chat history (always).** Because you're filing from inside the AI
   conversation, include the relevant exchange as text — the tester's prompt,
   the MCP's tool calls/responses, and the output that looks wrong. Text is
   searchable, quotable, and diffable, which a screenshot alone is not. Trim to
   the relevant turns; don't paste an entire unrelated session.
2. **Screenshot (always).** Also capture a screenshot of the full exchange — the
   prompt, the MCP's response, and anything that looks off. The screenshot and
   the chat history are complementary, not either/or: the log gives the
   verbatim, searchable text; the screenshot shows what the tester actually saw,
   including rendering, layout, and UI state that text can't convey. Since you
   (Claude) can't capture the tester's screen, **ask them for it** and attach it
   to the issue (see Step 4). If they can't grab it right then, still file the
   ticket and remind them to drag the screenshot onto the created issue.
3. **Your summary of the issue.** Write a tight, plain-language summary of what
   went wrong in your own words. This helps the team triage at a glance.

If the tester is wrapping up a session rather than reporting one specific bug,
ask: **"How was your experience using the Dscout staging MCP?"** and include
their answer. (If they prefer, summarize the session's friction points yourself
and confirm with them.) This open reflection often surfaces issues that don't
show up as hard errors.

## Step 3 — Assemble the ticket

Build the title and description before filing. Keep titles specific and
scannable — "MCP drafted a screener with un-recruitable age bands" beats "bug in
screener".

Use this description template:

```
**Client + model:** <e.g. Claude Desktop · Sonnet 4.6 / Figma Make>
**Severity:** <blocker | annoying | nice-to-have>
**Study / mission:** <app.dscout.com link, or "n/a">

### What I was doing
<the prompt or step, quoted>

### Expected
<what the tester expected>

### Actual
<what actually happened — error text or the questionable output>

### Summary
<your plain-language summary of the issue>

### Chat history
<the relevant turns: prompt → MCP tool calls/responses → output>

### Screenshot
<screenshot of the full exchange — attach the image to the issue>

### Experience notes (optional)
<the tester's answer to "how was your experience", if captured>
```

Map severity to Linear priority so triage views sort sensibly:

- `blocker` → priority **2** (High)
- `annoying` → priority **3** (Medium)
- `nice-to-have` → priority **4** (Low)

If you can't infer severity and the tester hasn't said, **default to `annoying`
(Medium)** so the preview is never blocked waiting on an answer — then let the
tester bump it up or down when they review in Step 4. Friction is the enemy; a
ready preview they can adjust beats a question that stalls the report.

Omit the optional **Experience notes** section when it doesn't apply — drop the
header rather than leaving it with "n/a", so the ticket stays clean and
scannable.

## Step 4 — Preview, confirm, then file

Show the assembled title + description to the tester and ask for a quick thumbs
up (and a chance to fix severity or add a detail). Reporting should feel like a
review, not a form.

On confirmation, **route the report**. Walk this order — the assembled title +
description are identical at every branch; only the destination changes:

1. **Linear connected?** If the Linear MCP `save_issue` tool is available in
   this client, file to Linear (the **File to Linear** path below). Done.
2. **Not connected, but the tester has a Linear account?** If `save_issue`
   isn't available, ask: *"Do you have a Dscout Linear account?"* If yes, point
   them to connect the Linear connector (Claude: Settings → Connectors → Linear,
   or `/mcp` in Claude Code; then re-run), and retry step 1. Prefer Linear
   whenever the tester can reach it.
3. **No Linear account, or the connector won't work?** Use the **Notion
   fallback** path below. This is the expected route for most CS & Support
   testers — don't treat it as a last resort or downgrade the detail.

### File to Linear

Call `save_issue` with:

- `team`: `MCP Researcher Pod`
- `project`: `MCP bug reporting project`
- `title`: the title you assembled
- `description`: the filled template (use literal newlines, not `\n`)
- `priority`: from the severity mapping above
- `links`: if a study/mission URL exists, attach it as
  `[{ "url": "<app.dscout.com link>", "title": "Study/mission" }]`

**Attach the screenshot.** If the tester shared a screenshot image in the
conversation, attach it to the issue using Linear's attachment upload flow
(prepare an upload slot, then create the attachment from that upload). If you
can't attach it programmatically in this client, file the issue first and then
tell the tester to drag the screenshot onto the created issue — don't let the
ticket go out without the visual.

Then report back the created issue's identifier and URL so the tester can find
it.

### Notion fallback — tester can't reach Linear

For testers without Linear access, file the **same** report into the **MCP Bug
Reports (CS/Support fallback)** database. Use the Notion MCP `notion-create-pages`
tool with:

- `parent`: `{ "data_source_id": "71b88ac4-de25-4d19-88fe-c281bea3d4a1" }`
- `properties`:
  - `Report`: the title you assembled (same title you'd use for Linear)
  - `Severity`: `blocker` | `annoying` | `nice-to-have`
  - `Status`: `New`
  - `Client + Model`: e.g. `Claude Desktop · Sonnet 4.6`
  - `Study / mission`: the `app.dscout.com` URL, if any (omit otherwise)
  - `Reporter`: the tester's name/email if known (omit otherwise)
- `content`: the **same filled description template** from Step 3, verbatim.
  Every section the team gets in Linear must appear here too — this is just a
  different home, not a lighter report.

**Screenshot:** Notion can't accept a programmatic image attachment the way
Linear can. File the page first, then give the tester the created page URL and
ask them to drag their screenshot into it. Don't skip the screenshot.

Then report back the created page's URL so the tester can find it.

If **neither** Linear nor the Notion connector is available in this client,
don't drop the report: print the fully assembled title + description, and give
the tester both destinations to file it manually — the Linear project
(https://linear.app/dscout/project/mcp-bug-reporting-project-ea74f3a55822) if
they have access, otherwise the Notion database
(https://app.notion.com/p/7aafb70a011d415fa5c7113b05327d70) — and remind them to
attach their screenshot.

## Notes

- This is alpha tooling: log liberally. Don't talk a tester out of filing
  because something seems small or possibly duplicate — the team would rather
  triage a duplicate than miss a signal.
- Never invent details to fill the template. If a field is genuinely unknown,
  write `unknown` rather than guessing — a fabricated repro wastes triage time.
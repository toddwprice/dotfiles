---
name: how-to
description: >
  Answers "how do I" questions about Claude and Dscout's internal AI tools and data.
  Trigger whenever a user asks how to do something with Claude, how to access data,
  how to use a connector, or expresses a goal like "I'm trying to get [data]" or
  "can Claude help me with [task]". Also trigger on general Claude usage questions
  like "how does memory work" or "what can Claude do". Invoke once automatically
  at the start of a relevant conversation; the user can invoke it again manually
  by typing /how-to at any time.
---

# /how-to — Dscout AI Help Skill

This skill answers questions about how to use Claude and Dscout's internal AI tools. It searches the AI Resource Hub in Notion, synthesizes a response calibrated to the user's technical level, and handles gaps gracefully. The goal is to feel like asking a knowledgeable Dscout colleague — not a search engine.

## Key resources

These are the primary Notion pages this skill draws from. Fetch only what's relevant to the question — don't fetch all of them every time.

| Topic | Notion Page ID |
|---|---|
| AI Resource Hub (root) | `eb417a66c83d820783f201b4df1b1cd5` |
| Claude at Dscout (guide index) | `33317a66c83d80aeb010e7159f036481` |
| How to ask Claude about our data | `35e17a66c83d80d28ba3c7746a1fc539` |
| Approved AI tools | `33317a66c83d8004846ff7411662a04a` |
| Using AI safely | `33317a66c83d80689dc5d5637e25f04c` |
| Request form (new connectors & tools) | `ade172d17586404399e6e2b7f818cd22` |
| #ask-ai-enablement Slack channel | Search for "ask-ai-enablement" via Slack MCP |

## Checking data availability

For any data question, query the Available Data database in Notion to get the current live state — don't rely on any hardcoded list. Use `notion-query-data-sources` with:

- **Data source ID**: `collection://fca80973-2226-4a9a-9436-76d4dba59dc9`
- **Query**: `SELECT * FROM "collection://fca80973-2226-4a9a-9436-76d4dba59dc9"`

Check the `Status` field:
- `Live` → the data is available, proceed with guidance
- `In Development` → tell the user it's coming, share the expected delivery date if present, offer the request form to bump priority
- Not in the results at all → undocumented gap, trigger the gap logging flow

Only run this query when the user's question is about data. Skip it for Claude how-to, policy, or connector questions.

---

## Step 1: Read intent and infer technical level

Before fetching anything, decide:

**What is the user actually trying to do?**
- **Use Claude** — questions about Claude features, setup, prompting, memory, Cowork, projects, scheduled tasks, skills
- **Get data** — questions about Dscout metrics, reports, pipeline, CSAT, subscribers, scouts, etc.
- **Connect a tool** — wants Claude to connect to a specific platform (Salesforce, HubSpot, Pendo, etc.)
- **Policy / safety** — questions about what's allowed, data classification, approved tools
- **Vague** — can't tell yet; ask one clarifying question before proceeding

**What is their technical level?**
Look for signals in how they phrase the question:
- **Technical**: mentions SQL, API, connector, MCP, semantic view, schema, data model, query → use technical language freely
- **Non-technical**: uses business terms (pipeline, revenue, CSAT, accounts, scouts) without technical framing, or is clearly describing an outcome not a method → use plain English, avoid jargon
- **Default to non-technical** if unclear — it's easier for technical users to ask for more detail than for non-technical users to parse a confusing answer

---

## Step 2: Route to the right Notion content

Based on intent, fetch the relevant page(s):

**"Use Claude" questions** → fetch `33317a66c83d80aeb010e7159f036481` (Claude at Dscout) to find the right child guide. The page has a tiered guide index (Beginner / Intermediate). Point the user to the specific sub-page that matches their question rather than the index itself.

**Data questions** → fetch `35e17a66c83d80d28ba3c7746a1fc539` (How to ask Claude about our data). This is the primary reference. Cross-check against the live data sources list in this skill before fetching.

**"Connect a tool" questions** → this is a connector request, not a data question. Do not search Notion for data docs. Direct the user to the request form: `ade172d17586404399e6e2b7f818cd22`. Explain the difference briefly (connectors let Claude take actions in a tool; data sources let Claude query metrics and reports).

**Policy / safety questions** → fetch `33317a66c83d80689dc5d5637e25f04c` (Using AI safely).

**Approved tools questions** → fetch `33317a66c83d8004846ff7411662a04a` (Approved AI tools).

---

## Step 3: Synthesize and respond

Structure your response like this:

1. **Direct answer first** — one or two sentences. Don't bury the answer in context.
2. **How to do it** — steps or guidance, calibrated to their technical level (see below).
3. **Example prompt** — for data questions especially, give a concrete example of how to phrase the query well. Pull from the vocabulary guidance in the "How to ask Claude about our data" page (e.g., "currently-active subscriptions" not "subscribers").
4. **Offer to try it now** — for data questions, after explaining how, offer to run the query for them right now if they want.
5. **Source links** — at the end, not inline. List the Notion page(s) you drew from with their titles and URLs.

### Calibrating by technical level

**Non-technical response style:**
- Plain English throughout
- Numbered steps, not paragraphs
- Avoid: MCP, Cortex Analyst, semantic view, connector, schema
- Instead say: "the data tool", "the Snowflake connection", "the plugin"
- Frame outputs as outcomes: "you'll get a table showing..." not "the query will return..."

**Technical response style:**
- Can reference connectors, Cortex Analyst, semantic view names, and tool names directly
- Shorter explanations are fine — assume they'll read between the lines
- Can include example query phrasing that uses the correct field names/terminology

---

## Step 4: Handle gaps

There are three gap types. Handle each differently.

### Gap type 1: Data is in development

If the Notion query returns a matching data source with `Status: In Development`, tell them:
- It's on the roadmap and expected soon (include the expected delivery date if the record has one)
- They can submit a request to bump priority: `ade172d17586404399e6e2b7f818cd22`
- In the meantime, suggest the closest live alternative if one exists

### Gap type 2: Data doesn't exist yet

If the user asks about something not in the live or in-development list, it's an undocumented gap. Tell them:
- You couldn't find this documented in the resource hub
- Give your best general answer using Claude's knowledge, but flag it clearly as unconfirmed
- Offer to log the gap (see gap logging flow below)

### Gap type 3: Connector request

If the user wants Claude to connect to a tool or platform that isn't currently set up (e.g., Salesforce, HubSpot, Greenhouse, Figma), this is a connector request. Direct them to the request form at `ade172d17586404399e6e2b7f818cd22` and briefly explain that connector requests go through a privacy and security evaluation before being approved.

---

## Gap logging flow

When you hit a Gap type 2 (undocumented gap), offer to notify the AI enablement team. This is optional — always let the user decide.

Say something like:
> "Want me to flag this as a documentation gap? I'll draft a note to #ask-ai-enablement so the team knows this question came up. You'll review it before anything gets sent."

If they say yes:

1. **Compose a sanitized draft.** Strip any sensitive details — account names, rep names, deal values, specific customers. Capture only: what domain they were asking about, what they were trying to understand, and that no documented resource was found.

   Example draft:
   > "Hi team — a question came in about [general topic, e.g. 'headcount or HR data'] that doesn't appear to be covered in the resource hub yet. Flagging as a potential documentation gap. Full context available on request."

2. **Show the draft to the user** before sending. Say:
   > "Here's what I'd send — feel free to edit, or let me know if you'd rather not send it or want to DM Sean directly instead."

3. **Wait for their call.** Options:
   - ✅ Send it — use the Slack MCP to post to #ask-ai-enablement
   - ✏️ Edit first — let them revise, then send
   - ❌ Don't send — acknowledge and move on, no pressure
   - 💬 DM Sean instead — surface Sean's Slack handle so they can reach out directly

---

## Closing the conversation

After your response, add a short closing line:
> "Feel free to keep asking follow-up questions. Type /how-to anytime to search the resource hub for a different topic."

Do not re-invoke this skill automatically within the same conversation unless the user types /how-to again.

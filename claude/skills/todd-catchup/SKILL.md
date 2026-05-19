---
name: todd:catchup
description: Check all communication channels and task systems for open items needing attention. Use when asked to catch up, check messages, or review what's pending.
disable-model-invocation: true
argument-hint: "[today|week]"
allowed-tools: Agent, Read
---

# Catchup — Unified Communications & Tasks Check

Check Google Calendar, Gmail, Slack, Notion, and Linear for open communications and tasks. Present results grouped by action type.

## Step 1: Compute Time Boundaries

Based on today's date and the argument provided:

- **Default / "today"**: `TIME_WINDOW_START` = 24 hours ago, `TIME_WINDOW_END` = end of today 23:59:59
- **"week"**: `TIME_WINDOW_START` = 7 days ago, `TIME_WINDOW_END` = end of Friday this week 23:59:59

Compute these as absolute ISO 8601 datetimes. Also compute:
- `NOW` = current datetime
- `AFTER_DATE` = TIME_WINDOW_START as YYYY-MM-DD (for Slack)
- `UPDATED_AFTER` = TIME_WINDOW_START as ISO 8601 (for Linear)
- `LOOKBACK_PERIOD` = for Notion: `{"type": "relative", "value": "custom", "direction": "past", "unit": "day", "count": 1}` for today, or `{"type": "relative", "value": "the_past_week"}` for week

Use the user's timezone: America/Chicago.

## Step 2: Read Agent Prompts

Read all five agent prompt files from this skill directory:
- [calendar-agent.md](calendar-agent.md)
- [gmail-agent.md](gmail-agent.md)
- [slack-agent.md](slack-agent.md)
- [notion-agent.md](notion-agent.md)
- [linear-agent.md](linear-agent.md)

## Step 3: Dispatch Parallel Subagents

Launch **all 5 agents simultaneously** using the Agent tool with `subagent_type: "general-purpose"`. For each agent, take the content from its `*-agent.md` file and append the computed time boundaries as concrete values replacing the placeholder variables.

Example for calendar agent prompt: take the calendar-agent.md content and replace the Inputs section with actual computed values:
- TIME_WINDOW_START = 2026-03-10T00:00:00
- TIME_WINDOW_END = 2026-03-11T23:59:59
- NOW = 2026-03-11T14:30:00

Do this for all five agents and dispatch them all in a single message (parallel tool calls).

## Step 4: Merge & Categorize Results

Collect all results from the 5 agents. Each agent returns lines in this format:
```
[Source] category | description — time context | optional_link
```

Group all items into four sections:

### Needs Your Reply
Items tagged `needs_reply` from any service. Sort by recency (most recent first).

### Open Tasks
Items tagged `open_task` from any service. Sort by priority (urgent first), then recency.

### Upcoming Events
Items tagged `upcoming_event` from any service. Sort chronologically.

### FYI / Updates
Items tagged `fyi` from any service. Sort by recency.

## Step 5: Present Output

Format the final output as:

```
## Needs Your Reply (N)
- [Service] description — time context [link]

## Open Tasks (N)
- [Service] description — status, priority [link]

## Upcoming Events (N)
- time — title (duration) [link]

## FYI / Updates (N)
- [Service] description — time context [link]
```

- Omit sections with zero items
- Include item counts in each header
- If any subagent failed, append at the bottom:
  ```
  ---
  ⚠ Could not reach: SERVICE_NAME (error summary). Try again or check MCP connection.
  ```

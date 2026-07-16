---
name: todd-linear-project-setup
description: Use when creating a new Linear project with milestones, issues, and dependency links. Triggers when the user wants to bootstrap a Linear project from a plan, spec, or scratch — including projects that need phased delivery via milestones and cross-issue dependency wiring.
---

# Linear Project Setup

## Overview

Bootstraps a complete Linear project structure — project, milestones, issues, and dependency links — from a plan file or interactive input. Gathers missing information through targeted questions before creating anything.

## Usage

```
/linear-project-setup [PLAN_FILE]
```

**Arguments:**
- `PLAN_FILE` (optional): Path to a markdown plan/spec with milestones and tasks. If omitted, all info is gathered interactively.

## When to Use

- Starting a new project that needs Linear tracking
- Have a plan, spec, or implementation plan with milestones and tasks
- Need phased delivery with proper dependency wiring between issues
- Bootstrapping a project from an architecture document or design doc

## Implementation Steps

### Step 1: Gather Information

**If a plan file was provided**, read it and extract:
- Project name
- Description / summary
- Milestones (sections, phases, or explicitly labeled milestones)
- Issues/tasks per milestone (headings, bullet items, or numbered steps)
- Dependencies (explicit "depends on", "blocked by", or implied ordering)
- Priorities, estimates, assignees (if mentioned)

**Regardless of plan file**, use `AskUserQuestion` to fill any gaps. Ask only about fields that are truly missing — never re-ask what the plan already provides.

**Required fields** (must resolve before proceeding):

| Field | Source | Fallback question |
|-------|--------|--------------------|
| Project name | Plan file title or heading | "What should the project be named?" |
| Team | Repo CLAUDE.md or plan | "Which team should own this project?" |
| At least 1 milestone | Plan sections/phases | "What are the milestone names? (comma-separated)" |
| At least 1 issue | Plan tasks/steps | "What issues belong in the first milestone?" |

**Optional fields** (ask once, allow skip):

| Field | When to ask |
|-------|-------------|
| Project description | If plan has no summary paragraph |
| Project lead | Always ask, default to "me" |
| Milestone target dates | Always ask, allow "none" |
| Issue priorities | If plan doesn't indicate priority |
| Issue estimates | Always ask, allow "none" |
| Issue assignees | If plan doesn't mention ownership |
| Dependencies | Always ask, allow "none" |

### Step 2: Validate Team

Before creating anything, verify the team exists:

1. Use `mcp__claude_ai_Linear__list_teams` to get available teams.
2. Match the team name (case-insensitive, partial match OK).
3. If no match, show available teams and ask the user to pick one.

### Step 3: Create Project

Use `mcp__claude_ai_Linear__save_project` with:
- `name`: resolved project name
- `description`: from plan or user input
- `addTeams`: [resolved team ID or name]
- `lead`: resolved lead (default "me")

Report the created project name and URL.

### Step 4: Create Milestones

For each milestone in order:

1. Use `mcp__claude_ai_Linear__save_milestone` with:
   - `project`: project name
   - `name`: milestone name
   - `targetDate`: if provided (ISO format)
   - `description`: if provided

2. Track milestone names for linking issues in the next step.

Report created milestones with their order.

### Step 5: Create Issues

For each issue, grouped by milestone:

1. Use `mcp__claude_ai_Linear__save_issue` with:
   - `title`: issue title
   - `team`: resolved team
   - `project`: project name
   - `milestone`: milestone name
   - `description`: issue details (from plan or user input, as markdown)
   - `priority`: if specified (0=None, 1=Urgent, 2=High, 3=Normal, 4=Low)
   - `estimate`: if specified
   - `assignee`: if specified

2. Capture the returned issue identifier (e.g., `DEV-75`) for dependency wiring.

Report issues created per milestone.

### Step 6: Wire Dependencies

For each dependency pair identified from the plan or user input:

1. Use `mcp__claude_ai_Linear__save_issue` with:
   - `id`: the blocked issue identifier
   - `blockedBy`: [array of blocking issue identifiers]

This appends to existing relations (never removes).

Common dependency patterns to recognize:
- "X depends on Y" → X `blockedBy` Y
- "Y blocks X" → X `blockedBy` Y
- Phase ordering → issues in later phases `blockedBy` key issues in earlier phases
- Numbered steps → step N+1 `blockedBy` step N (if explicitly sequential)

Report the dependency graph.

### Step 7: Summary

Print a structured summary:

```
Project: {name}
Team: {team}
Lead: {lead}

Milestones:
  1. {Milestone 1} ({N} issues, target: {date or none})
  2. {Milestone 2} ({N} issues, target: {date or none})

Issues: {total} total

Dependencies:
  {DEV-75} → blocked by {DEV-73, DEV-74}
  {DEV-78} → blocked by {DEV-75}
  ...

Linear URL: https://linear.app/{org}/project/{slug}
```

## Plan File Parsing

A plan file can be any markdown document. The skill looks for:

**Project name**: First `#` heading, or a title-like line near the top.

**Milestones**: Sections marked by `##` headings, `### Phase N` patterns, or explicit "Milestone:" labels. Milestones are created in document order.

**Issues per milestone**: Bullet items (`- `, `* `), numbered lists (`1. `), or `####` sub-headings within each milestone section. Each becomes a separate issue.

**Dependencies**: Look for these patterns within issue text:
- "depends on DEV-XX" or "depends on {title}"
- "blocked by DEV-XX" or "after DEV-XX"
- "requires {title}" or "needs {title} first"
- Implicit: numbered steps in a sequential section

**Priorities**: Look for priority keywords (urgent, high, normal, low, P0-P4).

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Creating all issues without milestones | Always assign issues to their milestone during creation |
| Forgetting to wire dependencies | Dependencies are a separate step — don't skip Step 6 |
| Using team name that doesn't exist | Always validate team in Step 2 before creating anything |
| Creating the project twice | Check if project exists first with `get_project` |
| Over-asking questions | Only ask about fields the plan file doesn't provide |
| Losing issue identifiers | Capture returned identifiers immediately for dependency wiring |

## Configuration

- **Default lead**: "me" (the current user)
- **Default priority**: 3 (Normal)
- **Default estimate**: none
- **Team resolution**: case-insensitive partial match against available teams
- **Dependency direction**: always stored as `blockedBy` on the downstream issue

## Dependencies

- Linear MCP server (plugin:linear:linear) must be configured and authenticated
- `AskUserQuestion` tool for interactive information gathering

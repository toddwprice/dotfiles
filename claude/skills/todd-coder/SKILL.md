---
name: todd:coder
description: Use when the user runs /todd:coder with a Linear ticket ID to either create an implementation plan or execute TDD implementation. Expects args in the form "[plan|impl] TICKET_ID" (e.g., "plan DEV-5" or "impl DEV-5"). Works seamlessly in git worktrees.
---

# Todd Coder

## Overview
Bridges Linear tickets with disciplined TDD implementation. Reads a ticket, creates or follows an implementation plan, and documents all work back to Linear. **Fully compatible with git worktrees** — automatically detects when running in a worktree and adjusts behavior.

## Usage
```
/todd:coder plan DEV-5                 # Create implementation plan from ticket
/todd:coder impl DEV-5                 # Implement ticket using TDD
/todd:coder impl DEV-5 --orchestrated  # Non-interactive mode, dispatched by /todd:phase
```

## Argument Parsing

Parse the args string to extract:
- **command**: First word, must be `plan` or `impl`. If it's anything else — including a free-form request like "diagnose this trace" or "start on the subtickets and work in parallel" — this is the wrong tool. Don't force-fit it: say plainly that `/todd:coder` only does `plan`/`impl` on a single ticket, name what the user actually seems to want, and stop. (Real runs have mis-fed this a Braintrust-trace prompt and a "work in parallel" instruction; a clean bounce beats improvising an orchestration this skill isn't built for.)
- **TICKET_ID**: Second word (e.g., `DEV-5`). If missing, show usage and stop.
- **`--orchestrated`** (optional flag, anywhere in the args): run non-interactively for an orchestrator like `/todd:phase`. See "Orchestrated Mode" below — the short version is: never block on a prompt, still post to Linear, auto-commit on success, and end with the structured status block.

## Worktree Detection

Before starting work, check if running in a git worktree:
1. Run `git worktree list` to see if current path is a worktree
2. If in a worktree, note the worktree path and branch
3. Report to user: "Working in worktree: {path} on branch {branch_name}"

**Why this matters**: Worktrees may have different branches, uncommitted changes, or different states. Being aware ensures proper git operations and prevents conflicts.

## Plan Mode

### Steps

1. **Detect worktree environment** (see above)

2. **Read ticket**: Call `mcp__claude_ai_Linear__get_issue` with the TICKET_ID. If not found, report error and stop.

3. **Explore codebase — delegate the search, keep only the findings**: Broad exploration is a fan-out that bloats context fast, and when this skill runs as a subagent under `/todd:phase` its context budget directly feeds implementation quality. So dispatch read-only search agents rather than grepping and reading files inline: `dev-flow:codebase-locator` to find the relevant files, `dev-flow:codebase-analyzer` to trace how they work, `dev-flow:codebase-pattern-finder` for conventions and examples to model. Run independent lookups in parallel (multiple Agent calls in one message), and fold their **returned findings** — not their raw file dumps — into the plan. You're trying to understand:
   - What files/modules are involved
   - Existing patterns, utilities, and functions to reuse
   - Test structure and conventions
   - Potential risks or complexity

4. **Draft implementation plan** including:
   - **Summary**: What the ticket asks for, in your own words
   - **Approach**: Step-by-step implementation strategy
   - **Files to modify/create**: With brief rationale
   - **Existing code to reuse**: Functions, patterns, utilities found during exploration
   - **Risks & considerations**: Edge cases, breaking changes, performance
   - **Questions/blockers**: Anything that MUST be answered before implementation (flag clearly)
   - **Estimated scope**: Small / Medium / Large

5. **Post plan to Linear**: Use `mcp__claude_ai_Linear__save_comment` with `issueId` set to TICKET_ID. Format the plan as markdown. Prefix the comment with `## 📋 Implementation Plan`.

6. **Report to user**: Show the plan and highlight any questions/blockers.

## Impl Mode

### Steps

1. **Detect worktree environment** (see above)

2. **Check git state**: Ensure worktree is clean (no uncommitted changes) OR report what will be staged. If in a worktree with uncommitted changes from previous work, ask the user whether to continue or stash — **unless `--orchestrated`**, where you can't wait on a prompt: if the changes look like a resumed prior attempt on *this* ticket, continue on top of them; otherwise stop with a `fatal` status. (An unexpected dirty tree in an unattended run is a real problem, not something to silently stash.)

3. **Read ticket**: Call `mcp__claude_ai_Linear__get_issue` with the TICKET_ID. If not found, report error and stop.

4. **Find plan**: Call `mcp__claude_ai_Linear__list_comments` with `issueId` set to TICKET_ID. Look for a comment starting with `## 📋 Implementation Plan`.

5. **Assess readiness**:
   - If plan found: proceed to implementation using the plan as guide.
   - If no plan found: evaluate the ticket's complexity.
     - **Straightforward** (single file, clear scope, low risk): proceed directly. Tell the user you're skipping the plan phase and why.
     - **Complex** (multi-file, ambiguous requirements, high risk): stop and suggest running `/todd:coder plan TICKET_ID` first.

6. **TDD implementation**: **REQUIRED: Use superpowers:test-driven-development**. Follow strict red-green-refactor:
   - Write a failing test first (RED)
   - Write minimal code to pass (GREEN)
   - Refactor while keeping tests green (REFACTOR)
   - Repeat for each piece of functionality
   - Follow all project testing conventions from CLAUDE.md

7. **Summarize work**: After implementation is complete, compile:
   - **What was done**: Files created/modified, features implemented
   - **Decisions made**: Any choices or tradeoffs during implementation, and why
   - **Test plan**: List of test cases written, what they cover, how to run them
   - **Remaining work**: Anything deferred or out of scope

8. **Post summary to Linear**: Use `mcp__claude_ai_Linear__save_comment` with `issueId` set to TICKET_ID. Format as markdown. Prefix with `## ✅ Implementation Summary`.

9. **Report to user**: Show the summary and test plan. **In `--orchestrated` mode, skip the chatty report** — the orchestrator reads the structured status block instead (see "Structured Return").

10. **In worktree only**: Commit changes if implementation succeeded. Interactive mode: offer first. `--orchestrated`: commit automatically (the orchestrator squashes/rebases and pushes later), then put the commit SHA in the structured return. Never push — that's the orchestrator's job.

## Orchestrated Mode (`--orchestrated`)

When `/todd:phase` (or any orchestrator) dispatches this skill into a subagent, there's no human on the other end of the chat, and the orchestrator only needs a compact result — not the full narrated report. In this mode:

- **Never block on a question.** Every interactive prompt gets a safe default (see the impl steps). If you genuinely can't proceed, stop with a `fatal` status rather than waiting on input that will never come.
- **Still post to Linear.** The plan and summary comments are the durable record the orchestrator (and Todd) rely on — keep posting them exactly as in normal mode. This is why the orchestrator dispatches *this skill* rather than running raw TDD: the Linear paper trail comes for free.
- **Commit automatically** on success; never push.
- **End with the structured status block** (below) as your final message — that's what the orchestrator parses.

## Comment Format Templates

### Plan Comment
```markdown
## 📋 Implementation Plan

### Summary
[What the ticket asks for]

### Approach
1. [Step 1]
2. [Step 2]

### Files to Modify
- `path/to/file.py` — [reason]

### Existing Code to Reuse
- `path/to/util.py:function_name` — [what it does]

### Risks & Considerations
- [Risk 1]

### Questions / Blockers
- ❓ [Question that must be answered before impl]

### Estimated Scope
[Small / Medium / Large]
```

### Implementation Summary Comment
```markdown
## ✅ Implementation Summary

### What Was Done
- [Change 1]
- [Change 2]

### Decisions Made
- [Decision]: [Why]

### Test Plan
| Test | Covers | Command |
|------|--------|---------|
| `test_name` | [what it validates] | `make test-unit` |

### How to Verify
1. [Step-by-step verification]

### Remaining Work
- [If any]
```

## Error Handling
- **Invalid args**: Show usage: `/todd:coder [plan|impl] TICKET_ID`
- **Ticket not found**: Report error with the TICKET_ID attempted
- **Linear MCP unavailable**: Tell user to check Linear plugin configuration
- **No plan for complex ticket**: Suggest running plan mode first, explain why
- **Worktree has uncommitted changes**: Ask user whether to stash, commit, or abort
- **Dirty worktree from previous work**: Offer to clean up or continue

## Worktree-Specific Behavior

**When running in a worktree:**
- Detect and report the worktree path and branch
- Check for uncommitted changes before starting
- Offer to commit changes after successful implementation (in impl mode)
- Never push to origin — leave that to the orchestrator (`/todd:phase`)
- Use `git status` to report changes when done

**Example output:**
```
🔧 Working in worktree: /path/to/repo/.worktrees/dev-65-set-up-python
📌 Branch: todd/dev-65-set-up-python-project-scaffold
✅ Worktree is clean — proceeding with implementation
```

## Structured Return (for orchestrators)

This skill runs in-context, not as a subprocess, so there's no real exit code — an orchestrator reads your **final message**. In `--orchestrated` mode, make that final message a compact, parseable status block and put nothing after it:

```
STATUS: success | recoverable | fatal | plan-required
TICKET: {TICKET_ID}
COMMIT: {sha, or "none"}
FILES: {count} changed
TESTS: {e.g. "42 passed" or "3 failed: <names>"}
BLOCKERS: {one line, or "none"}
PR_TITLE: {suggested PR title}
PR_BODY: |
  {summary / changes / test-plan the orchestrator can drop straight into the PR}
```

Status meanings (these replace the old exit codes 0–3):
- **success** — plan created, or implementation complete and committed.
- **recoverable** — transient failure; a re-run can retry this ticket.
- **fatal** — can't proceed (ticket not found, invalid args, unexpected dirty tree).
- **plan-required** — complex ticket with no usable plan; the orchestrator should run `plan` first, then re-dispatch `impl`.

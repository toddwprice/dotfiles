---
name: rpi-5-save-progress
---

# Save Progress

You are tasked with creating a comprehensive progress checkpoint when the user needs to pause work on a feature.

## When to Use This Command

Invoke this when:
- User needs to stop mid-implementation
- Switching to another task/feature
- End of work session
- Before a break or context switch

## Process

### Step 1: Assess Current State

1. **Review conversation history** to understand what was being worked on
2. **Check git status** for uncommitted changes
3. **Identify the active plan** if one exists
4. **Review todo list** for current tasks

### Step 2: Save Code Progress

1. **Commit meaningful work**:
   ```bash
   git status
   git diff
   # Create WIP commit if appropriate
   git add [specific files]
   git commit -m "WIP: [Feature] - [Current state]"
   ```

2. **Note uncommitted changes**:
   - List files with unsaved changes
   - Explain why they weren't committed
   - Document what needs to be done

### Step 3: Update Plan Document

If working from a plan, update it with:

```markdown
## Progress Checkpoint - [Date Time]

### Work Completed This Session
- [x] Specific task completed
- [x] Another completed item
- [ ] Partially complete task (50% done)

### Current State
- **Active File**: `path/to/file.js:123`
- **Current Task**: [What you were doing]
- **Blockers**: [Any issues encountered]

### Local Changes
- Modified: `file1.js` - Added validation logic
- Modified: `file2.py` - Partial refactor
- Untracked: `test.tmp` - Temporary test file

### Next Steps
1. [Immediate next action]
2. [Following task]
3. [Subsequent work]

### Context Notes
- [Important discovery or decision]
- [Gotcha to remember]
- [Dependency to check]

### Commands to Resume
```bash
# To continue exactly where we left off:
cd /path/to/repo
git status
/4_implement_plan ~/.claude/thoughts/shared/plans/feature.md
```
```

### Step 4: Create or Update Session Summary

**CRITICAL — Check for an existing session before creating a new one:**

1. **Search conversation history** for any session file that was loaded earlier in this conversation (e.g., via `/6_resume_work`). Look for file paths matching `~/.claude/thoughts/shared/sessions/NNN_*.md` that were read during this session.
2. **If a session file was resumed**: Update that file **in-place**. Update the frontmatter fields (`date`, `last_commit`, `status`) to reflect current state, then rewrite the body sections (Accomplishments, Decisions Made, Next Steps, etc.) to incorporate both previous and current session work. Do NOT create a new session file.
3. **If no session file was resumed**: Check existing session files to determine next sequence number, then create a new file at `~/.claude/thoughts/shared/sessions/NNN_feature.md` where NNN is a 3-digit sequential number (001, 002, etc.).

Session file template (for new sessions, or as a guide for sections to update in existing sessions):

```markdown
---
date: [ISO timestamp]
feature: [Feature name]
plan: ~/.claude/thoughts/shared/plans/[plan].md
research: ~/.claude/thoughts/shared/research/[research].md
status: in_progress
last_commit: [git hash]
---

# Session Summary: [Feature Name]

## Session Duration
- Started: [timestamp]
- Ended: [timestamp]
- Duration: [X hours Y minutes]

## Objectives
- [What we set out to do]

## Accomplishments
- [What was actually completed]
- [Problems solved]
- [Code written]

## Discoveries
- [Important findings]
- [Patterns identified]
- [Issues uncovered]

## Decisions Made
- [Architecture choices]
- [Implementation decisions]
- [Trade-offs accepted]

## Open Questions
- [Unresolved issues]
- [Needs investigation]
- [Requires team input]

## File Changes
```bash
# Git diff summary
git diff --stat HEAD~N..HEAD
```

## Test Status
- [ ] Unit tests passing
- [ ] Integration tests passing
- [ ] Manual testing completed

## Ready to Resume
To continue this work:
1. Read this session summary
2. Check plan: `[plan path]`
3. Review research: `[research path]`
4. Continue with: [specific next action]

## Additional Context
[Any other important information for resuming]
```

### Step 5: Clean Up

1. **Commit all meaningful changes**:
   ```bash
   # Review all changes one more time
   git status
   git diff

   # Commit any remaining work
   git add .
   git commit -m "WIP: [Feature] - Save progress checkpoint"
   # Document commit hash in session summary
   ```

2. **Update todo list** to reflect saved state

3. **Present summary** to user:
   ```
   ✅ Progress saved successfully!

   📁 Session summary: ~/.claude/thoughts/shared/sessions/[...]
   📋 Plan updated: ~/.claude/thoughts/shared/plans/[...]
   💾 Commits created: [list]

   To resume: /6_resume_work ~/.claude/thoughts/shared/sessions/[...]
   ```

## Important Guidelines

- **Always commit meaningful work** - Don't leave important changes uncommitted
- **Be specific in notes** - Future you needs clear context
- **Include commands** - Make resuming as easy as copy-paste
- **Document blockers** - Explain why work stopped
- **Reference everything** - Link to plans, research, commits
- **Test status matters** - Note if tests are failing

## Integration with Framework

This command works with:
- `/4_implement_plan` - Updates plan progress
- `/6_resume_work` - Paired resume command
- `/3_validate_plan` - Can validate partial progress

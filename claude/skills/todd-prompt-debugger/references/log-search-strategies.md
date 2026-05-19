# Log Search Strategies for Prompt Debugging

## Finding Relevant Spans in Braintrust

When diagnosing a prompt issue from a Linear ticket, the goal is to find 5-15 production log
spans that exhibit the reported failure. These spans become the reproduction dataset.

## Search Strategy

### Step 1: Extract Search Criteria from the Linear Issue

Parse the Linear issue for:
- **Error description**: What went wrong (e.g., "agent selects wrong tool", "response is truncated")
- **Reproduction steps**: Any specific inputs or scenarios mentioned
- **Time window**: When the issue was reported or observed (use issue creation date as upper bound)
- **User/session IDs**: If mentioned in the issue or comments
- **Keywords**: Specific tool names, error messages, or output patterns

### Step 2: Resolve the Braintrust Project

```bash
bt projects list --json | jq '.[] | select(.name == "dscript")'
```

This returns the project ID needed for SQL queries and log views.

### Step 3: Query Braintrust Project Logs

Use `bt sql` to search for spans matching the issue.

**Basic span search (recent errors):**
```bash
bt sql "SELECT id, input, output, error, created FROM project_logs('<project-id>') WHERE error IS NOT NULL AND created > now() - interval 7 day ORDER BY created DESC LIMIT 15"
```

**Search by output content (keyword match):**
```bash
bt sql "SELECT id, input, output, created FROM project_logs('<project-id>') WHERE output LIKE '%<keyword>%' AND created > now() - interval 7 day ORDER BY created DESC LIMIT 15"
```

**Search by metadata fields:**
```bash
bt sql "SELECT id, input, output, metadata, created FROM project_logs('<project-id>') WHERE metadata.tool_name = '<tool-name>' AND created > now() - interval 7 day ORDER BY created DESC LIMIT 15"
```

**Search by low scores:**
```bash
bt sql "SELECT id, input, output, scores, created FROM project_logs('<project-id>') WHERE scores.<score_name> < 0.5 AND created > now() - interval 7 day ORDER BY created DESC LIMIT 15"
```

### Step 4: Get Full Span Details

For each candidate span, fetch the full payload (untruncated):

```bash
bt view span --object-ref project_logs:<project-id> --id <span-id>
```

Or via SQL:
```bash
bt sql "SELECT * FROM project_logs('<project-id>') WHERE id = '<span-id>'" --non-interactive
```

### Step 5: Get Trace Context

To understand the full conversation flow around a failing span:

```bash
bt view trace --object-ref project_logs:<project-id> --trace-id <trace-id>
```

### Step 6: Validate and Select 5-15 Spans

For each candidate span:
1. Verify it exhibits the failure described in the Linear issue
2. Confirm the input is representative (not an edge case unless the issue IS about edge cases)

Target:
- **Minimum 5**: Enough to establish a pattern and avoid overfitting a fix
- **Maximum 15**: Keeps eval runs fast and focused
- **Ideal 8-10**: Good balance of coverage and speed

Prefer diversity:
- Different inputs that trigger the same failure
- Different times (not all from the same minute)
- Different users/sessions if available

## bt CLI Quick Reference for Log Search

```bash
# List projects
bt projects list --json

# Interactive log browser
bt view logs --object-ref project_logs:<project-id> --search "<keyword>" --window 7d

# Non-interactive log listing
bt view logs --object-ref project_logs:<project-id> --search "<keyword>" --window 7d --limit 20 --json

# Full span payload
bt view span --object-ref project_logs:<project-id> --id <span-id>

# Full trace
bt view trace --object-ref project_logs:<project-id> --trace-id <trace-id>

# SQL queries (non-interactive for scripting)
bt sql "<query>" --non-interactive
```

## Canvas/DScript-Specific Search Patterns

For Canvas issues (CNVS-* tickets), the Braintrust project is `dscript`.

Common failure patterns and how to find them:

| Failure Type | Search Strategy |
|---|---|
| Wrong tool selected | Filter by `metadata.tool_name`, compare to expected |
| Hallucinated content | Search output for specific wrong patterns |
| Missing required output | Check for NULL or empty fields in output |
| Workflow step errors | Filter by `metadata.workflow_step` |
| Response quality | Filter by low scores |

Key prompt slugs to investigate:
- `supervisor-select` - controls tool selection vs conversational response
- `system-prompt` - general system instructions

Key code files for prompt context:
- `apps/astro/app/domain/dscript/module.py` - prompt references
- `apps/astro/app/domain/dscript/agents/supervisor_agent/chat.py` - prompt invocation
- `apps/astro/app/domain/dscript/agents/supervisor_agent/progression.py` - workflow steps
- `apps/astro/app/domain/dscript/agents/supervisor_agent/tools/` - tool implementations

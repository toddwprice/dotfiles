---
name: todd:prompt-debugger
description: This skill should be used when the user asks to "debug a prompt", "diagnose a prompt issue", "investigate a prompt failure", "fix a prompt", "prompt regression", "reproduce a prompt bug", "create an eval for an issue", "write a scorer", or "why is the prompt failing". It also applies when the user provides a Linear issue ID (e.g. CNVS-421) and mentions prompt problems, or wants to trace a prompt failure from a Linear ticket through Braintrust logs to a verified fix.
---

# Prompt Debugger

Diagnose LLM prompt failures by tracing from a Linear issue through Braintrust production logs
to a verified fix using offline evals. The workflow produces a reproducible dataset and scoring
script that proves the fix works.

## Prerequisites

- `linctl` CLI authenticated (`linctl auth status`)
- `bt` CLI authenticated (`bt auth status`)
- Access to the relevant Braintrust project logs

## Workflow

### Step 1: Fetch the Linear Issue

Given an issue ID (e.g., `CNVS-421`), retrieve the full issue details:

```bash
linctl issue get <ISSUE_ID> --json
```

Also fetch comments for additional context:

```bash
linctl comment list <ISSUE_ID> --json
```

Extract from the issue:
- **Failure description**: What is going wrong with the prompt/LLM behavior
- **Reproduction context**: Any specific inputs, user scenarios, or steps mentioned
- **Time window**: Issue creation date as an upper bound for log search
- **Keywords**: Tool names, error messages, output patterns mentioned

### Step 2: Find Failing Spans in Braintrust

Read `references/log-search-strategies.md` for detailed search patterns.

1. Resolve the Braintrust project ID:
   ```bash
   bt projects list --json
   ```

2. Search for spans exhibiting the failure using `bt sql`:
   ```bash
   bt sql "SELECT id, input, output, error, created FROM project_logs('<project-id>') WHERE <conditions> ORDER BY created DESC LIMIT 20"
   ```

3. Refine the search based on the failure type (keyword match, metadata filter, low scores, errors).

4. Fetch full span details for promising candidates:
   ```bash
   bt view span --object-ref project_logs:<project-id> --id <span-id>
   ```

5. Select **5-15 spans** that clearly exhibit the reported failure. Prefer diversity in inputs
   and timestamps. Record the span IDs.

### Step 3: Ask Where to Create Scripts

Present the user with a choice of where to place the scoring and dataset scripts. The default
location follows the colocated pattern:

```
apps/astro/app/domain/<module>/offline_evals/
```

For Canvas/DScript issues, the default is:
```
apps/astro/app/domain/dscript/agents/supervisor_agent/offline_evals/
```

Confirm with the user before creating files.

### Step 4: Create the Dataset Script

Create a Python script that populates a Braintrust dataset with the identified spans.
The script should:

- Define the span IDs found in Step 2
- Use `braintrust.init_dataset()` to create a named dataset (`<issue-id>-repro`)
- Insert each span's input and expected output into the dataset
- Include `metadata.source_span_id` and `metadata.issue` for traceability

The user runs this script with: `python <path/to/create_dataset.py>`

### Step 5: Create the Scoring Script

Read `references/eval-patterns.md` for the full template and conventions.

Create a scoring script following the project's `create_eval()` pattern:

1. **`task(input, hooks)`**: Calls the same code path that production uses, replicating the
   failure conditions.

2. **`issue_repro` scorer**: Returns `Score(name="IssueRepro", score=0.0)` when the failure
   IS present, `Score(name="IssueRepro", score=1.0)` when it is NOT present. Each dataset
   row gets an individual pass/fail signal.

3. **`create_eval()` at module level**: Wires up the task, scorer, dataset, and prompt
   references. Name the experiment `<ISSUE_ID> Baseline`.

4. **`BraintrustPrompt` references**: Include the prompt(s) under investigation so they
   appear as editable parameters in the Braintrust UI.

The user runs this with: `uv run braintrust eval <path/to/scoring_script.py>`

### Step 6: Run Baseline

Execute the scoring script to confirm the issue reproduces:

```bash
cd apps/astro && uv run braintrust eval <path/to/scoring_script.py>
```

Verify that `IssueRepro` scores are 0.0 for the failing spans. If the issue does not reproduce,
revisit the task function or scorer logic.

### Step 7: Diagnose and Fix

Based on the failing spans and results, recommend changes to either:

**Prompt changes** (in Braintrust):
- Identify the prompt slug with `bt prompts list --project <project>`
- Recommend specific prompt modifications
- Update the version hash in the `BraintrustPrompt()` reference after changes

**Code changes** (in the codebase):
- Trace the code path from prompt invocation through the relevant files
- Recommend targeted modifications to tool definitions, state management, or response handling

### Step 8: Verify the Fix

Re-run the scoring script with a new experiment name:

```bash
cd apps/astro && uv run braintrust eval <path/to/scoring_script.py>
```

Update the experiment name to `<ISSUE_ID> Fix v1` (or increment version) before re-running.
Verify that `IssueRepro` scores improve to 1.0 for previously failing spans.

### Step 9: Comment on the Linear Issue
Summarize the investigation, fix, and verification results in a comment on the Linear issue:

```bash
linctl comment create <ISSUE_ID> --content "Investigation summary: ... Fix applied:
... Baseline IssueRepro scores: ... Post-fix IssueRepro scores: ..."
```

Include a section on how to QA:
- Create worktree with the fix
- Command to change to the correct directory
- Command to run the scoring script to confirm the fix works


## Tool Usage

- **Linear**: Use `linctl` CLI exclusively (the linctl skill has detailed patterns)
- **Braintrust**: Use `bt` CLI exclusively (the braintrust skill has detailed patterns).
  Do NOT use the Braintrust MCP server.
- **Code search**: Use Grep/Glob/Read tools to trace code paths

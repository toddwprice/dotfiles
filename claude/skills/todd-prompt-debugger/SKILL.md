---
name: todd-prompt-debugger
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

### Step 1: Establish the failure — from a Linear issue OR a trace/room-id

There are two front doors. A ticket is **not** required.

**1a — Starting from a trace/room-id (the common case).** Todd's loop usually begins at one bad
dscript session, triaged with `todd-trace-dys` — often before any ticket exists. If you were handed a
room-id + span id(s) + a one-line diagnosis (that's exactly what `trace-dys`'s handoff passes
forward), **skip the `linctl` fetch entirely**: you already have the failing span(s) and the failure
description. Carry forward from the handoff:
- **Failing span id(s)** and the Braintrust **project id** → these seed Step 2 directly (you may not
  need to search at all — you already have spans).
- **The one-line diagnosis** (which prompt section / gate / tool-availability drove the wrong
  behavior) → this is your failure description.
- **A known-good contrast session**, if `trace-dys` identified one → carry it into Step 4 as the
  calibration control.
Then go straight to Step 2 to widen the span set (find 5–15 similar failures), or to Step 3 if the
handoff already gave you enough. File a ticket later if the fix warrants tracking; don't block on one.

**1b — Starting from a Linear issue.** Given an issue ID (e.g., `CNVS-421`), retrieve full details:

```bash
linctl issue get <ISSUE_ID> --json
linctl comment list <ISSUE_ID> --json   # comments for extra context
```

Extract from the issue (or from the trace handoff, in 1a):
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
- **Add ≥1 known-good control span** — a session that behaved *correctly* on this same axis, tagged
  `metadata.control = "good"`. This is what makes the scorer-calibration gate in Step 6 possible.
  Without a good example in the set, you can't tell a real repro from a scorer that flags everything.

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

5. **`max_concurrency=1`** in the `Eval()`/`create_eval()` call whenever the task uses
   `asyncio.run()` — **dscript/DYS graph evals do**, and running them concurrently deadlocks the
   event loop (you'll see hangs, not errors). This is the single most common eval-setup gotcha here;
   default to `max_concurrency=1` for any dscript supervisor/drafter eval.

The user runs this with: `uv run braintrust eval <path/to/scoring_script.py>`

### Step 6: Run Baseline

Execute the scoring script to confirm the issue reproduces:

```bash
cd apps/astro && uv run braintrust eval <path/to/scoring_script.py>
```

Verify that `IssueRepro` scores are 0.0 for the failing spans. If the issue does not reproduce,
revisit the task function or scorer logic.

**Calibration gate — before you trust the baseline, prove the scorer isn't just flagging
everything.** The known-good control span(s) from Step 4 MUST score **1.0**. If a correct session
also scores 0.0, the scorer is miscalibrated — **fix the scorer, not the prompt.** This is a
recurring, expensive failure family here: FRG-845 was a *miscalibrated online judge* that false-flagged
correct studies, and FRG-993's scorer was *negation-blind* (spawning FRG-1005). A scorer that can't
separate the good control from the bad spans will "prove" any prompt change works and send you
chasing a fix for a bug that isn't there. Only proceed to Step 7 once: failing spans = 0.0 **and**
good control(s) = 1.0.

### Step 7: Diagnose and Fix

Based on the failing spans and results, recommend changes to either:

**Prompt changes** (in Braintrust) — **surface-and-wait; NEVER write the prompt yourself:**
- Identify the prompt slug with `bt prompts list --project <project>`.
- Recommend the specific modification concretely — show the exact before → after prompt text.
- **STOP and hand off the state-writing step to Todd.** Do **not** run `bt-prompt create`/`bt-prompt
  edit`, and do **not** edit the prompt via the Braintrust UI or API — Todd runs the version-writing
  step himself. Print the exact command for him to run, e.g.:
  ```
  bt-prompt edit <slug> --project <project>     # or `bt-prompt create` for a brand-new prompt
  ```
  Then **wait** for Todd to run it and paste back the new version hex.
- Only after Todd pastes the new hex: update the version hash in the `BraintrustPrompt()` reference
  to match, then proceed to Step 8 to verify.

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

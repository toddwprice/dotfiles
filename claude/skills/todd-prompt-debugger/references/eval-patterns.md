# Braintrust Eval Patterns for Prompt Debugging

## Eval Script Template

Eval scripts follow the colocated pattern in `apps/astro/`. They use `create_eval()` from
`app.core.llm` which wraps Braintrust's `Eval()` with prompt parameter support.

Run with: `uv run braintrust eval /path/to/eval_<issue_id>.py`

### Template

```python
"""Offline eval for <ISSUE_ID>: <issue title>.

Reproduces the failure described in the Linear issue by running the relevant
code path against a curated dataset of production spans that exhibit the bug.

HOW TO RUN:
-----------
uv run braintrust eval <path/to/this/file.py>

SCORERS:
--------
- issue_repro: 1.0 if the issue is NOT present in the output, 0.0 if it IS present
"""

import asyncio

from autoevals import Score

from app.core.llm import BraintrustPrompt, create_eval
from app.domain.dscript.module import get_module_name

# Reference the prompt(s) under investigation.
# Look up the slug and current version in module.py or the relevant tool file.
PROMPT_UNDER_TEST = BraintrustPrompt(
    slug="<prompt-slug>",
    version="<current-version-hash>",
    project=get_module_name(),
    use_guardrails=False,
)


def task(input, hooks):
    """Run the code path that exhibits the issue.

    Args:
        input: Dataset entry with fields matching production span input.
        hooks: Braintrust eval hooks for span logging and prompt parameters.

    Returns:
        The output from the code path under test.

    """
    # Call the same function/node that production uses.
    # For async functions, use asyncio.run():
    #
    #   result = asyncio.run(some_async_function(**input))
    #
    # For sync functions:
    #
    #   result = some_function(**input)
    #
    raise NotImplementedError("Replace with the actual code path under test")


def issue_repro(output, expected, input=None):
    """Score whether the issue is reproduced (0.0) or resolved (1.0).

    This scorer encodes the specific failure condition from the Linear issue.
    Each dataset row gets a pass/fail signal.

    Args:
        output: Actual output from the task function.
        expected: Expected output from the dataset (optional).
        input: Original input (optional).

    Returns:
        Score: 0.0 if the issue IS present, 1.0 if the issue is NOT present.

    """
    # TODO: Implement the specific failure check for this issue.
    #
    # Examples of failure checks:
    #
    #   # Wrong tool selected
    #   is_failing = output.tool_name != expected.get("tool_name")
    #
    #   # Response contains hallucinated content
    #   is_failing = "<hallucinated_pattern>" in str(output)
    #
    #   # Missing required field
    #   is_failing = not hasattr(output, "required_field") or output.required_field is None
    #
    #   # Incorrect classification
    #   is_failing = output.classification != expected.get("classification")

    is_failing = True  # Replace with actual check

    return Score(
        name="IssueRepro",
        score=0.0 if is_failing else 1.0,
        metadata={
            "issue": "<ISSUE_ID>",
            "failure_detected": is_failing,
            # Add details that help diagnose the failure
        },
    )


create_eval(
    experiment_name="<ISSUE_ID> Baseline",
    module_name=get_module_name(),
    task=task,
    scores=[issue_repro],
    dataset_name="<issue-id>-repro",
    prompts=[PROMPT_UNDER_TEST],
    max_concurrency=1,  # Use 1 if task uses asyncio.run()
)
```

### Key Conventions

1. **`task(input, hooks)`** signature is required by `create_eval()`.
2. **Scorers** return `autoevals.Score` with `name`, `score` (0.0-1.0), and `metadata`.
3. **`create_eval()` at module level** - Braintrust discovers and runs it on import.
4. **`module_name`** = Braintrust project name (e.g., `"dscript"`).
5. **`prompts` list** makes prompts editable in Braintrust UI for experimentation.
6. **`max_concurrency=1`** when the task uses `asyncio.run()` to avoid event loop deadlocks.
7. **Experiment naming**: `<ISSUE_ID> Baseline` for initial repro, `<ISSUE_ID> Fix v1` for fixes.

### Dataset Creation

Datasets are created in Braintrust and populated with production log spans. Use `bt sql` to
find spans, then create a dataset via the Braintrust SDK.

```python
import braintrust

client = braintrust.init_dataset(
    project="dscript",
    name="<issue-id>-repro",
)

# Insert rows extracted from production logs
for span in selected_spans:
    client.insert(
        input=span["input"],
        expected=span.get("expected", span.get("output")),
        metadata={
            "source_span_id": span["id"],
            "issue": "<ISSUE_ID>",
        },
    )

print(client.summarize())
client.close()
```

### Scorer Patterns

**Code-based scorer** (deterministic, fast):
```python
def issue_repro(output, expected, input=None):
    is_failing = <condition that detects the bug>
    return Score(name="IssueRepro", score=0.0 if is_failing else 1.0, metadata={...})
```

**Prompt-based scorer** (LLM judge, for semantic checks):
```python
from app.core.llm import BraintrustPrompt, PromptRunnable

EVAL_PROMPT = BraintrustPrompt(slug="<eval-slug>", version="<version>", project=get_module_name())

def semantic_scorer(output, expected, input=None):
    runner = PromptRunnable(prompt=EVAL_PROMPT, output_structure=EvalResultModel)
    result = asyncio.run(runner.ainvoke({"actual": str(output), "expected": str(expected)}))
    return Score(name="SemanticMatch", score=1.0 if result.decision == "PASS" else 0.0, metadata=result.model_dump())
```

## Prompt Modification Workflow

When modifying prompts stored in Braintrust:

1. **Identify the prompt**: `bt prompts list --project dscript`
2. **View current version**: Use `bt view` or Braintrust UI.
3. **Recommend the change, then STOP** — do NOT write it. The agent must never run `bt-prompt
   create`/`bt-prompt edit` or edit the prompt via the Braintrust UI/API. Print the exact
   `bt-prompt edit <slug> --project dscript` (or `bt-prompt create`) command and **wait** for Todd
   to run it and paste back the new version hex.
4. **Update the version hash** in the `BraintrustPrompt()` reference — only after Todd pastes the new hex.
5. **Re-run the eval** with a new experiment name (e.g., `<ISSUE_ID> Fix v1`).
6. **Compare**: Use Braintrust experiment comparison to see improvement.

When modifying code around the prompt:

1. **Identify the code path**: Trace from the prompt invocation through the codebase.
2. **Make targeted changes**: Modify tool definitions, system prompt construction, or response parsing.
3. **Re-run the eval**: Same eval script, new experiment name.
4. **Compare results**: Verify the scorer shows improvement.

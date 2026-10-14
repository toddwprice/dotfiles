# Transcript: CI Debugging Task (Without Skill)

## Task

"CI is failing on my PR #247. Can you check what's going on? Show me the failing checks and then show me the logs for the failed jobs."

## What I Read

- No files were read for this task. The instructions explicitly stated: "DO NOT actually run any gh commands" and "DO NOT read any skill files." The task was to produce the sequence of commands and explain the workflow, not to execute anything.

## What I Decided

### Approach Selection

I decided to structure the response as a progressive debugging workflow rather than a flat list of commands. The reasoning:

1. **CI debugging is inherently iterative** -- you cannot know which command to run next until you see the output of the previous command. A linear list of commands would be misleading because some commands require dynamic inputs (run IDs, job IDs) from prior outputs.

2. **The user asked for two specific things**: (a) show failing checks and (b) show logs for failed jobs. I mapped these to `gh pr checks` and `gh run view --log-failed` respectively, but included the intermediate steps needed to bridge between them.

### Command Selection Rationale

- **`gh pr checks 247`**: Chosen as the entry point because it directly answers "show me the failing checks" -- it lists all status checks on a PR with their pass/fail status.

- **`gh pr view 247`**: Included for context gathering. When debugging CI, knowing what code changed helps you reason about whether a failure is expected or surprising.

- **`gh run list --branch`**: Necessary bridge command. `gh pr checks` shows check names and statuses but does not directly give you run IDs needed for log retrieval. `gh run list` with the branch filter provides those IDs.

- **`gh run view <run-id>`**: Shows job-level breakdown within a run. Important because a workflow run typically contains multiple jobs and you need to identify which specific job(s) failed.

- **`gh run view <run-id> --log-failed`**: The key command for "show me the logs for the failed jobs." The `--log-failed` flag is more useful than `--log` because it filters to only failed steps, avoiding potentially thousands of lines of passing step output.

- **`gh run view <run-id> --log --job <job-id>`**: Included as a fallback for when `--log-failed` output lacks context. Sometimes the root cause appears in a step that technically passed but produced warnings or partial failures.

- **`gh run rerun <run-id> --failed`**: Included as an action step because the user may want to know what to do after identifying a transient failure.

### What I Excluded

- **`gh api` calls**: While you can hit the GitHub Actions API directly for more granular data, the `gh run` subcommands cover the common case well and are easier to use.
- **`gh pr checks --watch`**: Not relevant since the user is investigating a past failure, not waiting for a pending check.
- **Annotation queries**: GitHub Actions annotations can surface error summaries, but `--log-failed` is more reliable for full context.

### Format Decision

I included a decision tree diagram at the end of the response because CI debugging is branching by nature -- what you do next depends on what you find. The tree makes the conditional logic explicit rather than burying it in prose.

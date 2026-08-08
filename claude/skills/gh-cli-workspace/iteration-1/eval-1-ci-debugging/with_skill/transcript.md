# Transcript: CI Debugging Task with gh-cli Skill

## Task

"CI is failing on my PR #247. Can you check what's going on? Show me the failing checks and then show me the logs for the failed jobs."

## What I Read

### 1. Skill file: `/Users/toddprice/.agents/skills/gh-cli/SKILL.md`

Read the full skill file. Key sections relevant to this task:

- **Decision Tree** -- The table at the top routes "Check CI status or rerun jobs" to the "Actions & CI" section. This immediately told me the right section to focus on.
- **Check CI Status** (within Pull Request Workflows) -- Found `gh pr checks 123` for seeing all checks on a PR, `gh pr checks 123 --watch` for polling, and the JSON variant using `gh pr view 123 --json statusCheckRollup`.
- **Actions & CI** section -- Found `gh run list`, `gh run view <id>`, `gh run view <id> --log-failed`, `gh run view <id> --log`, and `gh run watch`. These are the core commands for the debugging workflow.
- **Output Formatting** section -- Confirmed that `--json` and `--jq` flags are available on most commands for structured output.
- **Reference Files table** -- Noted that `references/actions.md` has full CI/CD details and `references/pull-requests.md` has full PR check details.

### 2. Reference file: `/Users/toddprice/.agents/skills/gh-cli/references/actions.md`

Read the full actions reference. Key details extracted:

- **`gh run list` flags**: `--workflow`, `--branch`, `--status`, `--limit`, `--json`, `--jq`. The `--branch` flag is essential for filtering runs to the PR's branch. Available JSON fields include `databaseId`, `status`, `conclusion`, `headBranch`, `name`.
- **`gh run view` flags**: `--log` (full logs), `--log-failed` (only failed step logs), `--job` (specific job ID), `--exit-status`, `--attempt`. The `--log-failed` flag is the key tool for efficient debugging -- it filters out all the noise from passing steps.
- **`gh run rerun` flags**: `--failed` (rerun only failed jobs), `--job` (rerun specific job), `--debug` (enable debug logging). Useful as a follow-up action once the failure is diagnosed.

### 3. Reference file: `/Users/toddprice/.agents/skills/gh-cli/references/pull-requests.md`

Read the full PR reference. Key details extracted:

- **`gh pr checks` flags**: `--watch`, `--interval`, `--fail-fast`, `--required`, `--json`, `--jq`. The `--required` flag could be useful to focus on only required checks (ignoring optional/informational ones). The `--watch` flag is useful if checks are still in progress.
- **`gh pr view` JSON fields**: Confirmed `statusCheckRollup` is available, which provides check name, status, and conclusion in structured format.

## What I Decided

### Command sequence rationale

I designed a 7-step progressive debugging workflow that goes from broad to narrow:

1. **Start with `gh pr checks 247`** -- This is the most direct answer to "what checks are failing?" It maps 1:1 to the user's first request ("show me the failing checks"). I chose this as step 1 because it requires zero prior knowledge (just the PR number) and gives an immediate overview.

2. **Add the JSON/jq variant** -- The structured output version (`gh pr view 247 --json statusCheckRollup --jq ...`) provides the same data in a more parseable format. I included this because when there are many checks, scanning a formatted table can be tedious, and the TSV output is easier to filter programmatically.

3. **Use `gh run list --branch`** -- The skill file showed that `gh pr checks` gives check names and links, but to use `gh run view` (which needs a run ID), you need to get the numeric database ID. The `gh run list` command with `--branch` filter bridges this gap. I used the actual branch name from the git status (`cnvs-540-screen-recording-loop-android`).

4. **`gh run view <run-id>` for job breakdown** -- Before diving into logs, seeing which jobs within a workflow failed helps narrow the scope. A workflow might have 5 jobs but only 1 failed.

5. **`gh run view <run-id> --log-failed` for actual errors** -- This is the key command that answers the user's second request ("show me the logs for the failed jobs"). I specifically chose `--log-failed` over `--log` because full logs can be enormous (thousands of lines), while `--log-failed` filters to just the relevant failure output.

6-7. **Fallback commands** -- I included `--job` and `--log` as escalation paths in case `--log-failed` does not provide enough context. This anticipates common scenarios where the failure cause is not immediately visible in the failed step output alone.

### Interpretation guidance rationale

I included detailed interpretation tables because raw CI output can be ambiguous. For example:
- A "cancelled" status could mean human cancellation or cascading failure -- the correct next action differs.
- Multiple failing checks could be independent issues or a single root cause -- the debugging approach differs.
- The "next action" table at the end connects diagnosis to resolution, which is what the user ultimately needs.

### What I did NOT include

- I did not include `gh run rerun` in the primary sequence because the user asked to diagnose, not fix. However, I mentioned it in the interpretation section as a follow-up action for flaky tests.
- I did not include `gh run download` for artifacts because the user did not mention needing test artifacts, though this would be a natural next step if test result files are needed.
- I did not include `gh workflow view` because the user's question is about a specific PR's failures, not about understanding the workflow definition itself.

# Transcript: Issue Triage Task (with skill)

## What I Read

1. **`/Users/toddprice/.agents/skills/gh-cli/SKILL.md`** -- The main gh-cli skill file. Key sections used:
   - **Issue Workflows** (lines 166-228): Provided the core patterns for `gh issue list`, `gh issue close`, and JSON/jq output formatting.
   - **Bulk Operations** (lines 408-423): Showed the `xargs -I {}` pattern for closing multiple issues in a pipeline.
   - **Output Formatting** (lines 373-406): Confirmed available JSON fields for issues (`number`, `title`, `assignees`, `labels`, `createdAt`) and jq patterns for tab-separated output.
   - **Safety Notes** (lines 427-434): Noted that `gh issue delete` is irreversible (close is fine -- issues can be reopened).

2. **`/Users/toddprice/.agents/skills/gh-cli/references/issues.md`** -- Full issue command reference. Key sections used:
   - **List flags** (lines 43-63): Confirmed `--search`, `--label`, `--state`, `--limit`, `--json`, `--jq` flags and their behavior. Confirmed available JSON fields include `assignees`.
   - **Close flags** (lines 105-115): Confirmed `--comment` and `--reason` flags. Learned that `--reason` accepts `completed` (default) or `not planned`.

## Decisions Made

### How to filter by "last month"
- `gh issue list` has no native `--since` or `--created-after` flag.
- The `--search` flag accepts GitHub's search query syntax, which supports `created:>=YYYY-MM-DD`.
- Today is 2026-04-08, so "last month" = `created:>=2026-03-08`.
- I chose `--search` over `gh api` because it keeps the command simpler and stays within the `gh issue list` abstraction.

### How to output as a table
- Used `--json number,title,assignees` with `--jq` to format as TSV.
- Considered `--template` (Go templates) but jq is more widely understood and the skill file's examples predominantly use jq.
- Added a header row in the jq expression for readability.

### Handling assignees (array of objects)
- The `assignees` JSON field is an array of user objects with `.login` properties.
- Used `map(.login) | join(",")` to flatten to a string.
- Identified the edge case where `join(",")` on an empty array produces `""` not `null`, making the `//` alternative operator ineffective. Documented both the simple version and the correct version.

### How to find bug+stale issues
- `--label bug,stale` applies AND logic (both labels required). Confirmed this is standard `gh` behavior.
- Reused the same `--search "created:>=2026-03-08"` filter to stay within the "last month" scope.

### How to bulk close
- Used the `xargs -I {}` pattern from the skill file's Bulk Operations section.
- Chose `--reason "not planned"` over the default `completed` because we're cleaning up stale bugs, not marking them as fixed.
- Added a meaningful comment explaining the closure and inviting reopening.

### Limit setting
- Default is 30, which is too low for a triage operation. Set to 200.
- Noted the GitHub API hard cap of 1000 and the need for `gh api --paginate` if that's exceeded.

### Safety considerations
- Emphasized running Step 2 (list) before Step 3 (close) as a dry run.
- Called out rate limiting risks for large batches.
- Noted that close is reversible (reopen), but the comment is permanent.
- Documented permission requirements (write access needed).

## Files Created
- `/Users/toddprice/.agents/skills/gh-cli-workspace/iteration-1/eval-2-issue-triage/with_skill/outputs/response.md` -- The complete command sequence with explanations and edge cases.
- `/Users/toddprice/.agents/skills/gh-cli-workspace/iteration-1/eval-2-issue-triage/with_skill/transcript.md` -- This file.

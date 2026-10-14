# Transcript: Issue Triage Task (Without Skill)

## Task
Find all open issues labeled "bug" created in the last month, display as a table with number/title/assignee, then close all that are also labeled "stale" with a cleanup comment.

## What I Read
- No files were read for this task. The task is purely about `gh` CLI knowledge, so I worked from my built-in understanding of the GitHub CLI.

## Decisions Made

### 1. How to filter by date range
I chose `--search "created:>=2026-03-08"` over other approaches because:
- `gh issue list` does not have a native `--since` or `--created-after` flag.
- The `--search` flag passes through to GitHub's search API, which supports date qualifiers like `created:>=YYYY-MM-DD`.
- I calculated "last month" as 2026-03-08 since today is 2026-04-08.

### 2. How to format as a table
I chose `--json` + `--jq` + `column -t` over:
- The default `gh` table output (which doesn't let you pick columns precisely or handle missing assignees).
- `--template` (Go template syntax, more verbose and harder to read).
- `jq` as a separate piped command (using `--jq` inline is cleaner).

### 3. How to handle the assignee field
The `assignees` field is an array of objects. I used `map(.login) | join(", ")` to flatten it to a string, and `// "unassigned"` as a jq alternative operator fallback for empty arrays (which produce empty strings, which are falsy in jq).

### 4. How to combine the "bug" AND "stale" label filter
I used `--label "bug" --label "stale"` which applies AND logic. I verified in my knowledge that multiple `--label` flags are treated as AND conditions in `gh issue list`.

### 5. How to close with a comment in one step
I used `gh issue close <number> --comment "..."` which combines both operations in a single command. This is more efficient than separate `gh issue comment` + `gh issue close` calls.

### 6. Script structure
I provided three versions:
- Individual commands explained step by step (for understanding).
- A complete bash script (for practical use).
- Edge cases and gotchas (for production readiness).

### 7. Edge cases I identified
I enumerated 10 edge cases covering: label case sensitivity, UTC date interpretation, pagination limits, empty assignees handling, rate limiting, AND vs OR label logic, repo context awareness, dry-run workflow, reversibility, and gh version compatibility for the `--comment` flag.

## Confidence Assessment
High confidence in the command structure. The main area of uncertainty is whether `--search` combined with `--label` works as expected or if they conflict -- in practice, `--label` is a filter applied alongside `--search`, so they should compose correctly. If there were an issue, the fallback would be to move the label filter into the search string: `--search "label:bug created:>=2026-03-08"`.

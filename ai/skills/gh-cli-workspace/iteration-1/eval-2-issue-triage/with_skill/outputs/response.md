# Issue Triage: Find Open Bug Issues and Close Stale Ones

## Step-by-Step Command Sequence

### Step 1: List all open issues labeled "bug" created in the last month as a table

```bash
gh issue list \
  --label bug \
  --state open \
  --search "created:>=2026-03-08" \
  --limit 200 \
  --json number,title,assignees \
  --jq '
    ["NUMBER", "TITLE", "ASSIGNEE"],
    (.[] | [
      .number,
      .title,
      (.assignees | map(.login) | join(",") // "unassigned")
    ]) | @tsv
  '
```

### Step 2: Identify issues that have BOTH "bug" and "stale" labels

```bash
gh issue list \
  --label bug,stale \
  --state open \
  --search "created:>=2026-03-08" \
  --limit 200 \
  --json number \
  --jq '.[].number'
```

### Step 3: Close each bug+stale issue with a comment

```bash
gh issue list \
  --label bug,stale \
  --state open \
  --search "created:>=2026-03-08" \
  --limit 200 \
  --json number \
  --jq '.[].number' | \
  xargs -I {} gh issue close {} \
    --comment "Closing as part of stale bug cleanup. If this issue is still relevant, please reopen it with additional context." \
    --reason "not planned"
```

---

## Explanation of Flags, Expressions, and Decisions

### Flag choices

| Flag / Option | Why |
|---|---|
| `--label bug` | Filters to only issues with the "bug" label. |
| `--label bug,stale` | When comma-separated, `gh issue list` requires ALL listed labels to be present (AND logic), so this correctly targets issues that have both "bug" and "stale". |
| `--state open` | Only open issues (this is actually the default, but being explicit improves readability and makes intent clear). |
| `--search "created:>=2026-03-08"` | GitHub search qualifier to filter issues created on or after March 8, 2026 (one month ago from today, April 8, 2026). The `--search` flag accepts GitHub's full search query syntax, which is more powerful than the built-in flags for date filtering. |
| `--limit 200` | Default limit is 30, which would silently truncate results. 200 provides a reasonable upper bound; adjust upward if the repo is very active. |
| `--json number,title,assignees` | Requests structured JSON output with exactly the fields we need. `assignees` is an array of user objects. |
| `--jq '...'` | Processes the JSON into tab-separated values for clean table output. |
| `--reason "not planned"` | Sets the close reason to "not planned" rather than "completed", which is semantically correct for stale bug cleanup (the bug wasn't fixed, it's being triaged away). |

### jq expression breakdown

```jq
["NUMBER", "TITLE", "ASSIGNEE"],
```
Emits a header row first.

```jq
(.[] | [
  .number,
  .title,
  (.assignees | map(.login) | join(",") // "unassigned")
]) | @tsv
```
- `.[]` iterates over each issue in the array.
- `.assignees | map(.login)` extracts just the login usernames from the assignees array of objects.
- `join(",")` combines multiple assignees into a comma-separated string.
- `// "unassigned"` is jq's alternative operator: if the left side is `false` or `null`, use "unassigned" instead. This handles issues with no assignees.
- `@tsv` formats each array as a tab-separated line, giving clean columnar output.

**Note on the `//` operator:** There is a subtlety here. `join(",")` on an empty array produces `""` (empty string), which is falsy in jq only if it's `null` or `false` -- an empty string is actually truthy in jq. So a more robust version would be:

```jq
(.assignees | if length == 0 then "unassigned" else map(.login) | join(",") end)
```

### Why `xargs -I {}` for bulk closing

- `xargs -I {}` reads each issue number from stdin and substitutes it into the `gh issue close` command.
- This runs one `gh issue close` call per issue, which is necessary because `gh issue close` only accepts a single issue number.
- The `-I {}` pattern is shown in the gh CLI skill's bulk operations section and is the standard approach for this.

---

## Edge Cases and Gotchas

### 1. Pagination / limit truncation
The default `--limit` is 30. If there are more than 30 matching issues, you'll silently miss some. Always set `--limit` to a value higher than expected results. There is no `--paginate` flag for `gh issue list` (unlike `gh api`). If you have more than 1000 issues (the GitHub API hard cap), you'll need to use `gh api` with `--paginate` instead.

### 2. Date boundary precision
`created:>=2026-03-08` uses calendar dates, not timestamps. An issue created at 11:59 PM on March 7 will be excluded, while one at 12:01 AM on March 8 will be included. Both boundaries are in UTC. If your local timezone differs significantly, you might miss issues near the boundary.

### 3. The `//` jq operator vs empty strings
As noted above, `join(",")` on an empty assignees array produces `""`, not `null`. In jq, `"" // "unassigned"` evaluates to `""` because empty strings are truthy. Use the `if length == 0` pattern for correctness.

### 4. Label name case sensitivity
GitHub labels are case-insensitive in the API, so `--label Bug` and `--label bug` should both work. However, if the actual label is named differently (e.g., `type:bug` or `kind/bug`), you'll get no results. Verify label names first with:
```bash
gh label list --search bug
```

### 5. Rate limiting on bulk close
Each `gh issue close` call is a separate API request. If you're closing dozens of issues, you could hit GitHub's secondary rate limits (which throttle rapid mutation requests). `xargs` runs sequentially by default, which helps, but for very large batches consider adding a small delay:
```bash
... | xargs -I {} sh -c 'gh issue close {} --comment "..." --reason "not planned" && sleep 1'
```

### 6. Dry run first
Before running the bulk close in Step 3, always run Step 2 first and review the list of issue numbers. This confirms you're targeting the right issues. There's no undo for closing with a comment (you can reopen, but the comment is permanent).

### 7. Issues with many labels
The `--label bug,stale` filter requires both labels. An issue labeled `bug` but not `stale` won't be closed. An issue labeled `stale` but not `bug` won't be closed. This is the correct behavior for the stated task.

### 8. Repository context
These commands infer the repository from the current directory's git remote. If you're not in the repo directory, add `--repo owner/repo` to every command.

### 9. The `--search` flag combines with other filters
When using `--search` alongside `--label` and `--state`, they are ANDed together. This is the desired behavior -- we want open issues that are labeled bug AND were created in the last month.

### 10. Permission requirements
Closing issues requires write access to the repository. If you only have read (triage) access, the close commands will fail with a 403 error.

# Issue Triage: Find Open Bug Issues and Close Stale Ones

## Step 1: List all open issues labeled "bug" created in the last month as a table

```bash
gh issue list \
  --label "bug" \
  --state open \
  --search "created:>=2026-03-08" \
  --json number,title,assignees \
  --jq '.[] | [.number, .title, (.assignees | map(.login) | join(", ") // "unassigned")] | @tsv' \
  --limit 500 | column -t -s $'\t'
```

### Explanation of flags and expressions

- `--label "bug"` -- Filters to only issues with the "bug" label.
- `--state open` -- Only shows open issues (this is the default, but being explicit is clearer).
- `--search "created:>=2026-03-08"` -- Uses GitHub's search qualifier syntax to restrict to issues created on or after March 8, 2026 (one month ago from today, April 8, 2026). The `--search` flag passes through to GitHub's issue search API, which supports date range qualifiers.
- `--json number,title,assignees` -- Requests structured JSON output with only the fields we need.
- `--jq '...'` -- Transforms the JSON into tab-separated values:
  - `.[]` iterates over each issue.
  - `[.number, .title, ...]` builds an array of columns per row.
  - `.assignees | map(.login) | join(", ")` extracts assignee login names and joins them with commas if there are multiple assignees.
  - `// "unassigned"` provides a fallback when the assignees array is empty (the `//` operator in jq is the "alternative" operator -- it returns the right side when the left side is `false` or `null`).
  - `@tsv` formats each array as a tab-separated line.
- `--limit 500` -- Raises the default limit of 30 to catch all matching issues. Adjust higher if you expect more.
- `| column -t -s $'\t'` -- Formats the tab-separated output into an aligned table in the terminal.

**Alternative for a header row**: If you want a header, prepend it:

```bash
printf "NUMBER\tTITLE\tASSIGNEE\n" && gh issue list \
  --label "bug" \
  --state open \
  --search "created:>=2026-03-08" \
  --json number,title,assignees \
  --jq '.[] | [.number, .title, (.assignees | map(.login) | join(", ") // "unassigned")] | @tsv' \
  --limit 500 | column -t -s $'\t'
```

**Note on the empty-assignees edge case with jq**: The expression `map(.login) | join(", ")` on an empty array produces `""` (empty string), which is falsy in jq, so `// "unassigned"` correctly kicks in. However, if there is at least one assignee, `join` produces a non-empty string and the fallback is skipped. This handles both cases correctly.

---

## Step 2: Identify issues that also have the "stale" label

```bash
gh issue list \
  --label "bug" \
  --label "stale" \
  --state open \
  --search "created:>=2026-03-08" \
  --json number \
  --jq '.[].number' \
  --limit 500
```

### Explanation

- `--label "bug" --label "stale"` -- When you pass `--label` multiple times, `gh` treats them as an AND condition, returning only issues that have **both** labels. This is exactly what we want: issues labeled both "bug" and "stale".
- `--json number --jq '.[].number'` -- Extracts just the issue numbers so we can iterate over them in the next step.

---

## Step 3: Close each stale bug issue with a comment

```bash
gh issue list \
  --label "bug" \
  --label "stale" \
  --state open \
  --search "created:>=2026-03-08" \
  --json number \
  --jq '.[].number' \
  --limit 500 | while read -r issue_num; do
    echo "Closing issue #${issue_num}..."
    gh issue close "$issue_num" \
      --comment "Closing as part of stale bug cleanup. If this issue is still relevant, please reopen it or file a new issue."
done
```

### Explanation

- The pipeline reads issue numbers one per line and iterates with `while read`.
- `gh issue close "$issue_num"` -- Closes the issue.
- `--comment "..."` -- Adds a comment at the same time as closing. The `--comment` flag on `gh issue close` is the cleanest way to do both in a single API call rather than running `gh issue comment` separately followed by `gh issue close`.
- Using `echo` before each close provides a progress indicator so you can see what's happening.

---

## Complete One-Liner Script

Putting it all together as a script:

```bash
#!/usr/bin/env bash
set -euo pipefail

SINCE_DATE="2026-03-08"

echo "=== Open bug issues created since ${SINCE_DATE} ==="
echo ""

# Step 1: Display the table
(
  printf "NUMBER\tTITLE\tASSIGNEE\n"
  printf -- "------\t-----\t--------\n"
  gh issue list \
    --label "bug" \
    --state open \
    --search "created:>=${SINCE_DATE}" \
    --json number,title,assignees \
    --jq '.[] | [.number, .title, (.assignees | map(.login) | join(", ") // "unassigned")] | @tsv' \
    --limit 500
) | column -t -s $'\t'

echo ""
echo "=== Closing stale bug issues ==="
echo ""

# Step 2: Close stale ones with a comment
STALE_ISSUES=$(gh issue list \
  --label "bug" \
  --label "stale" \
  --state open \
  --search "created:>=${SINCE_DATE}" \
  --json number \
  --jq '.[].number' \
  --limit 500)

if [ -z "$STALE_ISSUES" ]; then
  echo "No stale bug issues found. Nothing to close."
else
  echo "$STALE_ISSUES" | while read -r issue_num; do
    echo "Closing issue #${issue_num}..."
    gh issue close "$issue_num" \
      --comment "Closing as part of stale bug cleanup. If this issue is still relevant, please reopen it or file a new issue."
  done
  echo ""
  echo "Done. Closed $(echo "$STALE_ISSUES" | wc -l | tr -d ' ') stale bug issues."
fi
```

---

## Edge Cases and Gotchas

### 1. The `--label` flag requires exact label name matches
Label matching is case-sensitive. If the repo uses "Bug" instead of "bug", or "Stale" instead of "stale", the query will return no results. Run `gh label list` first to verify exact label names if you're unsure.

### 2. The `--search` date filter uses the GitHub search API
The `created:>=YYYY-MM-DD` qualifier works because `--search` passes through to GitHub's search syntax. This is **not** a native `gh` filter -- it delegates to the GitHub search API. Be aware that:
- The search index can have a slight delay (usually seconds, occasionally minutes) compared to the REST API.
- The date is interpreted in UTC, not your local timezone. An issue created at 11 PM ET on March 7 would show as March 8 UTC and would be included.

### 3. Pagination / `--limit`
The default limit is 30 issues. If your repo has more than 30 open bug issues from the last month, you'll silently miss some. Always set `--limit` to a value higher than your expected count. The maximum is 1000 per call. If you might have more than 1000, you'd need to paginate with `--json` and `gh api` with `--paginate` instead.

### 4. Empty assignees array vs. null
In `gh`'s JSON output, unassigned issues return `"assignees": []` (empty array), not `null`. The jq expression `map(.login) | join(", ")` on an empty array produces `""`, and `"" // "unassigned"` correctly falls back because empty string is falsy in jq. This works correctly, but it's worth knowing why.

### 5. Rate limiting
If you have many stale issues to close, the `while read` loop makes one API call per issue. GitHub's API rate limit is 5,000 requests/hour for authenticated users. Closing 100 issues uses 100 requests (or 200 if `--comment` triggers a separate call internally, though `gh issue close --comment` batches this). You're unlikely to hit the limit for normal triage, but be aware for very large repos.

### 6. Multiple `--label` flags are AND, not OR
Passing `--label "bug" --label "stale"` returns issues with **both** labels. This is the behavior we want. If you needed OR logic (issues with "bug" OR "stale"), you'd need to use `--search "label:bug label:stale"` -- but be aware that search syntax labels are also AND by default. True OR requires separate queries or the GitHub search `OR` operator: `--search "label:bug OR label:stale"`.

### 7. Repo context
`gh issue list` operates on the repo determined by the current git remote. If you're in a monorepo or a fork, verify with `gh repo view --json nameWithOwner -q .nameWithOwner` that you're targeting the correct repository. You can also explicitly specify `--repo owner/repo` to be safe.

### 8. Dry run first
Before running the close loop, it's wise to first run Step 2 alone to see the list of issues that **would** be closed. Review the output before proceeding with Step 3. The script above naturally supports this: run the table display first, then decide whether to proceed.

### 9. Re-opening closed issues
`gh issue close` is reversible. Closed issues can be reopened with `gh issue reopen <number>`. The comment left on each issue mentions this, which is good practice for team communication.

### 10. The `--comment` flag on `gh issue close`
This flag was added in gh v2.14.0+. If you're on an older version of `gh`, you'd need to split into two commands:
```bash
gh issue comment "$issue_num" --body "Closing as part of stale bug cleanup..."
gh issue close "$issue_num"
```
Check your version with `gh --version` if you encounter errors.

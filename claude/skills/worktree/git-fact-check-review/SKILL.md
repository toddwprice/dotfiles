---
name: "git-fact-check-review"
allowed-tools: Bash(gh:*), Bash(git show:*), Bash(git fetch:*), Bash(cat:*), Bash(mktemp:*), Read, Grep, Glob, Agent
description: Fact-check PR review comments against the actual code and codebase patterns.
---

# Fact-Check PR Review Comments

Fact-check review comments on a GitHub pull request, verifying claims against the actual code and
established codebase patterns. Works in two modes depending on the source of the comments.

## Arguments

$ARGUMENTS format depends on the mode:

**Mode 1 — Fact-check published GitHub comments by specific reviewers:**
```
<PR_NUMBER> <REVIEWER_NAMES...>
```
Examples:
- `/git:fact_check_review 23029 snkutkoski`
- `/git:fact_check_review 23029 steven sam`
- `/git:fact_check_review 23029 snkutkoski samcdavid`

**Mode 2 — Fact-check your own unpublished review from the current conversation:**
```
<PR_NUMBER> context
```
Examples:
- `/git:fact_check_review 23029 context`

The keyword `context` tells the command to look for an unpublished review written earlier in this
session (e.g., from `/git:review_pr`) rather than fetching comments from GitHub.

## Step 1: Determine the mode

Parse $ARGUMENTS:
- If any argument (after the PR number) is exactly `context` (case-insensitive), use **context
  mode**.
- Otherwise, treat all arguments after the PR number as reviewer names and use **GitHub mode**.

## Step 2: Identify the comments to fact-check

### GitHub mode:
1. Fetch PR metadata using `gh pr view`.
2. Fetch all review comments using `gh api repos/{owner}/{repo}/pulls/{pr}/comments`.
3. Filter to comments authored by the specified reviewers. Match on:
   - Exact GitHub login match (case-insensitive)
   - First name prefix match against the login (e.g., "steven" matches "snkutkoski" only if no
     better match — prefer checking the GitHub user's display name via `gh api users/{login}`)
   - If a name is ambiguous (matches multiple commenters), ask the user to clarify.
4. If no comments are found for any specified reviewer, report this and stop.

### Context mode:
1. Locate the unpublished review from the current conversation.
2. Extract the file path, line number, and comment body for each comment.
3. If no review is found in the conversation, tell the user and stop.

## Step 3: Fetch the source code from the PR branch

For each file referenced by the filtered comments:
1. Fetch the file content from the PR's head branch using `git show origin/{branch}:{path}`.
2. If the branch isn't available locally, run `git fetch origin {branch}` first.

## Step 4: Fact-check each comment

For each comment, verify the claims by:

1. **Read the actual code** at the lines referenced by the comment.
2. **Verify factual claims** — Does the code actually do what the comment says it does? Are the
   function names, behaviors, and edge cases described accurately?
3. **Check codebase patterns** — Use the Agent tool with `codebase-pattern-finder` to search for
   similar patterns across the codebase. Determine whether the suggestion aligns with or contradicts
   established conventions. For example:
   - If the comment suggests a different error handling approach, find how similar cases are handled
     elsewhere.
   - If the comment flags a potential issue, check if the same pattern exists (and is accepted)
     in analogous code.
4. **Assess each comment** with one of:
   - **Accurate and actionable** — The claim is correct and the suggestion aligns with codebase
     patterns. The PR author should address it.
   - **Accurate but non-actionable** — The claim is correct, but the codebase already accepts this
     pattern elsewhere. The reviewer may want to soften or withdraw.
   - **Partially accurate** — Some claims are correct but there are nuances or inaccuracies that
     should be clarified.
   - **Inaccurate** — The claim is factually wrong based on the code.

Use parallel Agent calls when checking patterns for multiple independent comments.

## Step 5: Present findings to the user

Present a summary table:

| # | Comment topic | Accurate? | Aligns with codebase? | Recommended action |
|---|--------------|-----------|----------------------|-------------------|
| 1 | ...          | ...       | ...                  | ... |

Include a brief explanation for each row. Then proceed based on the mode:

### Context mode (user is the reviewer, pre-publish):

Present updated versions of each comment incorporating the fact-check findings:
- For **accurate and actionable** comments: keep as-is or strengthen with codebase evidence.
- For **accurate but non-actionable** comments: suggest softening the language or removing.
- For **partially accurate** comments: suggest revised wording that corrects inaccuracies.
- For **inaccurate** comments: recommend removing and explain why.

Ask the user to confirm the final set of comments. Then offer to publish the filtered review
directly to GitHub. If the user agrees:

1. Ask for the review event type: APPROVE, REQUEST_CHANGES, or COMMENT.
2. Build the review JSON payload containing only the approved comments:
   ```json
   {
     "body": "Overall review summary in markdown",
     "event": "APPROVE|REQUEST_CHANGES|COMMENT",
     "comments": [
       {
         "path": "relative/path/to/file.ext",
         "line": 42,
         "side": "RIGHT",
         "body": "Comment text with optional AI agent instructions in <details> block"
       }
     ]
   }
   ```
3. Write the JSON to a temp file and publish using:
   ```bash
   gh api repos/{owner}/{repo}/pulls/{pull_number}/reviews --input /path/to/review.json
   ```
4. Report the result with a link to the published review.

If the user declines to publish now, the updated comments remain in the conversation for later
use with `/git:publish_review`.

### GitHub mode (user is the author or observer, post-publish):

Ask the user if they want to post reply comments to each thread. If yes, for each comment reply
in the same thread using:
```bash
gh api repos/{owner}/{repo}/pulls/{pr}/comments/{comment_id}/replies -f body="..."
```

Each reply must:
- Start with `**AI fact check:**` to clearly denote it as AI-generated.
- Be concise (2-4 sentences typical).
- State whether the claim is accurate.
- Cite specific codebase evidence (e.g., "TrackSplitter uses the same pattern at line 98").
- Note any nuances or corrections without being dismissive of the original comment.
- When a comment is accurate but non-actionable due to existing patterns, acknowledge the
  observation while explaining the established convention.

Save comment bodies to temp files when posting to avoid shell quoting issues with markdown.

## Important Notes

- **Always confirm with the user** before posting anything to GitHub or modifying review content.
- When posting replies, write from the perspective of the account holder, using the "AI fact check"
  prefix to distinguish AI-generated content.
- Do not editorialize or add opinions beyond what the code and patterns support.
- If a comment is a question rather than an assertion, the fact-check should answer the question
  based on codebase evidence.

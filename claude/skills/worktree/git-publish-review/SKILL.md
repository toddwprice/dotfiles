---
name: "git-publish-review"
allowed-tools: Bash(gh:*), Bash(git:*), Bash(cat:*), Bash(mktemp:*)
description: Publish a PR review from the current session context to GitHub.
---

# Publish PR Review to GitHub

This command publishes a PR review that has been written in the current conversation to GitHub using the `gh api` command. It supports both creating new review comments and replying to existing comment threads.

## Prerequisites

A PR review must already exist in the conversation context. This review should include:
- An overall review summary/body
- File/line specific comments (optional but recommended)
- Thread replies to existing comments (optional)
- A review decision (APPROVE, REQUEST_CHANGES, or COMMENT)

## Process

1. **Identify the review** in the current conversation context
2. **Extract review components**:
   - Overall review body (the main summary text)
   - File/line specific NEW comments with their locations
   - Thread replies (comments marked as replies to existing threads with `in_reply_to` comment IDs)
   - Review event type (APPROVE, REQUEST_CHANGES, COMMENT)
3. **Determine the PR number** from $ARGUMENTS or the current branch
4. **Fetch existing review comments** to validate thread reply targets
5. **Format and publish** using `gh api`

## Review JSON Structure

The review must be formatted as JSON for the GitHub API:

```json
{
  "body": "Overall review summary in markdown",
  "event": "APPROVE|REQUEST_CHANGES|COMMENT",
  "comments": [
    {
      "path": "relative/path/to/file.py",
      "line": 42,
      "side": "RIGHT",
      "body": "Human-readable comment text\n\n<details>\n<summary>Instructions for AI Agents</summary>\n\nActionable instructions for AI coding agents to implement the suggested change.\n\n</details>\n"
    }
  ]
}
```

## Thread Reply JSON Structure

Thread replies are published separately using the pull request comments API:

```json
{
  "body": "Reply text",
  "in_reply_to": 12345
}
```

### Field Definitions

| Field | Required | Description |
|-------|----------|-------------|
| `body` | Yes | The overall review comment (supports markdown) |
| `event` | Yes | One of: `APPROVE`, `REQUEST_CHANGES`, `COMMENT` |
| `comments` | No | Array of file/line specific NEW comments |
| `comments[].path` | Yes | File path relative to repository root |
| `comments[].line` | Yes | Line number as shown in the PR diff |
| `comments[].side` | Yes | `RIGHT` for new/changed lines, `LEFT` for deleted lines |
| `comments[].body` | Yes | The comment text (supports markdown) |

## Your Task

1. **Find the review** in the current conversation that needs to be published
2. **Extract the PR number**: Use $ARGUMENTS if provided, otherwise determine from the current branch or ask the user
3. **Separate findings into two categories**:
   - **Thread replies**: Comments marked with `[REPLY]` and a comment ID — these reply to existing threads
   - **New comments**: All other file/line specific findings — these become new review comments
4. **Fetch existing comments** to validate reply targets:
   ```bash
   gh api repos/{owner}/{repo}/pulls/{pull_number}/comments --paginate --jq '.[] | {id, path, line, in_reply_to_id}'
   ```
   Verify that each `in_reply_to` target comment ID actually exists. Warn the user if any target IDs are invalid.
5. **Create a temporary JSON file** for the main review payload (body + event + new comments only)
6. **Show the user** the complete review that will be published, including:
   - The main review (body, event, new comments)
   - Thread replies (listed separately with the target comment ID and reply text)
   - Ask for confirmation before proceeding
7. **Publish the main review** (if it has a body or new comments):
   ```bash
   gh api repos/{owner}/{repo}/pulls/{pull_number}/reviews --input /path/to/review.json
   ```
8. **Publish thread replies** (one per existing thread):
   ```bash
   gh api repos/{owner}/{repo}/pulls/{pull_number}/comments -f body="Reply text" -F in_reply_to=12345
   ```
   Publish each reply individually. If any reply fails, report the error but continue with remaining replies.
9. **Report the result** to the user with a link to the published review

## Formatting AI Agent Instructions in Line-Level Comments

When a line-level comment includes AI agent instructions, the comment `body` must combine the
human-readable feedback with the AI agent instructions wrapped in a collapsible `<details>` block.
The format is:

```markdown
Human-readable review comment here.

<details>
<summary>Instructions for AI Agents</summary>

Specific, actionable instructions that an AI coding agent can follow to implement the change.

</details>
```

**Rules:**
- Only line-level comments (those with a `path` and `line`) should include the AI agent instructions
  section. The overall review `body` and any PR-level commentary must **not** include it.
- Thread replies should **not** include the AI agent instructions section — they are follow-ups to
  existing discussions, not new actionable items.
- Preserve the reviewer's human-readable comment exactly as written — do not merge it into the
  `<details>` block.
- Ensure there is a blank line before `<details>` and after `</details>` so GitHub renders the
  markdown correctly.

## Important Notes

- **Always confirm with the user** before publishing the review to GitHub
- **Validate the PR exists** before attempting to publish
- **Validate reply targets** — confirm that comment IDs for thread replies exist on the PR
- **Handle errors gracefully** and report any issues to the user
- File paths in comments must be relative to the repository root
- Line numbers must correspond to lines visible in the PR diff
- The `side` field should be `RIGHT` for comments on added/modified lines (most common case)
- Thread replies are published via the comments endpoint, NOT the reviews endpoint — they are separate API calls

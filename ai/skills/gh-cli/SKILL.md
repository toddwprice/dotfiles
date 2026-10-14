---
name: gh-cli
description: >
  GitHub CLI (gh) for interacting with GitHub from the terminal — repositories, issues, pull requests,
  Actions, search, and the GitHub API. Use this skill whenever the user wants to create/view/edit/merge
  pull requests, manage issues, check CI status, search GitHub, interact with releases, manage labels,
  or perform any GitHub operation from the command line. Also use when you need to look up gh command
  syntax, flags, or JSON output fields. Trigger even for simple requests like "open a PR" or "check
  CI" — the workflow guidance and flag reference prevent common mistakes.
---

# GitHub CLI (gh)

Workflow-oriented guide for GitHub CLI operations. This skill provides decision logic and common
patterns in this file, with full command references in `references/`.

## Before You Start

```bash
# Verify authentication
gh auth status

# If not authenticated
gh auth login
```

When operating on a repo, `gh` infers the repo from the current git remote. To target a different
repo, pass `--repo owner/repo` to any command.

## Decision Tree: What Are You Trying to Do?

| Goal | Go to |
|------|-------|
| Create, review, merge, or check a PR | [Pull Request Workflows](#pull-request-workflows) |
| Create, triage, or close issues | [Issue Workflows](#issue-workflows) |
| Check CI status or rerun jobs | [Actions & CI](#actions--ci) |
| Search code, issues, PRs, or repos | [Search](#search) |
| Make raw API calls or GraphQL queries | [API Requests](#api-requests) |
| Manage repos, releases, labels, gists | Read `references/repositories.md` or `references/misc.md` |

---

## Pull Request Workflows

### Create a PR

```bash
# Basic — uses current branch, targets default branch
gh pr create --title "Add widget feature" --body "Implements widget rendering"

# Draft PR
gh pr create --draft --title "WIP: Widget feature"

# With reviewers and labels
gh pr create --title "Fix auth bug" \
  --reviewer alice,bob \
  --label bug,auth \
  --body "Fixes #123"

# Link to issue (auto-closes on merge)
gh pr create --title "Fix login crash" --body "Closes #456"

# From a specific base branch
gh pr create --base develop --title "Feature X"

# Body from file (useful for templates)
gh pr create --title "Release v2.0" --body-file .github/PULL_REQUEST_TEMPLATE.md
```

### View & Inspect a PR

```bash
# Summary view
gh pr view 123

# With comments
gh pr view 123 --comments

# Open in browser
gh pr view 123 --web

# Get specific fields as JSON
gh pr view 123 --json title,state,author,reviewDecision,statusCheckRollup

# Just the diff
gh pr diff 123

# List changed files only
gh pr diff 123 --name-only
```

### Review a PR

```bash
# Approve
gh pr review 123 --approve --body "LGTM!"

# Request changes
gh pr review 123 --request-changes --body "Please fix the null check on line 42"

# Comment (no approval/rejection)
gh pr review 123 --comment --body "Have you considered using a map here?"
```

### Check CI Status

```bash
# See all checks for a PR
gh pr checks 123

# Watch checks in real-time (polls until done)
gh pr checks 123 --watch

# Get check status as JSON
gh pr view 123 --json statusCheckRollup \
  --jq '.statusCheckRollup[] | [.name, .status, .conclusion] | @tsv'
```

### Merge a PR

```bash
# Interactive merge (prompts for method)
gh pr merge 123

# Squash merge + delete branch (most common)
gh pr merge 123 --squash --delete-branch

# Merge commit
gh pr merge 123 --merge --delete-branch

# Rebase merge
gh pr merge 123 --rebase --delete-branch

# Auto-merge when checks pass
gh pr merge 123 --auto --squash --delete-branch
```

### Other PR Operations

```bash
# Checkout a PR locally
gh pr checkout 123

# Mark draft as ready
gh pr ready 123

# Edit PR metadata
gh pr edit 123 --add-label needs-review --add-reviewer alice

# Close without merging
gh pr close 123 --comment "Superseded by #456"

# List open PRs
gh pr list
gh pr list --author @me
gh pr list --label bug --state open

# Update branch with latest base
gh pr update-branch 123
```

For the full PR command reference including all flags and JSON fields, read `references/pull-requests.md`.

---

## Issue Workflows

### Create an Issue

```bash
# Basic
gh issue create --title "Button doesn't respond on mobile" --body "Steps to reproduce..."

# With labels and assignee
gh issue create \
  --title "Add dark mode support" \
  --label enhancement,ui \
  --assignee @me \
  --body "Users have requested dark mode"

# Body from file
gh issue create --title "Bug report" --body-file bug_report.md

# In a specific repo
gh issue create --repo owner/repo --title "Cross-repo issue"
```

### View & Triage Issues

```bash
# View issue
gh issue view 123
gh issue view 123 --comments
gh issue view 123 --web

# List issues
gh issue list
gh issue list --assignee @me
gh issue list --label bug --state open
gh issue list --milestone "v2.0"

# Search with GitHub query syntax
gh issue list --search "is:open label:bug sort:updated-desc"

# JSON output for scripting
gh issue list --json number,title,labels,assignees --jq '.[] | [.number, .title] | @tsv'
```

### Edit & Close Issues

```bash
# Edit
gh issue edit 123 --title "Updated title" --add-label priority:high

# Close
gh issue close 123 --comment "Fixed in PR #456"

# Reopen
gh issue reopen 123

# Comment
gh issue comment 123 --body "I can reproduce this on macOS 14"

# Create a branch from an issue
gh issue develop 123 --branch fix/issue-123
```

For the full issue command reference, read `references/issues.md`.

---

## Actions & CI

### Check Workflow Runs

```bash
# List recent runs
gh run list
gh run list --workflow ci.yml --branch main

# View a specific run
gh run view 12345678
gh run view 12345678 --log          # Full logs
gh run view 12345678 --log-failed   # Only failed job logs

# Watch a run in real-time
gh run watch 12345678

# JSON output
gh run list --json databaseId,status,conclusion,headBranch,name \
  --jq '.[] | select(.conclusion == "failure")'
```

### Rerun & Manage

```bash
# Rerun failed jobs
gh run rerun 12345678 --failed

# Rerun entire workflow
gh run rerun 12345678

# Cancel a run
gh run cancel 12345678

# Download artifacts
gh run download 12345678 --dir ./artifacts
gh run download 12345678 --name test-results
```

### Trigger Workflows

```bash
# Run a workflow manually
gh workflow run deploy.yml

# With inputs
gh workflow run deploy.yml -f environment=staging -f version=1.2.3

# From a specific branch
gh workflow run ci.yml --ref feature-branch
```

### Secrets & Variables

```bash
# List secrets
gh secret list

# Set a secret (reads from stdin)
echo "my-secret-value" | gh secret set API_KEY

# Set for specific environment
gh secret set DB_PASSWORD --env production

# Variables (non-secret config)
gh variable set DEPLOY_TARGET --body "staging"
gh variable list
```

For the full Actions reference, read `references/actions.md`.

---

## Search

```bash
# Search issues across GitHub
gh search issues "memory leak language:go"

# Search PRs
gh search prs "is:open review:required repo:owner/repo"

# Search code
gh search code "handleAuth" --repo owner/repo

# Search repositories
gh search repos "topic:cli language:rust stars:>100" --sort stars

# Search commits
gh search commits "fix auth" --repo owner/repo

# JSON output
gh search issues "label:bug" --json number,title,repository --limit 20
```

---

## API Requests

For operations not covered by built-in commands, use `gh api` directly.

```bash
# REST API — GET
gh api /repos/owner/repo

# REST API — POST
gh api --method POST /repos/owner/repo/issues \
  --field title="Created via API" \
  --field body="Description here"

# With jq filtering
gh api /repos/owner/repo/pulls --jq '.[].title'

# Paginate large result sets
gh api /repos/owner/repo/issues --paginate --jq '.[].title'

# GraphQL
gh api graphql -f query='
  query {
    repository(owner: "owner", name: "repo") {
      pullRequests(first: 5, states: OPEN) {
        nodes { title number author { login } }
      }
    }
  }
'

# Read PR review comments (not available via gh pr)
gh api repos/owner/repo/pulls/123/comments --jq '.[].body'

# Read PR review threads with file context
gh api repos/owner/repo/pulls/123/comments \
  --jq '.[] | {path: .path, line: .line, body: .body, author: .user.login}'
```

For the full API reference, read `references/search-and-api.md`.

---

## Output Formatting

Most `gh` commands support `--json` and `--jq` for structured output.

### Common Patterns

```bash
# Get specific JSON fields
gh pr view 123 --json title,state,author

# Filter with jq
gh pr list --json number,title,labels \
  --jq '.[] | select(.labels | map(.name) | index("bug"))'

# Tab-separated for scripting
gh issue list --json number,title --jq '.[] | [.number, .title] | @tsv'

# Count results
gh pr list --state open --json number --jq 'length'

# Go templates (alternative to jq)
gh pr view 123 --template '{{.title}} by {{.author.login}} ({{.state}})'
```

### Useful JSON Fields

**Pull Requests:** `number`, `title`, `state`, `author`, `headRefName`, `baseRefName`,
`reviewDecision`, `statusCheckRollup`, `mergeable`, `additions`, `deletions`, `files`,
`commits`, `labels`, `assignees`, `reviewRequests`, `comments`, `body`, `url`, `createdAt`

**Issues:** `number`, `title`, `state`, `author`, `labels`, `assignees`, `milestone`,
`comments`, `body`, `url`, `createdAt`, `closedAt`

**Runs:** `databaseId`, `name`, `status`, `conclusion`, `headBranch`, `event`,
`createdAt`, `updatedAt`, `url`

---

## Bulk Operations

```bash
# Close all stale issues
gh issue list --label stale --json number --jq '.[].number' | \
  xargs -I {} gh issue close {} --comment "Closing as stale"

# Add label to all open PRs by an author
gh pr list --author alice --json number --jq '.[].number' | \
  xargs -I {} gh pr edit {} --add-label needs-review

# List all failing CI runs on a branch
gh run list --branch main --json databaseId,conclusion \
  --jq '.[] | select(.conclusion == "failure") | .databaseId'
```

---

## Safety Notes

- `gh repo delete` and `gh issue delete` are **irreversible** — always confirm with the user
- `gh pr merge --admin` bypasses branch protection — use only when explicitly asked
- `gh secret set` reads from stdin to avoid secrets in shell history
- When creating PRs or issues, prefer `--body` over interactive mode (which requires TTY)
- Use `--repo owner/repo` to avoid operating on the wrong repository

---

## Reference Files

For detailed command flags, all subcommands, and less common operations:

| File | Contents |
|------|----------|
| `references/pull-requests.md` | Full PR commands: create, list, view, edit, merge, review, checks, diff, close, reopen, ready, revert, lock, update-branch |
| `references/issues.md` | Full issue commands: create, list, view, edit, close, reopen, comment, develop, pin, lock, transfer, delete |
| `references/repositories.md` | Repo management: create, clone, fork, edit, delete, sync, deploy-keys, autolinks, set-default |
| `references/actions.md` | CI/CD: workflow runs, workflow management, caches, secrets, variables |
| `references/search-and-api.md` | Search commands, `gh api` REST & GraphQL, output formatting details |
| `references/misc.md` | Releases, gists, codespaces, projects, labels, extensions, aliases, SSH/GPG keys, rulesets, config |

# Pull Requests — Full Reference

## Table of Contents
- [Create](#create)
- [List](#list)
- [View](#view)
- [Checkout](#checkout)
- [Diff](#diff)
- [Edit](#edit)
- [Review](#review)
- [Checks](#checks)
- [Merge](#merge)
- [Ready](#ready)
- [Close & Reopen](#close--reopen)
- [Comment](#comment)
- [Update Branch](#update-branch)
- [Revert](#revert)
- [Lock & Unlock](#lock--unlock)
- [Status](#status)

---

## Create

```bash
gh pr create [flags]
```

| Flag | Description |
|------|-------------|
| `--title` | PR title |
| `--body` | PR body text |
| `--body-file` | Read body from file |
| `--base` | Target branch (default: repo default branch) |
| `--head` | Source branch (default: current branch) |
| `--draft` | Create as draft |
| `--assignee` | Comma-separated assignees |
| `--reviewer` | Comma-separated reviewers |
| `--label` | Comma-separated labels |
| `--milestone` | Milestone name |
| `--project` | Project name |
| `--issue` | Link to issue number |
| `--repo` | Target repository (owner/repo) |
| `--web` | Open in browser after creation |
| `--no-maintainer-edit` | Disallow maintainer edits |
| `--fill` | Use commit info for title/body |
| `--fill-first` | Use first commit for title/body |
| `--fill-verbose` | Use verbose commit info |
| `--recover` | Recover from failed create |
| `--template` | Body template file |

**Examples:**
```bash
# Fill from commits
gh pr create --fill

# With milestone and project
gh pr create --title "Feature" --milestone "v2.0" --project "Sprint 5"
```

---

## List

```bash
gh pr list [flags]
```

| Flag | Description |
|------|-------------|
| `--state` | `open` (default), `closed`, `merged`, `all` |
| `--head` | Filter by head branch |
| `--base` | Filter by base branch |
| `--author` | Filter by author (`@me` for self) |
| `--assignee` | Filter by assignee |
| `--label` | Filter by labels (comma-separated) |
| `--search` | GitHub search query |
| `--limit` | Max results (default 30) |
| `--json` | Output JSON with specified fields |
| `--jq` | jq expression to filter JSON |
| `--template` | Go template for output |
| `--web` | Open in browser |
| `--sort` | `created`, `updated`, `popularity`, `long-running` |
| `--order` | `asc`, `desc` |
| `--app` | Filter by GitHub App author |
| `--draft` | Filter by draft status |

**Available JSON fields:** `additions`, `assignees`, `author`, `autoMergeRequest`, `baseRefName`, `body`, `changedFiles`, `closed`, `closedAt`, `comments`, `commits`, `createdAt`, `deletions`, `files`, `headRefName`, `headRefOid`, `headRepository`, `headRepositoryOwner`, `id`, `isCrossRepository`, `isDraft`, `labels`, `latestReviews`, `maintainerCanModify`, `mergeCommit`, `mergeStateStatus`, `mergeable`, `mergedAt`, `mergedBy`, `milestone`, `number`, `potentialMergeCommit`, `projectCards`, `projectItems`, `reactionGroups`, `reviewDecision`, `reviewRequests`, `reviews`, `state`, `statusCheckRollup`, `title`, `updatedAt`, `url`

---

## View

```bash
gh pr view [<number> | <url> | <branch>] [flags]
```

| Flag | Description |
|------|-------------|
| `--comments` | Show comments |
| `--json` | Output JSON fields |
| `--jq` | jq filter |
| `--template` | Go template |
| `--web` | Open in browser |

Accepts PR number, URL, or branch name. No argument = PR for current branch.

---

## Checkout

```bash
gh pr checkout <number> [flags]
```

| Flag | Description |
|------|-------------|
| `--branch` | Local branch name to use |
| `--force` | Reset existing local branch |
| `--detach` | Checkout in detached HEAD |
| `--recurse-submodules` | Update submodules |

---

## Diff

```bash
gh pr diff [<number>] [flags]
```

| Flag | Description |
|------|-------------|
| `--color` | `always`, `never`, `auto` |
| `--name-only` | Show only changed file names |
| `--patch` | Show in patch format |

---

## Edit

```bash
gh pr edit <number> [flags]
```

| Flag | Description |
|------|-------------|
| `--title` | New title |
| `--body` | New body |
| `--body-file` | Body from file |
| `--base` | Change base branch |
| `--add-label` | Add labels |
| `--remove-label` | Remove labels |
| `--add-assignee` | Add assignees |
| `--remove-assignee` | Remove assignees |
| `--add-reviewer` | Add reviewers |
| `--remove-reviewer` | Remove reviewers |
| `--add-project` | Add to project |
| `--remove-project` | Remove from project |
| `--milestone` | Set milestone |

---

## Review

```bash
gh pr review [<number>] [flags]
```

| Flag | Description |
|------|-------------|
| `--approve` | Approve the PR |
| `--request-changes` | Request changes |
| `--comment` | Leave a comment review |
| `--body` | Review comment body |
| `--body-file` | Review body from file |

Exactly one of `--approve`, `--request-changes`, or `--comment` is required in non-interactive mode.

---

## Checks

```bash
gh pr checks [<number>] [flags]
```

| Flag | Description |
|------|-------------|
| `--watch` | Poll until checks complete |
| `--interval` | Polling interval in seconds (default 10) |
| `--fail-fast` | Exit on first failure when watching |
| `--required` | Show only required checks |
| `--json` | JSON output |
| `--jq` | jq filter |

---

## Merge

```bash
gh pr merge [<number>] [flags]
```

| Flag | Description |
|------|-------------|
| `--merge` | Merge commit |
| `--squash` | Squash and merge |
| `--rebase` | Rebase and merge |
| `--auto` | Auto-merge when requirements met |
| `--disable-auto` | Disable auto-merge |
| `--delete-branch` | Delete branch after merge |
| `--admin` | Bypass branch protections |
| `--subject` | Merge commit subject |
| `--body` | Merge commit body |
| `--match-head-commit` | Only merge if HEAD matches this SHA |

---

## Ready

```bash
gh pr ready [<number>]
```

Marks a draft PR as ready for review. No flags.

---

## Close & Reopen

```bash
gh pr close <number> [--comment "reason"] [--delete-branch]
gh pr reopen <number>
```

---

## Comment

```bash
gh pr comment <number> [flags]
```

| Flag | Description |
|------|-------------|
| `--body` | Comment text |
| `--body-file` | Comment from file |
| `--edit-last` | Edit your last comment |
| `--web` | Open in browser |

---

## Update Branch

```bash
gh pr update-branch <number> [flags]
```

| Flag | Description |
|------|-------------|
| `--rebase` | Use rebase instead of merge |

---

## Revert

```bash
gh pr revert <number> [flags]
```

| Flag | Description |
|------|-------------|
| `--branch` | Name for the revert branch |
| `--body` | Body for the revert PR |
| `--title` | Title for the revert PR |
| `--draft` | Create revert PR as draft |

---

## Lock & Unlock

```bash
gh pr lock <number> [--reason off-topic|too-heated|resolved|spam]
gh pr unlock <number>
```

---

## Status

```bash
gh pr status [--repo owner/repo] [--json] [--jq]
```

Shows PRs relevant to you: created by you, requesting your review, and current branch.

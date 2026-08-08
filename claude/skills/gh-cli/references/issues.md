# Issues — Full Reference

## Table of Contents
- [Create](#create)
- [List](#list)
- [View](#view)
- [Edit](#edit)
- [Close & Reopen](#close--reopen)
- [Comment](#comment)
- [Develop](#develop)
- [Pin & Unpin](#pin--unpin)
- [Lock & Unlock](#lock--unlock)
- [Transfer](#transfer)
- [Delete](#delete)
- [Status](#status)

---

## Create

```bash
gh issue create [flags]
```

| Flag | Description |
|------|-------------|
| `--title` | Issue title |
| `--body` | Issue body |
| `--body-file` | Read body from file |
| `--label` | Comma-separated labels |
| `--assignee` | Comma-separated assignees (`@me` for self) |
| `--milestone` | Milestone name |
| `--project` | Project name |
| `--repo` | Target repository |
| `--web` | Open in browser |
| `--template` | Issue template to use |
| `--recover` | Recover from failed create |

---

## List

```bash
gh issue list [flags]
```

| Flag | Description |
|------|-------------|
| `--state` | `open` (default), `closed`, `all` |
| `--assignee` | Filter by assignee (`@me` for self) |
| `--author` | Filter by author |
| `--label` | Filter by labels (comma-separated) |
| `--milestone` | Filter by milestone |
| `--search` | GitHub search query syntax |
| `--limit` | Max results (default 30) |
| `--json` | Output JSON fields |
| `--jq` | jq expression |
| `--template` | Go template |
| `--web` | Open in browser |
| `--sort` | `created`, `updated`, `comments` |
| `--order` | `asc`, `desc` |
| `--app` | Filter by GitHub App author |

**Available JSON fields:** `assignees`, `author`, `body`, `closed`, `closedAt`, `comments`, `createdAt`, `id`, `isPinned`, `labels`, `milestone`, `number`, `projectCards`, `projectItems`, `reactionGroups`, `state`, `stateReason`, `title`, `updatedAt`, `url`

---

## View

```bash
gh issue view <number> [flags]
```

| Flag | Description |
|------|-------------|
| `--comments` | Show comments |
| `--json` | JSON fields |
| `--jq` | jq filter |
| `--template` | Go template |
| `--web` | Open in browser |

---

## Edit

```bash
gh issue edit <number> [flags]
```

| Flag | Description |
|------|-------------|
| `--title` | New title |
| `--body` | New body |
| `--body-file` | Body from file |
| `--add-label` | Add labels |
| `--remove-label` | Remove labels |
| `--add-assignee` | Add assignees |
| `--remove-assignee` | Remove assignees |
| `--add-project` | Add to project |
| `--remove-project` | Remove from project |
| `--milestone` | Set milestone |

---

## Close & Reopen

```bash
# Close
gh issue close <number> [flags]
```

| Flag | Description |
|------|-------------|
| `--comment` | Add a closing comment |
| `--reason` | `completed` (default), `not planned` |

```bash
# Reopen
gh issue reopen <number> [--comment "reason"]
```

---

## Comment

```bash
gh issue comment <number> [flags]
```

| Flag | Description |
|------|-------------|
| `--body` | Comment text |
| `--body-file` | Comment from file |
| `--edit-last` | Edit your last comment |
| `--web` | Open in browser |

---

## Develop

Create a branch linked to an issue — useful for starting work on an issue.

```bash
gh issue develop <number> [flags]
```

| Flag | Description |
|------|-------------|
| `--branch` | Branch name (default: issue-<number>) |
| `--base` | Base branch |
| `--checkout` | Checkout the branch after creating |
| `--repo` | Target repository |

---

## Pin & Unpin

```bash
gh issue pin <number>
gh issue unpin <number>
```

Pin issues to the top of the issue list (max 3 pinned per repo).

---

## Lock & Unlock

```bash
gh issue lock <number> [--reason off-topic|too-heated|resolved|spam]
gh issue unlock <number>
```

---

## Transfer

```bash
gh issue transfer <number> <destination-repo>
```

Transfers an issue to another repository in the same owner/org.

---

## Delete

```bash
gh issue delete <number> [--yes]
```

**Irreversible.** The `--yes` flag skips confirmation.

---

## Status

```bash
gh issue status [--repo owner/repo] [--json] [--jq]
```

Shows issues relevant to you: assigned to you, mentioning you, and recently opened.

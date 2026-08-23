# Repositories — Full Reference

## Table of Contents
- [Create](#create)
- [Clone](#clone)
- [List](#list)
- [View](#view)
- [Edit](#edit)
- [Fork](#fork)
- [Sync](#sync)
- [Set Default](#set-default)
- [Rename](#rename)
- [Archive & Unarchive](#archive--unarchive)
- [Delete](#delete)
- [Deploy Keys](#deploy-keys)
- [Autolinks](#autolinks)
- [Gitignore & License](#gitignore--license)

---

## Create

```bash
gh repo create <name> [flags]
```

| Flag | Description |
|------|-------------|
| `--public` | Public visibility |
| `--private` | Private visibility |
| `--internal` | Internal visibility (orgs only) |
| `--description` | Repository description |
| `--homepage` | Homepage URL |
| `--license` | License template (e.g., `mit`, `apache-2.0`) |
| `--gitignore` | Gitignore template (e.g., `Python`, `Node`) |
| `--clone` | Clone after creation |
| `--source` | Path to local source (`.` for current dir) |
| `--remote` | Remote name (default `origin`) |
| `--push` | Push local commits |
| `--template` | Template repository |
| `--disable-issues` | Disable issues |
| `--disable-wiki` | Disable wiki |
| `--add-readme` | Add a README |
| `--include-all-branches` | Include all branches from template |

**Common patterns:**
```bash
# New repo from current directory
gh repo create my-project --source=. --public --push

# New repo from template
gh repo create my-app --template org/template-repo --clone

# Org repo
gh repo create my-org/new-service --private --clone
```

---

## Clone

```bash
gh repo clone <repository> [<directory>] [-- <git-flags>]
```

Repository can be `owner/repo`, a URL, or just `repo` (infers owner from auth).

---

## List

```bash
gh repo list [<owner>] [flags]
```

| Flag | Description |
|------|-------------|
| `--limit` | Max results |
| `--public` | Public repos only |
| `--private` | Private repos only |
| `--source` | Non-fork repos only |
| `--fork` | Fork repos only |
| `--archived` | Include archived |
| `--no-archived` | Exclude archived |
| `--language` | Filter by language |
| `--topic` | Filter by topic |
| `--json` | JSON output fields |
| `--jq` | jq filter |

---

## View

```bash
gh repo view [<repository>] [flags]
```

| Flag | Description |
|------|-------------|
| `--json` | JSON output fields |
| `--jq` | jq filter |
| `--template` | Go template |
| `--web` | Open in browser |
| `--branch` | View specific branch |

**Useful JSON fields:** `name`, `owner`, `description`, `url`, `sshUrl`, `defaultBranchRef`, `isPrivate`, `isFork`, `isArchived`, `stargazerCount`, `forkCount`, `languages`, `licenseInfo`, `homepageUrl`, `createdAt`, `pushedAt`

---

## Edit

```bash
gh repo edit [<repository>] [flags]
```

| Flag | Description |
|------|-------------|
| `--description` | Set description |
| `--homepage` | Set homepage |
| `--visibility` | `public`, `private`, `internal` |
| `--default-branch` | Set default branch |
| `--enable-issues` / `--disable-issues` | Toggle issues |
| `--enable-wiki` / `--disable-wiki` | Toggle wiki |
| `--enable-projects` / `--disable-projects` | Toggle projects |
| `--enable-discussions` / `--disable-discussions` | Toggle discussions |
| `--enable-merge-commit` / `--disable-merge-commit` | Toggle merge commits |
| `--enable-squash-merge` / `--disable-squash-merge` | Toggle squash merge |
| `--enable-rebase-merge` / `--disable-rebase-merge` | Toggle rebase merge |
| `--enable-auto-merge` / `--disable-auto-merge` | Toggle auto-merge |
| `--delete-branch-on-merge` | Auto-delete merged branches |
| `--allow-forking` | Allow forks of private repo |
| `--allow-update-branch` | Allow updating PR branches |

---

## Fork

```bash
gh repo fork [<repository>] [flags]
```

| Flag | Description |
|------|-------------|
| `--clone` | Clone after forking |
| `--remote` | Add remote for fork |
| `--remote-name` | Remote name (default `origin`) |
| `--org` | Fork to organization |
| `--fork-name` | Custom fork name |
| `--default-branch-only` | Fork default branch only |

---

## Sync

```bash
gh repo sync [<destination>] [flags]
```

| Flag | Description |
|------|-------------|
| `--branch` | Branch to sync |
| `--force` | Force sync (hard reset) |
| `--source` | Source repository |

---

## Set Default

```bash
gh repo set-default [<repository>]
gh repo set-default --unset
```

Sets which repository `gh` commands target in the current directory.

---

## Rename

```bash
gh repo rename <new-name> [--repo owner/repo] [--yes]
```

---

## Archive & Unarchive

```bash
gh repo archive [<repository>] [--yes]
gh repo unarchive [<repository>] [--yes]
```

---

## Delete

```bash
gh repo delete [<repository>] [--yes]
```

**Irreversible.**

---

## Deploy Keys

```bash
# List
gh repo deploy-key list

# Add (read-only by default)
gh repo deploy-key add <key-file> --title "Server" [--allow-write]

# Delete
gh repo deploy-key delete <key-id>
```

---

## Autolinks

```bash
# List
gh repo autolink list

# Create
gh repo autolink create --key-prefix "JIRA-" --url-template "https://jira.example.com/browse/<num>"

# Delete
gh repo autolink delete <id> [--yes]
```

---

## Gitignore & License

```bash
# List available gitignore templates
gh repo gitignore list

# View a template
gh repo gitignore view Python

# List available licenses
gh repo license list

# View a license
gh repo license view mit
```

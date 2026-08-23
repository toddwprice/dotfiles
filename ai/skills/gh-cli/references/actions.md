# Actions & CI — Full Reference

## Table of Contents
- [Workflow Runs (gh run)](#workflow-runs)
- [Workflows (gh workflow)](#workflows)
- [Caches (gh cache)](#caches)
- [Secrets (gh secret)](#secrets)
- [Variables (gh variable)](#variables)

---

## Workflow Runs

### List Runs

```bash
gh run list [flags]
```

| Flag | Description |
|------|-------------|
| `--workflow` | Filter by workflow file name or ID |
| `--branch` | Filter by branch |
| `--actor` | Filter by user who triggered |
| `--event` | Filter by event type (`push`, `pull_request`, etc.) |
| `--status` | `queued`, `in_progress`, `completed`, `success`, `failure`, `cancelled`, etc. |
| `--limit` | Max results (default 20) |
| `--json` | JSON output fields |
| `--jq` | jq filter |

**Available JSON fields:** `databaseId`, `name`, `displayTitle`, `headBranch`, `headSha`, `status`, `conclusion`, `event`, `number`, `workflowDatabaseId`, `workflowName`, `createdAt`, `updatedAt`, `startedAt`, `url`

### View Run

```bash
gh run view <run-id> [flags]
```

| Flag | Description |
|------|-------------|
| `--log` | Show full logs |
| `--log-failed` | Show logs for failed steps only |
| `--job` | View specific job ID |
| `--exit-status` | Exit with non-zero if run failed |
| `--json` | JSON output |
| `--web` | Open in browser |
| `--verbose` | Show verbose output |
| `--attempt` | View specific attempt number |

### Watch Run

```bash
gh run watch <run-id> [flags]
```

| Flag | Description |
|------|-------------|
| `--interval` | Polling interval in seconds (default 3) |
| `--exit-status` | Exit with non-zero if run fails |

### Rerun

```bash
gh run rerun <run-id> [flags]
```

| Flag | Description |
|------|-------------|
| `--failed` | Rerun only failed jobs |
| `--job` | Rerun specific job ID |
| `--debug` | Enable debug logging |

### Cancel

```bash
gh run cancel <run-id>
```

### Delete

```bash
gh run delete <run-id>
```

### Download Artifacts

```bash
gh run download <run-id> [flags]
```

| Flag | Description |
|------|-------------|
| `--name` | Download specific artifact by name |
| `--pattern` | Glob pattern for artifact names |
| `--dir` | Output directory |

---

## Workflows

### List Workflows

```bash
gh workflow list [flags]
```

| Flag | Description |
|------|-------------|
| `--all` | Include disabled workflows |
| `--limit` | Max results |
| `--json` | JSON output |

### View Workflow

```bash
gh workflow view <workflow-id-or-filename> [flags]
```

| Flag | Description |
|------|-------------|
| `--yaml` | Show workflow YAML content |
| `--ref` | Branch to view from |
| `--web` | Open in browser |

### Run Workflow (Manual Dispatch)

```bash
gh workflow run <workflow> [flags]
```

| Flag | Description |
|------|-------------|
| `--ref` | Branch/tag to run on |
| `-f key=value` | String input |
| `-F key=@file` | Input from file |
| `--json` | Input as JSON |

**Example with inputs:**
```bash
gh workflow run deploy.yml --ref main \
  -f environment=production \
  -f version=1.2.3
```

### Enable / Disable

```bash
gh workflow enable <workflow>
gh workflow disable <workflow>
```

---

## Caches

```bash
# List
gh cache list [--limit N] [--sort created-at|last-accessed-at|size] [--order asc|desc]

# Delete specific cache
gh cache delete <cache-id>

# Delete by key pattern
gh cache delete --key "npm-*"

# Delete all
gh cache delete --all
```

---

## Secrets

```bash
gh secret set <name> [flags]
```

| Flag | Description |
|------|-------------|
| `--body` | Secret value (prefer stdin for security) |
| `--env` | Set for specific environment |
| `--org` | Set for organization |
| `--repos` | Limit org secret to repos (comma-separated) |
| `--visibility` | Org secret visibility: `all`, `private`, `selected` |
| `--app` | App context: `actions`, `codespaces`, `dependabot` |

```bash
# List
gh secret list [--env <env>] [--org <org>] [--app <app>]

# Delete
gh secret delete <name> [--env <env>] [--org <org>]

# Best practice: pipe from stdin
echo "$VALUE" | gh secret set MY_SECRET
printenv API_KEY | gh secret set API_KEY --env production
```

---

## Variables

```bash
gh variable set <name> [flags]
```

| Flag | Description |
|------|-------------|
| `--body` | Variable value |
| `--env` | Set for environment |
| `--org` | Set for organization |
| `--repos` | Limit org variable to repos |
| `--visibility` | Org variable visibility |

```bash
# Get
gh variable get <name> [--env <env>] [--org <org>]

# List
gh variable list [--env <env>] [--org <org>]

# Delete
gh variable delete <name> [--env <env>] [--org <org>]
```

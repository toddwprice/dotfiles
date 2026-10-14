# Search & API — Full Reference

## Table of Contents
- [Search](#search)
- [REST API (gh api)](#rest-api)
- [GraphQL API](#graphql-api)
- [Output Formatting](#output-formatting)
- [Authentication & Config](#authentication--config)

---

## Search

All search commands support `--json`, `--jq`, `--template`, `--web`, `--limit`, `--order`, and `--sort`.

### Search Issues

```bash
gh search issues <query> [flags]
```

| Flag | Description |
|------|-------------|
| `--repo` | Filter to specific repo |
| `--owner` | Filter to owner |
| `--visibility` | `public`, `private`, `internal` |
| `--state` | `open`, `closed` |
| `--label` | Filter by label |
| `--language` | Filter by language |
| `--match` | Match in `title`, `body`, `comments` |
| `--milestone` | Filter by milestone |
| `--assignee` | Filter by assignee |
| `--author` | Filter by author |
| `--mentions` | Filter by mentions |
| `--sort` | `created`, `updated`, `comments`, `reactions`, etc. |

**Query syntax examples:**
```bash
gh search issues "memory leak" --repo owner/repo --state open
gh search issues "label:bug label:critical is:open"
gh search issues "in:title auth error" --language go
```

### Search PRs

```bash
gh search prs <query> [flags]
```

Same flags as issues, plus:
| Flag | Description |
|------|-------------|
| `--draft` | Filter by draft status |
| `--merged` | Filter by merged status |
| `--review` | `none`, `required`, `approved`, `changes_requested` |
| `--merged-at` | Date range (e.g., `>2024-01-01`) |

### Search Code

```bash
gh search code <query> [flags]
```

| Flag | Description |
|------|-------------|
| `--repo` | Filter to repo |
| `--owner` | Filter to owner |
| `--language` | Filter by language |
| `--filename` | Filter by filename |
| `--extension` | Filter by file extension |
| `--path` | Filter by file path |
| `--size` | Filter by file size (e.g., `>1000`) |

```bash
gh search code "handleAuth" --repo owner/repo --extension ts
gh search code "func main" --language go --filename main.go
```

### Search Repos

```bash
gh search repos <query> [flags]
```

| Flag | Description |
|------|-------------|
| `--owner` | Filter to owner |
| `--language` | Filter by language |
| `--topic` | Filter by topic |
| `--visibility` | `public`, `private` |
| `--license` | Filter by license |
| `--archived` | Filter by archived status |
| `--sort` | `stars`, `forks`, `updated`, `help-wanted-issues` |
| `--number-topics` | Filter by topic count range |
| `--stars` | Filter by star count (e.g., `>1000`) |
| `--forks` | Filter by fork count |
| `--created` | Filter by creation date |
| `--size` | Filter by repo size |

### Search Commits

```bash
gh search commits <query> [flags]
```

| Flag | Description |
|------|-------------|
| `--repo` | Filter to repo |
| `--owner` | Filter to owner |
| `--author` | Filter by author |
| `--committer` | Filter by committer |
| `--author-date` | Date range |
| `--committer-date` | Date range |
| `--merge` | Filter merge commits |
| `--hash` | Filter by commit hash |

---

## REST API

```bash
gh api <endpoint> [flags]
```

| Flag | Description |
|------|-------------|
| `--method` | HTTP method (`GET`, `POST`, `PUT`, `PATCH`, `DELETE`) |
| `-f key=value` | String field |
| `-F key=value` | Typed field (numbers, bools parsed) |
| `-F key=@file` | Field value from file |
| `--input` | Request body from file |
| `--raw-field` | Raw string field (no @ interpretation) |
| `-H key:value` | HTTP header |
| `--jq` | jq filter on response |
| `--template` | Go template |
| `--paginate` | Auto-paginate results |
| `--slurp` | Combine paginated results into array |
| `--include` | Include response headers |
| `--silent` | Suppress response body |
| `--cache` | Cache duration (e.g., `5m`, `1h`) |
| `--hostname` | GitHub Enterprise hostname |
| `--preview` | API preview header |

### Common REST Patterns

```bash
# Get repo info
gh api /repos/owner/repo

# List PR comments (not available via gh pr)
gh api repos/owner/repo/pulls/123/comments

# List PR review comments with context
gh api repos/owner/repo/pulls/123/comments \
  --jq '.[] | {path: .path, line: .line, body: .body, user: .user.login}'

# Create an issue
gh api --method POST /repos/owner/repo/issues \
  -f title="Bug report" -f body="Details here" -f labels[]="bug"

# Add reaction to issue
gh api --method POST /repos/owner/repo/issues/123/reactions \
  -f content="+1"

# List team members
gh api /orgs/my-org/teams/my-team/members --jq '.[].login'

# Get rate limit
gh api /rate_limit --jq '.rate'

# Paginate all issues
gh api /repos/owner/repo/issues --paginate --jq '.[].title'

# Check if user is collaborator
gh api /repos/owner/repo/collaborators/username --silent && echo "yes" || echo "no"
```

---

## GraphQL API

```bash
gh api graphql -f query='...' [-F variable=value] [--jq '...']
```

### Common GraphQL Queries

```bash
# Viewer info
gh api graphql -f query='{ viewer { login name } }'

# Repository with PRs
gh api graphql -f query='
  query($owner: String!, $name: String!) {
    repository(owner: $owner, name: $name) {
      pullRequests(first: 10, states: OPEN) {
        nodes { number title author { login } }
      }
    }
  }
' -F owner=owner -F name=repo

# Issues with labels
gh api graphql -f query='
  query($owner: String!, $name: String!) {
    repository(owner: $owner, name: $name) {
      issues(first: 20, states: OPEN, labels: ["bug"]) {
        nodes { number title labels(first: 5) { nodes { name } } }
      }
    }
  }
' -F owner=owner -F name=repo

# GraphQL with pagination
gh api graphql --paginate -f query='
  query($endCursor: String) {
    viewer {
      repositories(first: 100, after: $endCursor) {
        pageInfo { hasNextPage endCursor }
        nodes { nameWithOwner }
      }
    }
  }
'
```

---

## Output Formatting

### JSON + jq

```bash
# Select specific fields
gh pr list --json number,title --jq '.[].title'

# Filter
gh pr list --json number,title,labels \
  --jq '.[] | select(.labels | map(.name) | index("bug"))'

# Transform
gh issue list --json number,title --jq '.[] | "\(.number): \(.title)"'

# Aggregate
gh pr list --json additions,deletions --jq '[.[] | .additions + .deletions] | add'

# Tab-separated (for scripts)
gh pr list --json number,title,author --jq '.[] | [.number, .title, .author.login] | @tsv'

# CSV
gh issue list --json number,title,state --jq '.[] | [.number, .title, .state] | @csv'
```

### Go Templates

```bash
# Simple
gh pr view 123 --template '{{.title}} ({{.state}})'

# With range
gh pr list --template '{{range .}}#{{.number}} {{.title}}{{"\n"}}{{end}}'

# Conditional
gh pr view 123 --template '{{if .isDraft}}DRAFT: {{end}}{{.title}}'
```

---

## Authentication & Config

### Auth Commands

```bash
# Login interactively
gh auth login

# Login with token from stdin
echo "$TOKEN" | gh auth login --with-token

# Check status
gh auth status
gh auth status --show-token

# Switch accounts
gh auth switch --hostname github.com --user username

# Get current token
gh auth token

# Refresh scopes
gh auth refresh --scopes write:org,read:public_key

# Setup git credential helper
gh auth setup-git
```

### Config Commands

```bash
# List all config
gh config list

# Get/set values
gh config get editor
gh config set editor vim
gh config set git_protocol ssh
gh config set prompt disabled
gh config set pager "less -R"

# Clear cache
gh config clear-cache
```

### Environment Variables

| Variable | Description |
|----------|-------------|
| `GH_TOKEN` | Authentication token (overrides logged-in token) |
| `GH_HOST` | Default GitHub hostname |
| `GH_REPO` | Default repository (owner/repo) |
| `GH_EDITOR` | Editor for interactive commands |
| `GH_PAGER` | Pager for output |
| `GH_PROMPT_DISABLED` | Disable interactive prompts |
| `GH_ENTERPRISE_HOSTNAME` | Enterprise server hostname |
| `GH_TIMEOUT` | HTTP timeout in seconds |
| `NO_COLOR` | Disable color output |

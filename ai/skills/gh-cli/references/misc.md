# Miscellaneous Commands — Full Reference

## Table of Contents
- [Releases](#releases)
- [Labels](#labels)
- [Gists](#gists)
- [Codespaces](#codespaces)
- [Projects](#projects)
- [Extensions](#extensions)
- [Aliases](#aliases)
- [SSH Keys](#ssh-keys)
- [GPG Keys](#gpg-keys)
- [Rulesets](#rulesets)
- [Attestations](#attestations)
- [Status](#status)
- [Browse](#browse)
- [Completion](#completion)

---

## Releases

### Create

```bash
gh release create <tag> [<files>...] [flags]
```

| Flag | Description |
|------|-------------|
| `--title` | Release title |
| `--notes` | Release notes |
| `--notes-file` | Notes from file |
| `--target` | Target branch/commit |
| `--draft` | Create as draft |
| `--prerelease` | Mark as pre-release |
| `--latest` | Mark as latest (default: auto) |
| `--generate-notes` | Auto-generate notes from commits |
| `--notes-start-tag` | Starting tag for auto-generated notes |
| `--discussion-category` | Create linked discussion |
| `--verify-tag` | Abort if tag doesn't exist |

```bash
# Common pattern: create with auto-generated notes
gh release create v1.2.0 --generate-notes --title "v1.2.0"

# Upload assets during creation
gh release create v1.0.0 ./build/*.tar.gz --notes "First release"
```

### Other Commands

```bash
# List
gh release list [--limit N] [--exclude-drafts] [--exclude-pre-releases]

# View
gh release view [<tag>] [--json] [--web]

# Edit
gh release edit <tag> [--title] [--notes] [--draft] [--prerelease] [--latest]

# Upload assets
gh release upload <tag> <files>... [--clobber]

# Download assets
gh release download [<tag>] [--pattern "*.tar.gz"] [--dir ./out] [--archive zip|tar.gz]

# Delete
gh release delete <tag> [--yes] [--cleanup-tag]

# Delete specific asset
gh release delete-asset <tag> <asset-name> [--yes]
```

---

## Labels

```bash
# List
gh label list [--limit N] [--sort name|created] [--order asc|desc] [--json]

# Create
gh label create <name> --color <hex> [--description "..."]

# Edit
gh label edit <name> [--name <new-name>] [--color <hex>] [--description "..."]

# Delete
gh label delete <name> [--yes]

# Clone labels from another repo
gh label clone <source-repo> [--force]
```

Color values: 6-character hex without `#` (e.g., `d73a4a`), or with `#` (e.g., `#a2eeef`).

---

## Gists

```bash
# List
gh gist list [--public] [--secret] [--limit N]

# Create
gh gist create <file>... [--public] [--desc "..."] [--filename <name>] [--web]

# Create from stdin
echo "content" | gh gist create --filename "example.txt"

# View
gh gist view <id> [--files] [--filename <name>] [--raw]

# Edit
gh gist edit <id> [--add <file>] [--remove <filename>] [--filename <name>]

# Delete
gh gist delete <id>

# Clone
gh gist clone <id> [<directory>]

# Rename file in gist
gh gist rename <id> <old-filename> <new-filename>
```

---

## Codespaces

```bash
# List
gh codespace list [--repo owner/repo] [--org org] [--limit N] [--json]

# Create
gh codespace create [flags]
```

| Flag | Description |
|------|-------------|
| `--repo` | Repository |
| `--branch` | Branch |
| `--machine` | Machine type (`basicLinux`, `standardLinux`, `premiumLinux`, etc.) |
| `--retention-period` | Retention period (e.g., `720h`) |
| `--idle-timeout` | Idle timeout (e.g., `30m`) |
| `--devcontainer-path` | Path to devcontainer.json |
| `--location` | Location preference |
| `--status` | Show creation status |

```bash
# Connect
gh codespace ssh [--codespace <name>] [--profile <ssh-profile>]
gh codespace code [--codespace <name>] [--insiders] [--web]
gh codespace jupyter [--codespace <name>]

# Manage
gh codespace stop [--codespace <name>]
gh codespace delete [--codespace <name>] [--all] [--days N]
gh codespace rebuild [--codespace <name>] [--full]
gh codespace edit [--codespace <name>] [--machine <type>]

# File operations
gh codespace cp <src> <dest>    # Use remote: prefix for codespace paths
gh codespace logs [--codespace <name>] [--follow]
gh codespace ports [--codespace <name>] [--json]
gh codespace ports forward <local>:<remote>
gh codespace ports visibility <port>:<visibility>
```

---

## Projects

### Project Management

```bash
# List
gh project list [--owner <owner>] [--closed] [--limit N] [--json] [--web]

# View
gh project view <number> [--owner <owner>] [--json] [--web] [--format json]

# Create
gh project create --title "..." [--owner <owner>] [--readme "..."]

# Edit
gh project edit <number> [--title "..."] [--description "..."] [--readme "..."] [--visibility public|private]

# Close / Delete / Copy
gh project close <number> [--owner <owner>] [--undo]
gh project delete <number> [--owner <owner>]
gh project copy <number> --target-owner <owner> --title "..."
gh project mark-template <number> [--owner <owner>] [--undo]
```

### Fields

```bash
# List fields
gh project field-list <number> [--owner <owner>] [--json]

# Create field
gh project field-create <number> --name "..." --data-type <type> [--single-select-options "..."]
# Data types: TEXT, NUMBER, DATE, SINGLE_SELECT, ITERATION

# Delete field
gh project field-delete --id <field-id>
```

### Items

```bash
# List items
gh project item-list <number> [--owner <owner>] [--limit N] [--json]

# Create draft item
gh project item-create <number> --title "..." [--body "..."]

# Add existing issue/PR
gh project item-add <number> --url <issue-or-pr-url>

# Edit item field
gh project item-edit --id <item-id> --field-id <field-id> --text "value"
gh project item-edit --id <item-id> --field-id <field-id> --number 42
gh project item-edit --id <item-id> --field-id <field-id> --date "2024-12-31"
gh project item-edit --id <item-id> --field-id <field-id> --single-select-option-id <option-id>

# Archive / Delete
gh project item-archive <number> --id <item-id> [--undo]
gh project item-delete <number> --id <item-id>
```

---

## Extensions

```bash
# Search
gh extension search [<query>] [--limit N] [--sort installs|stars]

# Browse (opens browser)
gh extension browse

# Install
gh extension install <repo> [--pin <version>]

# List installed
gh extension list

# Upgrade
gh extension upgrade <name> [--all] [--force] [--dry-run]

# Remove
gh extension remove <name>

# Create new extension
gh extension create <name> [--precompiled go|other]

# Execute
gh extension exec <name> [args...]
```

---

## Aliases

```bash
# List
gh alias list

# Set
gh alias set <name> '<expansion>'
gh alias set co 'pr checkout'
gh alias set bugs 'issue list --label bug'

# Shell aliases (more flexible)
gh alias set --shell igrep 'gh issue list --label "$1"'

# Delete
gh alias delete <name>

# Import from file
gh alias import <file>
```

---

## SSH Keys

```bash
gh ssh-key list
gh ssh-key add <key-file> [--title "..."] [--type authentication|signing]
gh ssh-key delete <id>
```

---

## GPG Keys

```bash
gh gpg-key list
gh gpg-key add <key-file>
gh gpg-key delete <id>
```

---

## Rulesets

```bash
# List rulesets
gh ruleset list [--repo owner/repo] [--org org] [--limit N]

# View ruleset details
gh ruleset view <id> [--repo owner/repo] [--web]

# Check rules for a branch
gh ruleset check [--branch <branch>] [--repo owner/repo] [--web]
```

---

## Attestations

```bash
# Verify artifact attestation
gh attestation verify <artifact-path> [--repo owner/repo] [--signer-repo owner/repo]

# Download attestation bundle
gh attestation download <artifact-path> [--repo owner/repo] [--dir <dir>]

# Get trusted root
gh attestation trusted-root [--repo owner/repo]
```

---

## Status

```bash
gh status [--repo owner/repo] [--org org] [--exclude owner/repo]
```

Shows a dashboard of notifications, assigned issues, review requests, and mentions.

---

## Browse

```bash
gh browse [<path-or-number>] [flags]
```

| Flag | Description |
|------|-------------|
| `--branch` | View specific branch |
| `--commit` | View specific commit |
| `--no-browser` | Print URL instead of opening |
| `--repo` | Target repository |
| `--settings` | Open settings page |
| `--wiki` | Open wiki |
| `--projects` | Open projects tab |
| `--releases` | Open releases page |
| `--actions` | Open actions tab |

```bash
gh browse                        # Open repo
gh browse 123                    # Open issue/PR #123
gh browse src/main.go:42         # Open file at line
gh browse --settings             # Open settings
```

---

## Completion

```bash
# Generate completion script
gh completion -s bash > ~/.gh-complete.bash
gh completion -s zsh > ~/.gh-complete.zsh
gh completion -s fish > ~/.gh-complete.fish
gh completion -s powershell > ~/.gh-complete.ps1
```

Add to shell rc file:
```bash
# bash
source ~/.gh-complete.bash

# zsh (add to .zshrc before compinit)
source ~/.gh-complete.zsh
```

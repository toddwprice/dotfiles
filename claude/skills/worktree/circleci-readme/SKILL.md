---
name: "circleci-readme"
---

# CircleCI Slash Commands

## Environment Setup

These commands require a CircleCI Personal API Token.

### Create a token

1. Go to [CircleCI Personal API Tokens](
   https://app.circleci.com/settings/user/tokens)
2. Click "Create New Token"
3. Give it a name (e.g., "claude-code")
4. Copy the token value

**Important:** Project tokens do NOT work with API v2. You must use
a personal token.

### Configure your environment

Add to your shell profile (`~/.zshrc` or `~/.bashrc`):

```bash
export CIRCLECI_API_TOKEN=your_token_here
```

### Verify

```bash
curl -s https://circleci.com/api/v2/me \
  -H "Circle-Token: $CIRCLECI_API_TOKEN" | jq .name
```

## Available Commands

| Command                  | Description                          |
|--------------------------|--------------------------------------|
| `/circleci:flaky_tests`  | Find flaky tests across the project  |
| `/circleci:failing_jobs` | Find failing jobs for a branch       |
| `/circleci:troubleshoot` | Diagnose a specific CI failure       |

## Script Reference

These commands use the diagnostic script at
`ops/platform/aws/dscops/scripts/circleci-diagnose.sh`.

You can also run the script directly:

```bash
# List all commands
ops/platform/aws/dscops/scripts/circleci-diagnose.sh

# Examples
circleci-diagnose.sh flaky-tests
circleci-diagnose.sh diagnose my-branch
circleci-diagnose.sh test-results 1234567
```

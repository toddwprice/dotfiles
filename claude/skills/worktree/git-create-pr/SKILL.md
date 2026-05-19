---
name: "git-create-pr"
allowed-tools: Bash(gh:*), Bash(git:*), mcp__sequential-thinking__sequentialthinking
description: Create concise, targeted pull request descriptions with intelligent risk assessment.
---

# Intelligent PR Description Generator

This command creates concise, targeted pull request descriptions that only include detailed risk assessments for major changes.

## Process

1. **Use sequential thinking** to analyze the git changes and categorize them as major or minor
2. **Generate concise content** following the improved format guidelines
3. **Present complete PR description** to user for approval
4. **Create the pull request** using gh CLI after approval

## Analysis Guidelines

### Major Changes (require detailed risk assessment):

- Database migrations (`apps/*/priv/repo/migrations/`)
- New third-party service integrations
- Infrastructure changes (docker-compose.yaml, ops/)
- New dependencies in mix.exs, package.json, pyproject.toml, Gemfile
- Security/authentication changes
- Changes affecting multiple apps simultaneously
- Ecto schema modifications
- New background job types

### Minor Changes (simplified format):

- Bug fixes in single modules/functions
- UI/UX improvements without backend impact
- Test additions or fixes
- Documentation updates
- Code refactoring without functional changes
- Configuration tweaks

## Content Guidelines

### Summary Format:

- **Maximum 1 paragraph** explaining what changed and why
- **Maximum 5 bullet points** for key changes
- Short, sweet, to the point - reviewers can check Resources for more details

### QA Instructions:

- **Frontend changes**: Provide user-facing testing steps
- **Backend/API changes**: Include code blocks (curl commands, GraphQL queries, SQL)
- **Bug fixes**: Include reproduction steps and verification of fix
- **Always include**: Expected outputs and success criteria

### Risk Assessment (only for major changes):

- Risk level (Low/Medium/High)
- Rollback plan
- Recovery time estimate
- Monitoring considerations

## Your Task

1. **Analyze the changes** using sequential thinking to understand scope and impact
2. **Categorize** as major or minor change based on the guidelines above
3. **Generate** a concise PR description following the template format
4. **Present the complete description** to the user, being very descriptive about the entire content
5. **Create the PR** with gh CLI once approved

Use the current branch name as inspiration for the PR title. **Important**: The title must end with `[NOJIRA]`, `[NOLINEAR]`, or `[PROJECT-123]` format as required by `.github/workflows/pr_ticket_check.yaml`.

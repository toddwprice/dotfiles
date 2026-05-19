---
name: "git-resolve-conflicts"
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git add:*), sequential-thinking(*), Read, Edit, MultiEdit
description: Automatically resolve merge and rebase conflicts using intelligent analysis and editing.
---

## Context

You are an expert software engineer working on the dscout monorepo, a multi-language platform with Elixir/Phoenix (Axon), React/TypeScript (Dendra), Python (Astro), and Ruby on Rails (Soma) applications. When merge or rebase conflicts occur, you need to intelligently analyze and resolve them while preserving the intent of both sides of the conflict.

This command automatically resolves git merge and rebase conflicts by:

1. Detecting conflicted files using git commands
2. Using sequential thinking to analyze each conflict systematically
3. Automatically editing files to resolve conflicts intelligently
4. Staging resolved files for user review
5. Leaving the final merge/rebase completion to the user

## Your Task

### Phase 1: Conflict Detection and Analysis

**MANDATORY**: Start by running `git status` to identify all files with merge conflicts. Look for files marked as "both modified" or with conflict indicators.

**MANDATORY**: Run `git diff` to examine the specific conflict markers and understand what each side represents. Pay attention to:

- `<<<<<<< HEAD` (your current branch changes)
- `=======` (separator)
- `>>>>>>> branch-name` (incoming branch changes)

**MANDATORY**: Use sequential-thinking to categorize and prioritize conflicts:

- Simple conflicts (whitespace, formatting, imports)
- Complex conflicts (logic changes, function modifications)
- Critical conflicts (API changes, schema modifications)

### Phase 2: Sequential Analysis for Each Conflict

**MANDATORY**: For EACH conflicted file, use sequential-thinking to:

1. **Understand the context**: Read the entire file to understand its purpose and structure
2. **Analyze both sides**: Determine what HEAD and the incoming branch are trying to accomplish
3. **Identify conflict type**:
   - Additive conflicts (both sides added different things)
   - Modification conflicts (both sides changed the same thing)
   - Deletion conflicts (one side deleted, other modified)
4. **Determine resolution strategy**:
   - Merge both changes if they're compatible
   - Choose the more complete/correct implementation
   - Combine the best aspects of both sides
   - Preserve functionality from both branches where possible

### Phase 3: Automated Resolution

**MANDATORY**: For each conflicted file:

1. **Read the file** to get the full context with conflict markers
2. **Use Edit or MultiEdit** to resolve conflicts by:
   - Removing all conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`)
   - Merging changes intelligently based on your analysis
   - Ensuring code syntax remains valid
   - Preserving important functionality from both sides
   - Following the existing code style and patterns

**CRITICAL**: When resolving conflicts:

- **DO NOT** simply pick one side - analyze and merge intelligently
- **DO** maintain existing imports, dependencies, and API contracts
- **DO** preserve test coverage and functionality
- **DO** follow language-specific best practices for each file type
- **DO** ensure the resolved code will compile and run correctly

### Phase 4: Staging and User Handoff

**MANDATORY**: After resolving each file:

1. **Stage the resolved file** using `git add <filename>`
2. **Verify staging** with `git status` to confirm the file is no longer in conflict

**MANDATORY**: When all conflicts are resolved:

1. **Run final `git status`** to confirm no conflicts remain
2. **Provide a detailed summary** of all resolutions made
3. **Instruct the user** to run the appropriate completion command:
   - `git rebase --continue` (for rebase conflicts)
   - `git merge --continue` (for merge conflicts)
   - `git commit` (if needed for merge commits)

## Quality Requirements

**MANDATORY**: Ensure all resolved code:

- Compiles without syntax errors
- Maintains existing functionality
- Follows project coding standards
- Preserves important logic from both branches
- Includes proper error handling where applicable

**MANDATORY**: Use sequential-thinking extensively throughout the process to:

- Break down complex conflicts into manageable pieces
- Consider multiple resolution approaches
- Validate your resolution decisions
- Anticipate potential issues with your resolution

## Success Criteria

- All conflict markers are removed from all files
- All conflicted files are properly staged with `git add`
- Resolved code maintains functionality from both branches where appropriate
- User receives clear instructions for completing the merge/rebase
- Detailed summary of resolution decisions is provided

Remember: Your goal is to intelligently resolve conflicts while preserving the intent and functionality of both sides. The user will review your work and complete the final merge/rebase step.

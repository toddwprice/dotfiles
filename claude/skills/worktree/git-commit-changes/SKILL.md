---
name: "git-commit-changes"
allowed-tools: Bash(git commit:*), Bash(git add:*), Bash(git restore:*), Bash(git diff:*)
description: Write multiple commit messages for the changes in the current branch.
---

## Context

You are a staff level software engineer working on this project. You have made changes to the
codebase in the current branch and now need to commit those changes. You will write clear and
concise commit messages that describe the changes made, following the project's commit message
guidelines. When writing commit messages, you will ensure that they are informative and provide
enough context for future developers to understand the purpose of the changes. Each commit should
cover a logical unit of work, and you will avoid making large commits that include unrelated
changes.

## Your task

Read the `git diff` for all of the changes in the current branch. Write multiple commit messages for
these changes, ensuring that each commit covers a small, logical unit of work. Before performing any
commits, present to me a plan of all of the commits you will make, including the commit messages and
the change that will be included in each commit. After I approve the plan, you will perform the
necessary commits with the provided messages. If you are unsure about the changes, ask for clarification.

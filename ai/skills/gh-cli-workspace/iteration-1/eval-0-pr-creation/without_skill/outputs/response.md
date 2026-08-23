# PR Creation with `gh` CLI

## The Exact Command

```bash
gh pr create \
  --base main \
  --title "Fix screen recording loop on Android" \
  --label "bug" \
  --reviewer alice,bob \
  --body "$(cat <<'EOF'
## Summary

Fixes the screen recording loop issue on Android by adding platform awareness to the track type mapping for mobile screen-and-camera recordings.

Closes #540

## Changes

- Added platform-aware track type mapping so Android screen-and-camera returns the correct single `audio_video` track
- Ensures mobile screen recording no longer enters an infinite loop on Android devices

## Test Plan

- [ ] Verify Android screen-and-camera recording starts and stops cleanly without looping
- [ ] Verify iOS screen recording behavior is unchanged
- [ ] Verify web screen recording behavior is unchanged
EOF
)"
```

## Explanation of Flags and Options

| Flag | Purpose |
|------|---------|
| `--base main` | Specifies the target branch for the PR. Since the task says "targeting main," this ensures the PR merges into `main`. If `main` is the default branch, this flag is technically optional, but it is good practice to be explicit. |
| `--title "Fix screen recording loop on Android"` | Sets the PR title exactly as requested. |
| `--label "bug"` | Attaches the `bug` label to the PR. The label must already exist in the repository; `gh pr create` will not create labels on the fly. If the label does not exist, the command will fail. |
| `--reviewer alice,bob` | Requests reviews from GitHub users `alice` and `bob`. These must be valid GitHub usernames (not display names) and they must have access to the repository. Multiple reviewers are comma-separated with no spaces. |
| `--body "..."` | Sets the PR description. The key line is `Closes #540`, which uses GitHub's auto-close keyword so that issue #540 is automatically closed when the PR merges into the default branch. |

### Why `Closes #540` for Auto-Close

GitHub recognizes several keywords that link a PR to an issue and auto-close it on merge:

- `Closes #540`
- `Fixes #540`
- `Resolves #540`

Any of these work. I chose `Closes` as it is the most common convention. The keyword must appear in the PR body (not the title) for GitHub to register the auto-close link. The auto-close only triggers when merging into the repository's **default branch**, which aligns with our `--base main` target.

## Alternative Approaches

### 1. Using `--assignee` in addition to `--reviewer`

If you also want to assign yourself (or others) to the PR:

```bash
gh pr create \
  --base main \
  --title "Fix screen recording loop on Android" \
  --label "bug" \
  --reviewer alice,bob \
  --assignee @me \
  --body "Closes #540"
```

### 2. Using a file for the body

For longer PR descriptions, you can write the body to a file and reference it:

```bash
gh pr create \
  --base main \
  --title "Fix screen recording loop on Android" \
  --label "bug" \
  --reviewer alice,bob \
  --body-file pr-body.md
```

### 3. Two-step: create then modify

If you need to add labels or reviewers after creation (e.g., if the label does not exist yet and you need to create it first):

```bash
# Create the label if it doesn't exist
gh label create bug --description "Something isn't working" --color d73a4a

# Create the PR
gh pr create --base main --title "Fix screen recording loop on Android" --body "Closes #540"

# Then add label and reviewers
gh pr edit --add-label "bug" --add-reviewer alice,bob
```

### 4. Interactive mode

Omitting `--title` and `--body` launches an interactive editor, but this is not scriptable and not recommended for automation.

## Gotchas to Watch Out For

1. **Label must exist.** `gh pr create --label bug` will fail if the `bug` label has not been created in the repository. You can check with `gh label list` and create with `gh label create bug` if needed.

2. **Reviewer usernames must be valid.** `alice` and `bob` must be actual GitHub usernames with access to the repo. If they are team names, use `--reviewer org/team-name` syntax instead.

3. **Branch must be pushed.** The command assumes the current branch has already been pushed to the remote (the task states "I just pushed my branch," so this is satisfied). If the branch is not pushed, add a `git push -u origin HEAD` before running `gh pr create`.

4. **Auto-close only works on default branch merges.** If `main` is not the repository's default branch, the `Closes #540` keyword will link the issue but will **not** auto-close it on merge. Verify with `gh repo view --json defaultBranchRef`.

5. **Multiple labels.** If you need to add more than one label, repeat the flag: `--label "bug" --label "android"`. The comma-separated syntax (`--label "bug,android"`) does **not** work; it would look for a single label named `bug,android`.

6. **Draft PRs.** If you want to create a draft PR first, add `--draft`. This is useful for WIP branches where you want feedback before the PR is ready for merge.

7. **Head branch inference.** `gh pr create` automatically uses your current checked-out branch as the head (source) branch. If you want to specify a different branch, use `--head branch-name`.

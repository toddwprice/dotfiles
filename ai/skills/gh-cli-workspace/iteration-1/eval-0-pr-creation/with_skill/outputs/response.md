# PR Creation: Fix Screen Recording Loop on Android

## 1. Exact Command

```bash
gh pr create \
  --base main \
  --title "Fix screen recording loop on Android" \
  --label bug \
  --reviewer alice,bob \
  --body "$(cat <<'EOF'
## Summary

Fixes the screen recording loop issue on Android by adding platform awareness to track type mapping and ensuring mobile screen-and-camera returns a single audio_video track.

Closes #540

## Test Plan

- [ ] Verify Android screen recording no longer enters an infinite loop
- [ ] Confirm iOS screen recording behavior is unchanged
- [ ] Validate that mobile screen-and-camera correctly returns a single audio_video track
EOF
)"
```

## 2. Explanation of Flags and Options

| Flag | Why |
|------|-----|
| `--base main` | Explicitly targets `main` as the merge target. While `main` is likely the default branch and `gh` would infer it, being explicit avoids any ambiguity, especially in repos where the default might be `develop` or `master`. |
| `--title "Fix screen recording loop on Android"` | Sets the PR title exactly as requested. |
| `--label bug` | Attaches the `bug` label to the PR at creation time. The `--label` flag accepts comma-separated values, but since we only need one label, a single value suffices. Note: the label must already exist in the repository or the command will fail. |
| `--reviewer alice,bob` | Requests reviews from both `alice` and `bob`. These are GitHub usernames passed as comma-separated values to `--reviewer`. Both users must have access to the repository. For team reviewers, the format would be `org/team-name`. |
| `--body "..."` | Provides the PR description inline. The body includes `Closes #540`, which is one of GitHub's recognized keyword patterns for auto-closing issues. When this PR is merged into the default branch, GitHub will automatically close issue #540. |

### Why "Closes #540" works for auto-close

GitHub recognizes several keywords that, when followed by an issue reference in a PR body, will auto-close the linked issue upon merge:
- `Closes #540`
- `Fixes #540`
- `Resolves #540`

All three are equivalent. I used `Closes #540` as it is the most common convention. The keyword is case-insensitive (`closes`, `Closes`, `CLOSES` all work). The issue reference must be in the PR body (not just the title) for auto-close to trigger.

### Why HEREDOC for the body

Using `cat <<'EOF' ... EOF` inside a command substitution keeps the body cleanly formatted across multiple lines and avoids issues with shell interpolation of special characters. The single quotes around `EOF` prevent any variable expansion inside the body text.

## 3. Alternative Approaches and Gotchas

### Alternative: Two-step create + edit

If you are unsure whether the label or reviewers exist, you could create the PR first and then add metadata:

```bash
# Step 1: Create the PR
gh pr create --base main \
  --title "Fix screen recording loop on Android" \
  --body "Closes #540"

# Step 2: Add label and reviewers (using the PR number returned by step 1)
gh pr edit <PR_NUMBER> --add-label bug --add-reviewer alice,bob
```

This approach is more resilient: `gh pr create` will fail entirely if a label does not exist, whereas `gh pr edit --add-label` will also fail but at least the PR will already exist.

### Alternative: Using `--body-file`

For longer PR descriptions or team templates, use `--body-file`:

```bash
gh pr create --base main \
  --title "Fix screen recording loop on Android" \
  --label bug \
  --reviewer alice,bob \
  --body-file .github/PULL_REQUEST_TEMPLATE.md
```

This is useful when you have a standardized template, but you would need to ensure the file includes the `Closes #540` reference.

### Gotchas to Watch Out For

1. **Label must pre-exist.** If `bug` is not already a label in the repository, `gh pr create --label bug` will fail. You can check with `gh label list` and create it with `gh label create bug --color d73a4a` if needed.

2. **Reviewer access.** Both `alice` and `bob` must be collaborators on the repository (or members of the organization). If either username is invalid or lacks access, the command will fail.

3. **Branch must be pushed.** The `gh pr create` command requires the current branch to have a remote tracking branch. Since the user confirmed they just pushed, this is satisfied. If not, you would need `git push -u origin HEAD` first.

4. **Auto-close only works on default branch merge.** The `Closes #540` keyword only triggers auto-close when the PR is merged into the repository's default branch. If `--base` pointed to a non-default branch (e.g., `develop`), the issue would not auto-close until those changes reach the default branch.

5. **Issue must be in the same repo (or use full reference).** `#540` refers to issue 540 in the same repository. For cross-repo references, use `owner/repo#540`.

6. **Current branch detection.** `gh pr create` uses the current git branch as the `--head` (source branch). Make sure you are on the correct branch (`cnvs-540-screen-recording-loop-android`) when running the command.

7. **Draft vs. ready.** The command above creates a non-draft PR. If you want to create it as a draft first (e.g., for CI to run before requesting reviews), add `--draft` and then later run `gh pr ready <number>` to mark it as ready.

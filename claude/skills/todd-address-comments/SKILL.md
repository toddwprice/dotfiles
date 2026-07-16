---
name: todd:address-comments
description: >
  Pull, triage, fact-check, and respond to PR review comments end-to-end. Use this WHENEVER Todd
  wants to deal with comments on a pull request — phrasings like "pull comments for the PR and
  propose how to address them", "address the baz comments", "resolve the comments on PR 25840",
  "respond to sam's comments", "process pr comments for 25834", "look at the feedback baz left and
  resolve it", "reply to the low-severity comments", "check for baz comments on my open PRs", or
  "what needs to be done to satisfy the comments on this PR". Trigger even when Todd doesn't say the
  word "skill" and even when he names a specific reviewer (baz, sam, mbrashid62) or a PR number.
  This skill fetches the threads itself (you do NOT need them pasted in), fact-checks each claim
  against the actual code, and by default PROPOSES a plan + draft replies and waits for approval
  before changing code or pushing.
allowed-tools: Bash(gh:*), Bash(git:*), Bash(mix:*), Bash(yarn:*), Bash(uv:*), Bash(cat:*), Bash(mktemp:*), Read, Grep, Glob, Agent
---

# Address PR Review Comments

Todd's most-repeated manual loop. He kept re-typing "pull the comments and propose how to address
them" because the skill he owned (`git-address-comments`) made him paste the comments in by hand —
the part worth automating is the **pulling + triage + fact-check + per-thread reply**, not the
addressing. This skill does the whole loop and **stops to get his OK before it writes code or
pushes** (his chosen default — see the question he answered when this was built).

## The contract

**Default mode is propose-first.** Pull → fact-check → present a triage table with draft replies and
a fix plan → **wait**. Only after Todd says go do you implement, reply, run CI, and push.

If Todd's request clearly says "just do it" / "resolve them for me and push" / "full auto", you may
run straight through — but still show the triage table first so he can abort, then proceed without a
second prompt.

## Step 1 — Identify the PR

`$ARGUMENTS` may contain a PR number, reviewer name(s), or be empty.

- PR number → use it.
- Empty → `gh pr view --json number,headRefName,url -q '{n:.number,b:.headRefName,u:.url}'` for the
  current branch. If there's no PR for the branch, say so and stop.
- "check my open/drafted PRs for baz comments" → `gh pr list --author @me --json number,title,url`
  then loop the steps below over each, reporting which PRs actually have unaddressed comments.

Resolve `{owner}/{repo}` once: `gh repo view --json nameWithOwner -q .nameWithOwner`.

## Step 2 — Pull every thread (this is the part Todd hates doing by hand)

Get the three comment surfaces in parallel:

```bash
# Inline review comments (the threads on specific lines)
gh api repos/{owner}/{repo}/pulls/<N>/comments --paginate \
  --jq '.[] | {id, in_reply_to_id, path, line, original_line, user:.user.login, body, created_at}'

# Top-level PR conversation comments
gh api repos/{owner}/{repo}/issues/<N>/comments --paginate \
  --jq '.[] | {id, user:.user.login, body, created_at}'

# Review summaries (APPROVE / REQUEST_CHANGES / COMMENT bodies)
gh api repos/{owner}/{repo}/pulls/<N>/reviews --paginate \
  --jq '.[] | {id, user:.user.login, state, body, submitted_at}'
```

**Find what's actually unaddressed.** GitHub's "resolved" state isn't in the REST payload — use
GraphQL to get `isResolved` per thread so you don't re-litigate settled discussions:

```bash
gh api graphql -f query='
  query($owner:String!,$repo:String!,$num:Int!){
    repository(owner:$owner,name:$repo){
      pullRequest(number:$num){
        reviewThreads(first:100){ nodes {
          isResolved isOutdated
          comments(first:50){ nodes { databaseId author{login} path line body } }
        }}
      }
    }
  }' -f owner={owner} -f repo={repo} -F num=<N> \
  --jq '.data.repository.pullRequest.reviewThreads.nodes'
```

Group inline comments into threads by their root (`in_reply_to_id == null` is a root; replies hang
off it). For each thread record: root comment id, path, line, author, full body, `isResolved`, and
whether the **last** reply is from Todd (i.e. already answered).

**Skip** threads that are `isResolved` or already answered by Todd unless he explicitly asks to
revisit them. Report how many you skipped and why.

### Reviewer awareness

- **baz** is the AI reviewer (a GitHub App) and is the dominant commenter on Todd's PRs. Its
  comments often carry a severity and an embedded `<details>Instructions for AI Agents</details>`
  block. Weight baz comments by their stated severity; low-severity baz nits can be acknowledged and
  declined with a one-line rationale rather than always actioned.
- **Humans** (e.g. `sam`, `mbrashid62`, `snkutkoski`) are authoritative — fact-check, but lean
  toward addressing or explicitly explaining.

## Step 3 — Fact-check each comment against the code

Don't take any comment at face value, including baz's. For each unaddressed thread:

1. Fetch the file from the PR head branch: `git show origin/<headRef>:<path>` (run
   `git fetch origin <headRef>` first if needed). Read the lines the comment references.
2. Verify the claim: does the code actually do what the comment says? Are the named functions /
   behaviors / edge cases described accurately?
3. Check codebase patterns with a `dev-flow:codebase-pattern-finder` (or `codebase-pattern-finder`)
   sub-agent — is the suggestion consistent with how the rest of the repo handles this, or does the
   repo already accept the flagged pattern elsewhere? Run these in parallel across independent
   threads.
4. Assess each as one of:
   - **Accurate & actionable** — correct and aligns with conventions → fix it.
   - **Accurate but non-actionable** — correct but the repo already accepts this pattern → reply
     explaining why we're keeping it.
   - **Partially accurate** — has a real kernel but overreaches → fix the real part, clarify the rest.
   - **Inaccurate** — wrong about the code → reply with the evidence that refutes it.

## Step 4 — Present the triage table and WAIT

Show Todd a compact table, then the draft replies and the fix plan. Stop here in propose-first mode.

```
| # | Thread (file:line)        | Reviewer | Severity | Verdict            | Plan        |
|---|---------------------------|----------|----------|--------------------|-------------|
| 1 | errorhandling.ts:42       | baz      | medium   | Accurate&actionable| fix + reply |
| 2 | study_setup.py:1283       | baz      | low      | Accurate non-act.  | reply only  |
| 3 | screener_pair.ex:88       | sam      | —        | Partially accurate | fix part    |
```

Under the table, for each thread give: the **draft reply** (Todd's voice — clear, terse, kind; lead
with the answer; cite `file:line` evidence) and, for the ones you'll fix, a one-line **what you'll
change**. Then ask Todd to confirm, edit, or drop any before you proceed.

Use the `speak-as-todd` skill conventions for reply wording.

## Step 5 — Implement (after approval)

**Work in the PR's checkout, not wherever you happen to be.** Todd works in git worktrees, so the
CWD is often a *different* branch's tree. Before editing: confirm you're on the PR's branch
(`git branch --show-current` == `<headRef>`); if not, switch to that branch's worktree
(`git worktree list` to find it) or check it out. Never edit/commit against the wrong tree.

- Make the agreed code changes. If the change has behavioral surface, follow the repo's TDD norm
  (write/extend the failing test first). Keep edits scoped to what the comments asked for.
- Commit with a clear message. End commit messages with the repo trailer:
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- **Checks are mandatory before pushing** — this is a hard rule for Todd's branches. There is **no
  runnable `./bin/ci`** (`bin/ci/` is a *directory* of per-task CI scripts, not an aggregate
  command). Run the CLAUDE.md pre-push checklist for **each app the diff touches**:
  - **Axon** (`apps/axon`): `mix format --check-formatted && mix compile --warnings-as-errors` (and
    `mix test` if behavior changed; `mix lint` for the fuller pass).
  - **Dendra** (`apps/dendra`): `yarn lint && yarn test`.
  - **Astro** (`apps/astro`): `uv run ruff check . && uv run pytest`.
  - **Axon SPAs** (`apps/axon/assets`): `npm run lint && npm run test`.
  Make them green before pushing. To mirror a specific CI task locally, the individual scripts live
  in `bin/ci/*.sh` (e.g. `bin/ci/axon-exunit.sh`).

## Step 6 — Reply to each thread, then push

> Posting mechanics + the Answer-only rule (no `<details>Instructions for AI Agents</details>` block
> on Todd's replies) are the shared canonical spec at `~/.claude/skills/_shared/review-payload.md`.

Reply on the **comments** endpoint (thread replies are NOT the reviews endpoint):

```bash
gh api repos/{owner}/{repo}/pulls/<N>/comments -f body="<reply>" -F in_reply_to=<root_comment_id>
```

- One reply per thread, explaining how it was addressed (or why it wasn't). Thread replies are
  follow-ups to a discussion — do **not** wrap them in `<details>Instructions for AI Agents</details>`.
- Publish each reply individually; if one fails, report it and continue with the rest.
- Optionally resolve the threads you fully addressed:
  ```bash
  gh api graphql -f query='mutation($id:ID!){resolveReviewThread(input:{threadId:$id}){thread{isResolved}}}' -f id=<threadNodeId>
  ```
- Push the branch. Report a one-line summary: threads addressed / replied-only / skipped, the commit
  sha, and the PR URL.

## Notes

- Never push without showing the triage table first.
- If Todd points at a local review file instead (`~/Downloads/pr-XXXX-review.{md,json,html}`), that's
  the inverse direction — publishing *his* review — handing off to `todd:sync-review` is the better
  fit; mention it.
- If a comment says "filed for later" or implies a follow-up ticket, check whether one actually
  exists and offer `todd:followup-ticket` to create it.

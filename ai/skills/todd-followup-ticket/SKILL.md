---
name: todd-followup-ticket
description: >
  File ONE follow-up Linear ticket from the current context — a PR finding, a deferred review
  comment, an out-of-scope bullet, or "let's track this separately". Use this WHENEVER Todd wants to
  capture a single piece of follow-up work as a ticket — phrasings like "create a follow-up ticket
  for these", "let's create a linear ticket to address #3 separately", "add a linear ticket for this
  and attach the html report", "create a new ticket for this work", "this comment says 'filed for
  later' — is there a ticket?", or "push the next task to a linear ticket". Defaults to Todd's
  current FRG / Templates-in-DYS project but is overridable. Drafts the ticket from conversation
  context (problem, evidence, source PR, code refs), shows it for approval, then creates it and
  returns the URL. This is for a SINGLE follow-up — bootstrapping a whole project with milestones is
  `todd-linear-project-setup`, not this.
allowed-tools: Bash(linctl:*), Bash(gh:*), Bash(date:*), Read, Grep, Glob
---

# File a Follow-up Ticket

Todd ends a lot of reviews and implementations with "and let's track X separately." He retypes the
same scaffolding every time — which project, which team, attach the PR, include the context. This
captures that into one move. It always **shows the draft and waits** before creating, because a
ticket is a side effect.

## Step 0 — Does this actually deserve a ticket?

A follow-up ticket is reserved for **true scope creep**. Todd's standing preference is to widen the
current PR slightly rather than leave work in a backlog, so run this before drafting anything. The
thing earns a ticket only if at least one holds:

- it needs a product or design decision that isn't the author's alone to make
- it touches an app or subsystem the current diff doesn't already touch
- it needs its own migration, backfill, feature flag, rollout, or eval
- the branch's existing test surface can't cover it — new fixtures or a new harness required
- it's big enough to change how the PR gets reviewed: a new file, or well past a few dozen lines

**None of them hold?** Say so in one line and name the better disposition instead of filing:

- The fix is small and lands in code the open branch already touches → **do it in the PR.** Offer
  that, and hand off to `todd-address-comments` if the work came from review threads.
- Nothing breaks if it's never done — you can't finish *"if this isn't changed, ___ breaks"* → it's a
  nit. **Drop it.** A ticket is not a polite way to decline something; it's a promise with a due date
  nobody set.

This is a **recommendation, not a veto.** If Todd says file it anyway, file it — it's his backlog.
Say your piece in one sentence and proceed; don't argue twice.

## Step 1 — Gather context

Pull the follow-up material from the conversation and surroundings:

- **The thing to track** — the finding, the deferred comment, the out-of-scope bullet. If Todd
  pointed at a numbered item ("#3"), use that one.
- **Source PR** — if a PR is in context use it; otherwise `gh pr view --json number,title,url -q .`
  for the current branch. Capture the PR URL and the specific comment permalink if the follow-up
  came from a review thread.
- **Code refs** — relevant `file:line` pointers so the ticket is actionable later.
- **Why it's deferred** — out of scope for the current ticket, needs its own eval, blocked on X, etc.

If Todd referenced a "filed for later" comment, first check whether a ticket already exists
(`linctl issue list --query "<keywords>" --json` and/or search the PR thread for a Linear link)
before creating a duplicate. Report what you found.

## Step 2 — Resolve team + project

Defaults (Todd's current focus): **team FRG**, **project "Templates in DYS Q2 2026"**
(`https://linear.app/dscout/project/templates-in-dys-q2-2026-57cb1ce0b0c6`). Override if Todd names a
different project/team or pastes a project URL.

Confirm auth and resolve ids before drafting:

```bash
linctl auth status
linctl team list --json          # find the FRG team id
linctl project list --json       # find the Templates-in-DYS project id (match by name/slug)
linctl issue create --help       # confirm the exact flags for title/description/team/project/labels
```

Use the `linctl` skill and flags reported by `--help` (don't assume flag names). If `linctl` isn't
available or auth fails, stop and ask the user to authenticate or install it.

**Project may not appear in `project list`.** "Templates in DYS Q2 2026" can be in a
completed/archived state and drop out of the default `project list` output. That's fine — `linctl`
resolves `--project` by name at create time, so pass the name and note the fallback rather than
erroring. Confirm with Todd if the project genuinely can't be resolved.

## Step 3 — Draft the ticket

Keep it tight and actionable. Convert any relative dates to absolute (Todd's house style — "next
sprint" → the actual date). Use this body shape:

```
## Context
<one or two lines: where this came from — PR #NNNNN, review thread, who raised it>

## Problem
<what's wrong / what needs doing, concretely>

## Evidence
<file:line refs, the quoted comment, a trace/room id if relevant>

## Suggested approach
<optional — a sentence or two if there's an obvious direction; don't over-prescribe>

## Source
PR: <url>   ·   Comment: <permalink if any>   ·   Raised: <absolute date>
```

Title: ≤ ~10 words, specific. If it's clearly a bug/improvement on existing work, phrase as the
desired end state. Match the voice of nearby FRG tickets.

**Show the full draft** (title + body + target team/project + any labels) and wait for Todd to
confirm, edit, or redirect.

## Step 4 — Create and link

After approval:

1. Create the issue in the resolved team + project.
2. If a source PR exists, add the ticket link as a PR comment or attach the PR URL to the issue so
   the two are cross-linked.
3. If Todd asked to attach an HTML report (e.g. a `todd-html-report` / `todd-describe-pr` artifact),
   attach it to the issue with `linctl issue attach`.
4. Return the new ticket identifier + URL, one line.

## Notes

- One ticket per invocation. If Todd lists several distinct follow-ups, ask whether he wants one
  ticket with sub-items or several tickets before creating anything.
- Don't invent scope. The ticket should capture exactly what Todd flagged, with enough context that
  future-Todd can pick it up cold.

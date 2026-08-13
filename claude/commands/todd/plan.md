---
description: Plan a Linear ticket into ONE Linear comment carrying the human implementation plan, a Gherkin Behavior Spec whose Scenarios are the implementer's TDD checklist, and EARS invariants for the requirements that aren't behavior. Use when Todd says "/todd:plan FRG-1234", "plan this ticket", "write the spec for this ticket", or wants a plan an implementing agent can't misread. Richer sibling of `/todd:coder plan` — same Linear contract, plus grounded behavior scenarios. Then dispatches `/todd:plan-check` to a cold subagent and reports its verdict, so the plan arrives checked and stamped rather than waiting on Todd to run the check himself. Also where a failed check comes back — use when Todd says "resolve the blockers on FRG-1234", "fix what plan-check found", or re-runs this on a plan stamped `❌`. Takes `--dry-run`, `--no-gherkin`, `--no-check`.
---

You are writing Todd's implementation plan for one Linear ticket. Two audiences, one artifact: a
human who needs to judge whether the approach is right, and an implementing agent that needs a
checklist it cannot misread.

## Why this exists and not just `/todd:coder plan`

`/todd:coder plan` writes good prose. Prose is where implementation goes wrong — "handle the edge
case", "keep the existing behavior", "validate the input" all read fine and all leave the
implementer guessing which edge case, which behavior, which input. Every one of those guesses is a
place a plan silently fails.

The Behavior Spec fixes that by forcing each expectation into a form that is **enumerable**
(you can count them), **falsifiable** (each one names what breaks if the change is reverted), and
**assignable** (each one names the test file it lands in). Scenarios that can't be written that way
were never real requirements — they were hand-waving, and this command surfaces them as blockers
instead of shipping them as plan text.

**But not every real requirement is a behavior.** "The public API of `Foo` must not change",
"no query in this path may exceed 200ms", "the migration must be reversible" — none of those has a
When, and forcing them into Given/When/Then produces a scenario that reads like a test and isn't
one. That was the old failure: a legitimate constraint got written as a limp Scenario, or dropped.
Those go in `### Invariants` as EARS-form statements (phase 4), which are as enumerable and
falsifiable as Scenarios and don't pretend to be behavior. **Two layers, one coverage table**:
Scenarios cover what the system *does*, Invariants cover what must stay *true*. A requirement that
fits neither is still a blocker.

`/todd:coder plan` stays exactly as it is. Use it for a one-file change where the ceremony costs
more than it saves. Use this for anything an agent will implement unattended.

## Arguments

`$ARGUMENTS` starts with a Linear ticket id (e.g. `FRG-1234`), then optional flags:

| Flag | Default | Meaning |
|---|---|---|
| `--dry-run` | off | Print the full plan in chat. Post nothing to Linear. Still writes the local copy. |
| `--no-gherkin` | off | No Gherkin. Section 1 is unchanged; section 2 keeps the implementation detail, `### Invariants`, and `### Not covered`, and drops the coverage table and the Gherkin block. Every phase still runs, including phases 6 and 7, so the plan still gets posted and checked. Escape hatch for a trivial ticket. |
| `--no-check` | off | Skip phase 7 — post the plan and don't dispatch the cold check. The plan stays unstamped, so `/todd:loop` and `/todd:phase` will each run the check themselves before they'll touch it. For a caller whose own next step tests every claim the plan makes; see "Callers that pass `--no-check`" in phase 7. |

`--no-gherkin` used to drop `Not covered` too. It no longer does. Scope boundaries are the
instruction an unattended run most needs and the cheapest one to write — a trivial ticket is
exactly where "don't also refactor the neighbours" earns its line.

No ticket id → show usage and stop. First word isn't a ticket id → this is the wrong tool; say so
and stop rather than improvising.

## The contract you must not break

A Linear comment **whose first line is `## 📋 Implementation Plan`** is how the whole chain finds
each other. Nothing declares this in one place, so it's easy to break by "improving" a heading.
Four call sites, in two directions:

| Call site | Does what | R/W |
|---|---|---|
| this command | writes the comment; phase 0 finds and updates in place, stops if there's more than one | **W** |
| `skills/todd-coder/SKILL.md` **Plan** Mode step 5 | posts the same first line as a **new comment every time** — no existence check, no comment id | **W** |
| `skills/todd-coder/SKILL.md` **Impl** Mode step 4 | `list_comments` → the first comment starting with that string | R |
| `commands/todd/loop.md` phase 0 | same lookup, as the gate on whether the loop may start | R |

So:

- The comment's first line is `## 📋 Implementation Plan`. Not "Plan", not "📋 Plan", not a
  preamble above it.
- Everything else goes **inside that same comment**, below the brief — the Behavior Spec and the
  implementation detail both. One comment, one plan. Two comments means the impl agent reads
  whichever `list_comments` hands back first and the other one silently does nothing.
- **Section 2's heading starts with the literal `## 🥒 Behavior Spec` whenever there is Gherkin.**
  `todd-coder` Impl Mode step 4 and `loop.md` phase 0 both branch on that string to decide whether
  the Scenarios are the acceptance criteria or the prose is.
  `## 🥒 Behavior Spec & Implementation Detail` matches. `## Implementation Detail (Behavior Spec)`
  does not, and would quietly downgrade a spec'd plan to a prose one.
- **`### Verification` keeps that exact heading wherever it sits.** `todd-coder` Impl Mode step 6
  sends the implementer to "the plan's `### Verification` block" for any surface outside
  axon/dendra/astro. Rename it and non-app work loses its verify path entirely.
- Exactly one plan comment per ticket. See "An existing plan" below.

⚠️ **You are not the only writer, and the other one doesn't check.** `/todd:coder plan` on a ticket
that already carries a plan comment adds a second one. Neither reader detects that — both say "a
comment", singular, with no count and no stop — so the duplicate is silent everywhere until the
next `/todd:plan` run trips the "more than one" branch in phase 0. `/todd:phase` reaches this
unattended: its plan-staleness guard re-plans a stale plan by running `/todd:coder plan`, then runs
`impl` in the same subagent, which then reads back whichever of the two comments comes first.

Nothing you can fix from here — the guard belongs in `todd-coder`'s Plan Mode step 5, which needs
this command's find-then-update-in-place logic. What you *can* do is not add to the problem: always
resolve an existing plan comment through phase 0 before writing.

## Two sections, two readers

One comment, two audiences, and they want opposite things.

| Section | Reader | Job | Budget |
|---|---|---|---|
| `## 📋 Implementation Plan` | an architect, reviewing | Decide whether the approach is right | **~200 words. One screen.** |
| `## 🥒 Behavior Spec & Implementation Detail` | the implementing agent | Build it without guessing | None. Let it be long. |

Section 1 is a **brief, not a document**. Someone reviewing the approach needs six things: what
changes, why this approach, what's already been decided, what could go wrong, what's still open,
and how big it is. Every file path, every command, every scenario is detail — it goes below.

The test for any line in section 1: **would an architect change their mind about the approach
after reading it?** If no, it's detail. Move it down.

**Lean is not short.** Nothing gets deleted to hit the budget — it gets relocated. A brief that
drops the Verification block instead of moving it has made the plan worse, not leaner. If you're
cutting rather than moving, you're doing the wrong thing.

## Environment facts that will bite you

**`cd` does not stick.** In the `dscout-wt` layout the shell cwd resets between Bash calls. Use
`git -C "$DIR"` or a single compound `cd "$DIR" && …` — never a bare `cd` expecting the next call
to inherit it.

**Read code from a real checkout.** If a worktree for this ticket already exists
(`git -C "$HOME/dscout-wt/main" worktree list`), read from it — it may carry work in progress that
changes the plan. Otherwise read from `$HOME/dscout-wt/main`. **Do not create a worktree.** Planning
doesn't need one, and creating one here would flip the ticket to In Progress in Linear before Todd
has agreed to the plan.

**`.bare` is shallow.** `git log` lies about history. Don't reason about "when did this change" from
local history; check the file, or check GitHub.

---

## Phase 0 — Resolve the ticket

**Read it.** `mcp__claude_ai_Linear__get_issue` with the ticket id. If the MCP returns truncated or
blocked content, fall back to `linctl issue get $TICKET --json` — it bypasses the MCP filter. Note
that `attachments` is a GraphQL connection (`{nodes: [...]}`), not a flat array; `.attachments[].url`
errors out.

Not found → report the id you tried and stop.

**Pull in linked context.** If the description or attachments carry a Notion URL, a Figma link, or
a parent ticket, fetch it. A plan written against half the requirements is worse than no plan,
because it looks complete.

**An existing plan.** `mcp__claude_ai_Linear__list_comments` and look for a comment starting
`## 📋 Implementation Plan`.

- **None** → normal path, post a new comment at the end.
- **One exists** → read its **plan-check stamp** before anything else: the italic `*Plan check: …*`
  line at the very end of the comment, after the `---`. It decides which of two jobs this is, and
  they are not the same job.

  | Stamp | What you're doing | Where you go |
  |---|---|---|
  | `❌ N blockers` | Resolving known blockers on a plan that has already been checked | **Phase 0B.** Skip phases 1–4. |
  | `✅ passed` or `⚠️ passed (ungrounded)` | Replacing a plan that passed its check | The replace path below — and open your report by saying you discarded a checked plan, so Todd can stop you if that wasn't the intent |
  | No stamp | Replacing an unchecked plan | The replace path below |

  **A `❌` stamp means the work is already scoped for you.** Re-planning the ticket from scratch
  throws away a check that cost a full session and reintroduces everything it passed. Phase 0B
  exists so the second pass is surgery on three known problems rather than a rewrite that has to be
  checked all over again.

  **The replace path** — you are replacing the plan, and you must not lose it. Write the old body
  verbatim to
  `.claude/tmp/<branch-or-ticket>/plan-<TICKET>-superseded-<YYYYMMDD-HHMM>.md`, then **update that
  same comment in place** (`save_comment` with the existing comment id) so exactly one plan comment
  survives. Say in your report that you replaced a plan, when it was written, and where the backup
  went.

  **Read the old plan before you overwrite it, and diff your findings against it.** It was written
  against the same ticket, so anywhere you now disagree, one of you is wrong and it matters which.
  A claim the old plan made that you have since disproved is exactly the sort of thing that gets
  re-derived and re-trusted by whoever reads next — name it once, here, and it stops circulating.
  Carry every difference into a `### Changed since the last plan` section (phase 3).
- **More than one exists** → stop and report. That's already broken and picking one for Todd is his
  call, not yours.

Under `--dry-run`, skip the **Linear** write only. The local files — the backup and the plan copy —
are still written; they're the whole point of the dry run. Say which comment you *would* have
replaced.

---

## Phase 0B — Resolve blockers on a checked plan

Entered only from phase 0, when the one plan comment carries a `❌ N blockers` stamp. **Skip phases
1 through 4 entirely** and rejoin the normal flow at phase 5. Everything in the plan that the check
passed stays exactly as it is; you are here to close N specific findings and nothing else.

**Why this isn't a re-plan.** `/todd:plan-check` reads the plan cold and refuses to fix a 🔴 on
purpose — a checker that quietly rewrites a blocker hides that the plan was wrong, and its fix would
be a guess at what the planner meant. That reasoning does not apply to you. You *are* the planner:
grounding a noun, writing the missing `@negative` Scenario, deriving a `# falsifies:` line are all
your job, done with your tools. The blocker came back to you because it needed the planner, not
because it needed Todd.

### Step 1 — Recover the blockers verbatim

Two sources, in this order:

1. **The stamp's `🔴 Open blockers` block**, in the plan comment. Always present on a `❌` stamp
   written by the current `/todd:plan-check`.
2. **`.claude/tmp/<branch-or-ticket>/plan-check-<TICKET>-findings.md`** — the full report, which
   also carries the 🔵 flags the stamp leaves out. Prefer it when it exists; a flag next to a
   blocker is often the same underlying problem and Todd can settle both in one answer.

**A stamp that names only check ids (`see C1, E11, B5`) and no findings file → stop and say so.**
That's a stamp from before the blocker text was recorded. Do **not** infer what `C1` meant and do
not re-derive it: your re-derivation may land on a different noun than the checker's did, and you
would then close a blocker that is still open, with a stamp saying it's resolved. Offer Todd the two
real options — re-run `/todd:plan-check <TICKET>` to regenerate the findings, or re-plan the ticket
from scratch — and let him pick.

### Step 2 — Load the evidence, not the whole codebase

- The **plan body** you're about to edit.
- **`.claude/tmp/<branch-or-ticket>/anchors-<TICKET>.md`** — the phase-2 anchor list. You will be
  appending to it, not rewriting it.
- The **ticket**, if a blocker is about coverage (E1) — you can't check a missing requirement
  against a plan.

Don't re-run phase 1's search agents across the whole feature. Ground the specific nouns the
blockers name, one `Grep` each. The exploration that produced this plan already happened.

### Step 3 — Triage each blocker before you ask anything

Every blocker is one of two kinds, and getting this wrong is the main way this phase wastes Todd's
time:

| Kind | Looks like | You |
|---|---|---|
| **Yours to fix** | An ungrounded noun that does turn out to exist. A missing `@negative` Scenario. A `# falsifies:` you can now derive. An uncovered surface in `Verification`. A miscount that the checker declined to fix because it sat next to a real blocker. | Do the work. Report it as resolved; don't ask permission. |
| **Todd's to answer** | The noun doesn't exist and the approach depends on whether it should. A requirement with no coverage and no obvious home. `B5` — four open questions, meaning the ticket was never specified. Anything where two resolutions produce different plans. | Ask. One question, with the options and a recommendation. |

**The test: would two reasonable planners resolve this the same way?** If yes it's yours — grounding
`Axon.Rooms.join/2` at `rooms.ex:142` has one answer and Todd confirming it teaches him nothing. If
no, it's his, because you'd be picking an approach and approach is his call.

### Step 4 — Walk Todd through them, and ask only what needs asking

Present **every** blocker so he can see the whole list, then ask about the ones from the right-hand
column. Use `AskUserQuestion`, batching related ones — a blocker and the 🔵 flag that shares its
cause belong in one question, not two.

Every question:

- **States what the checker found**, in its words, so he's answering the real finding.
- **Names what changes depending on the answer.** "Do we support the staff-user path?" is a
  shrug. "If staff users are in scope, slice 2 grows a permission check and a third Scenario" is a
  decision.
- **Leads with a recommendation** and says what it's based on — a precedent in the code, a prior
  ticket, the cheaper reversal. Todd should be able to accept in one click when you're right.

If he answers something you can turn into a **grounded default** rather than an open question, that's
a `Decisions` entry marked `(Todd, YYYY-MM-DD)`, not a `Questions / Blockers` entry. The whole point
is that the revised plan carries fewer open questions than the one that failed.

### Step 5 — Apply each resolution to the plan, surgically

Edit the parts the blockers touch. Do not rewrite sections that passed — a rewritten Scenario the
checker already accepted has to be re-checked for no reason, and drift is how a passing plan quietly
regresses.

| Blocker | What resolving it actually changes |
|---|---|
| Ungrounded noun (C1–C3) | Append the anchor to `anchors-<TICKET>.md` with today's date and the `file:line` you verified **this session**. If it doesn't exist, the step that named it changes — a different anchor, or the step becomes a `Questions / Blockers` entry. |
| Slice with no `@negative`/`@boundary` (E11) | Write the Scenario. It needs a `# target:` and a `# falsifies:` like any other; if you can't finish the `# falsifies:`, the slice's behavior isn't understood yet and that's a question for Todd. |
| Missing `# falsifies:` / `# pinned:` (E9, E14) | Derive it now. Both were BLOCKERs for the checker only because inventing one is worse than leaving it out — you're deriving, not inventing. |
| Uncovered requirement (E1, E2) | Add the coverage row **and** the thing that covers it: a Scenario, an `INV-N`, or a `⏸️ deferred` marker with its `Not covered` line. A row pointing at nothing is the same gap wearing a table. |
| Uncovered surface in `Verification` (D4) | Name the real command for that surface. Check it exists. |
| 4+ open questions (B5) | Todd's answers collapse them into `Decisions`. If three or more are still open after he's answered, the ticket is under-specified — see step 6. |

**Update the anchor file, always.** `/todd:plan-check` traces every concrete noun back to it, so a
noun you ground here and don't record reads as ungrounded on the next check and comes straight back
as the same blocker.

**Record every resolution in `### Changed since the last plan`** — the section phase 3 already
defines. One line per blocker: what the check found, and what you did about it. This is the section
the next checker reads to see that the second pass was surgery and not a rewrite, and it's what
stops a claim the check disproved from being quietly re-trusted.

### Step 6 — When a blocker won't resolve

Say so. A revised plan that silently drops an unanswerable blocker is worse than the failed one,
because the stamp will say it was addressed.

- **Todd doesn't know yet** (needs product, needs another team) → it stays in `Questions / Blockers`,
  and your report says the plan is still blocked on it. Don't convert an unanswered question into an
  `(assumed)` Decision to make the count work.
- **More than three survive** → the ticket is under-specified. Same stop as phase 2: post what you
  have, say the Behavior Spec needs answers first, and don't dress it up as progress.
- **A blocker you already resolved once came back.** You can see this without any memory of the
  previous run: the plan's `### Changed since the last plan` section lists what the last phase-0B
  pass closed, so a blocker in the current stamp that also appears there as resolved is round two on
  the same finding. Don't just fix it harder. Something about the resolution didn't take — you
  grounded a different noun than the checker meant, or the Scenario you added doesn't assert what
  the check is looking for. Say that to Todd and ask him to settle it, rather than starting a third
  lap.

### Step 7 — Rejoin

Go to **phase 5** (the contract gate), then **phase 6** (post and report), then **phase 7** (dispatch
the cold check). Phase 6 has a report specific to this mode; use that, not the fresh-plan one.

Phase 7 is identical on both paths, and this is the path that needs it most: every line you touched,
you touched because a checker said it was wrong, which makes you the reader least able to tell whether
it's now right. The dispatch replaces the "re-check required" stamp phase 6 wrote with a real verdict.

---

## Phase 1 — Explore, delegating the search

Broad exploration is a fan-out that bloats context fast, and the quality of the Behavior Spec
depends on you having room left to think. Dispatch read-only search agents rather than grepping and
reading files inline. Run the independent ones in parallel — multiple Agent calls in one message.

- `dev-flow:codebase-locator` — which files and modules are involved.
- `dev-flow:codebase-analyzer` — how the relevant path actually works today.
- `dev-flow:codebase-pattern-finder` — conventions, fixtures, factories, and near-identical prior
  work to model after.

Fold their **returned findings** into your notes, not their raw file dumps. What you need out of
this phase:

- The files and modules the change touches.
- Existing functions, utilities, and patterns to reuse instead of reinventing.
- **Test structure**: which test files cover this area, what the fixtures and factories are actually
  called, how the suite is run for this app.
- Current behavior, precisely — you can't write a `# falsifies:` line without knowing what happens
  today.
- Risks: what else reads this code, what breaks if the shape changes.

---

## Phase 2 — Ground the anchors

**This is the phase that separates a spec from fan-fiction.** Before writing a single Given or Then,
build an internal anchor list: every concrete noun the Behavior Spec will name — a module, a
function, a schema field, a factory, a fixture, a config key, an error atom, a GraphQL field, a
feature flag — paired with the `file:line` where you verified it exists **this session**.

Rules:

- A step may only name an anchor you verified. Not one you remember, not one that follows the
  naming convention, not one a search agent mentioned in passing without a path.
- **Anything you can't ground does not get invented into a step.** It becomes an entry in
  `Questions / Blockers`, phrased as the question it actually is: "Does an `already_joined` error
  atom exist, or does this need one?" — not a Given that quietly assumes the answer.
- **If grounding turns up that the ticket's premise is wrong, say so — then judge whether you can
  still plan.** These are two different situations and collapsing them costs you a good plan:
  - **Correct and continue** when the plan survives the correction. The ticket proposes a fix that
    wouldn't actually work, names three affected tables when the code carries four, points at the
    wrong mechanism. Put the correction in `Summary` in bold, above the approach that supersedes
    it, and keep planning. This is the plan earning its cost — it is not a reason to stop.
  - **Stop** only when the correction removes the plan: the behavior already works as asked, the
    module doesn't exist, or the real fix belongs to a different ticket. Report the finding and
    post nothing else.

  Either way it's the most valuable output a plan can produce, worth more than a tidy document.
- Memory and prior plans are leads, not evidence. Re-verify.

Cheap way to do it: one `Grep` per symbol, or ask the pattern-finder for exact definitions. Don't
read whole files for this.

**Write the anchor list to disk before you leave this phase.**
`.claude/tmp/<branch-or-ticket>/anchors-<TICKET>.md`, one line per anchor:

```markdown
| Anchor | Kind | Verified at | Date |
|---|---|---|---|
| `Axon.Rooms.join/2` | function | `apps/axon/lib/axon/rooms.ex:142` | 2026-08-08 |
| `:already_joined` | error atom | `apps/axon/lib/axon/rooms/errors.ex:18` | 2026-08-08 |
| `build(:mission_draft)` | factory | `apps/axon/test/support/factory.ex:203` | 2026-08-08 |
```

This is the one thing a later session cannot reconstruct. `/todd:plan-check` traces every concrete
noun in the plan back to this file; without it, it can only check that a noun *looks* plausible,
which is precisely the failure grounding exists to prevent. It costs you three lines and it is the
difference between a check and a vibe. Write it even under `--dry-run` — especially under
`--dry-run`, since that's when the plan is most likely to be revised before posting.

### Blockers have a budget: three

An ungrounded anchor becomes a blocker. Ungrounded anchors are cheap to produce and a plan that
lists nine of them has stopped being a plan — Todd reads it as "you didn't do the work", and an
unattended `impl` run reads nine reasons to halt. **Cap `Questions / Blockers` at three.** Rank by
what actually changes the plan and keep the top three:

1. **Scope** — does this include or exclude a case? Wrong answer means rebuilding.
2. **Data and correctness** — which record is authoritative, what happens on conflict.
3. **User-visible behavior** — what the caller sees on the unhappy path.
4. **Technical detail** — last. Usually has a defensible default.

Everything below the cut gets a **grounded default instead of a question**: pick the answer the
codebase already implies, write it into `Decisions` as `(assumed, YYYY-MM-DD)` with the precedent
you're following, and move on. An assumption Todd can veto in one line beats a question that stops
the run.

**Don't ask about these at all** — take the local convention, cite it in `Decisions` if it's
load-bearing, and keep going: error-message wording, log level, naming that follows an existing
module, test file location when a sibling test exists, timeout and retry values that match the
neighbouring call, migration naming, changeset validation style.

**More than three blockers survive the ranking → the ticket is under-specified.** That's the
existing "can't ground half the anchors" branch in the failure table. Post the brief and the detail
block, say the Behavior Spec needs answers first, and stop. Don't ship a twelve-question plan.

---

## Phase 3 — Write the architect's brief

Section 1. This is what gets read to decide whether the approach is right, so it carries the
*judgement* and nothing else — phase 4 carries the detail, the Behavior Spec carries the
expectations. Six headings, **~200 words all in**. Same in both modes; `--no-gherkin` changes
nothing here.

````markdown
## 📋 Implementation Plan

### Summary
[≤3 sentences. What the ticket asks for in your own words, and the shape of your answer. If your
reading differs from the ticket's wording, say so — that's the disagreement worth catching before
code. A correction to the ticket's proposed fix goes here too, in bold, above the approach that
supersedes it.]

### Changed since the last plan
<!-- Only when phase 0 replaced an existing plan. Omit the whole section otherwise. -->
- **[What changed]** — [what the old plan claimed, what's actually true]

### Decisions
<!-- Settled calls that shape the design. One line each, with who made them and when. Omit if none. -->
- **[The call]** — [why, and what it rules out]. (Todd, YYYY-MM-DD)
- **[The call]** — [the default you took, and the precedent in the code you took it from]. (assumed, YYYY-MM-DD)

### Approach
1. [Slice 1 — one line. Name the outcome, not the steps. A vertical path that leaves the tree working.]
2. [Slice 2]

### Risks
<!-- ≤3, one line each. Omit the section if there genuinely are none. -->
- [Risk, and what makes it one]

### Questions / Blockers
<!-- Max 3, ranked per phase 2. Anything below the cut became an (assumed) Decision. Omit if none. -->
- ❓ [One line, phrased as the question it actually is, and naming what changes depending on the
  answer. Settled calls and taken defaults go in Decisions, not here.]

### Scope
[Small / Medium / Large] · [N] slices · [N] files ([apps touched]) · [N] deferred
````

**Slices are the spine.** Number them in `Approach`, because the Behavior Spec tags every Scenario
with the slice it belongs to and the implementer walks them in order. A slice that no Scenario tags
is a slice with no acceptance criteria — either it needs one or it isn't really a slice. (Under
`--no-gherkin` there are no Scenarios to tag, so number the slices anyway and let the prose carry
the ordering.) One line each: if a slice needs a paragraph to describe, it's two slices.

**`Scope` is one line and it's the blast radius.** The size word alone tells a reviewer nothing.
The file count and the apps are what makes them look twice — "Small · 2 slices · 14 files (axon,
dendra, astro)" is a plan worth a second read, and the old `### Estimated Scope` would have said
"Small" and moved on. Count the files from phase 4's `Files to Modify`. `[N] deferred` is the count
of ticket requirements marked `⏸️ deferred` in the coverage table; drop that clause at zero, and
drop it entirely under `--no-gherkin`.

**`Risks` means risk to the approach, not to the implementation.** "This prop rename breaks three
external Strata consumers" changes whether the approach is right — it belongs here. "Remember the
factory is called `build(:mission_draft)`" doesn't — that's a note for whoever writes the test, and
it goes next to the thing it's about in phase 4. Three risks is the cap. A list of five means you
haven't decided which ones matter.

**Decisions are settled; Questions are open.** Don't leave a resolved call sitting in
`Questions / Blockers` — an implementer who reads a question stops and asks it. Move it to
`Decisions` with the reason and the date. A decision that reverses something in the ticket
description belongs there too, and the `Summary` correction should point at it.

**`(assumed, …)` is a first-class decision, not a weaker question.** It says: I picked this, here's
the precedent, override me if I'm wrong. It lets `impl` proceed. A question does not. The failure
this prevents is the plan that hedges on nine small calls and blocks on all of them — three real
questions and six cited assumptions is a plan; nine questions is a request for a meeting.

### What does not go in section 1

Every one of these was in the brief before and is now in phase 4. Putting one back is the failure
mode this split exists to prevent.

| Not here | Where | Why |
|---|---|---|
| `### Files to Modify` | phase 4 | An architect judges the approach, not the file list. The count in `Scope` is the part that changes their mind. |
| `### Existing Code to Reuse` | phase 4 | Reuse is *how* you build it, not *whether* to. |
| `### Verification` and its `⚠️` line | phase 4 | Commands are for whoever runs them. |
| A Scenario restated in prose | phase 4 | The Gherkin says it better, and two copies drift. |
| A gotcha the implementer needs | phase 4, next to the thing it's about | It's a note on the work, not a risk to the approach. |
| Background on how the code works today | nowhere | It was phase 1 input. It's how you *arrived* at the approach, not part of it. |

---

## Phase 4 — Write the implementation section

Section 2 of the same comment: everything the implementer needs and the architect doesn't. **No
budget here.** This is where the detail belongs, so let it run as long as the work warrants — the
brief stayed short precisely so this one can be complete.

The heading, and it matters — see "The contract you must not break":

| Mode | Heading |
|---|---|
| default | `## 🥒 Behavior Spec & Implementation Detail` |
| `--no-gherkin` | `## 🔧 Implementation Detail` |

The first starts with the literal `## 🥒 Behavior Spec`, which is what impl and loop look for. The
second deliberately doesn't — that absence is how they know this plan's acceptance criteria are
prose rather than Scenarios. Don't "fix" the inconsistency by giving them the same heading.

**No budget is not the same as no order.** The implementing agent reads this section into a context
window it also has to hold the codebase in, and recall degrades as that window fills — the middle of
a long block is where a constraint goes unread. So: **the things that stop the agent doing the wrong
work go first.** `Files to Modify` and `Invariants` before `Existing Code to Reuse`; the Gherkin,
which is worked through scenario by scenario rather than scanned, goes last. And if section 2 is
running past roughly 400 lines, the question to ask is not how to trim it — it's whether this is one
ticket. Three slices that each need a page of setup are three tickets.

### The detail block — both modes, always

````markdown
### Files to Modify
- `path/to/file.ex` — [reason]

### Invariants
<!-- EARS form. The requirements that are not behavior. See "Invariants" below. Omit if none. -->
- **INV-1** — THE SYSTEM SHALL [property that must hold]. *Check:* `[command or grep that fails if it doesn't]`

### Unchanged behavior
<!-- Required when the ticket is a bug fix. Omit for pure feature work. -->
- [What works today and must still work after the fix] — covered by `[existing test file]`

### Existing Code to Reuse
- `path/to/util.ex:function_name` — [what it does, why it fits]

### Verification
```bash
[the exact commands that prove this work, for every surface it touches]
```
⚠️ [what a green run does NOT prove. Omit the line only if there is genuinely nothing.]
````

### Invariants — the requirements that aren't behavior

A Scenario needs a `When`. Plenty of real requirements don't have one: a contract that must not
change, a budget that must not be exceeded, a property that must hold across every path. Written as
Gherkin they come out as `When the refactor is done / Then the API is the same`, which is the
unfalsifiable anti-pattern this command already bans. Written as nothing, they get violated.

Write them in **EARS** form — the same Easy Approach to Requirements Syntax that Kiro's
`requirements.md` uses. One statement, one of these shapes, and a `Check:` that a machine can run:

| Shape | Use for |
|---|---|
| `THE SYSTEM SHALL <property>` | An always-true invariant. The public shape of a module, an index that must exist. |
| `WHEN <trigger> THE SYSTEM SHALL <response>` | An event-driven constraint that isn't worth a full Scenario. |
| `IF <condition> THEN THE SYSTEM SHALL <response>` | An unwanted condition — the error path, the conflict. |
| `WHILE <state> THE SYSTEM SHALL <property>` | A constraint that holds only in a state (during migration, while a flag is on). |
| `WHERE <feature is present> THE SYSTEM SHALL <property>` | Behavior conditional on a flag or a deployment. |

```markdown
### Invariants
- **INV-1** — THE SYSTEM SHALL keep `Axon.Rooms.join/2`'s arity and return shape.
  *Check:* `grep -rn "Rooms.join(" apps/ --include=*.ex | wc -l` unchanged, and `mix test test/axon/rooms_test.exs`
- **INV-2** — WHILE the `duplicate_tab_guard` flag is off THE SYSTEM SHALL behave exactly as today.
  *Check:* `mix test test/axon_web/channels/ai_mod_channel_test.exs --only legacy_path`
```

**The `Check:` is not optional and it is not prose.** "Verify the API is unchanged" is a wish.
A command, a grep with an expected result, or a named existing test is a check. An invariant you
can't write a `Check:` for is the same failure as a Scenario you can't write a `# falsifies:` for —
sharpen it or move it to `Questions / Blockers`.

**Invariants are numbered `INV-N` and they appear in the coverage table** alongside Scenarios. They
are not a dumping ground: if the thing has a trigger and an observable outcome, it's a Scenario.
Invariants are for what must stay true, not for what should happen.

### Unchanged behavior — required on bug tickets

A bug fix has a third requirement class the ticket almost never writes down: *what must keep
working*. The ticket says what's broken and what it should do instead; nobody writes "and don't
break the other four callers", so nobody plans for it and the regression ships.

When the ticket is a bug, name the behavior adjacent to the fix that must survive it, with the
existing test that proves it. If no such test exists, that's a Scenario tagged `@regression` —
write it, and say in `Not covered` that it didn't exist before this ticket.

This is not the same as `Not covered`. `Not covered` is scope: what you're deliberately not
building. `Unchanged behavior` is risk: what you could break by accident.

This is also where the implementer's gotchas live — the ones phase 3 kept out of `Risks`. Put each
one next to the thing it's about: a factory's real name under the file that needs it, a fixture's
quirk under the module it belongs to. A gotcha in a list at the bottom gets read after the mistake.

**Verification is required, and it is not the pre-push checklist.** `/todd:coder impl` knows exactly
three verify commands — `mix test` for axon, `yarn lint && yarn test` for dendra,
`uv run ruff check . && uv run pytest` for astro. For anything outside those three apps it has
nothing: a tool under `.claude/`, a script in `bin/`, a terraform composition, a shared Python
package, the e2e suite. If you don't name the commands, the implementer either guesses or skips
verification entirely. Name them, for every surface in `Files to Modify`.

**Then say what a green run does not prove.** This is the half that gets left out, and these are
real from this repo:

- **Nothing under `.claude/` runs in CI.** Check it — `grep -rn '<tool>' .rwx/` coming back empty
  means the suite only ever runs when a human types it, so "tests pass" says nothing about the
  merge.
- **A self-skipping harness exits 0 with the assertions unrun.** `skip() { echo "SKIP: …"; exit 0; }`
  is the pattern; the signal is the `PASS:` line, not the exit code.
- **A pytest node id that matches nothing passes silently.** So does a `-k` filter with a typo.

Find one of these and it belongs in the `⚠️` line, because the implementer will otherwise trust a
green terminal.

**Under `--no-gherkin`, phase 4 ends here.** Continue to phase 5 — the plan still gets
self-checked, written to disk, and posted. The hard rules and the failure table below apply in
every mode.

### The Behavior Spec — skipped under `--no-gherkin`

Below the detail block, in the same section:

```markdown
Each Scenario is one required failing test. A slice is not done until every Scenario tagged with it
is green **and every Invariant's `Check:` still passes**. `# falsifies:` is the mutation check — if
reverting the change doesn't turn that scenario red, the test isn't testing the change.
```

Then the coverage table, then one fenced ` ```gherkin ` block, then `Not covered`.

### Anatomy

```gherkin
Feature: Reject duplicate participant tabs [AIM-1066]
  A participant who opens a second tab must not join the room twice — the existing
  tab keeps the session and the new tab is refused.

  Background:
    Given an AI Mod room in state "live"
    And participant P joined from tab A

  @slice-1 @axon
  Scenario: A second tab from the same participant is refused
     When P joins the same room from tab B
     Then the join is rejected with reason "already_joined"
      And tab A's socket stays connected
    # target: test/axon_web/channels/ai_mod_channel_test.exs
    # falsifies: revert the guard -> tab B joins and tab A is dropped

  @slice-1 @axon @boundary
  Scenario: A rejoin after a clean disconnect is allowed
    Given tab A has disconnected and the presence entry has expired
     When P joins from tab B
     Then the join succeeds
    # target: test/axon_web/channels/ai_mod_channel_test.exs
    # falsifies: guard keyed on participant id alone -> legitimate rejoin is refused

  @slice-2 @dendra @negative
  Scenario Outline: The refused tab explains itself instead of hanging
     When a join is refused with reason "<reason>"
     Then the tab shows "<message>"
      And no reconnect is attempted
    # target: src/apps/ai_mod/__tests__/JoinGuard.test.tsx
    # falsifies: reason ignored -> every refusal shows the generic error

    Examples:
      | reason         | message                        |
      | already_joined | You're already in this session |
      | room_closed    | This session has ended         |
```

### Rules

**Feature** — one per ticket. Title is the outcome, not the task, and ends with the ticket id in
brackets. Two or three lines underneath saying what "done" means in plain language.

**Background** — only steps true for *every* Scenario. If it's true for most, it belongs in the
Scenarios that need it. A Background that has to be mentally subtracted for half the file is worse
than no Background.

**Scenario** — one observable behavior. Named as a statement of what happens, not a label
("A second tab from the same participant is refused", not "Duplicate tab handling").

**One `When` per Scenario.** Two actions means two Scenarios, or a `Given` doing the setup. This is
the single most reliable way to keep scenarios testable.

**Tags, in this order:**

| Tag | Meaning |
|---|---|
| `@slice-N` | Which numbered step in `Approach` this belongs to. Required. |
| `@axon` `@dendra` `@astro` `@ai_mod` `@e2e` | Which app's suite it lands in. |
| `@<area>` | For work outside those apps — a tool under `.claude/`, a script in `bin/`, a terraform composition, a shared package. Name it after the directory: `@copy-data`, `@stroma`, `@dscout_core_py`. An app tag **or** an area tag is required; `# target:` disambiguates the suite. Just use it — no prose note explaining why the app tags didn't fit. |
| `@negative` | Asserts a refusal, an error, or that something does *not* happen. |
| `@boundary` | Zero, empty, null, max, off-by-one, the edge of a range. |
| `@regression` | Protects behavior that already works and must keep working. |

**Two trailing comments per Scenario, both required:**

- `# target:` — the test file this becomes. Real path, from the test structure you found in phase 1.
  If you don't know where it goes, you don't understand the change well enough to plan it.
- `# falsifies:` — what would make this scenario red. State the broken implementation, not the
  feeling: "guard keyed on participant id alone -> legitimate rejoin is refused" tells the
  implementer what to avoid; "fails if the guard is wrong" tells them nothing.

**At least one `@negative` or `@boundary` Scenario per slice.** Not a suggestion. Happy paths are
the ones that get implemented correctly by accident; the refusals, the zero, and the empty list are
where the real bugs live. A slice with only happy-path scenarios is an unfinished spec.

**`Scenario Outline` + `Examples`** for genuinely table-driven behavior. The Examples rows must
differ in *kind*, not just in value — include the empty one, the zero, the maximum. Four rows that
are all the same shape are one scenario wearing a costume.

**A measured constant in a `Then` names its source and its shelf life.** `Then submissions holds
364 rows` is admirably precise and it will rot. That 364 came from somewhere, and if that somewhere
is the shared dev database, it isn't pinned in the repo — `bin/dscout_db restore` pulls
`dscout_development.dump` from S3, so the next refresh turns the test red for reasons that have
nothing to do with the code. Two acceptable forms:

- **Derive it.** `Then the target row count equals the source row count` — no constant, no rot.
- **Pin it and label it.** Keep the literal and add a third trailing comment:
  `# pinned: 364 = project 12255 submissions on local dscout_development, measured 2026-08-05 — re-measure after a dump restore`

Applies to any number you *measured* rather than *chose*: counts, ids, sizes, durations. A number
you chose (a limit of 50, a timeout of 30s) is part of the spec and needs no pin.

### Anti-patterns — check every scenario against these

| Don't | Why | Instead |
|---|---|---|
| `When I click Save` | Ties the spec to a UI that will change, and unit tests can't run it | Describe the behavior: `When the draft is submitted`. Clicks are fine only under `@e2e`. |
| `When the guard ships` / `When the fix is applied` | Describes the change, not the behavior. Unfalsifiable and meaningless after merge. | Describe what a user or caller does. The scenario should read true after the work and false before it. |
| `Given a valid study` | "Valid" hides the setup that matters, and "study" may not be what the factory is called | Name the grounded fixture and the property under test: `Given a mission with no screener questions`. |
| `Then the record is saved` | Not observable — you're asserting an internal | Assert what a caller can see: a return value, a response field, a persisted field you then read back. |
| `Then A And B And C` where only A is real | A conjunction where the later clauses are always-true padding makes the assertion unfailable | Every `And` must be able to fail on its own. If it can't, cut it. |
| A scenario with no `# falsifies:` | It isn't testing anything | Sharpen it until you can write the line, or delete it. |
| Two scenarios asserting the same thing in different words | Inflates the count, adds no coverage | Merge them. |
| Only happy paths | See above | Add the `@negative`/`@boundary` one. |
| `Then it holds 364 rows` with no provenance | A number measured from a refreshable source rots, and goes red for reasons unrelated to the change | Derive it from the source, or add `# pinned:` naming where and when you measured it. |
| A Scenario whose `When` is "the refactor is complete" | It's an invariant wearing a Scenario costume — unfalsifiable, and it inflates the scenario count with something no test will assert | Move it to `### Invariants` in EARS form with a runnable `Check:`. |

### Coverage table

Sits between the detail block and the Gherkin so a reader can check the mapping without reading
Gherkin. One row per requirement from the ticket:

```markdown
| Requirement (from the ticket) | Kind | Covered by | Slice | Target test / check |
|---|---|---|---|---|
| Duplicate tab must not join twice | Scenario | A second tab from the same participant is refused | 1 | `ai_mod_channel_test.exs` |
| Existing tab must survive | Scenario | (same) | 1 | `ai_mod_channel_test.exs` |
| Join API must not change shape | Invariant | INV-1 | 1 | `mix test test/axon/rooms_test.exs` |
| Survives 500 concurrent joins | — | ⏸️ deferred → Not covered | — | — |
```

`Kind` is `Scenario`, `Invariant`, or `—`. It exists so a reviewer can see at a glance that a
requirement was *classified*, not just mentioned — an invariant sitting in the Scenario column with
no `When` is the misfiling this column catches.

A requirement with nothing covering it is a gap, and there are exactly four ways to close it:

1. **Write the Scenario** — it has a trigger and an observable outcome.
2. **Write the Invariant** — it's a property that must hold, with a runnable `Check:`.
3. **`⏸️ deferred → Not covered`** — a real requirement you're consciously not doing now. Give the
   reason in `Not covered`, and if it deserves its own ticket, say that too.
4. **Move it to `Questions / Blockers`** — it can't be specified until someone answers something.
   Subject to the cap of three; below the cut it becomes an `(assumed)` Decision instead.

**Never leave a cell empty, and never drop the row.** A requirement that quietly disappears from the
table reads as covered, which is the one failure this table exists to prevent.

### Not covered

A short list, after the Gherkin, of behavior deliberately left alone:

```markdown
### Not covered
- Reconnect-after-network-drop — existing behavior, unchanged by this ticket.
- Staff-user joins — out of scope, tracked separately.
```

This is scope control. It tells the implementer what *not* to build, which is the instruction most
often missing from a plan and the reason unattended runs wander.

---

## Phase 5 — The pre-post gate

**This is not the plan review.** The full review — 23 checks across contract, brief, detail,
invariants, and Gherkin — moved to `/todd:plan-check`, which reads the posted plan cold, the way
the implementing agent will. Two reasons it belongs there and not here:

- **It was a second copy of the rules.** Nearly every item in the old phase 5 restated something
  phases 3 and 4 already say at the point where you're writing it — one `When` per Scenario, a
  `# falsifies:` on every Scenario, `Verification` required, the ~200-word brief. The guidance
  stays where it's actionable. The duplicate checklist is what made this command a laundry list,
  and a laundry list is the shape that degrades the reasoning of the session carrying it.
- **You are the worst reader of your own plan.** You know what you meant by "the guard", so you
  can't tell that the plan never says which guard. A session that has never seen your reasoning
  can. That's the check that actually catches things, and it's structurally impossible from here.

What stays here is a **contract gate**: five things that make the artifact unusable if they're
wrong, so there's no point posting it. Fix inline; don't report them, just fix them.

1. The comment's first line is exactly `## 📋 Implementation Plan`. Four call sites find the plan
   by that string. Break it and the plan is invisible to the whole chain.
2. Section 2's heading is `## 🥒 Behavior Spec & Implementation Detail`, or
   `## 🔧 Implementation Detail` under `--no-gherkin`. Not one of them under both, and never a
   third wording — impl and loop branch on that literal to decide whether Scenarios or prose are
   the acceptance criteria.
3. `### Verification` exists under that exact heading. Non-app work loses its verify path entirely
   without it.
4. One comment, and it's the one phase 0 resolved. Never a second `## 📋 Implementation Plan`.
5. `Questions / Blockers` has at most three entries. Four means you should have stopped in phase 2
   rather than posted — go back, don't paper over it here. (Coming from phase 0B there is no phase 2
   to go back to; that's step 6's stop, and the answer is the same — say the ticket is
   under-specified rather than trimming the list to fit.)

Everything else — word counts, heading order, count reconciliation, anchor tracing, coverage-table
completeness, tag and comment presence, EARS form, scenario anti-patterns — is `/todd:plan-check`'s
job. Don't do it twice.

---

## Phase 6 — Post and report

**Write the local copies first**, always, including under `--dry-run`:

- `.claude/tmp/<branch-or-ticket>/plan-<TICKET>.md` — the plan body exactly as posted. Cheap
  insurance against a failed Linear write, and what `/todd:plan-check --local` reads.
- `.claude/tmp/<branch-or-ticket>/anchors-<TICKET>.md` — the phase-2 anchor list. Not optional;
  `/todd:plan-check` can't trace nouns without it.

**Post** with `mcp__claude_ai_Linear__save_comment` — new comment, or the existing comment id if
phase 0 found one. Under `--dry-run`, post nothing and say so plainly.

**Report to Todd, blockers first.** He reads the top three lines:

```
FRG-1234 — <ticket title>
Scope: Medium · 3 slices · 7 files (axon, dendra) · 11 scenarios (4 negative/boundary) · 3 invariants · 2 blockers
Plan: <linear comment url>

❓ Blockers
- <the ungrounded thing, phrased as the question it is>

Slices
1. <name> — 4 scenarios, tests in <file>
2. ...
```

The `Scope:` line is section 1's `### Scope` plus the counts only this report carries — scenarios
and blockers. Keep the two consistent; a report claiming 7 files over a brief claiming 5 means one
of them was written from memory.

Under `--no-gherkin` there are no scenario counts to report. Drop them rather than printing zeros —
the `Scope:` line becomes `Scope: Small · 2 slices · 3 files (astro) · 2 invariants · 1 blocker`,
the per-slice lines lose their scenario counts, and say plainly that this plan has no Behavior Spec
so Todd knows which kind of run `impl` is about to get. Invariants survive the flag, so their count
stays; drop the clause only at zero.

Then the plan itself. If phase 2 corrected the ticket's premise, **lead with the correction** — it's
the finding, and a reader who skims past it implements the wrong thing. If the correction was big
enough that you stopped, that's the whole report.

### After a phase-0B run, three things differ

**1. Replace the stamp.** The plan comment still carries `*Plan check: ❌ N blockers*` with the
blocker list under it. Leave it and every reader — Todd, `impl`, the next checker — sees a plan
still failing on findings you just closed. Replace the whole stamp, blocker block included, with:

```markdown
---
*Plan revised 2026-08-11 to resolve 3 blockers (C1, E11, B5) — re-check required.*
```

🛑 **Never write a `✅ passed` stamp.** That stamp is `/todd:plan-check`'s to write and only after it
has actually run the checks. Stamping your own revision as passed is precisely the laundering the
checker refuses to do in the other direction, and it would walk an unchecked plan straight past
every gate that reads the stamp. If a blocker is still open, say that in the revision line too:
`— 2 of 3 resolved, B5 still open, re-check required`.

**2. The report is a diff, not a plan.** Todd already read the plan; what he needs is what moved:

```
FRG-1234 — <ticket title>
Revised: 3 blockers resolved · 0 still open · 2 anchors added · 1 scenario added
Plan: <linear comment url>

Resolved
- [C1] `Axon.Rooms.reject_join/2` — exists at rooms.ex:181. Grounded and added to anchors.
- [E11] Slice 2 — added @boundary scenario "a rejoin after presence expiry is allowed".
- [B5] 4 questions → 3 answered by you and moved to Decisions.

Still open
- ❓ [B5] Whether staff-user joins are in scope — you deferred to product.
```

**3. The revision is unchecked, and the stamp you just wrote says so.** Don't close the report here —
phase 7 dispatches the check and its verdict is the last thing Todd reads. A revision is *more* in
need of a cold read than a fresh plan, not less: every line you touched, you touched because a
checker told you it was wrong, and you are now the person most convinced those lines are fixed.

**Why the check cannot run in this session.** `/todd:plan-check` works because it has never seen the
reasoning that produced the plan — that's the entire argument at the top of that file. You have now
spent a session deciding that `rooms.ex:181` is the right anchor and that the new `@boundary`
Scenario says what it needs to. You are, at this moment, the worst available reader of exactly the
lines you just wrote. A check run from here would produce a pass that means nothing.

That's an argument against *this context*, not against automation — which is what phase 7 is for. A
dispatched subagent starts with no transcript: it gets the prompt you write and nothing else. Give it
a bare invocation and it is a genuinely cold reader. Paste your reasoning in and you have rebuilt this
session inside it and thrown the check away.

### Both modes

**Don't close the report yet.** The plan is posted and unchecked. Go to phase 7, which dispatches the
check and writes the closing line from its verdict. Under `--no-check` — and only then — close it
here, in one line, as the last thing Todd reads:

```
Unchecked (--no-check). Run `/todd:plan-check FRG-1234` before impl.
```

Under `--dry-run` that's `/todd:plan-check FRG-1234 --local`. Don't soften it into "you may want
to" — an unchecked plan that reads well is exactly the artifact this whole command exists to stop
shipping.

---

## Phase 7 — Dispatch the cold check

Runs in both modes and on both paths — a fresh plan and a phase-0B revision. Skipped only under
`--no-check`.

A plan nobody checked is the artifact this command exists to stop shipping, and the old ending — a
line telling Todd to go run the check himself — put the one step that catches things behind a manual
action, in a flow whose whole point is unattended `impl`. So run it. Just not from here.

**A subagent is the cold session.** It starts with no transcript: it gets the prompt you write and
nothing else. That's the same qualification the check has always needed and the reason it can now be
automatic — the objection in phase 6 was to *this context*, never to automation. A second benefit
falls out: the check is 47 checks over a ticket, a plan, an anchor file and a handful of greps, and
none of it lands in your window.

### The dispatch

Foreground, and wait for it. There is nothing useful to do until the verdict arrives, and the closing
line is written from it.

```
Agent(
  subagent_type="general-purpose",
  description="Cold plan check <TICKET>",
  prompt=<the four blocks below, verbatim>
)
```

`general-purpose` because the check **writes**: it fixes 🟡 findings in place, writes
`plan-check-<TICKET>-findings.md`, and stamps the Linear comment. The read-only agents (`Explore`,
`Plan`) can't do any of that and would come back with a report and no stamp — which reads as a check
that ran.

**The prompt is exactly these four blocks.** Fill in the ticket id, the flags, and the absolute path.
Change nothing else, and add nothing else:

````
Read ~/.claude/commands/todd/plan-check.md and follow it exactly.

Its $ARGUMENTS: <TICKET>

Resolve every `.claude/tmp/<branch-or-ticket>/…` path in that file against this absolute directory:
<ABSOLUTE TMP DIR>

The Linear MCP tools may be deferred in your session — load them with ToolSearch before its phase 0.
`save_comment` is how the stamp gets written and it has no fallback.

Return its phase-6 report verbatim, plus the stamp text you wrote.
````

Read-the-file rather than `Skill(skill="todd:plan-check")` for one reason: `Read` is available to
every agent and the `Skill` tool may not be. Following the file is what invoking it does anyway.

### Why the prompt has no fifth block

Everything the checker needs about this plan is in the plan. It fetches the comment itself (its phase
0), reads the ticket itself (coverage can only be checked against the original requirements), and
traces every noun to the anchor file you wrote (its phase 3). It needs no help from you, and the help
is the damage: which anchors you felt sure of, which Scenario you rewrote after the last check, why
the brief is the length it is — that is precisely the reasoning that makes the author blind, and
handing it over reconstructs this session inside the one place that was supposed to be free of it.
A prompt that carries the invocation and the paths is a cold read. A prompt that carries context is
this session wearing a subagent costume, and it will agree with you.

Don't paste the plan body either. The comment is the artifact every downstream reader gets; a pasted
copy can differ from it, and then the check passed something nobody will read.

### The paths, and the silent failure they cause

`/todd:plan-check` reads `.claude/tmp/<branch-or-ticket>/anchors-<TICKET>.md` — **a relative path**,
resolved against the subagent's cwd. Phase 0 may well have sent you to read code from the ticket's
worktree while the session cwd stayed `main`, so the anchor file you wrote in phase 2 and the path a
subagent resolves are routinely two different places.

Get this wrong and nothing errors. The checker finds no anchor file, enters **degraded mode**, and
comes back `⚠️ passed (ungrounded)` — a pass with grounding unchecked, which is the one check that
matters most and the reason phase 2 exists. So pass the absolute directory, and read the verdict with
this in mind: **a degraded verdict on a plan whose phase 2 ran means you passed the wrong path, not
that the anchors are missing.** Fix the path and re-dispatch once before reporting it as degraded.

Under `--dry-run` the plan isn't on Linear, so `$ARGUMENTS` is `<TICKET> --local` and the check reads
the local copy phase 6 wrote. Nothing is written to Linear on either side of the dispatch, which is
what `--dry-run` promised.

### Reading the verdict

Relay it. You don't get a vote — you are the author, the finding is about your lines, and "actually
that noun is fine" from you is the exact move the separation exists to prevent. Report its blockers,
fixes and flags in its words, then close with the line its verdict dictates:

| Verdict returned | Closing line |
|---|---|
| `✅ passed` | ``Plan checked. Next: `/clear`, then `/todd:loop <TICKET>`.`` |
| `⚠️ passed (ungrounded)` | Re-dispatch once with the path corrected. Still degraded → ``Plan checked, grounding unchecked — no anchor file found at <path>. Next: `/clear`, then `/todd:loop <TICKET>`.`` |
| `❌ N blockers` | ``Blocked. Run `/todd:plan <TICKET>` to resolve the N blockers.`` |
| nothing usable — the dispatch failed | ``Posted and unchecked — the check didn't run. Run `/todd:plan-check <TICKET>`.`` |

**On a pass, the next step is `/clear` and `/todd:loop <TICKET>` — and the `/clear` is half the
instruction, not politeness.** `/todd:loop` runs a ticket to a reviewed PR across eight phases, and
its own architecture note says why it can't do this for itself: a command cannot call `/clear`, so
every phase runs in a dispatched subagent and the orchestrator deliberately holds almost nothing but
the ticket id, the worktree path and each phase's one-line return. Start that orchestrator in the tail
of this session and it inherits a window already full of anchors, Scenario drafts and search-agent
findings — the one command most likely to compact mid-flow, handed the fullest possible starting
context. A loop that compacts during its baz round has lost the thread. Todd pressing `/clear` is the
only thing that actually empties the window, which is why the closing line asks for it by name rather
than just naming the command.

`/todd:loop` is the destination rather than `/todd:coder impl` because its phase 0 gates on the stamp
you just earned: `✅` and `⚠️` proceed, `❌` stops, and an unstamped plan makes it run the check
itself. Sending Todd to `impl` skips the PR, the self-review, the manual test plan and the baz round —
all work he'd then do by hand. `impl` stays the right call when he wants to drive it himself; it just
isn't the default worth printing.

A degraded pass goes to the same place. `⚠️` means grounding went unchecked, not that a check failed,
and `/todd:loop` accepts it explicitly — so the handoff names the loop and the missing anchor file in
the same breath, and Todd decides whether unchecked grounding is worth a re-plan before an unattended
run.

**On `❌`, stop.** Don't resolve the blockers in this session even though you could — phase 0B is
right there and you have the anchors loaded. Three reasons: the checker's own handoff sends them to
`/todd:plan`, which reaches phase 0B through the `❌` stamp on the next run, so a fresh session does
this properly; a good share of blockers (B5, a scope question, an ungrounded noun that turns out not
to exist) need Todd's answer and not yours; and closing a finding about lines you wrote, in the
session that wrote them, is the same blindness one layer down. Report the blockers and let him re-run.

**The loop terminates on a clean check, not on a tidy-looking plan.** plan → check → blockers → plan
→ check, one dispatch per lap. Each pass should close findings and open none; if the same blocker
survives two passes, stop looping and say what's actually stuck. A third round on the same finding
means it needs a decision nobody in the loop can make.

### Callers that pass `--no-check`

Two commands invoke this one through `Skill(skill="todd:plan")` and then say, in their own text, not
to run the check — so they pass `--no-check` and phase 7 doesn't fire:

| Caller | Why |
|---|---|
| `/todd:bug-next` step 9 | Plans the bug **before** the root cause is known, so ungrounded anchors are the expected output, not a defect. Its debugging step tests every claim the plan makes. A `❌` here would be noise, and it would sit on the ticket blocking `/todd:loop` and `/todd:phase` later. |
| `/todd:devops-next` step 11 | Same shape, same reason. |

That's the flag's whole job: a caller whose next step *is* the check. It is not a way to skip the
check because the plan looks fine — that judgement is the thing you are worst at making.

---

## Hard rules

- Never invent an anchor. An ungrounded noun is a blocker, not a Given.
- Never leave more than one `## 📋 Implementation Plan` comment on a ticket.
- Never change the first line of that comment.
- Never put implementation detail in section 1. If it names a file path, a command, or a Scenario,
  it belongs in section 2.
- Never hit the section-1 budget by deleting. Move it down, every time. The brief is short so the
  detail can be complete, not instead of it.
- Never create a worktree or move the ticket's Linear state. Planning is read-mostly; the one write
  is the comment.
- Never write a Scenario you can't finish the `# falsifies:` line for, or an Invariant you can't
  finish the `Check:` line for.
- Never post more than three `Questions / Blockers`. Four means the ticket isn't ready — say that
  instead.
- Never write an invariant as a Scenario to make the scenario count look better.
- Never leave phase 2 without writing `anchors-<TICKET>.md`. A plan whose anchors weren't persisted
  cannot be checked, only admired.
- Never report a plan as done on your own authority. It's posted and unchecked until phase 7's
  dispatch comes back with a verdict, and the verdict is the checker's to give.
- Never re-plan a ticket whose plan carries a `❌` stamp. That's phase 0B — surgery on the named
  blockers, with everything the check passed left alone.
- Never write a `✅ passed` stamp. `/todd:plan-check` writes that, after running the checks. A
  revision stamps itself as revised and unchecked.
- Never leave a `❌` stamp on a plan you revised, and never close a blocker you had to guess the
  meaning of. A resolved-looking blocker that was never understood is worse than an open one.
- Never run the check inside this session — not after a fresh plan, not after a phase-0B revision.
  You can't cold-read lines you just wrote. Phase 7 dispatches it to a subagent, which is a session
  that wasn't in this one.
- Never add context to the dispatch prompt. Four blocks, the ticket id, the flags, the absolute path.
  Every sentence of yours that reaches the checker is a sentence it was supposed not to have.
- Never write, replace, or summarize the checker's stamp. It writes its own, and a stamp you wrote
  from a report is a claim about checks you didn't run.
- Never report a pass the dispatch didn't return. A subagent that errored, returned nothing, or came
  back without a stamp is an unchecked plan — say that, and give Todd the command.
- Never argue with a finding, and never resolve one in this session. Relay it. A `❌` goes back to a
  fresh `/todd:plan` run, which reaches phase 0B through the stamp.
- One ticket per invocation. A whole project with milestones is `/todd:linear-project-setup`.

## Failure handling

| Failure | Do |
|---|---|
| Ticket not found | Report the id attempted. Stop. |
| Linear MCP blocked or truncating | Fall back to `linctl issue get $TICKET --json`. |
| Multiple existing plan comments | Stop and report. Todd picks. |
| Plan carries a `❌` stamp | Phase 0B. Resolve the named blockers; don't re-plan. |
| `❌` stamp names only check ids, no blocker text and no findings file | Stop. Offer to re-run `/todd:plan-check <TICKET>` for the findings, or to re-plan from scratch. Never infer what a bare `C1` meant. |
| A blocker Todd can't answer | It stays in `Questions / Blockers`, the revision stamp says it's still open, and the report says the plan is still blocked. Never convert it to an `(assumed)` Decision to make the count work. |
| The same blocker survives two phase-0B passes | Stop looping. Say what's stuck and why the loop can't settle it. |
| Ticket premise contradicted by the code | Correct it in bold in `Summary` and keep planning if the plan survives the correction; stop and report only if it doesn't. Never quietly plan around it. |
| Can't ground more than about half the anchors | The ticket is under-specified. Post the brief and the detail block with the blockers, and say the Behavior Spec needs answers first. Don't ship a spec built on guesses. |
| More than 3 blockers survive the phase-2 ranking | The ticket is under-specified. Post the brief and the detail block, name the three that matter most, and stop. Don't ship a twelve-question plan. |
| Section 2 runs past ~400 lines | Post it, and say in the report that the ticket looks like two or three. Never trim the detail to hit a number. |
| `save_comment` fails | The local copy is already on disk — report its path so nothing is retyped. |
| Phase 7's subagent errors, times out, or returns no verdict | The plan is posted and unchecked. Say exactly that and give Todd `/todd:plan-check <TICKET>`. Never infer the verdict from your own read of the plan. |
| The check comes back `⚠️ passed (ungrounded)` | You probably passed the wrong tmp directory — phase 2 always writes the anchor file. Re-dispatch once with the absolute path corrected. Still degraded → report it as degraded, and say grounding went unchecked. |
| The check comes back `❌` | Relay the blockers verbatim and close with `/todd:plan <TICKET>`. Don't resolve them here; a fresh run reaches phase 0B through the stamp. |
| The same blocker comes back from two dispatches | Stop. That's the two-pass rule in phase 7 — say what's stuck rather than starting a third lap. |

Now plan $ARGUMENTS.

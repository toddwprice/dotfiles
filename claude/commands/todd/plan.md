---
description: Plan a Linear ticket into ONE Linear comment carrying both the human implementation plan and a Gherkin Behavior Spec whose Scenarios are the implementer's TDD checklist. Use when Todd says "/todd:plan FRG-1234", "plan this ticket", "write the spec for this ticket", or wants a plan an implementing agent can't misread. Richer sibling of `/todd:coder plan` — same Linear contract, plus grounded behavior scenarios. Takes `--dry-run`, `--no-gherkin`.
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

`/todd:coder plan` stays exactly as it is. Use it for a one-file change where the ceremony costs
more than it saves. Use this for anything an agent will implement unattended.

## Arguments

`$ARGUMENTS` starts with a Linear ticket id (e.g. `FRG-1234`), then optional flags:

| Flag | Default | Meaning |
|---|---|---|
| `--dry-run` | off | Print the full plan in chat. Post nothing to Linear. Still writes the local copy. |
| `--no-gherkin` | off | No Gherkin. Section 1 is unchanged; section 2 keeps the implementation detail and drops the coverage table, the Gherkin block, and `Not covered`. Every phase still runs, including Phase 6, so the plan still gets posted. Escape hatch for a trivial ticket. |

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
- **One exists** → you are replacing it, and you must not lose it. Write the old body verbatim to
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

### Approach
1. [Slice 1 — one line. Name the outcome, not the steps. A vertical path that leaves the tree working.]
2. [Slice 2]

### Risks
<!-- ≤3, one line each. Omit the section if there genuinely are none. -->
- [Risk, and what makes it one]

### Questions / Blockers
- ❓ [Anything still open, including every ungrounded anchor from phase 2. One line, phrased as the
  question it actually is. Settled calls go in Decisions, not here.]

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

### The detail block — both modes, always

````markdown
### Files to Modify
- `path/to/file.ex` — [reason]

### Existing Code to Reuse
- `path/to/util.ex:function_name` — [what it does, why it fits]

### Verification
```bash
[the exact commands that prove this work, for every surface it touches]
```
⚠️ [what a green run does NOT prove. Omit the line only if there is genuinely nothing.]
````

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
is green. `# falsifies:` is the mutation check — if reverting the change doesn't turn that scenario
red, the test isn't testing the change.
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

### Coverage table

Sits between the detail block and the Gherkin so a reader can check the mapping without reading
Gherkin. One row per requirement from the ticket:

```markdown
| Requirement (from the ticket) | Scenario | Slice | Target test |
|---|---|---|---|
| Duplicate tab must not join twice | A second tab from the same participant is refused | 1 | `ai_mod_channel_test.exs` |
| Existing tab must survive | (same) | 1 | `ai_mod_channel_test.exs` |
| Survives 500 concurrent joins | ⏸️ deferred → Not covered | — | — |
```

A requirement with no Scenario is a gap, and there are exactly three ways to close it:

1. **Write the Scenario.**
2. **`⏸️ deferred → Not covered`** — a real requirement you're consciously not doing now. Give the
   reason in `Not covered`, and if it deserves its own ticket, say that too.
3. **Move it to `Questions / Blockers`** — it can't be specified until someone answers something.

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

## Phase 5 — Check your own work before posting

Run this against what you wrote. Fix inline; don't report the failures, just fix them.

**Always, both modes:**

1. Comment's first line is exactly `## 📋 Implementation Plan`. This is the cross-file contract —
   it's the check that matters *most* under `--no-gherkin`, because impl and loop still find the
   plan by that string whether or not it carries a spec.
2. **Count the words in section 1.** Over ~250 and something in it is detail. Find it against the
   "What does not go in section 1" table and move it to section 2 — move, never delete.
3. **Section 1 has only these headings**, in this order: `Summary`, `Changed since the last plan`
   (conditional), `Decisions`, `Approach`, `Risks`, `Questions / Blockers`, `Scope`. Anything else
   up there is misfiled. `Summary` is ≤3 sentences, each slice and each risk is one line, `Risks`
   is ≤3 bullets, and `Scope` is one line.
4. `### Scope`'s file count matches the number of entries in section 2's `Files to Modify`, and its
   apps match the paths there. Two numbers that disagree is worse than one number.
5. Section 2's heading is `## 🥒 Behavior Spec & Implementation Detail`, or
   `## 🔧 Implementation Detail` under `--no-gherkin`. Not one of them under both.
6. Every concrete noun you named — module, function, file, factory, config key, error atom —
   traces to a phase-2 anchor. Anything that doesn't is now a blocker, not a claim.
7. `### Verification` exists in section 2 under that exact heading, names real commands covering
   every surface in `Files to Modify`, and says what a green run doesn't prove.
8. Nothing settled is sitting in `Questions / Blockers`. A resolved call belongs in `Decisions`
   with its date — left phrased as a question, it reads as a reason to stop.
9. If phase 0 replaced a plan, `### Changed since the last plan` exists and names each difference.

**Gherkin only — skip these under `--no-gherkin`:**

10. Every requirement in the ticket appears in the coverage table, resolved as a Scenario, a
    `⏸️ deferred` marker, or a `Questions / Blockers` entry. No empty cells, no dropped rows.
11. `Scope`'s deferred count equals the number of `⏸️ deferred` rows in the coverage table.
12. Every Scenario has a `@slice-N` tag, and every slice in `Approach` has at least one Scenario.
13. Every Scenario has an app-or-area tag, a `# target:`, and a `# falsifies:`.
14. Every slice has at least one `@negative` or `@boundary` Scenario.
15. Every measured constant asserted in a `Then` is either derived at runtime or carries a
    `# pinned:` line naming its source and the date you measured it.
16. No Scenario has two `When` steps.
17. No two Scenarios assert the same thing.
18. Every `And` under a `Then` can fail independently.
19. `Not covered` is present, and every line in it says what's excluded *and why*. If genuinely
    nothing is out of scope, write that as the single line — an empty section reads as forgotten.

---

## Phase 6 — Post and report

**Write the local copy first**, always, including under `--dry-run`:
`.claude/tmp/<branch-or-ticket>/plan-<TICKET>.md`. Cheap insurance against a failed Linear write.

**Post** with `mcp__claude_ai_Linear__save_comment` — new comment, or the existing comment id if
phase 0 found one. Under `--dry-run`, post nothing and say so plainly.

**Report to Todd, blockers first.** He reads the top three lines:

```
FRG-1234 — <ticket title>
Scope: Medium · 3 slices · 7 files (axon, dendra) · 11 scenarios (4 negative/boundary) · 2 blockers
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
the `Scope:` line becomes `Scope: Small · 2 slices · 3 files (astro) · 1 blocker`, the per-slice
lines lose their scenario counts, and say plainly that this plan has no Behavior Spec so Todd knows
which kind of run `impl` is about to get.

Then the plan itself. If phase 2 corrected the ticket's premise, **lead with the correction** — it's
the finding, and a reader who skims past it implements the wrong thing. If the correction was big
enough that you stopped, that's the whole report.

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
- Never write a Scenario you can't finish the `# falsifies:` line for.
- One ticket per invocation. A whole project with milestones is `/todd:linear-project-setup`.

## Failure handling

| Failure | Do |
|---|---|
| Ticket not found | Report the id attempted. Stop. |
| Linear MCP blocked or truncating | Fall back to `linctl issue get $TICKET --json`. |
| Multiple existing plan comments | Stop and report. Todd picks. |
| Ticket premise contradicted by the code | Correct it in bold in `Summary` and keep planning if the plan survives the correction; stop and report only if it doesn't. Never quietly plan around it. |
| Can't ground more than about half the anchors | The ticket is under-specified. Post the brief and the detail block with the blockers, and say the Behavior Spec needs answers first. Don't ship a spec built on guesses. |
| `save_comment` fails | The local copy is already on disk — report its path so nothing is retyped. |

Now plan $ARGUMENTS.

---
description: Review a posted implementation plan cold, the way the implementing agent will read it. Fixes what is mechanically wrong, flags what needs Todd's judgement, and stamps the plan as checked so `impl` and `loop` can gate on it. Use when Todd says "/todd:plan-check FRG-1234", "check the plan", "is this plan ready", or after any `/todd:plan` or `/todd:coder plan` run. Takes `--local`, `--report-only`, `--strict`.
---

You are reviewing an implementation plan you did not write, for a ticket you have not planned.
That is the entire point. Do not re-plan it.

## Why this is a separate command

`/todd:plan` used to check itself. It was worse at it for two reasons that don't go away with a
better checklist:

**The author is the worst reader of their own plan.** The session that wrote "the guard rejects the
join" knows which guard. It cannot see that the plan never says. Every ambiguity a plan ships with
looked unambiguous to the session that wrote it — that's *why* it shipped. You have never seen that
reasoning, which is the only qualification that matters here.

**A 23-item checklist carried through planning degrades the planning.** The checks mostly restated
rules `/todd:plan` already states at the point of authoring. Carrying a second copy through six
phases cost attention that phase 2 needed for grounding. The rules stayed where they're actionable;
the verification moved here, where it's the only job.

**You are not a second planner.** The temptation is to read the plan, disagree with the approach,
and write a better one. Don't. Approach is Todd's call and he already has the brief. You check
whether the plan says what it needs to say, not whether you'd have said something else. The one
exception is a factual contradiction — the plan names a module that doesn't exist — and that's a
finding, not a rewrite.

## Arguments

`$ARGUMENTS` starts with a Linear ticket id (e.g. `FRG-1234`), then optional flags:

| Flag | Default | Meaning |
|---|---|---|
| `--local` | off | Read `.claude/tmp/<branch-or-ticket>/plan-<TICKET>.md` instead of Linear. For checking a `--dry-run` plan before it's posted. Writes fixes back to the local file only. |
| `--report-only` | off | Change nothing. Report every finding, including the ones you would have fixed. Use when Todd wants to see what the plan got wrong, not a corrected plan. |
| `--strict` | off | `FLAG` findings are treated as `BLOCKER`. Nothing passes with an open judgement call. For a plan about to go into an unattended `/todd:phase` run. |

No ticket id → show usage and stop.

## Severity — three levels, and they behave differently

| Level | Means | You do |
|---|---|---|
| 🔴 **BLOCKER** | The plan is unusable or will be silently misread. A broken contract string, an ungrounded anchor asserted as fact, a requirement with no coverage. | **Do not fix. Report, fail the check, and hand it back to `/todd:plan`.** These need a decision, and a checker that quietly rewrites them hides the fact that the plan was wrong. |
| 🟡 **FIX** | Mechanically wrong with exactly one correct answer. A miscounted `Scope`, a missing `@slice-N` tag on a scenario that obviously belongs to slice 2, a heading out of order. | **Fix it in place, silently.** List what you fixed in the report; don't ask. |
| 🔵 **FLAG** | Judgement. Two scenarios that might be duplicates, a `Risks` entry that reads like a gotcha, a section 2 that's long enough to suggest the ticket should split. | **Report it. Change nothing.** Todd decides. Under `--strict` these become BLOCKERs. |

**The line between FIX and BLOCKER is whether there's one right answer.** A `Scope` line claiming
5 files over a `Files to Modify` listing 7 has one right answer: 7. A Scenario with no
`# falsifies:` does not — you'd have to invent the falsification, and an invented one is worse than
a missing one because it looks checked. That's a BLOCKER.

**Never fix by deletion.** A duplicate scenario, an over-budget brief, an unfalsifiable assertion —
none of those get resolved by removing the line. Removing it makes the check pass and the plan
worse. Relocate, or report.

---

## Phase 0 — Load the plan and its evidence

**The plan.** `mcp__claude_ai_Linear__list_comments` for the ticket, find the comment whose first
line is `## 📋 Implementation Plan`.

- **None** → nothing to check. Report that, and say whether `/todd:plan` or `/todd:coder plan` has
  been run. Stop.
- **More than one** → 🔴 BLOCKER, and stop. This is the known duplicate-writer bug: `/todd:coder
  plan` posts a new comment every time without checking for an existing one, so a ticket can carry
  two plans while both readers say "a comment", singular. Report both comment ids and their
  timestamps, say which one `list_comments` returns first (that's the one `impl` will read), and
  let Todd pick. Never merge them yourself.
- **One** → that's the plan. Note its comment id; you'll need it to write the stamp.

Under `--local`, read `.claude/tmp/<branch-or-ticket>/plan-<TICKET>.md` instead and skip the
comment-count logic entirely.

**The ticket.** `mcp__claude_ai_Linear__get_issue`, falling back to `linctl issue get $TICKET
--json` if the MCP truncates. You need the original requirements to check coverage — a plan can't
tell you what it left out. Pull linked Notion and Figma context too, for the same reason.

**The anchors.** `.claude/tmp/<branch-or-ticket>/anchors-<TICKET>.md`, written by `/todd:plan`
phase 2. This is your evidence base for every noun in the plan.

**Missing anchor file** → you are checking in **degraded mode**. Say so in the report, at the top,
in bold. You can still check structure, coverage, counts, and form; you cannot check grounding,
which is the check that matters most. Do not silently substitute your own greps for the anchor list
and call it grounded — re-verifying a handful of nouns yourself is not the same as knowing the
planning session verified all of them, and reporting it as a pass would be a lie about what was
checked. Offer to re-ground with a `dev-flow:codebase-locator` pass if Todd wants it, and let him
decide whether that's worth the tokens.

**Mode detection.** Section 2's heading tells you which checks apply:

| Heading | Mode |
|---|---|
| **starts with** `## 🥒 Behavior Spec` | full — every check |
| `## 🔧 Implementation Detail` | `--no-gherkin` — skip group E |
| anything else | 🔴 BLOCKER. Report and stop; downstream readers can't find section 2. |

**Match the Gherkin heading on its prefix, not the whole string.** `plan.md:70` writes the contract
as "Section 2's heading **starts with** the literal `## 🥒 Behavior Spec` whenever there is
Gherkin", and `plan.md:496` says that prefix "is what impl and loop look for" — confirmed at
`todd-coder` SKILL.md:76 and `loop.md:55`, which both match `## 🥒 Behavior Spec`. So the full
`## 🥒 Behavior Spec & Implementation Detail` matches, and so does a bare `## 🥒 Behavior Spec`.
Demanding the long form would fail plans their actual consumers read fine — and because A2 stops
the check, it would fail them before anything else got looked at.

---

## Phase 1 — Group A: the cross-file contract

These break the chain. All 🔴 BLOCKER, no exceptions, and if any fails, report and stop — the rest
of the check is moot on a plan nobody can find.

| # | Check |
|---|---|
| A1 | First line is exactly `## 📋 Implementation Plan`. Not "Plan", not "📋 Plan", no preamble above it. |
| A2 | Section 2's heading either starts with `## 🥒 Behavior Spec` or is `## 🔧 Implementation Detail` — one of the two, not both. Prefix match on the first; see the mode table above. |
| A3 | `### Verification` exists somewhere in the plan. `todd-coder` Impl step 6 sends the implementer to "the plan's `### Verification` block" for any surface outside axon/dendra/astro, and doesn't care which section it sits in — renamed or missing, non-app work has no verify path. |
| A4 | Exactly one plan comment on the ticket (resolved in phase 0). |

---

## Phase 2 — Group B: the brief

Section 1 is read by an architect deciding whether the approach is right. Everything here is about
whether it can do that job in one screen.

| # | Check | Level |
|---|---|---|
| B1 | Section 1 is under ~250 words. | 🟡 relocate the detail to section 2 — never delete |
| B2 | Headings are exactly `Summary`, `Changed since the last plan` (conditional), `Decisions`, `Approach`, `Risks`, `Questions / Blockers`, `Scope`, in that order. | 🟡 reorder; 🔵 if there's an extra heading, since where it belongs is a judgement |
| B3 | `Summary` ≤3 sentences; each `Approach` slice one line; `Risks` ≤3 bullets; `Scope` one line. | 🟡 |
| B4 | `Scope`'s file count equals the number of entries in section 2's `Files to Modify`, and its apps match those paths. | 🟡 correct the count to match the file list |
| B5 | `Questions / Blockers` has ≤3 entries. | 🔴 at 4+ — the ticket was under-specified and got posted anyway |
| B6 | Nothing in `Questions / Blockers` is actually settled. A resolved call or a taken default belongs in `Decisions`. | 🔵 |
| B7 | Every `(assumed, …)` Decision names the precedent it followed. An assumption with no cited precedent is a guess wearing a date. | 🔴 |
| B8 | No file paths, commands, or restated Scenarios in section 1. | 🟡 move down |
| B9 | If a superseded backup exists in `.claude/tmp/`, `### Changed since the last plan` exists and names each difference. | 🔴 — a silently-replaced plan is how a disproved claim gets re-trusted |

**On B1:** count the words. Don't estimate. The budget exists because an architect who has to scroll
stops reading, and every plan drifts over it by accretion, one reasonable-looking line at a time.

---

## Phase 3 — Group C: grounding

This is the check that only exists because phase 2 of `/todd:plan` wrote the anchor file, and it's
the one most likely to find something real.

Walk every concrete noun the plan names — module, function, file path, factory, fixture, config
key, error atom, GraphQL field, feature flag — and trace it to a row in `anchors-<TICKET>.md`.

| # | Check | Level |
|---|---|---|
| C1 | Every concrete noun in section 2 appears in the anchor file. | 🔴 for each one that doesn't |
| C2 | Every anchor's `Verified at` is a real `file:line` that still resolves. Spot-check the ones the plan leans on hardest — the ones in a `Given`, a `# target:`, or an `INV-N` `Check:`. | 🔴 if a cited location doesn't exist |
| C3 | Every `# target:` path is a real test file, or a plausible new one in a directory that exists. | 🔴 if the directory doesn't exist |
| C4 | Every `INV-N` `Check:` is a runnable command, a grep with a stated expected result, or a named existing test — never prose. | 🔴 |
| C5 | Every command in `### Verification` is real for the surface it claims to cover. | 🔴 if a command doesn't exist |

**An ungrounded noun is a BLOCKER, not a FIX.** Do not go find it yourself and add it to the anchor
file. The finding is not "this module exists after all" — the finding is that the planning session
asserted something it hadn't verified, which means you don't know what else it asserted that way.
Report the noun, report where it appears, and let that inform whether Todd trusts the rest.

---

## Phase 4 — Group D: the detail block

| # | Check | Level |
|---|---|---|
| D1 | `Files to Modify` and `Invariants` come before `Existing Code to Reuse`. The constraints that stop wrong work belong where they'll be read. | 🟡 reorder |
| D2 | Every `### Invariants` entry is EARS-form (`SHALL`, with `WHEN`/`IF`/`WHILE`/`WHERE` where it applies) and numbered `INV-N`. | 🟡 if the numbering is off; 🔴 if a statement has no `SHALL` and no testable property |
| D3 | If the ticket is a bug, `### Unchanged behavior` exists and every line names an existing test or a `@regression` Scenario. | 🔴 — a bug plan with no regression surface is incomplete |
| D4 | `### Verification` names commands covering **every** surface in `Files to Modify`, not just the app surfaces. | 🔴 for each uncovered surface |
| D5 | `### Verification` carries the `⚠️` line saying what a green run does *not* prove. | 🔵 if absent — it may be genuinely nothing, but usually isn't |
| D6 | `### Not covered` exists, in both modes, and every line says what's excluded *and why*. | 🟡 if it's missing the "why"; 🔴 if the section is absent |
| D7 | Section 2 is under ~400 lines. | 🔵 — flag as "this looks like two tickets", never trim |

**On D4, the surfaces that get missed:** a tool under `.claude/`, a script in `bin/`, a terraform
composition, a shared Python package, the e2e suite. `impl` knows three commands — `mix test`,
`yarn lint && yarn test`, `uv run ruff check . && uv run pytest` — and nothing else. Anything in
`Files to Modify` outside axon/dendra/astro with no named command means the implementer guesses or
skips.

**On D5, what to look for in the repo before accepting its absence:** does anything under
`.claude/` actually run in CI (`grep -rn '<tool>' .rwx/` coming back empty means it doesn't)? Does
the harness self-skip (`skip() { echo "SKIP: …"; exit 0; }` exits 0 with assertions unrun)? Does a
pytest node id or `-k` filter with a typo pass silently? If one of these applies and the `⚠️` line
doesn't mention it, that's a 🔴, not a 🔵 — the implementer will trust a green terminal.

---

## Phase 5 — Group E: the Behavior Spec

Skip this group entirely under `--no-gherkin`.

**Coverage first**, because it's the check that finds missing work rather than malformed work:

| # | Check | Level |
|---|---|---|
| E1 | Every requirement in the **ticket** appears as a row in the coverage table. Read the ticket, not the table — the table can only tell you about requirements someone remembered. | 🔴 for each missing row |
| E2 | Every row resolves to a Scenario, an `INV-N`, a `⏸️ deferred` marker, or a `Questions / Blockers` entry. No empty cells. | 🔴 |
| E3 | Every row's `Kind` matches its `Covered by` cell — no invariant filed as a Scenario. | 🟡 |
| E4 | Every `INV-N` in `### Invariants` has a table row, and every `INV-N` in the table exists in the section. | 🟡 |
| E5 | `Scope`'s deferred count equals the `⏸️ deferred` row count. | 🟡 |
| E6 | Every `⏸️ deferred` row has a matching `Not covered` line giving the reason. | 🔴 — a deferral with no reason reads as an oversight |

**Then the Scenarios**, one at a time:

| # | Check | Level |
|---|---|---|
| E7 | Has a `@slice-N` tag, and every slice in `Approach` has at least one Scenario. | 🟡 for a missing tag where the slice is unambiguous; 🔴 for a slice with no Scenarios |
| E8 | Has an app tag or an area tag. | 🟡 |
| E9 | Has a `# target:` and a `# falsifies:`. | 🔴 — never invent either |
| E10 | Exactly one `When`. | 🔴 — splitting it is a planning decision, not a fix |
| E11 | Every slice has at least one `@negative` or `@boundary` Scenario. | 🔴 — happy paths are the ones that get implemented correctly by accident |
| E12 | Every `And` under a `Then` can fail independently. | 🔵 |
| E13 | No two Scenarios assert the same thing, and no Scenario restates an Invariant. | 🔵 |
| E14 | Every measured constant in a `Then` is derived at runtime or carries a `# pinned:` naming source and date. | 🔴 |
| E15 | No Scenario's `When` describes the change rather than a behavior ("when the guard ships", "when the refactor is complete"). | 🔴 — unfalsifiable, and meaningless after merge |
| E16 | No `Given` hides the setup that matters behind "a valid X". | 🔵 |
| E17 | No `Then` asserts an internal that a caller can't observe. | 🔵 |
| E18 | `Scenario Outline` `Examples` rows differ in kind, not just value. | 🔵 |

**On E9 and E14 being BLOCKERs:** you could write the missing `# falsifies:` line, and it would
look fine, and it would be your guess about what the implementer should avoid rather than the
planner's knowledge of it. A confidently wrong falsification is worse than a missing one, because
the missing one gets noticed.

---

## Phase 6 — Report and stamp

**Report to Todd, blockers first.** He reads the top four lines:

```
FRG-1234 — <ticket title>
Plan check: ❌ FAILED · 3 blockers · 5 fixed · 2 flagged
Checked: 47 checks across A–E · full mode · anchors present
Plan: <linear comment url>

🔴 Blockers — these need you
- [C1] `Axon.Rooms.reject_join/2` is named in slice 1 and is not in the anchor file.
  Nothing verified it exists.
- [E11] Slice 2 has 4 scenarios, all happy path. No @negative or @boundary.
- [B5] 4 entries in Questions / Blockers. The ticket wasn't ready to plan.

🟡 Fixed
- [B4] Scope said 5 files; Files to Modify lists 7. Corrected to 7.
- [E5] Deferred count was 1; table has 2 deferred rows. Corrected.

🔵 Flagged — your call
- [D7] Section 2 is 520 lines across 3 slices. This looks like two tickets.
- [E13] "Rejoin after clean disconnect" and "expired presence allows rejoin" may be
  the same scenario in different words.

Blocked. Run `/todd:plan FRG-1234` to resolve the 3 blockers.
```

Under `--report-only` the 🟡 section becomes **Would fix** and nothing is written anywhere.

**Close with the handoff, and name the command.** The last line Todd reads is what happens next,
and it depends only on whether there are blockers:

| Outcome | Last line |
|---|---|
| ≥1 🔴 blocker | ``Blocked. Run `/todd:plan <TICKET>` to resolve the N blockers.`` |
| 0 blockers | ``Plan checked. Ready for `/todd:coder impl <TICKET>`.`` |

`/todd:plan` is the right destination for a blocker and this command is not, for the reason the top
of this file gives: fixing a 🔴 takes the planner's knowledge, and you don't have it. You found that
the plan asserts an ungrounded noun; the planner is the one who can go ground it or turn it into a
real question. Sending Todd anywhere else — or just listing the blockers and stopping — leaves a
failed plan sitting on the ticket with nothing driving it to a fix.

Don't soften it into "you may want to". A `❌` plan that nobody re-plans still reaches `impl`,
because the stamp is documentation rather than a gate (see "Wiring this into the rest of the
chain").

**Then write the stamp**, unless `--report-only`. The last line of the plan comment, after a `---`:

```markdown
---
*Plan check: ✅ passed — 2026-08-08 · 47 checks · full mode · 5 auto-fixed*
```

or, on failure — and on failure the stamp **carries the blockers themselves**, not just their ids:

```markdown
---
*Plan check: ❌ 3 blockers — 2026-08-08 · resolve with `/todd:plan FRG-1234`*

**🔴 Open blockers**
- **[C1]** `Axon.Rooms.reject_join/2` is named in slice 1 and is not in the anchor file.
  Nothing verified it exists.
- **[E11]** Slice 2 has 4 scenarios, all happy path. No `@negative` or `@boundary`.
- **[B5]** 4 entries in `Questions / Blockers`. The ticket wasn't ready to plan.
```

**Why the full text and not just `see C1, E11, B5`:** the session that resolves these is a fresh
`/todd:plan` run that never saw your report. `C1` tells it a noun was ungrounded and not *which*
noun, so it would have to re-derive your finding from scratch — and a re-derivation that comes out
differently silently resolves the wrong thing. Linear is the only store both sessions are
guaranteed to share; the tmp directory is per-worktree and Todd may re-plan from anywhere. One line
per blocker, copied verbatim from the report, is what makes the loop work.

Write each blocker the way the report does: the check id in bold, then what's wrong, then what it
means. `/todd:plan` reads this block; keep it parseable by a human and an LLM, not by a regex.

**Rules for the stamp:**

- It goes **inside the existing comment**, at the end, via `save_comment` with the comment id from
  phase 0. Never a new comment — a second comment on the ticket is the duplicate-plan bug you exist
  partly to catch.
- Replace any previous stamp rather than appending a second one. One stamp, always the latest.
- **The `🔴 Open blockers` block is part of the stamp**, so it gets replaced wholesale too — and a
  passing run *removes* it. A plan that now passes must not still be carrying last run's blocker
  list; `/todd:plan` would walk Todd through three issues that are already fixed.
- **You are not the only writer of this slot.** `/todd:plan` phase 0B, after resolving blockers,
  replaces the stamp with `*Plan revised <date> to resolve N blockers (C1, E11, B5) — re-check
  required.*`. Expect to find one and replace it like any other stamp — but **read it first**: the
  ids it names are the blockers your previous run raised. Any of them you raise *again* is a
  resolution that didn't take, and that's worth saying plainly in the report rather than filing as a
  fresh finding.
- The first line of the comment does not change. Ever. Check it after your write.
- In degraded mode (no anchor file) the stamp says so: `⚠️ passed (ungrounded) — anchors missing,
  grounding unchecked`. A pass that didn't check grounding must never look like one that did.

**Write the local copies** before posting, so a failed Linear write costs nothing:

- `.claude/tmp/<branch-or-ticket>/plan-<TICKET>-checked-<YYYYMMDD-HHMM>.md` — the checked plan body.
- `.claude/tmp/<branch-or-ticket>/plan-check-<TICKET>-findings.md` — the **full report**: blockers,
  what you fixed, what you flagged. Stable filename, overwritten every run, so a later session can
  open it without globbing for a timestamp. This is the long form of what the stamp summarizes —
  `/todd:plan` prefers it when it's there, because it also carries the 🔵 flags, which the stamp
  deliberately doesn't. Write it even under `--report-only`; a report-only run is exactly when Todd
  wants the findings kept without the plan being touched.

---

## Wiring this into the rest of the chain

Three call sites need to know about the stamp. **None of them are this command's to change**, and
you should not edit them from here — but say so in the report the first time you run on a repo
where they haven't been updated:

| Call site | What it should do |
|---|---|
| `commands/todd/loop.md` phase 0 | Already gates on the plan comment existing. Should also refuse to start on a plan whose stamp says `❌`, or that has no stamp at all. |
| `skills/todd-coder/SKILL.md` Impl step 4 | Reads the plan. Should surface an unchecked or failed stamp to the implementer rather than proceeding silently. |
| `commands/todd/phase.md` | Its plan-staleness guard re-plans with `/todd:coder plan` and runs `impl` in the same subagent. That path produces an unchecked plan *and* risks a duplicate comment. It should run `/todd:plan-check --strict` between the two. |

Until those land, the stamp is documentation rather than a gate, and an unchecked plan can still
reach `impl`. That's worth saying out loud once rather than letting Todd assume the gate is live.

---

## Hard rules

- Never re-plan. You check the plan that exists; you don't write a better one.
- Never fix a 🔴. Fixing it hides that the plan was wrong, and your fix is a guess.
- Never fix by deleting. Relocate, or report.
- Never add to the anchor file. Grounding is phase 2 of `/todd:plan`'s job, and re-grounding here
  would report as checked something that was never verified during planning.
- Never post a second comment. One plan comment, one stamp, inside it.
- Never report a pass in degraded mode without saying grounding went unchecked.
- Never change the first line of the plan comment, or either section heading.
- Never end a failed check without sending Todd to `/todd:plan <TICKET>`. A blocker list with no
  next command is where the loop stops.
- Never record a blocker as a bare check id. The stamp carries the finding in words, or the session
  that has to resolve it is guessing at what you meant.

## Failure handling

| Failure | Do |
|---|---|
| No plan comment | Report it, say which command should have written one, stop. |
| Multiple plan comments | 🔴 Report both ids and timestamps, name the one `impl` would read, stop. Todd picks. |
| Section 2 heading matches neither literal | 🔴 Report and stop. Everything downstream branches on it. |
| Anchor file missing | Degraded mode. Run every other group, say so in bold at the top of the report and in the stamp. |
| Ticket not found or MCP truncating | Fall back to `linctl issue get $TICKET --json`. If that also fails, run groups A–D and skip E1 — you can't check coverage against a ticket you can't read. Say which group you skipped. |
| Plan contradicted by the code | 🔴 Report it as a finding. Don't correct the plan; the correction may change the approach, which is Todd's call. |
| `save_comment` fails | The checked local copy is on disk — report its path. |

Now check $ARGUMENTS.

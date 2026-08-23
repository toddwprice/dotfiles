---
name: todd-plan-check
description: Review a posted implementation plan cold, the way the implementing agent will read it. Fixes what is mechanically wrong, flags what needs Todd's judgement, and stamps the plan as checked so `impl` and `loop` can gate on it. Use when Todd says "/todd-plan-check FRG-1234", "check the plan", "is this plan ready", or after any `/todd-plan` or `/todd-coder plan` run. Takes `--local`, `--report-only`, `--strict`.
---

You are reviewing an implementation plan you did not write, for a ticket you have not planned.
That is the entire point. Do not re-plan it.

## Why this is a separate command

`/todd-plan` used to check itself. It was worse at it for two reasons that don't go away with a
better checklist:

**The author is the worst reader of their own plan.** The session that wrote "the guard rejects the
join" knows which guard. It cannot see that the plan never says. Every ambiguity a plan ships with
looked unambiguous to the session that wrote it — that's *why* it shipped. You have never seen that
reasoning, which is the only qualification that matters here.

**A 23-item checklist carried through planning degrades the planning.** The checks mostly restated
rules `/todd-plan` already states at the point of authoring. Carrying a second copy through six
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
| `--strict` | off | `FLAG` findings **and advisories** are treated as `BLOCKER`. Nothing passes with an open judgement call or a carried-forward note. This is what `/todd-loop` runs, so it's the regime a plan headed for an unattended run has to survive. |

No ticket id → show usage and stop.

## Severity — three levels and one disposition, and they behave differently

| Level | Means | You do |
|---|---|---|
| 🔴 **BLOCKER** | The plan is unusable or will be silently misread. A broken contract string, an ungrounded anchor asserted as fact, a requirement with no coverage. | **Do not fix. Report, fail the check, and hand it back to `/todd-plan`.** These need a decision, and a checker that quietly rewrites them hides the fact that the plan was wrong. |
| 🟡 **FIX** | Mechanically wrong with exactly one correct answer. A miscounted `Scope`, a missing `@slice-N` tag on a scenario that obviously belongs to slice 2, a heading out of order. | **Fix it in place, silently.** List what you fixed in the report; don't ask. |
| 🔵 **FLAG** | Judgement. Two scenarios that might be duplicates, a `Risks` entry that reads like a gotcha, a section 2 that's long enough to suggest the ticket should split. | **Report it. Change nothing.** Todd decides. Under `--strict` these become BLOCKERs. |
| ⚪ **ADVISORY** | Not a fourth severity — a **disposition of a 🔴** that makes the plan thin rather than wrong, within the limits in "An advisory is not a blocker" below. | **Report it, change nothing, and don't fail the plan.** It goes in the stamp so `impl` picks it up as a note. Under `--strict` these become BLOCKERs too. |

**The line between FIX and BLOCKER is whether there's one right answer.** A `Scope` line claiming
5 files over a `Files to Modify` listing 7 has one right answer: 7. A Scenario with no
`# falsifies:` does not — you'd have to invent the falsification, and an invented one is worse than
a missing one because it looks checked. That's a BLOCKER.

**Never fix by deletion.** A duplicate scenario, an over-budget brief, an unfalsifiable assertion —
none of those get resolved by removing the line. Removing it makes the check pass and the plan
worse. Relocate, or report.

## Two rules that decide how many laps this costs

These were learned from the run history, not reasoned from first principles. Audited 2026-08-13
over 41 runs of this command: 6 tickets passed, 6 failed, and one — ENA-443 — took **nine checks
without ever passing**, its blocker count going *up* twice. Both rules below exist because of what
that history showed, and ignoring either one is how a plan takes nine laps instead of two.

### 1. Report the whole class, never the first instance

**When a check fires, sweep every instance of it in the plan before you write it up.** E9 fired on
FRG-1240 three passes running — Scenario 4, then the single-toast Scenario, then another — because
each report named one Scenario and the next pass found the next one. Three laps for one defect.

So: E9 fires → check the `# target:`/`# falsifies:` on *every* Scenario. C1 fires → trace *every*
noun. C4 fires → read *every* `INV-N` `Check:`. D4 fires → walk *every* surface in
`Files to Modify`. Report them as one finding with every instance listed:

```
- **[E9]** Three Scenarios have no `# falsifies:`: "a rejoin after presence expiry" (slice 1),
  "the refused tab explains itself" (slice 2), "an expired token is rejected" (slice 3).
```

A finding that names one instance of a class you didn't sweep is a finding that will come back.
This is the single cheapest thing you can do to shorten the loop.

### 2. An advisory is not a blocker

A plan can be thinner than ideal without being wrong, and the run history says four of the six
failures were **a single blocker** — one missing `# falsifies:`, one uncovered requirement, one
duplicate comment. A single-instance gap costing a full lap (fresh session, re-read the ticket, the
plan and the anchors, re-run every check) is the loop's biggest avoidable cost.

So some 🔴s are **advisory-eligible**: they ride along as impl-time notes instead of failing the
plan. A finding is advisory-eligible only when **all** of these hold:

- It's in this set: **E9, E14, D5, B7, D2, E6, C1-that-verifies** (see C1).
- After the class sweep, it has **≤2 instances**.
- Total advisories across the whole check is **≤3**.

Anything else is a blocker. In particular these are **never** advisory-eligible, because each one
means the plan is *wrong* rather than *thin*: **A1–A4** (nobody can find the plan), **B5** (the
ticket wasn't ready), **B9** (a disproved claim gets re-trusted), **C2, C4, C5** (a cited thing
doesn't exist), **D3, D4, E1, E2, E7, E10, E11, E15** (a requirement or a surface has no coverage —
DEVOPS-2259's D3 would have shipped a service booting healthy on a database it couldn't serve).

Under `--strict`, nothing is advisory-eligible. Advisories become blockers, same as 🔵 flags do.

---

## Phase 0 — Load the plan and its evidence

**The plan.** `mcp__claude_ai_Linear__list_comments` for the ticket, find the comment whose first
line is `## 📋 Implementation Plan`. If the Linear MCP is unavailable, deferred, or errors, run
`linctl auth status` and `linctl issue get $TICKET --json`; read the same comment from
`.comments.nodes`. The fallback has the same duplicate-plan stop: do not choose between two plan
comments just because the MCP is absent.

- **None** → nothing to check. Report that, and say whether `/todd-plan` or `/todd-coder plan` has
  been run. Stop.
- **More than one** → 🔴 BLOCKER, and stop. This is the known duplicate-writer bug: `/todd-coder
  plan` posts a new comment every time without checking for an existing one, so a ticket can carry
  two plans while both readers say "a comment", singular. Report both comment ids and their
  timestamps, say which one `list_comments` returns first (that's the one `impl` will read), and
  let Todd pick. Never merge them yourself.
- **One** → that's the plan. Note its comment id; you'll need it to write the stamp.

Under `--local`, read `.claude/tmp/<branch-or-ticket>/plan-<TICKET>.md` instead and skip the
comment-count logic entirely.

**The existing stamp tells you which run this is.** Read it before you check anything — it carries
three things you need, and skipping it is how this command re-does work it already did.

| Stamp you find | This run is | Scope |
|---|---|---|
| none | **pass 1** | Every check. |
| `*Plan revised … — re-check required*` | **a re-check** of a phase-0B revision | Delta — see below. |
| `Plan check: ✅ / ⚠️ / ❌ …` with no revision line after it | **a re-run** on an unchanged plan | Every check. Say so in the report; nothing changed, so the verdict shouldn't either. |

**Delta mode, on a re-check.** A phase-0B revision is surgery on named findings, and re-running all
43 checks over the untouched majority is what turns a two-lap fix into a nine-lap one — every pass
is a fresh chance to raise a *new* finding on a line nobody edited. So on a re-check, run:

1. **All of group A.** Cheap, and a revision can break a heading.
2. **Every check id the previous stamp named**, swept across the whole plan per rule 1 above. These
   are the ones most likely to be half-fixed.
3. **The coverage table** (E1–E6). Cheap, and it's where a revision silently drops a row.
4. **Every line `### Changed since the last plan` names**, plus the Scenarios and Invariants the
   revision touched.

Do **not** re-audit Scenarios the last pass accepted and this revision didn't touch. If you can't
tell what it touched — `### Changed since the last plan` is missing or vague — that's B9, and B9 is
a blocker precisely because it makes a delta check impossible. Fall back to the full check and say
you had to.

**Count the pass.** Take the previous stamp's `pass N` and add one; absent, this is pass 1. The
stamp you write carries it. Two things read it:

- **At pass 3, stop checking and escalate.** Report what's still open, say plainly that three passes
  have not settled it, and hand it to Todd as a scoping question rather than a fourth lap. The old
  guard — "the same blocker survives two passes" — keyed on blocker *identity*, so a loop that found
  a different instance each lap never tripped it. ENA-443 reached nine. A pass counter can't be
  fooled that way.
- **A check id that fired on the previous pass and fires again** is a resolution that didn't take,
  not a fresh finding. Say that in the report, in those words. On ENA-443 the closure *moved* the
  problem one layer down each time — the re-aimed `# falsifies:` landed on a mutation the target
  still couldn't observe — and nothing in the report ever said so, so the next pass treated it as
  new.

**Read the rulings block.** If the plan carries a `**⚖️ Held by decision**` block in its stamp,
those findings are **closed** — by Todd, or by a previous run of this command where the entry is
marked `(auto, …)` — and you do not raise them again. Either kind. List them in one line —
`⚖️ Held by decision: B1 (brief length, auto, pass 1), D7 (section 2 length, pass 2)` — and move on.

This exists because the history says these never close on their own: **B1 was flagged 10 times**
across the audited runs and fixed zero times; ENA-443's ninth findings file reads *"Section 1 is
2270 words against budget — 9th run… Same conclusion as the last seven runs"* and *"[D7] Held
by decision since pass 7."* Re-raising a settled call is noise that makes a passing plan look like a
failing one.

**The ticket.** `mcp__claude_ai_Linear__get_issue`, falling back to `linctl issue get $TICKET
--json` if the MCP truncates. You need the original requirements to check coverage — a plan can't
tell you what it left out. Pull linked Notion and Figma context too, for the same reason.

**The anchors.** `.claude/tmp/<branch-or-ticket>/anchors-<TICKET>.md`, written by `/todd-plan`
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

**Match the Gherkin heading on its prefix, not the whole string.** `plan.md`'s "The contract you must
not break" writes it as "Section 2's heading **starts with** the literal `## 🥒 Behavior Spec`
whenever there is Gherkin", and its phase 4 heading table says that prefix "is what impl and loop
look for" — confirmed at
`todd-coder` SKILL.md:76 and `loop.md:55`, which both match `## 🥒 Behavior Spec`. So the full
`## 🥒 Behavior Spec & Implementation Detail` matches, and so does a bare `## 🥒 Behavior Spec`.
Demanding the long form would fail plans their actual consumers read fine — and because A2 stops
the check, it would fail them before anything else got looked at.

---

## Phase 1 — Group A: the cross-file contract

These break the chain: get one wrong and the plan is invisible to `impl`, `loop` and `phase`. But
three of the four are **literal strings with exactly one right answer**, which by this command's own
FIX/BLOCKER test makes them fixes, not blockers. Failing a plan over a heading typo costs a full lap
to correct a string you could have corrected here — DEVOPS-2244 spent one that way.

| # | Check | Level |
|---|---|---|
| A1 | First line is exactly `## 📋 Implementation Plan`. Not "Plan", not "📋 Plan", no preamble above it. | 🟡 rewrite the line; the body below it doesn't change |
| A2 | Section 2's heading either starts with `## 🥒 Behavior Spec` or is `## 🔧 Implementation Detail` — one of the two, not both. Prefix match on the first; see the mode table above. | 🟡 **only if you can tell which mode it is** from the body — Gherkin present → the 🥒 form, no Gherkin → the 🔧 form. Both present, or ambiguous → 🔴 and stop |
| A3 | `### Verification` exists somewhere in the plan. `todd-coder` Impl step 6 sends the implementer to "the plan's `### Verification` block" for any surface outside axon/dendra/astro, and doesn't care which section it sits in — renamed or missing, non-app work has no verify path. | 🟡 if a block of verify commands is sitting under a different heading — rename it. 🔴 if there's no such block at all; that's D4's missing content, and you'd be inventing commands |
| A4 | Exactly one plan comment on the ticket (resolved in phase 0). | 🔴 and stop. Which duplicate survives is Todd's call, and picking one could discard the plan he wants |

**Fixing A1–A3 does not make them silent.** Report each one in the 🟡 section, and say in the
report that the contract was broken — `/todd-plan` phase 5 is supposed to gate exactly these four
before posting, so an A-group fix here means that gate didn't run. That's worth Todd knowing even
though it cost him nothing this time.

**Stop only on an A you couldn't fix.** The rest of the check is moot on a plan nobody can find, but
a plan you just made findable is worth checking — the old "any A fails → report and stop" meant a
one-character heading error hid every real finding until the next lap.

---

## Phase 2 — Group B: the brief

Section 1 is read by an architect deciding whether the approach is right. Everything here is about
whether it can do that job in one screen.

| # | Check | Level |
|---|---|---|
| B1 | Section 1 is under ~300 words. | **≤500 words → 🟡: actually do the relocation.** Over 500 → **decide it yourself and record it. Never a 🔵, never a question for Todd** — see below |
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

**Then act on the count, because the old instruction never got executed.** B1 was raised **10 times**
across the audited runs and the relocation happened **zero** times — the 🟡 said "relocate" and every
run reported it instead. Two bands, and they need different things:

- **Under ~500 words** — do it. Take the file paths, commands and restated Scenarios out of section 1
  and put each one where phase 4 of `plan.md` says it belongs. This is mechanical, it has one right
  answer, and it's a 🟡 like any other. Report what you moved.
- **Over ~500 words** — don't relocate, and **don't ask.** ENA-443's brief was **2270 words**, and
  relocating 2000 words is not a fix, it's a rewrite of both sections, which is re-planning and not
  yours to do. So take the only other call available: **the brief stays as written.** Record it as an
  auto-held entry (below), say once in the report what the length actually indicates — *"Section 1 is
  2270 words against a ~300 budget; this reads like a brief for more than one ticket"* — and never
  raise it again.

**Neither band is Todd's call.** The over-ceiling case used to raise a 🔵 and wait for him to rule.
It doesn't now, because there were only ever two answers — relocate, or leave it — and which one
applies is decided entirely by the word count you already have. Asking him to pick between them
taught him nothing and spent a line in every report until someone wrote the ruling down.

**Write the auto-held entry into `⚖️ Held by decision`, marked `(auto, pass N)`.** That block is
otherwise Todd's, and a length call is the one thing you may add to it yourself — see the stamp rules
in phase 6. It has to be durable precisely because you read the plan cold: with no record, the next
pass measures the same 640-word brief, reaches the same conclusion, and the report grows another line
for a call that was already made. That is the mechanism that let B1 be raised **10 times**.

**D7 (section 2 length) keeps its 🔵 and stays Todd's.** It shares B1's history — flagged four times
on one ticket, held by decision from pass 7 onward — but not its arithmetic. A long section 2 has no
relocation available at any length, so there is no count-driven answer to fall back on, and what it
actually asks is whether this is one ticket. That's a scoping call and it's his. Don't extend B1's
auto-decide to it.

---

## Phase 3 — Group C: grounding

This is the check that only exists because phase 2 of `/todd-plan` wrote the anchor file, and it's
the one most likely to find something real.

Walk every concrete noun the plan names — module, function, file path, factory, fixture, config
key, error atom, GraphQL field, feature flag — and trace it to a row in `anchors-<TICKET>.md`.

**This group is where the loop lives.** In the audited history, group C produced **23 of roughly 50
blockers — 46% of everything this command has ever raised.** C1 alone fired **10 times and was fixed
zero times**; C2 fired 8. Everything below is written to keep the real findings and drop the ones
that were costing a lap without telling anyone anything.

| # | Check | Level |
|---|---|---|
| C1 | Every concrete noun in section 2 appears in the anchor file. | Tiered — see below. Not a flat 🔴 |
| C2 | Every anchor's **symbol** is still present in the file its `Verified at` names. Spot-check the ones the plan leans on hardest — the ones in a `Given`, a `# target:`, or an `INV-N` `Check:`. | 🔴 if the file is gone or the symbol isn't in it. **🟡 if the symbol is there and only the line number is off** — correct the number |
| C3 | Every `# target:` path is a real test file, or a plausible new one in a directory that exists. | 🔴 if the directory doesn't exist |
| C4 | Every `INV-N` `Check:` is a runnable command, a grep with a stated expected result, or a named existing test — never prose. | 🔴 |
| C5 | Every command in `### Verification` is real for the surface it claims to cover. | 🔴 if a command doesn't exist |

**On C2, a line number is not the finding.** The check is meant to catch *a planning session citing a
location that doesn't exist*. A `file:line` whose line has drifted — because main moved, because the
plan sat overnight, because the planner grepped a different worktree — is not that; the anchor is
sound and the number is stale. Demanding an exact line match failed plans whose grounding was
genuinely done, and it made every anchor in a day-old plan a fresh blocker. So: grep the anchor's
symbol in the cited file. Present → 🟡, correct the number, move on. Absent, or the file is gone →
🔴, and that is a real finding.

**On C1, three tiers, because "not in the anchor file" and "doesn't exist" are different findings.**
Sweep every noun first (rule 1 above), then for each one that's missing from the anchor file, spend
one `Grep` establishing whether it's real:

| What you find | Level |
|---|---|
| The noun **doesn't exist** — no such module, function, factory, atom, field | 🔴. This is the finding C1 exists for: the plan asserts something nothing verified, and an implementer will go looking for it. |
| It exists, and **≤2 nouns** are in this state | **Advisory.** Report each with the `file:line` you found, say grounding was incomplete, and let it ride. |
| It exists, but **3 or more nouns** are in this state | 🔴, as one finding. Three misses is not an oversight — the planning session's grounding is systematically incomplete, and now you don't know what else it asserted that way. |

**Still never add to the anchor file.** That rule stands and it isn't in tension with the tiers: the
advisory *reports* what you verified without *recording* it as grounded, because grounding is
`/todd-plan` phase 2's job and a row you wrote would claim the planning session did work it didn't.
Phase 0B appends the row when it resolves the advisory.

**Say which side of the fence a C1 came from.** "The noun exists at `rooms.ex:181`, it just wasn't
recorded" and "there is no such function" both used to print as `[C1] ungrounded noun`, and they need
completely different work from the planner. Name the file:line when you found one.

**When every C1 is on the advisory side, name the cause.** `/todd-plan` writes `anchors-<TICKET>.md`
in its phase 2 but authors section 2 in its phase 4, so every noun phase 4 introduces was structurally
guaranteed to miss the anchor file — that ordering, not carelessness, is what produced ten C1s and
zero fixes. Its phase 5 now carries a reconciliation gate. A plan still arriving with unrecorded
nouns that all verify means that gate didn't run, and saying so is more useful than the finding.

---

## Phase 4 — Group D: the detail block

| # | Check | Level |
|---|---|---|
| D1 | `Files to Modify` and `Invariants` come before `Existing Code to Reuse`. The constraints that stop wrong work belong where they'll be read. | 🟡 reorder |
| D2 | Every `### Invariants` entry is EARS-form (`SHALL`, with `WHEN`/`IF`/`WHILE`/`WHERE` where it applies) and numbered `INV-N`. | 🟡 if the numbering is off; 🔴 if a statement has no `SHALL` and no testable property |
| D3 | If the ticket is a bug, `### Unchanged behavior` exists and every line names an existing test or a `@regression` Scenario. | 🔴 — a bug plan with no regression surface is incomplete |
| D4 | `### Verification` names commands covering **every** surface in `Files to Modify`, not just the app surfaces. | 🔴 for each uncovered surface |
| D5 | `### Verification` carries the `⚠️` line saying what a green run does *not* prove. | 🔵 if absent and you checked the repo for the traps below and found none. **Advisory-eligible 🔴 if one of them applies** and the line doesn't mention it |
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

**D5's Level column used to say plain `🔵` while this paragraph escalated it, and the escalation is
what actually ran: D5 came back as a blocker 4 times.** The table now says both, so the severity you
report matches the severity you applied. And because a missing `⚠️` line makes the plan *thin* rather
than *wrong* — the commands are still real, the coverage is still there — it's advisory-eligible: say
what a green run won't prove, let it ride as an impl-time note, and don't spend a lap on it.

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
Plan check: ❌ FAILED · 2 blockers · 5 fixed · 1 advisory · 2 flagged
Checked: 43 checks across A–E · full mode · anchors present · pass 2 of 3
Plan: <linear comment url>

🔴 Blockers — these need you
- [C1] `Axon.Rooms.reject_join/2` is named in slice 1, is not in the anchor file, and
  does not exist — no `reject_join` in `apps/axon/lib/axon/rooms.ex` at any arity.
- [E11] Slices 2 and 3 have no @negative or @boundary scenario (swept all 3 slices;
  slice 1 has one). 7 scenarios total, 6 happy path.

🟡 Fixed
- [A1] First line was `## 📋 Plan`. Rewrote it to `## 📋 Implementation Plan` — note that
  /todd-plan's phase-5 contract gate should have caught this.
- [B4] Scope said 5 files; Files to Modify lists 7. Corrected to 7.
- [C2] `build(:mission_draft)` cited at factory.ex:203; it's at :211. Line corrected.
- [E5] Deferred count was 1; table has 2 deferred rows. Corrected.
- [B1] Section 1 was 340 words. Moved the 3 file paths and the verify command to section 2.

⚪ Advisories — riding along as impl notes, not blocking
- [E9] "an expired token is rejected" (slice 3) has no `# falsifies:`. The other 6
  scenarios have one.

🔵 Flagged — your call
- [E13] "Rejoin after clean disconnect" and "expired presence allows rejoin" may be
  the same scenario in different words.
- [D7] Section 2 is 520 lines across 3 slices. This looks like two tickets.
  ⚠️ book severity 🔴 — this one fails under `--strict`, which is what `/todd-loop` runs.

⚠️ [E11] also fired on pass 1. The resolution didn't take — last pass it was slice 2 only,
   and the scenario added there asserts a refusal the target can't observe.

⚖️ Held by decision: B6 (the flag question, pass 1), B1 (brief length, auto, pass 1).

Blocked. Run `/todd-plan FRG-1234` to resolve the 2 blockers.
```

Under `--report-only` the 🟡 section becomes **Would fix** and nothing is written anywhere.

**Five things in that template are new, and each one exists to stop a lap:**

- **`⚪ Advisories`** — the advisory tier from the top of this file. Never merge these into 🔴 or 🔵;
  they're the findings that would have failed a plan for being thin.
- **`pass N of 3`** — from phase 0. At pass 3 you escalate instead of failing again.
- **The `⚠️ also fired on pass 1` line** — a repeat check id, called out as a resolution that didn't
  take. Put it *below* the finding sections so it reads as commentary on them.
- **`⚖️ Held by decision`** — one line, findings already settled and never re-argued: Todd's rulings,
  plus any over-ceiling B1 you decided yourself, marked `(auto, …)`.
- **`⚠️ book severity 🔴` on a 🔵** — a flag that would fail under `--strict`. `/todd-loop` runs
  `--strict`, so without this a plan passes here and red-lines there, and Todd finds out a lap later.
  Seen on DEVOPS-2241: `✅ passed · 4 flagged`, two of them book-🔴.

**Close with the handoff, and name the command.** The last line Todd reads is what happens next,
and it depends only on whether there are blockers:

| Outcome | Last line |
|---|---|
| ≥1 🔴 blocker, and this is pass 1 or 2 | ``Blocked. Run `/todd-plan <TICKET>` to resolve the N blockers.`` |
| ≥1 🔴 blocker, and this is **pass 3** | ``Three passes haven't settled this. Not a fourth lap — <the one thing that's actually unresolved>, and that's a scoping call.`` |
| 0 blockers, ≥1 advisory | ``Plan checked, N advisories riding along as impl notes. Next: `/clear`, then `/todd-loop <TICKET>`.`` |
| 0 blockers, 0 advisories | ``Plan checked. Next: `/clear`, then `/todd-loop <TICKET>`.`` |

**Pass 3 is a stop, not a failure.** By the third check the loop has demonstrated it can't settle the
thing on its own, and a fourth lap is the shape that took ENA-443 to nine. Name the one finding that
keeps coming back, say what two resolutions of it would produce different plans, and hand Todd that
question. Don't list all the blockers again — he's read them twice.

`/todd-plan` is the right destination for a blocker and this command is not, for the reason the top
of this file gives: fixing a 🔴 takes the planner's knowledge, and you don't have it. You found that
the plan asserts an ungrounded noun; the planner is the one who can go ground it or turn it into a
real question. Sending Todd anywhere else — or just listing the blockers and stopping — leaves a
failed plan sitting on the ticket with nothing driving it to a fix.

**On a pass, `/todd-loop` is the destination and the `/clear` is part of the instruction.** The stamp
you just wrote is exactly what `/todd-loop` phase 0 gates on — `✅` and `⚠️` proceed, `❌` stops, and an
unstamped plan makes it run this check itself — so a passed plan is a loop-ready ticket, not just an
`impl`-ready one. The `/clear` matters because a loop cannot empty its own window: it holds the ticket
id, the worktree path and one line per phase precisely so it doesn't compact mid-flow, and starting it
in a session that has just read a plan, a ticket and an anchor file hands it the fullest possible
context to begin from. Todd's keystroke is the only thing that fixes that, so ask for it by name.

A degraded pass gets the same handoff. `⚠️ passed (ungrounded)` is a pass with grounding unchecked,
which `/todd-loop` accepts explicitly — say both things in the one line and let him decide whether to
re-plan first.

**One exception: when a runner invoked you inline, the handoff isn't yours to write.** `/todd-loop`
phase 0 runs this command on an unstamped plan and then reads the stamp itself; telling it to `/clear`
and start the loop it is already running is noise. Invoked that way, end on the verdict and the stamp
and let the caller drive.

Don't soften it into "you may want to". A `❌` blocks `loop` and `phase`, but a bare
`/todd-coder impl` will still build it (see "Wiring this into the rest of the chain"), so a failed
plan nobody re-plans is a plan that can still ship.

**Then write the stamp**, unless `--report-only`. The last line of the plan comment, after a `---`:

```markdown
---
*Plan check: ✅ passed — 2026-08-13 · 43 checks · full mode · pass 1 · 5 auto-fixed*
```

With advisories, the verdict says so — a pass that carried notes forward must not read like a clean
one, and `impl` needs to see them:

```markdown
---
*Plan check: ✅ passed with 1 advisory — 2026-08-13 · 43 checks · full mode · pass 2 · 5 auto-fixed*

**⚪ Advisories** — impl-time notes, not blockers
- **[E9]** "an expired token is rejected" (slice 3) has no `# falsifies:`. Derive one before
  writing that test; the other 6 scenarios have theirs.
```

or, on failure — and on failure the stamp **carries the blockers themselves**, not just their ids:

```markdown
---
*Plan check: ❌ 2 blockers — 2026-08-13 · pass 2 of 3 · resolve with `/todd-plan FRG-1234`*

**🔴 Open blockers**
- **[C1]** `Axon.Rooms.reject_join/2` is named in slice 1, is not in the anchor file, and does
  not exist — no `reject_join` in `apps/axon/lib/axon/rooms.ex` at any arity.
- **[E11]** Slices 2 and 3 have no `@negative` or `@boundary` scenario (all 3 slices swept).
  ⚠️ Also fired on pass 1 — last pass's fix covered slice 2 only, and the scenario it added
  asserts a refusal the target can't observe.

**⚖️ Held by decision**
- **[B6]** The flag question in `Questions / Blockers` — Todd ruled it stays as written (pass 1).
```

**The `⚖️ Held by decision` block is Todd's, with one exception.** `/todd-plan` phase 0B writes it
when he rules on a 🔵. You **read** it (phase 0), you **carry it forward verbatim** into every stamp
you write, and you never raise what's in it. Dropping the block is how a settled question comes
back — it is the only reason B1 could be raised ten times.

The exception is **B1 over the ceiling**, which phase 2 tells you to decide yourself. Append that one
marked `(auto, pass N)`, so the block stays honest about who settled what:

```markdown
**⚖️ Held by decision**
- **[B1]** Section 1 is 640 words. Relocating it would be a re-plan, so the brief stays as
  written (auto, pass 1).
- **[D7]** Section 2 is 526 lines — Todd ruled it isn't a split (pass 2).
```

`(auto, …)` and Todd's rulings are read the same way by everything downstream: never re-raised, never
re-argued, carried forward verbatim. The marker exists so that a human reading the stamp can tell a
call Todd made from one you made for him.

**Carry the pass counter, always, on every verdict including a pass.** It's the only lap count either
command has, and a `✅` that loses it means the next failure starts over at pass 1.

**Why the full text and not just `see C1, E11, B5`:** the session that resolves these is a fresh
`/todd-plan` run that never saw your report. `C1` tells it a noun was ungrounded and not *which*
noun, so it would have to re-derive your finding from scratch — and a re-derivation that comes out
differently silently resolves the wrong thing. Linear is the only store both sessions are
guaranteed to share; the tmp directory is per-worktree and Todd may re-plan from anywhere. One line
per blocker, copied verbatim from the report, is what makes the loop work.

Write each blocker the way the report does: the check id in bold, then what's wrong, then what it
means. `/todd-plan` reads this block; keep it parseable by a human and an LLM, not by a regex.

**Rules for the stamp:**

- It goes **inside the existing comment**, at the end. Use `save_comment` with the comment id from
  phase 0 when the Linear MCP is available. If it is unavailable, deferred, or the write fails, run
  `linctl auth status`, then `linctl comment update <COMMENT_ID> --body "$(<CHECKED_PLAN_PATH)"`.
  `CHECKED_PLAN_PATH` is the checked local copy written below, and `COMMENT_ID` is the one plan
  comment selected in phase 0. Never create a new comment — a second comment on the ticket is the
  duplicate-plan bug you exist partly to catch. Re-read `linctl issue get $TICKET --json` and verify
  that this same comment still starts with `## 📋 Implementation Plan` and ends with the new stamp.
- Replace any previous stamp rather than appending a second one. One stamp, always the latest.
- **The `🔴 Open blockers` and `⚪ Advisories` blocks are part of the stamp**, so they get replaced
  wholesale too — and a passing run *removes* the blocker list. A plan that now passes must not still
  be carrying last run's blockers; `/todd-plan` would walk Todd through issues that are already fixed.
- **`⚖️ Held by decision` is the one block you never replace — you append to it.** Everything else in
  the stamp is this run's output; that block is the accumulated record of what has been settled, and
  it has to survive every run or the settled thing comes back. Copy it forward verbatim and keep the
  `(pass N)` markers so its age is visible. The **only** entry you add yourself is an over-ceiling B1,
  marked `(auto, pass N)`; everything else in there is Todd's and arrives via `/todd-plan` phase 0B.
- **You are not the only writer of this slot.** `/todd-plan` phase 0B, after resolving blockers,
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
  advisories, what you fixed, what you flagged. Stable filename, so a later session can open it
  without globbing for a timestamp. This is the long form of what the stamp summarizes —
  `/todd-plan` prefers it when it's there, because it also carries the 🔵 flags, which the stamp
  deliberately doesn't. Write it even under `--report-only`; a report-only run is exactly when Todd
  wants the findings kept without the plan being touched.

  **Prepend this run, don't overwrite the file.** It used to be overwritten every run, which is why
  the loop had no memory: at pass 9 on ENA-443 the only surviving evidence was pass 9, so every
  earlier finding — including the ones Todd had ruled on — read as new. Newest run at the top, under
  a header, so the file opens on the current state and the history is one scroll away:

  ```markdown
  # Plan check findings — FRG-1234

  ## Pass 3 — 2026-08-13 14:02 — ❌ 2 blockers
  …this run's report verbatim…

  ## Pass 2 — 2026-08-12 09:40 — ❌ 1 blocker
  …
  ```

  Before you write, **read the passes already in there.** A check id you're about to raise that
  appears in an earlier pass marked resolved is the repeat case — that's where the
  `⚠️ also fired on pass N` line comes from, and the file is the only place you can see it when the
  stamp has already been replaced.

---

## Wiring this into the rest of the chain

The stamp is a **live gate** in three places. Verified 2026-08-13 against the files, so don't spend a
run re-checking the wiring and don't report it as unwired — this section used to say the opposite and
had the checker telling Todd something false on every run.

| Call site | What it does with a `❌` |
|---|---|
| `commands/todd/loop.md:67` | **Stops the loop.** An unstamped plan makes it run this command with `--strict` inline first. |
| `skills/todd-coder/SKILL.md:103` | **Surfaces loudly but does not refuse.** "This gate surfaces, it doesn't refuse." |

Two consequences worth naming in a report rather than assuming Todd remembers:

- **A bare `/todd-coder impl <TICKET>` is the hole.** It's the one path that will build a plan this
  command failed. When you return a `❌`, say that `loop` is blocked and a direct `impl`
  is not.
- **`/todd-loop` runs `--strict`, and `/todd-plan` phase 7 doesn't.** So a plan you pass with 🔵
  flags or advisories can red-line the moment `/todd-loop` re-checks it — a guaranteed extra lap that
  this run had every piece of information to prevent. That's why the report marks a flag
  `⚠️ book severity 🔴`: it tells Todd which of today's flags are tomorrow's blockers, while he's
  still looking at the plan.

---

## Hard rules

- Never re-plan. You check the plan that exists; you don't write a better one.
- Never fix a 🔴. Fixing it hides that the plan was wrong, and your fix is a guess. (A1–A3 are not
  exceptions to this — they're 🟡 now, because a heading is a string with one right answer.)
- Never fix by deleting. Relocate, or report.
- Never add to the anchor file. Grounding is phase 2 of `/todd-plan`'s job, and re-grounding here
  would report as checked something that was never verified during planning. Reporting a C1 advisory
  with the `file:line` you found is not adding to it.
- **Never report one instance of a class you didn't sweep.** If E9 fires, every Scenario gets checked;
  if C1 fires, every noun does. A finding that names the first instance and stops is a finding that
  comes back next pass, and that is the loop.
- **Never re-raise anything in the `⚖️ Held by decision` block**, and never drop that block from a
  stamp you write. It's settled — by Todd, or by an `(auto, …)` call a previous run made. Re-arguing
  it is how B1 got raised ten times.
- **Never send brief length to Todd.** B1 resolves here in both bands: relocate under ~500 words,
  auto-hold over it. He gets told what you did, not asked what to do.
- **Never fail a plan for being thin when the finding is advisory-eligible** and inside its limits.
  One missing `# falsifies:` out of seven Scenarios is a note for the implementer, not a lap.
- **Never lose the pass counter.** It's the only lap count in the chain, and at pass 3 it's what stops
  a fourth.
- Never post a second comment. One plan comment, one stamp, inside it.
- Never report a pass in degraded mode without saying grounding went unchecked.
- Never change the first line of the plan comment, or either section heading.
- Never end a failed check without sending Todd to `/todd-plan <TICKET>`. A blocker list with no
  next command is where the loop stops. The one exception is pass 3, where the next step is a scoping
  question and not another lap.
- Never record a blocker as a bare check id. The stamp carries the finding in words, or the session
  that has to resolve it is guessing at what you meant.
- Never report the wiring as unwired, or the check count as 47. There are **43** checks, and all three
  stamp consumers are live.

## Failure handling

| Failure | Do |
|---|---|
| No plan comment | Report it, say which command should have written one, stop. |
| Multiple plan comments | 🔴 Report both ids and timestamps, name the one `impl` would read, stop. Todd picks. |
| Section 2 heading matches neither literal | 🟡 if the body tells you which mode it is — rewrite the heading and report it. 🔴 and stop only if it's ambiguous. |
| First line isn't `## 📋 Implementation Plan` | 🟡 rewrite that one line and keep checking. Say the phase-5 contract gate didn't run. |
| Anchor file missing | Degraded mode. Run every other group, say so in bold at the top of the report and in the stamp. |
| This is pass 3 and there are still blockers | Stop the loop. Name the one unresolved thing as a scoping question for Todd. Never start a fourth lap. |
| A check id fires that an earlier pass recorded as resolved | Report it as a resolution that didn't take, with what changed and why it didn't hold. Never file it as a fresh finding. |
| The stamp carries a `⚖️ Held by decision` block | Read it, carry it forward verbatim, and raise nothing in it — Todd's rulings and `(auto, …)` entries alike. |
| Section 1 runs past ~500 words | Your call, not Todd's. The brief stays as written; append the `(auto, pass N)` entry to `⚖️ Held by decision` and say once in the report that it reads like a brief for more than one ticket. |
| An anchor's line number is off but the symbol is in the file | 🟡. Correct the number. Not a blocker — the grounding was done. |
| Ticket not found or MCP truncating | Fall back to `linctl issue get $TICKET --json`. If that also fails, run groups A–D and skip E1 — you can't check coverage against a ticket you can't read. Say which group you skipped. |
| Plan contradicted by the code | 🔴 Report it as a finding. Don't correct the plan; the correction may change the approach, which is Todd's call. |
| `save_comment` is unavailable or fails | Fall back to `linctl auth status` then `linctl comment update <COMMENT_ID> --body "$(<CHECKED_PLAN_PATH)"`; re-read the issue and verify the one plan comment carries the new stamp. Report the local path only if both writes fail. |

Now check $ARGUMENTS.

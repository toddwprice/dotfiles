# Plan approval walkthrough

This is a manager review, not a reading of the plan. Explain the design in plain language, expose
the calls you made, and give Todd a real chance to change them. Do not dump the whole plan and ask
"thoughts?" at the end. Move through the checkpoints below and wait for his answer at each one.
For a small plan, tightly related slices can share a checkpoint; independent decisions cannot.

## Checkpoint 1 — Non-test file map

Start here, before any test file, Scenario, fixture, or verification command. Show every non-test
file that will be created or modified, including migrations, schemas, config, generated artifacts,
scripts, CI files, and documentation. Keep test targets out of this view even though they remain in
`Files to Modify` in the plan.

Use this shape in chat:

```markdown
Non-test files
| Change | File | Why this file changes | Responsibility after the change |
|---|---|---|---|
| Modify | `path/to/file` | [the behavior entering or leaving this file] | [what this file owns afterward] |
| Create | `path/to/new_file` | [why a new file is warranted] | [the one job the new file owns] |
```

For each row, explain what the file does today and why this plan puts the change there. If a file
could reasonably live in two places, say which alternative you rejected and why. If there are no
non-test changes, say that directly and explain why the ticket is test-only.

Then ask one concrete scope question and **wait**:

> Does this file map match the boundary you expect, or is there a responsibility you want handled
> somewhere else?

Do not continue because Todd acknowledged the message. Continue when his answer shows that the file
boundary is understood and acceptable. If his response is ambiguous, name the part you are unsure
he agrees with and ask about that part.

## Checkpoint 2 — Walk the behavior through slice by slice

Once the file map is settled, take the numbered `Approach` slices in order. For each slice, explain:

1. What happens today.
2. What happens after the change, from the caller's or user's point of view.
3. How control or data moves through the non-test files from checkpoint 1.
4. The decisions made in this slice, the credible alternative, why you chose this one, and how hard
   it would be to reverse.
5. The main failure mode, invariant, and explicit out-of-scope behavior.

Use a concrete example when an abstraction hides the behavior: one request, record, event, or user
action moving through the path. Do not turn the walkthrough into a line-by-line code tour.

After each independent slice or decision, ask whether Todd is OK with **that decision and its
tradeoff**, then wait. Do not quiz him or ask him to repeat the design back. Ask a comprehension
question only when his response suggests the mental model is unclear or when two interpretations
would lead to different implementations.

## Checkpoint 3 — Decision ledger

Now collect the calls in one place. Include every `Decisions` entry plus any choice implied by file
placement, ownership, data shape, error behavior, compatibility, rollout, or deferral.

```markdown
Decisions to approve
| Decision | Why | Alternative not taken | Reversal cost | Source |
|---|---|---|---|---|
| [functional decision] | [evidence] | [credible alternative] | Low/Medium/High — [why] | Ticket / precedent / assumed / Todd |
```

Do not hide a default in the walkthrough prose. If the codebase precedent supports only one answer,
name it as an assumed decision and cite the precedent. If two reasonable answers produce different
plans, ask Todd to choose. Any answer he gives becomes a `Decisions` entry marked
`(Todd, YYYY-MM-DD)`; remove the corresponding question or assumption.

Ask whether he wants to change any decision before you move to tests, then wait.

## Checkpoint 4 — Tests and proof

Only after the non-test design is accepted, explain the test work. Do not read the Gherkin block
back verbatim. Map each behavior and invariant to:

- the test file that will prove it;
- whether that test is new or extends existing coverage;
- the implementation mistake that makes it fail;
- the verification command; and
- what a green run still does not prove.

Call out the negative and boundary coverage by slice. Ask:

> Does this prove the behavior you care about, or is there another failure mode you expect us to
> cover?

Wait for the answer. Add missing coverage to the plan before asking for final approval.

## Final approval

Summarize the settled result in five short lines: non-test files, slices, decisions Todd changed or
explicitly accepted, top risks, and test/verification coverage. Then ask exactly:

> Do you approve this plan for posting and cold check, or what do you want changed?

Approval must be explicit: "approved", "looks good", "go ahead", or an equally clear instruction.
An answer to the last technical question is not approval. If Todd wants a change:

1. Update the plan, anchors, counts, coverage, and local draft.
2. Run phase 5's contract gate again.
3. Walk through the changed file rows, slices, decisions, risks, and test coverage. Summarize what did
   not change; do not make him review unchanged material again.
4. Ask for approval again.

For a phase 0B revision, show the full current non-test file map first, then focus the rest of the
walkthrough on the blocker resolutions and their effects. A previously approved plan does not grant
approval to a revised body.

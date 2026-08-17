---
name: axon-fixup
description: >
  Use when verifying the axon app (`apps/axon` — the Elixir/Phoenix GraphQL backend) is clean, before
  pushing, opening a PR, or handing work off — phrasings like "verify axon", "run the axon checks",
  "axon fixup", "is axon green", "did I break axon", "check axon before I push", or after any change
  under `apps/axon`. Covers compile-with-warnings-as-errors, format, credo, tests, the `assets/`
  frontend gate, and `apps/axon/AGENTS.md` compliance as one ordered gate. Prefer this over the
  generic `axon:axon-verify` skill for dscout work.
---

Run the following verification steps for the axon application, in order. Stop and report if any step fails.

All commands should be run from the `apps/axon` directory.

## 1. Compile with warnings as errors

```bash
cd apps/axon && mix compile --warnings-as-errors
```

## 2. Format check (read-only)

```bash
cd apps/axon && mix format --check-formatted
```

## 3. Credo static analysis

```bash
cd apps/axon && mix credo
```

## 4. Run tests

```bash
cd apps/axon && mix test
```

## 5. Frontend verification (if assets/ changed)

If any files under `apps/axon/assets/` were modified, run:

```bash
cd apps/axon && mix assets.lint && mix assets.typecheck && mix assets.test
```

Skip this step if no frontend files changed.

## 6. AGENTS.md compliance

Read `apps/axon/AGENTS.md` (or `apps/axon/CLAUDE.md`) and verify that all changes in the current branch follow the rules documented there. Pay particular attention to:

- Structured logging (map-based Logger calls, no string interpolation)
- Keyword lists for optional params (`opts \\ []`) with `Keyword.get/3`
- Atom keys over string keys
- Factory patterns in tests (`build(:entity)` / `build(:entity, opts)`, not raw maps or `Factory.some_function()`)
- Never use test modules (`Axon.Factory`, `test/support/`) in production code under `lib/`
- FollowerRepo for read-heavy queries; primary Repo for writes and consistency-critical reads
- Oban workers: required args in `args_schema`, atom keys in args maps
- Safe migration patterns (if migrations are present — check `safe_ecto_migrations/README.md`)
- Test modules include `async: true` when safe

Report a summary of all steps: passed, failed, or warnings.

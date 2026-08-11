---
name: copy-data
description: >
  Copy a dscout-owned (account_id=2) project (optionally authoring-only, dropping
  submissions/responses), single mission, or the guided template library out of PROD into a local
  or staging Postgres for test data — read-only prod access via the snowflake-eng MCP, no direct
  prod DB connection. Use WHENEVER Todd wants realistic test data in staging/local — phrasings like
  "copy this account/project into staging", "seed staging with a real project", "pull mission X into
  my local db", "copy the template library to staging", "get better test data in staging", "run
  copy-data", or points at a prod project/mission URL to clone. Run with no scope flag to start an
  interactive wizard (from/to/scope/id/grant prompts). Wraps the `.claude/commands/copy-data/` ETL
  tool (resolve → target-first existence check → gate → manifest → extract → transform → load → seed
  → smoke) and enforces its non-negotiable safety gate + seeds.
allowed-tools: Bash(python3:*), Bash(psql:*), Bash(bash:*), Bash(mktemp:*), Bash(cat:*), Read, Grep, Glob
---

# Copy an account / project / mission / templates from prod → staging or local

This wraps the ENA ETL tool that builds realistic test data by copying **dscout-owned
(`account_id=2`)** content out of prod. It reads prod **read-only via the `dscout-data-mcp:snowflake-eng`
MCP** (`dscout-raw-sql`) — never a direct prod DB connection — transforms/synthesizes, and loads into
a target Postgres.

Run `/copy-data` with **no scope flag** and it starts an **interactive wizard** (from/to/scope/id/grant
prompts) that assembles the equivalent invocation and confirms before doing anything. Before touching
prod it does a **target-first existence check**: if the requested project/mission/templates scope is
already present in the target, it skips the copy entirely and just grants access. Project mode has an
authoring-only option, `--no-submissions`, that drops participant submissions/responses from the copy.

> **Where the tool lives.** The scripts are in the monorepo at
> `.claude/commands/copy-data/` (`resolve.py`, `manifest.py`, `extract.py`,
> `transform.py`, `load.sh`, `seed_membership.sh`, `seed_template_consumers.sh`, `tests/`). They
> merged to **`main`** and are tracked there as of 2026-08 — run from any current worktree, no
> branch switching needed. (They previously lived on
> `ena-292-create-better-test-data-in-staging`; that worktree is gone — ignore any older
> instruction to `cd` there.) There's also a repo slash-command wrapper `.claude/commands/copy-data.md`;
> this skill is the portable, always-discoverable front door to the same workflow.

## Prerequisites (check first, fail loud)

- **snowflake-eng MCP authed** for prod reads (`dscout-raw-sql`; token ~24h — re-auth via `/mcp`).
  Not needed when using `--source` Postgres.
- **`psql`/libpq** for `--source` reads and all loads/seeds.
- **Target PG reachable with an account-2 team already seeded** (`mission_groups.team_id` is
  NOT NULL, so a team owned by account 2 must exist), and — for seeds — the target account + user
  must exist. Default target `postgresql://dscout:dscout@localhost:5432/dscout_development`; local
  app creds `dev@dscout.com` / `Password1234*`.

## The one rule you never skip

**`account_id = 2` safety gate.** Before *any* prod extract, the tool verifies the project (or the
mission's parent project) is owned by `account_id = 2`. No row or `≠ 2` → **refuse and stop**. This
is what keeps a real customer account from ever being copied. It is skipped **only** with `--source`
(a staging/local Postgres is dscout-owned by construction), and is a no-op in `--templates` mode
(ownership is enforced inside the subgraph via `--owner-account-id 2`). Never work around it.

## The three modes (mutually exclusive)

| Mode | Flag | Scopes |
|------|------|--------|
| **Project** | `--project <id\|url>` [`--no-submissions`] | full subgraph: mission_groups → missions → screeners → parts → questions → stims → submissions → responses; add `--no-submissions` for authoring-only (drops submissions/responses) |
| **Mission** | `--mission <id\|url>` | one mission's authoring subgraph only (mission_groups seed-if-absent → missions → parts → questions → stims; no screeners/submissions/responses); parent project resolved from the mission for the gate |
| **Templates** | `--templates` | 7-table guided-template library (study_templates → screeners → questions/stims/question_stims/selected_target_attributes/template_ai_restrictions); `study_template_consumers` is **seeded, not copied** |

## Source: prod (default) vs `--source` Postgres

- **Default** = prod via the snowflake-eng MCP (`dscout-raw-sql`). Gate + volume guard apply.
- **`--source <dsn>`** = read from a Postgres (e.g. staging) via `extract.py from-pg` (`psql \copy …
  TO STDOUT`); manifest renders with `--dialect postgres`; gate + volume guard are skipped.

## Run it (end-to-end)

Let `TOOL=.claude/commands/copy-data` and `WORK=$(mktemp -d)`.

1. **Resolve** the request into a plan:
   ```bash
   python3 $TOOL/resolve.py <--project|--mission|--templates …> [--source <dsn>] [--target <dsn>] [--dry-run]
   # → JSON {mode, project_id, mission_id, target, source, dry_run, keep_temp}
   ```
2. **Gate** — run the `account_id=2` ownership check via `dscout-raw-sql` (skip if `source` set). Stop on failure.
3. **Dry-run** — if `dry_run`, print the plan and stop here.
4. **Manifest (plan the tables)**:
   ```bash
   python3 $TOOL/manifest.py --project <id>          # project mode
   python3 $TOOL/manifest.py --mission --mission-id <mid> --project <pid>   # mission mode
   python3 $TOOL/manifest.py --templates --owner-account-id 2               # templates mode
   # add --dialect postgres when using --source
   ```
   `manifest.py` also emits the specs the loader needs: `--order`, `--reparent-spec`, `--null-fks-spec`,
   and (mission mode) `--skip-existing-spec`.
5. **Extract** per table in dependency order:
   ```bash
   # prod (Snowflake via MCP): guard on row count, then convert the jsonv2 result to TSV
   python3 $TOOL/extract.py check-volume <count>          # exits non-zero if > threshold (see below)
   python3 $TOOL/extract.py to-tsv <result.json> $WORK/<t>.raw.tsv
   # --source Postgres:
   python3 $TOOL/extract.py from-pg "<dsn>" "<select_sql>" $WORK/<t>.raw.tsv
   ```
6. **Transform** (un-Hevo + PII synthesis) each table:
   ```bash
   python3 $TOOL/transform.py $WORK/<t>.raw.tsv $WORK/<t>.tsv
   ```
7. **Load** atomically (discover the account-2 `TEAM_ID` first):
   ```bash
   $TOOL/load.sh --work "$WORK" --tables "$(… manifest --order)" --target "$target" \
     --account-id 2 --creator-id 1 \
     --reparent "$(… manifest --reparent-spec … --team-id "$TEAM_ID")" \
     --null-fks "$(… manifest --null-fks-spec)" \
     [--skip-existing "$(… manifest --skip-existing-spec --mission)"]   # mission mode
   ```
8. **Seed (mandatory — do not skip):**
   ```bash
   $TOOL/seed_membership.sh --target "$target" --project-id <id> --user-id <uid>   # project/mission
   $TOOL/seed_template_consumers.sh --target "$target" --account-id 2              # templates
   ```
   Both are idempotent (`WHERE NOT EXISTS`). **Skipping breaks the copy silently:** without
   `memberships`, efflux 404s the project (invisible in the UI); without `study_template_consumers`,
   copied templates have no consumer row and are invisible to the account.
9. **Smoke-verify:**
   ```bash
   $TOOL/tests/smoke.sh --work "$WORK" --project <id> [--target <dsn>] [--seed-membership-user <uid>]
   ```

## Volume guard + `--bulk` (large extracts)

`extract.py check-volume <count>` exits non-zero when a table's row count exceeds
`DEFAULT_VOLUME_THRESHOLD` (50,000; override `--threshold N`) — streaming that many rows back through
the MCP conversation is the wrong path. The intended escape hatch is a `--bulk` mode (mode C), which
is **not yet implemented** (tracked as **ENA-385**). Until it lands: narrow the scope (a smaller
project/mission), or use `--source` from a Postgres that already has the data. `from-pg` has no guard
(it writes straight to a file).

## Tests

- Transform units (no DB): `python3 -m unittest discover -s $TOOL/tests`
- Load / seeds (throwaway local PG): `$TOOL/tests/test_load.sh`, `test_seed_membership.sh`, `test_seed_template_consumers.sh`
- E2E: `$TOOL/tests/smoke.sh` — needs a `$WORK` dir of pre-extracted `*.raw.tsv` (extract is a live
  MCP session, not scriptable) and a reachable target PG with an account-2 team.

## Notes

- `--dialect` (`snowflake`|`postgres`) and `--owner-account-id` are **`manifest.py`** flags only; the
  command derives them from the source/mode — don't pass them to `resolve.py`.
- Keep the `$WORK` dir until the smoke passes (`resolve.py` exposes `keep_temp`); it holds the
  extracted/transformed TSVs you'd otherwise have to re-pull from prod.
- Related: [staging-setup] for logging into staging + the older `copy-templates-cross-env`; this skill
  supersedes that for prod→staging/local copies. See ENA-362..367 / 388 / 400 for the build history.

---
name: staging-setup
description: "Use when Todd needs a working login into a named dscout staging env (staging-N, e.g. staging-19), needs to create/seed a researcher or staff user there, can't sign in to staging-N.app.dscout.com, or wants to copy specific DB tables/templates/a subset (e.g. study_templates, template_ai_restrictions) from a staging env's Postgres into local dscout_development. Triggers: \"get me a login for staging-X\", \"create a user on staging-N\", \"reset my staging password\", \"copy table Y from staging into local postgres\", \"seed templates from staging-19 to my localhost\", \"I'm tunneled into staging-N\"."
disable-model-invocation: true
---

# staging-setup

Two recurring jobs against dscout staging environments (`staging-0` … `staging-21`, hosted on EC2 reached via AWS SSM):

- **Job A — Login:** get a working sign-in for `staging-N.app.dscout.com`, either for Todd's own user or a brand-new named user.
- **Job B — Copy data:** copy specific tables / a template subset from a staging Postgres into local `dscout_development`.

Both reach staging through an **SSM tunnel or remote eval** — there is no direct network path. All commands run from the dscout monorepo (`/Users/toddprice/dscout-wt/main` or any worktree).

## Critical safety rules

- **State-changing commands hit shared, multi-user environments.** Confirm the exact target env (`staging-N`) and the exact action with Todd before running anything that writes (creating users, resetting passwords, mutating account `idp_type`, importing rows). Never guess the env number.
- **Never hardcode or commit secrets.** Connection strings, passwords, and the `application` DB password are session-scoped — Todd pastes them per run; do not store them in files, memory, or commits.
- **AWS SSO first.** `bin/ssm` / `bin/env_config` require an active SSO session (`bin/aws-login`); default profile is `dev` for staging, `prod` for prod.
- Prefer `--account-id` scoped to a sandbox/personal account over the shared internal account `2` when copying, so you don't pollute everyone's library.

## Prerequisites (both jobs)

```bash
bin/aws-login                 # AWS SSO + ECR login (re-run if sessions expired)
which psql                    # libpq client on PATH (Postgres 14+; 17 tested)
```

---

## Job A — Login to staging-N

dscout auth identity is **per-account** via `accounts.idp_type` (one of `dscout`, `google_oauth2`, `saml`, `google_or_dscout`, `saml_or_dscout`). **Staff users** (`users.staff = true`) resolve their idp from `accounts.id = 2` (the dscout-internal account), bypassing their own account's setting. Verified: `apps/axon/lib/axon/accounts/account.ex` (`@idp_types`), `apps/axon/lib/axon/accounts/account_query.ex` (`idp_type_for_user`), `apps/axon/lib/axon/auth.ex` (`sign_in/3` runs six checks: fetch → locked → deprovisioned → required_sso → password → 2FA).

The remote eval seam is `bin/ssm staging-N axon_eval '<elixir>'` (wraps `bin/axon eval`, non-interactive) — verified in `bin/ssm` usage. Use it to run changesets / `Axon.E2E.setup_account/1` / `Axon.Auth.sign_in` against the live box.

### A1. Diagnose before resetting (read the actual error)

Don't blind-reset. Ask which check is failing:

```bash
bin/ssm staging-N axon_eval 'Axon.Auth.sign_in({"todd.price@dscout.com", "the-password-you-tried"}, %{original_ip: "127.0.0.1"}, nil) |> inspect() |> IO.puts()'
```

- `{:error, {:sso_required, _}}` → it's an IDP problem (Job A3), not a password problem.
- `:invalid_password` / locked / 2FA → handle that specific check.

### A2. Reset / set password for an existing user (email+password login)

The staff-bypass changeset path (no current-password, no reset token, bcrypt-hashed for you) is `Axon.Accounts.Users.update_user_by_staff/3` → `User.staff_update_changeset` → `staff_change_password_changeset`. Verified in `apps/axon/lib/axon/accounts/users.ex:690` and `apps/axon/lib/axon/accounts/user.ex:509`.

<!-- TODO: confirm with Todd the exact `update_user_by_staff/3` arg shape + acting-staff user he wants to run live (args map keys, opts). The function exists and is the right path; the precise one-liner he prefers (changeset vs direct Repo.update_all of encrypted_password) was discussed but not finalized in transcript. -->

### A3. Enable email/password login when the account is SSO/Google-only

If the restored staging DB has `dscout.com`'s account set to `google_oauth2` (or you're staff and account `2` is google-only), email+password sign-in is blocked by `check_required_sso`. Options, in order of least blast radius:

1. **Become staff + rely on account 2** — staff idp resolves from account `2`; set account 2's `idp_type` to a value that permits password login (`google_or_dscout` allows both). Confirm scope with Todd first (account 2 is shared internal).
2. **Use Google OAuth as-is** — if `GOOGLE_CLIENT_ID`/`GOOGLE_CLIENT_SECRET` are wired for that staging env (`apps/axon/config/runtime.exs`) and the env's OAuth callback is registered, just sign in with Google; no DB change needed. Whether each staging env has working Google OAuth is env-specific.

<!-- TODO: confirm with Todd the exact mutation he wants for the SSO case (which account id, target idp_type value), and whether staging Google OAuth callbacks are registered per-env — these were explored but the env-by-env answer wasn't pinned down. -->

### A4. Create a brand-new account + user (fresh sandbox)

`Axon.E2E.setup_account/1` builds the whole subgraph in one `Ecto.Multi`: account row, owner user with encrypted password, `primary_account_id`, license, features, 2FA disabled, **and flips `staff: true`** via `make_staff_step`. Verified: `apps/axon/lib/axon/e2e.ex:649` (`setup_account/1`), `:951` (`make_staff_step` sets `staff: true, primary_account_id: account.id`); param `:owner_email` defaults `e2e_owner@dscout.com` (`e2e.ex:628`). Also exposed as `POST /e2e/setup_account` (router `apps/axon/lib/web/router.ex:800`) but gated by `config :axon, :e2e_endpoints_enabled` — only enabled where that flag is true.

```bash
bin/ssm staging-N axon_eval 'Axon.E2E.setup_account(%{account_name: "Todd Sandbox", owner_email: "todd.price@dscout.com", password: "<choose>"}) |> inspect() |> IO.puts()'
```

<!-- TODO: confirm with Todd the full accepted param map for setup_account/1 (read apps/axon/lib/axon/e2e.ex:628-655 for the get_param keys) and his preferred password — the key names beyond owner_email weren't all enumerated. -->

### A5. After login works — record the IDs you'll need for Job B

```bash
bin/ssm staging-N psql   # then:
# SELECT id, primary_account_id, staff FROM users WHERE email = 'todd.price@dscout.com';
```
Keep that user id (`--creator-id`) and account id (`--account-id`) — Job B reparents copied rows onto them. On staging, `primary_account_id = 2` means the shared dscout-internal account.

---

## Job B — Copy tables / templates from staging into local Postgres

### B1. Open the tunnel to the staging DB

```bash
bin/ssm staging-N tunnel
```
Verified (`bin/ssm`): this port-forwards the cluster DB to **`localhost:1NNNN`** where `NNNN` is the zero-padded cluster number — staging-19 → `10019`, staging-11 → `10011` — and **prints the full `postgres://<user>:<pass>@localhost:1NNNN/dscout_staging` URI** on connect. The DB user is `application`. Leave the tunnel running in its own terminal; it can drop mid-run (just re-run). Alternatively `bin/ssm staging-N psql` runs psql on the box directly (no local tunnel) for quick reads.

Local target DSN (standard dev seed): `postgresql://dscout:dscout@localhost:5432/dscout_development`.

### B2a. Copy a full TEMPLATE subgraph (the common case)

A "template" is a subgraph (study_templates → screeners → questions/ordinals/stims/question_stims, selected_target_attributes, template_ai_restrictions, study_template_consumers), not one row. Use the purpose-built, schema-drift-aware tool — **verified to exist** at:

```
/Users/toddprice/dscout-knowledge/scripts/tools/copy-templates-cross-env/run.sh   (+ README.md)
```

```bash
cd /Users/toddprice/dscout-knowledge/scripts/tools/copy-templates-cross-env

# All templates that have template_ai_restrictions, reparented to local account 2 / user 1:
./run.sh --source 'postgres://application:<pass>@localhost:10019/dscout_staging'

# A specific subset, scoped to a chosen account/user:
./run.sh --source "$STAGING_DSN" --screener-ids '15673,15674,15732' \
  --account-id <id> --creator-id <id>
```

Flags (from README): `--source` (required, the tunneled env), `--target` (default local `dscout_development`), `--account-id` (default `2`), `--creator-id` (default `1`), `--screener-ids <csv>` (default = all w/ restrictions), `--keep-temp`. It runs atomically (`ON_ERROR_STOP`, one transaction), preserves ids for the core tables (so **re-running the same templates aborts — not an upsert**), remaps `target_attribute_id` across the per-env catalog, computes common columns to survive schema drift, and creates an account-scoped `study_template_consumers` row so the template is actually **visible** to your login. It deliberately excludes runtime/analysis data (submissions, payouts, ai_analysis_*, videos). Read the README for the full subgraph diagram and the three non-obvious correctness notes.

This same tool also runs **local → staging** (the source/target are just DSNs) — e.g. seeding template 150 from localhost to staging-11. Confirm direction and target with Todd before a staging-write run.

### B2b. Copy an arbitrary table / subset (no dedicated script)

For tables outside the template subgraph, do a targeted `psql | psql` pipe. Source rows reference accounts/users/projects that won't exist locally, so **always reparent FK columns** to a local account/user and use **explicit column lists** (never positional `SELECT *`) because staging tables have schema drift vs local.

```bash
# Example shape — adapt columns + WHERE to the actual table:
psql "$STAGING_DSN" -At -F$'\t' \
  -c "\copy (SELECT col_a, col_b, ... FROM the_table WHERE <filter>) TO STDOUT" \
  | psql "$LOCAL_DSN" -v ON_ERROR_STOP=1 \
      -c "\copy the_table (col_a, col_b, ...) FROM STDIN"
```

Wrap multi-table loads in a single `BEGIN; … COMMIT;` with `ON_ERROR_STOP=1` so a FK/PK failure rolls back cleanly. If you find yourself copying the same non-template table repeatedly, propose promoting it into a reusable script alongside `copy-templates-cross-env`.

<!-- TODO: confirm with Todd whether he wants a generic per-table copy helper built (mirroring copy-templates-cross-env's fill-defaults / common-column approach) — so far only the template subgraph has a dedicated tool. -->

### B3. Verify

```bash
psql "$LOCAL_DSN" -At -F'|' -c "SELECT count(*) FROM <table> WHERE <your filter>;"
# Templates should then appear in the library at /efflux/home/<account_id>/templates
```

---

## Local-dev credential convention (for verifying the result in a browser)

Default seed user from `bin/dscout_db restore` (LOCAL ONLY — never reuse anywhere):

- Email: `dev@dscout.com`  ·  Password: `Password1234*`  ·  Sign-in: `http://localhost:5000/auth/sign_in`
- That user is the copy default `--creator-id 1`; account `2` is "dscout-internal".

## Quick reference

| Need | Command |
|------|---------|
| AWS SSO | `bin/aws-login` |
| Diagnose staging login | `bin/ssm staging-N axon_eval 'Axon.Auth.sign_in({email,pw}, %{original_ip: "127.0.0.1"}, nil)'` |
| Create staging account+user | `bin/ssm staging-N axon_eval 'Axon.E2E.setup_account(%{...})'` |
| Reset password (staff path) | `update_user_by_staff/3` via `axon_eval` (see A2) |
| Get user/account ids | `bin/ssm staging-N psql` → `SELECT id, primary_account_id FROM users WHERE email=...` |
| Open staging DB tunnel | `bin/ssm staging-N tunnel` → `localhost:1NNNN` |
| Copy template subgraph | `cd /Users/toddprice/dscout-knowledge/scripts/tools/copy-templates-cross-env && ./run.sh --source <DSN>` |
| Per-staging Astro Eppo key | `bin/env_config -a astro staging-N set_key EPPO_SDK_KEY <val>` |

## Common mistakes

- **Copied template invisible in the UI** → no `study_template_consumers` row matching your login's account (listing query INNER JOINs consumers). The copy tool creates one for `--account-id`; for manual copies add it yourself.
- **Re-running the copy aborts** → core-table ids are preserved, not upserted. Use fresh templates or clear the prior rows first.
- **Eppo-gated feature works on FE but not in DYS on staging** → staging *Astro* needs its own `EPPO_SDK_KEY` (separate from Axon), or all flags silently default off. Fix: `bin/env_config -a astro staging-N set_key EPPO_SDK_KEY <val>`.
- **"new password isn't working"** → diagnose with `Axon.Auth.sign_in` first (A1); it may be `:sso_required`, locked, or 2FA — not the password.
- **Tunnel dropped mid-copy** → the copy script sets `statement_timeout` so it fails fast instead of hanging; re-open the tunnel and re-run.

## Open questions to confirm with Todd (see inline TODOs)

1. Exact live one-liner for A2 password reset (`update_user_by_staff/3` arg map + acting staff user, vs direct `Repo.update_all` of `encrypted_password`).
2. SSO case (A3): which account id + target `idp_type`, and whether each staging env has working Google OAuth callbacks.
3. Full accepted param map for `Axon.E2E.setup_account/1` (read `apps/axon/lib/axon/e2e.ex:628-655`).
4. Whether to build a generic per-table copy helper (B2b) beyond the template subgraph tool.

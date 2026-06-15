---
name: eppo-flag
description: "Use when Todd wants to turn an Eppo feature flag on/off or target/untarget a user/account for an env (staging-N, prod), or when a flag is set but resolving wrong (governed-users, llm_routing_enabled, eyd_single_mission_supervisor, per-type study flags) — works on the FE/home page but not in DYS/dscript, treats a governed user as ungoverned, silently defaults OFF, is_governed=false unexpectedly, or you need to verify a flag actually resolved for a subject end-to-end."
disable-model-invocation: true
---

# eppo-flag

Toggle and (critically) **verify** Eppo feature flags for the dscout platform. The verify half is load-bearing: a flag can be set correctly in Eppo yet resolve OFF because an env's `EPPO_SDK_KEY` is missing — silently, with no error.

**SAFETY: this skill mutates real feature-flag state.** Never toggle/target a prod or staging flag without Todd's explicit go-ahead naming the flag + env. Read first, confirm, then mutate.

## Two halves

- **(A) Toggle / target** a flag for an env — scriptable via the `eppo-flags` CLI, or via the Eppo UI.
- **(B) Verify** it resolves — Eppo state + the per-env `EPPO_SDK_KEY` wiring + the actual resolved value for the target subject.

## (A) Toggle / target — `eppo-flags` CLI (scriptable)

Run from `apps/astro`; needs `EPPO_MANAGEMENT_API_KEY` in `apps/astro/.env`. The `<environment>` is an Eppo env *name* (run `envs` to list); it is NOT the SDK key.

```bash
cd apps/astro
uv run eppo-flags list                                   # all flags + per-env on/off
uv run eppo-flags get governed-users                     # detail incl. per-env targeting rules
uv run eppo-flags envs                                   # list Eppo env names
uv run eppo-flags enable  <key> <environment>            # match-all ON
uv run eppo-flags disable <key> <environment>            # OFF
uv run eppo-flags target  <key> <environment> --user-ids "429003" [--account-ids "13598"]
uv run eppo-flags set-value <key> <environment> <variation>   # STRING flags only
```

- `target` **replaces** the env's rule list (idempotent, not additive). Re-running with a new id set overwrites. At least one of `--user-ids`/`--account-ids` required; both → two rules OR'd. `target` also enables the flag if it wasn't.
- Subject attributes are camelCase (`userId`, `accountId`) — must match `app/core/features/eppo_client.py::_build_subject_attributes`.
- `enable`/`target` are idempotent against an already-on env (the CLI guards the "already ON" 400).

CLI internals: `apps/astro/agent_cli/eppo/cli.py` + `api_client.py` (Management API `https://eppo.cloud/api/v1`, `X-Eppo-Token` header).

### Eppo UI (Todd's saved link shape)

`https://eppo.cloud/configuration/feature-flags/<flag_id>/targeting/<base64_env_id>`
<!-- TODO: confirm with Todd — the only verified example is staging-19 governed-users: flag 173206, env token RW52aXJvbm1lbnQ6MTM1NA== . There is no per-env URL lookup helper; ask Todd for the link or use the CLI to find the flag/env. -->

## (B) Verify resolution — the part Todd keeps getting burned on

Setting the flag in Eppo is only step 1. A subject resolves the flag only if the consuming app initialized the Eppo SDK, which requires that app's **own** `EPPO_SDK_KEY` for that env.

### B1 — Eppo says the subject matches

```bash
cd apps/astro && uv run eppo-flags get <key>   # confirm env ENABLED + the userId/accountId rule
```

### B2 — Is `EPPO_SDK_KEY` set for THIS env's Astro AND Axon? (the gotcha)

dscout runs a **separate Eppo environment per staging env** (staging-0…21), and the FE + BE init Eppo with their **own** key. A flag only behaves end-to-end if every consuming deploy has a key for that env.

- **Astro (Python SDK, server-side)** reads `EPPO_SDK_KEY` and inits at import (`app/core/features/__init__.py:28`, web) + `app/core/worker/process_manager.py:74` (worker). If unset, `initialize_eppo` logs `"Eppo not configured (EPPO_SDK_KEY not set), skipping initialization"` at INFO, `_eppo_client` stays `None`, and **every flag returns its hardcoded default** (`governed-users` → `False`) with no error. `governance.py:24` `GOVERNED_USERS_FLAG = "governed-users"`, default `False`.
- **Axon → dendra (JS SDK, client-side)**: Axon does NOT evaluate Eppo in Elixir. It reads `EPPO_SDK_KEY` (`apps/axon/config/runtime.exs:355`) and ships it to the browser as `eppo_sdk_key` runtime config (`apps/axon/lib/web/views/dendra_view.ex`). Dendra evaluates flags in-browser (`apps/axon/assets/shared/eppo/EppoProvider.tsx:39`, `hooks.ts` `getBooleanAssignment`). So a missing Astro key breaks DYS/dscript while the home-page/FE flag still looks correct — the classic "works on the FE but not in DYS" split.

**Check + fix per-env (config, not code):**
```bash
bin/env_config -a astro <env> get_key EPPO_SDK_KEY     # e.g. <env> = staging-19
bin/env_config -a axon  <env> get_key EPPO_SDK_KEY
bin/env_config -a astro <env> set_key EPPO_SDK_KEY <value>   # only with Todd's go-ahead
```
(`bin/env_config` defaults to app `axon`; `-a astro` targets the Astro secret. Staging uses the `dev` SSO profile, prod uses `prod`.)

To confirm a deploy actually initialized Eppo, look in Datadog for `"Eppo client initialized successfully"` vs `"Eppo not configured (EPPO_SDK_KEY not set)"` for that env's astro service (GRA-978 saw staging-19 astro with 0 inits + 50× not-set/24h while prod had 50 inits).

### B3 — Did it resolve TRUE for the target subject?

- **DYS/dscript (governed-users):** `is_governed` is sampled once at session creation and persisted on `SupervisorState.is_governed` (immutable for the session — a mid-session flag flip does NOT retroactively govern an in-flight session; start a new session). Verify via the Braintrust trace for the session: `is_governed: true` on SupervisorState and progression rooted at `current_step_id: "select_templates"` means it resolved. `is_governed: false` for a subject Eppo says matches ⇒ B2 (missing Astro key) is the usual cause.
- **Eppo assignment log (authoritative):** in Datadog, the Eppo assignment for `<flag> → variation: true` for the subject (userId) at session-create time confirms resolution independent of trace state.

### Verify recipe (copy/paste skeleton)
```bash
cd apps/astro
uv run eppo-flags get <key>                              # 1. Eppo: env ENABLED + subject rule present
bin/env_config -a astro <env> get_key EPPO_SDK_KEY       # 2. Astro key present for THIS env?
bin/env_config -a axon  <env> get_key EPPO_SDK_KEY       # 2. Axon/FE key present for THIS env?
# 3. Datadog: "Eppo client initialized successfully" for <env> astro; assignment log shows variation:true for the subject
# 4. (DYS) New session → Braintrust trace: is_governed:true, current_step_id:"select_templates"
```

## Common mistakes

| Mistake | Reality |
|---|---|
| **Set the Eppo flag but didn't set Astro's `EPPO_SDK_KEY` for the env** | Astro's Python SDK silently skips init and every flag returns its hardcoded default (governed-users → False). Works on the FE, dead in DYS/dscript. **Always run B2 for BOTH astro and axon.** (GRA-978) |
| Set `EPPO_SDK_KEY` only for axon, assuming astro inherits it | Each app/env has its own secret. `bin/env_config -a astro <env> set_key ...` separately. |
| Expecting a mid-session flag flip to govern an in-flight DYS session | `is_governed` is sampled once at session creation and is immutable. Start a NEW session after flipping. |
| Treating `is_governed: false` as definitely an Eppo failure | Could be a prompt-adherence drift, not governance. Confirm via the Datadog Eppo *assignment log* (variation:true) before blaming the flag/key (staging19 bare-greeting case). |
| Passing the SDK key as the CLI `<environment>` | `<environment>` is an Eppo env *name* (`uv run eppo-flags envs`); the SDK key is a separate per-app/per-env secret. |
| Using `target` additively | `target` **replaces** the rule list. Include every id you still want each run. |
| `set-value` on a boolean flag | `set-value` is STRING-flag only; use `enable`/`disable` for booleans. |
| Numeric/percentage flag | dscout's Eppo org doesn't support numeric flags — use a boolean with per-user traffic allocation for percentage rollouts. |

## Known flag keys (verified in code)

- `governed-users` — `apps/astro/app/core/features/governance.py:24` (default False)
- `llm_routing_enabled` — global kill switch, subject `"global"`, no targeting (per AIM-391)
- `eyd_single_mission_supervisor` — account-scoped, FE-gated (per astro CLAUDE.md)
<!-- TODO: confirm with Todd the canonical list/keys for per-type study flags (the {available_types} per-type gating in progression.py) if he wants them enumerated here. -->

# Manual verification — shared procedure

Drive the local dscout stack in a browser, run the ticket's Manual Test Plan, and check
items off with evidence.

Two callers read this file, and they must not drift:

- **`/todd-coder`** — authors the plan in Plan Mode, runs this in Impl Mode.
- **`/todd-loop`** — runs this as its own phase, after the self-review fixes land and
  before the PR flips to ready.

Everything below was verified against the running stack on 2026-09-02. Where a command
looks redundant, it's because the obvious shorter version fails — the notes say how.

---

## The rule that makes the evidence worth anything

**Each worktree gets its own Compose project, and they all fight over the same host
ports.** `compose.yaml` reads `name: ${COMPOSE_PROJECT_NAME:-dscout}` and each worktree
supplies its own name through `.env.compose.local` (`frg-1313`, `dscout-main`, …) — but
every one of those files still pins `DSCOUT_AXON_PORT=5000`. Only one worktree's stack can
hold that port, and the holder is whichever came up last.

**The URL cannot tell you which worktree you reached.** Verified: `frg-1313.localhost` and
`dscout-main.localhost` both resolve to `127.0.0.1`, both on `:5000`. A `200` proves a
stack is up, not that it is *your* stack. Browse on that alone and you produce screenshots
that "prove" code you never ran.

So: **confirm the running stack is bound to the worktree holding your changes — by Compose
label, never by URL — or don't claim verification at all.** A wrong-worktree screenshot is
worse than no screenshot, because it looks like proof.

Record the binding and the commit SHA alongside the results. That provenance is what
makes a reader trust the ticks.

---

## Step 0 — Guards. Refuse rather than fake it.

Stop, and report the items as unverified with the reason, if any of these hold:

| Guard | Why |
|---|---|
| The base URL isn't the loopback URL `bin/dscout-compose status` reports for this worktree | This procedure signs in with shared local dev credentials. The host must be `localhost` or a `*.localhost` name — never staging, never production. |
| Docker isn't running (`docker info` fails) | Nothing to verify against. |
| The plan carries no `### 🧪 Manual Test Plan` | Nothing to run. Say so; don't invent a checklist at verification time. |
| Every item is marked not browser-verifiable | Report why, skip the browser entirely, don't spin the stack up for nothing. |
| `../reset-stack.sh` is missing or not executable | Step 1 has no supported fallback. Report every item unverified; never improvise with direct `docker compose` calls. |

---

## Step 1 — Bring the stack up

### 1a. Reset the stack onto this worktree

`../reset-stack.sh` is the one supported way in. Run it from inside the worktree holding
your changes — the script resolves the worktree root itself (`git rev-parse
--show-toplevel`) and hands off to `bin/dscout-compose`, which resolves that worktree's
project name, env file, and ports.

```bash
cd "$WT" && ../reset-stack.sh
```

`WT` is the absolute worktree path holding your changes. `../reset-stack.sh` resolves
because every worktree lives one level under `~/dscout-wt/`.

| Invocation | Use |
|---|---|
| `../reset-stack.sh` | First bring-up of this worktree's stack in the session. Runs `dscout-compose setup` — re-prepares Axon dev/test DB state, re-runs Astro migrations — then `up`. |
| `../reset-stack.sh --quick` | Restarting a stack that already exists. Skips `setup`, goes straight to `up`. Much faster; use it for a mid-session restart. |

**Give it a long timeout.** `bin/dscout-compose up` runs `up -d --wait --wait-timeout 300`
and a full `setup` adds more on top — well past the Bash tool's 120s default. Call it with
`timeout: 600000`. Because of `--wait`, **exit 0 means the configured services reported
healthy**, so there is nothing to poll or sleep on afterwards.

If it exits nonzero, capture the failure, report every item unverified, and continue. Don't
retry blind, and don't fall back to direct `docker compose` — see the trap below.

### It stops every container on the machine. Record what you evicted.

`reset-stack.sh` runs `docker ps -q | xargs docker stop` before it starts anything. That is
deliberate: the ports collide, so the previous worktree's stack has to go before yours can
bind `:5000`. Two consequences you own:

- **Note what you evicted.** Capture the bindings *before* you run it and say in the
  results which worktree previously held the ports. Another session may have been mid-run.
- **Nothing queues.** There is no reservation or mutex. If a second agent runs this while
  you're browsing, your stack goes down under you. A page that suddenly can't connect
  mid-checklist means you lost the ports — report the remaining items unverified rather
  than re-running and re-screenshotting into a race.

```bash
docker ps --format '{{.Label "com.docker.compose.project"}}\t{{.Label "com.docker.compose.project.working_dir"}}' | sort -u
```

### Don't reach for `ddu`, `dscout-up`, or bare `docker compose`

**Bare `docker compose` addresses the wrong project.** Without the worktree's env file it
interpolates `name: ${COMPOSE_PROJECT_NAME:-dscout}` down to `dscout` — verified: run from
inside `frg-1313`, `docker compose config` reports `name: dscout`, a project that doesn't
exist. Every `exec`, `logs`, and `down` aimed that way silently misses.

**`ddu` cannot work from the Bash tool.** It is `alias ddu="dscout-down && dscout-up"`
(`~/.dotfiles/zshrc:80`), and those functions live in `~/.config/zsh/dscout.zsh`. The Bash
tool replays a snapshot of the interactive profile, and that snapshot **keeps the alias and
the two public functions but drops every `_`-prefixed helper** plus the `_DSCOUT_APPS`
array. Verified:

```
ddu                   PRESENT (alias)
dscout-up             PRESENT (function)
_dscout_root          MISSING
_dscout_ensure_env    MISSING
_dscout_running_root  MISSING
_DSCOUT_APPS          UNSET
```

The failure is quiet and misleading rather than loud: `_dscout_root` returns empty, `cd ""`
doesn't error in zsh, and `docker compose down` then runs **in whatever directory the shell
happens to be in** with an empty service list — `no such service:`. Nothing is destroyed
(no `-v`, no services matched), but nothing you wanted happened either.

`../reset-stack.sh` replaces all of these.

### 1b. Confirm the stack is bound to this worktree

Read the identity `bin/dscout-compose` resolves, and take the base URL from it:

```bash
cd "$WT" && bin/dscout-compose status
AXON_URL="$(cd "$WT" && bin/dscout-compose status 2>/dev/null | sed -n 's/^urls:.*axon=\([^ ]*\).*/\1/p')"
```

`status` prints `root:`, `project:`, `ports:`, and `urls: axon=… dendra=… astro=…`. **Do not
assume `localhost:5000`** — on a linked worktree it is `http://<name>.localhost:5000`.

Two notes on that command, both verified:

- **Anchor the extraction to the `urls:` line.** `ports:` also contains `axon=`, so an
  unanchored `sed -n 's/.*axon=\([^ ]*\).*/\1/p'` returns two lines (`5000` and the URL).
- **`status` exits 1 when any service is unhealthy but still prints the identity block
  first.** Read the identity even on a nonzero exit; just don't treat it as readiness.

Then check the binding by label — the only check that can actually distinguish worktrees:

```bash
docker ps --filter "label=com.docker.compose.project.working_dir=$WT" \
  --format '{{.Names}}\t{{.Label "com.docker.compose.service"}}'
curl -fsS -o /dev/null -w '%{http_code}\n' "$AXON_URL/auth/sign_in"
```

- Containers listed for `$WT` **and** `200` from that worktree's own `urls: axon=` value →
  the stack is right. Continue to step 2.
- No containers for `$WT`, or `status` reports a different `root:` → report every item
  unverified. Something else owns the ports.

**Never substitute the URL check for the label check.** `curl` returning `200` on `:5000`
tells you a stack is up, not whose — both `*.localhost` names resolve to `127.0.0.1`. And
don't hardcode a container name: `docker inspect dscout-axon-1`, which this doc used to
prescribe, now errors `no such object`, because containers are named `<project>-axon-1`
(`frg-1313-axon-1`, `dscout-main-axon-1`).

If `reset-stack.sh` failed on missing files: a linked worktree **must** have its own
untracked `.env.compose.local` — the tracked `.env.compose.sample` is read only when the
worktree is on `main` — plus `apps/axon/.env` and `apps/astro/.env`. Create those, then
re-run.

### 1c. Migrations, if the work added one

The code reloader covers `lib/`. It does **not** cover migrations, `config/`, `mix.exs`, or
new deps — those need the restart above, and a migration needs running. Resolve the
container by label rather than guessing its name:

```bash
axon="$(docker ps --filter "label=com.docker.compose.project.working_dir=$WT" \
  --filter 'label=com.docker.compose.service=axon' --format '{{.Names}}' | head -1)"
[ -n "$axon" ] || { echo "axon service is not running for $WT" >&2; exit 1; }
docker exec "$axon" mix ecto.migrate
```

---

## Step 2 — Sign in

Credentials come from the environment, with a fallback to the seeded local dev user:

```bash
echo "${TEST_USER_EMAIL:-dev@dscout.com}"
echo "${TEST_USER_PASSWORD:+set}"      # never echo the value itself
```

- `TEST_USER_EMAIL` / `TEST_USER_PASSWORD` are the intended source. They are **not** set
  anywhere by default — not in the repo, not in any `.env`, not in the shell.
- Fallback is `dev@dscout.com` / `Password1234*`, the user seeded by
  `apps/axon/lib/axon/dev_tools/seed.ex:75` and documented in the repo's own AGENTS.md as
  local-only. **Say which pair you used** in the results.
- These are local-only credentials. That is the entire reason step 0 refuses any host that
  isn't loopback.

### The verified sequence

```
browser_navigate    $AXON_URL/auth/sign_in      ← from step 1b, not a hardcoded port
browser_fill_form   input[type=email]     ← email
                    input[type=password]  ← password
browser_click       button[type=submit]
```

Then confirm the URL contains `/efflux` (observed: `/efflux/home/2`). That redirect *is*
the success assertion — `session_controller.ex:32-36` sends a signed-in user to
`/efflux`, and the Dendra SPA then client-navigates to `/efflux/home/<account>`.

**Use the `input[type=...]` selectors, not ids.** `#session_email` / `#session_password`
come from `main`'s HEEx template and **do not exist on every running build** — verified
failing against a stack bound to another worktree. Type-based selectors survive that;
role-and-name (`textbox "Email"`, as `apps/e2e/tests/auth.setup.ts:95-104` does it) is the
other portable option. Snapshot refs (`ref=e12`) change every run — never bake one into a
skill.

### When sign-in doesn't land on `/efflux`

Don't retry blind, and don't work around it. Report the items as unverified with the
landing URL:

| Landed on | Meaning |
|---|---|
| `/auth/two_factor` | Account requires 2FA. Needs a TOTP secret this procedure doesn't have. |
| SSO redirect | Account is SSO-required (`required_sso`). Not scriptable here. |
| Back on `/auth/sign_in` with "Invalid Email or password" | Credentials are wrong, or the dev user isn't seeded — check `bin/dscout_db restore` ran. |

---

## Step 3 — Run the checklist

For each item marked browser-verifiable, in order:

1. Navigate to the item's stated **Route**.
2. Perform the item's single action.
3. Observe whether the **Expect** clause actually holds. Read the accessibility snapshot
   for structure — it's better than a screenshot for deciding what happened, and it's what
   you act on. The screenshot is for the human reader, not for you.
4. Capture evidence (step 4) **whether it passed or failed.** A failure screenshot is the
   most valuable artifact in the run.
5. Tick or don't, per the honesty rules below.

If an item's route 404s or its control isn't on the page, that is a **finding**, not a
tooling problem. Report it — it usually means the change isn't wired up, which is
precisely what a manual plan exists to catch and what unit tests routinely miss.

Console errors are worth a glance (`browser_console_messages`) but are not on their own a
failure — the efflux home page throws a couple dozen on a clean load.

---

## Step 4 — Capture evidence

### Where files may go — this is enforced, not a convention

The Playwright MCP **roots every write at the session's own working directory.** Verified
error: `File access denied: … is outside allowed roots. Allowed roots:
/Users/toddprice/dscout-wt/main/.playwright-mcp, /Users/toddprice/dscout-wt/main`.

Consequences, all verified:

- **An absolute path outside the session cwd is rejected.** Including the job tmp dir.
- **You cannot write evidence into `$WT` when `$WT` isn't the session cwd.** This is the
  normal case for `/todd-loop`, which runs from `~/dscout-wt/main` but implements in
  `~/dscout-wt/<ticket>`. Don't fight it — write into the session checkout.
- **Parent directories are not created for you** — a nested filename fails `ENOENT`.
  `mkdir -p` first, from Bash.
- Use a **relative** filename. It resolves against the session cwd, which is always inside
  the allowed roots, so it works no matter which worktree the code lives in.

```bash
mkdir -p .claude/tmp/manual-verification/$TICKET
```

`**/.claude/tmp/` is gitignored, so nothing lands in the working tree. A bare filename is
**not** ignored — it drops the PNG in the repo root as untracked noise. (`.playwright-mcp/`
is already ignored.)

### Capture

```
browser_take_screenshot
  filename: .claude/tmp/manual-verification/<TICKET>/MT<N>-<slug>.png
  scale:    css
```

- One screenshot per item, named for the item, so evidence maps to checklist row with no
  guessing. `fullPage: true` when the thing you're proving sits below the fold.
- Capture the state that *demonstrates the expectation* — after the action, not before.

### Screen recordings

**The Playwright MCP has no video or recording tool.** Screenshots are the evidence
format; don't promise a recording it can't produce.

A GIF is possible via the Chrome MCP's `gif_creator`, but that's a **separate browser**
with its own session — you'd have to sign in and redo the flow there from scratch. Only
worth it for a genuinely multi-step interaction where stills don't tell the story, and
never as a substitute for the stills.

---

## Step 5 — Post the results to Linear

### Post a new comment. Do not rewrite the plan comment.

The Manual Test Plan is *defined* in the `## 📋 Implementation Plan` comment and its
results go in a **separate** `## 🧪 Manual Verification` comment.

Rewriting the plan comment to tick its boxes is tempting and wrong: `/todd-plan-check`
writes its stamp as the **last line** of that comment, that slot already has more than one
writer, and a rewrite that drops the stamp silently converts a checked plan into an
unchecked one. It also destroys the record of what was originally asked for. Re-render the
checklist in the results comment instead — ticked, with evidence.

### Attaching the screenshots

Use the `linctl` skill to attach evidence. For a URL that already hosts the screenshot, run
`linctl issue attach <TICKET> --url <URL> --title "Manual verification screenshot"`. For a local
file, inspect `linctl mcp tools` after `linctl mcp sync` and use the current attachment-upload
operation it exposes; it is the CLI-backed path for Linear API operations that do not yet have a
first-class command. Upload each file one at a time because signed upload URLs expire quickly.

Embed the returned attachment URL in the comment body as `![MT1](<assetUrl>)` so the image renders
inline. If an embed doesn't render, the attachment row is the durable copy — say so rather than
silently dropping the evidence.

### Leave the stack up

There is nothing to release — `../reset-stack.sh` takes no lock. **Leave the stack
running.** Tearing it down only makes the next session pay for a full rebuild, and a
`down` aimed at the wrong project is how you break a run that isn't yours.

State the binding in the results comment so the next reader knows who owns the ports:

```bash
cd "$WT" && bin/dscout-compose status | grep -E '^(root|project|urls):'
```

Never run `purge`, `down --volumes`, or `docker compose down -v` here. `purge` is the only
lifecycle command that deletes named volumes, and those volumes hold the local database,
MinIO contents, and the warm build caches.

If uploading fails, **still post the comment** with the local paths and a note that the
upload failed. Losing the results because the attachment step broke is the worse outcome.

### Comment format

```markdown
## 🧪 Manual Verification

**Stack:** worktree `<WT>` @ `<short-sha>` · Compose project `<project>` · `<axon-url>` · signed in as `<email>` (`TEST_USER_EMAIL` | seeded dev fallback)
**Evicted:** `<project previously holding the ports, or "nothing running">`
**Verified:** <n> of <total> · **Failed:** <n> · **Not verifiable:** <n>

- [x] **MT1** — <action> → **Expect:** <result>
  - Observed: <what actually happened>
  - ![MT1](<assetUrl>)
- [ ] **MT2** — <action> → **Expect:** <result>
  - ❌ **Failed.** Observed: <what happened instead>
  - ![MT2](<assetUrl>)
- [ ] **MT3** — <action> → **Expect:** <result>
  - ⏭️ Not verifiable here — <reason, e.g. needs a Snowflake sync>

### Notes
- <anything a human should re-check by hand>
```

---

## Honesty rules

These are the whole point. A checklist that can be ticked without looking is worth less
than no checklist, because it launders a guess as a fact.

- **Tick `[x]` only for an expectation you watched hold in the browser this run.** Not
  because the code looks right, not because a unit test covers it, not because it passed
  last time.
- **A failure stays unticked and gets reported**, with the screenshot and what you saw
  instead. Never quietly reword an item so it passes.
- **Never infer from reading code.** Manual verification exists to catch what tests can't
  see — wiring, rendering, navigation. Inferring from source defeats it entirely.
- **Anything you couldn't reach gets `⏭️` and a reason.** Needs prod data, needs an inbound
  email, needs a second account, needs a scout on a phone, needs a background job that
  isn't running locally. A named blocker is a useful result; a blank is not.
- **Wrong-worktree evidence doesn't count.** If step 1 couldn't bind the stack to the code
  under test, report everything unverified. Screenshots of code you didn't run are the one
  failure mode here that actively misleads.
- **Say what you skipped and why**, in the summary the caller reports upward. An
  unattended run is trusted exactly as far as it is honest about its gaps.

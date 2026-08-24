# Manual verification — shared procedure

Drive the local dscout stack in a browser, run the ticket's Manual Test Plan, and check
items off with evidence.

Two callers read this file, and they must not drift:

- **`/todd-coder`** — authors the plan in Plan Mode, runs this in Impl Mode.
- **`/todd-loop`** — runs this as its own phase, after the self-review fixes land and
  before the PR flips to ready.

Everything below was verified against the running stack on 2026-08-11. Where a command
looks redundant, it's because the obvious shorter version fails — the notes say how.

---

## The rule that makes the evidence worth anything

**Every worktree shares one Compose project.** `compose.yaml` pins `name: dscout`, so
the containers that answer `localhost:5000` are bound to whichever worktree last brought
them up — not to the one you just edited. Browse without checking, and you produce
screenshots that "prove" code you never ran.

So: **confirm the running stack is bound to the worktree holding your changes, or don't
claim verification at all.** A wrong-worktree screenshot is worse than no screenshot,
because it looks like proof.

Record the binding and the commit SHA alongside the results. That provenance is what
makes a reader trust the ticks.

---

## Step 0 — Guards. Refuse rather than fake it.

Stop, and report the items as unverified with the reason, if any of these hold:

| Guard | Why |
|---|---|
| Base URL isn't `http://localhost:5000` | This procedure signs in with shared local dev credentials. Never point it at staging or production. |
| Docker isn't running (`docker info` fails) | Nothing to verify against. |
| The plan carries no `### 🧪 Manual Test Plan` | Nothing to run. Say so; don't invent a checklist at verification time. |
| Every item is marked not browser-verifiable | Report why, skip the browser entirely, don't spin the stack up for nothing. |

---

## Step 1 — Bring the stack up

### 1a. Reserve the shared environment first

The app containers and Chrome are a single-machine resource. **Do not probe,
restart, or drive `localhost` until this session owns the reservation.**
`acquire` waits in FIFO order, so a manual-verification agent queues behind an
active browser session instead of replacing the checkout it is testing.

Prefer the command from the worktree under test once this feature is on `main`.
Until then, `$HOME/dscout-wt/shared-docker-resources` is the local rollout copy.
`DSCOUT_SHARED_ENV_BIN` lets a caller supply a different copy explicitly.

```bash
shared_env_bin="$WT/bin/shared-env"
if [ ! -x "$shared_env_bin" ]; then
  shared_env_bin="${DSCOUT_SHARED_ENV_BIN:-$HOME/dscout-wt/shared-docker-resources/bin/shared-env}"
fi

if [ ! -x "$shared_env_bin" ]; then
  echo "shared-env is unavailable; cannot safely run browser verification" >&2
  exit 1
fi

cd "$WT" && "$shared_env_bin" acquire \
  --purpose "manual verification: $TICKET" \
  --up
```

- Exit `0` means the reservation is yours and the app services are ready for
  this worktree. Continue below.
- Exit `7` means the reservation is yours but Compose could not start the app
  services. Capture the service failure, release the reservation, and mark all
  items unverified. Do not test a previous checkout by accident.
- Any other nonzero exit means no reservation was acquired. Report the queue or
  timeout result; do not start Compose directly and do not drive the browser.

The reservation spans every browser tool call in this procedure. Release it
after posting results, including when a checklist item fails or verification
becomes impossible.

Each Bash tool call starts with a fresh shell. Repeat the resolver block when a
later command needs `$shared_env_bin`; do not assume that variable or `cd "$WT"`
survives from the acquisition call.

### Never call `ddu` from the Bash tool. It is guaranteed to fail.

`ddu` is `alias ddu="dscout-down && dscout-up"` (`~/.dotfiles/zshrc:80`), and those
functions live in `~/.config/zsh/dscout.zsh`. The Bash tool replays a snapshot of the
interactive profile, and that snapshot **keeps the alias and the two public functions but
drops every `_`-prefixed helper** plus the `_DSCOUT_APPS` array. Verified:

```
ddu                   PRESENT (alias)
dscout-up             PRESENT (function)
_dscout_root          MISSING
_dscout_ensure_env    MISSING
_dscout_running_root  MISSING
_DSCOUT_APPS          UNSET
```

The failure is quiet and misleading rather than loud: `_dscout_root` returns empty,
`cd ""` doesn't error in zsh, and `docker compose down` then runs **in whatever directory
the shell happens to be in** with an empty service list — `no such service:`. Nothing is
destroyed (no `-v`, no services matched), but nothing you wanted happened either.

The reservation command above replaces `ddu` and direct `docker compose` calls.
`WT` is the absolute worktree path holding your changes.

### 1b. Confirm the reservation loaded this worktree

```bash
curl -fsS -o /dev/null -w '%{http_code}\n' http://localhost:5000/auth/sign_in
docker inspect dscout-axon-1 \
  --format '{{index .Config.Labels "com.docker.compose.project.working_dir"}}'
```

- `200` **and** the binding equals `$WT` → the stack is right. Continue to step 2.
- A different binding, or no successful response → report every item unverified and
  release the reservation. Do not bypass the mutex with direct Compose commands; the
  reservation is specifically what keeps another session's browser run intact.

If `acquire --up` failed because the worktree is missing required `.env` files,
create or link those files, then run `cd "$WT" && "$shared_env_bin" up` while
you still hold the reservation. The repository's shared-env guide lists the
required files and one-time database setup.

### 1c. Migrations, if the work added one

The code reloader covers `lib/`. It does **not** cover migrations, `config/`, `mix.exs`,
or new deps — those need the restart above, and a migration needs running:

```bash
cd "$WT" && docker compose -f compose.yaml exec -T axon mix ecto.migrate
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
- These are local-only credentials. That is the entire reason step 0 refuses any host
  other than `localhost:5000`.

### The verified sequence

```
browser_navigate    http://localhost:5000/auth/sign_in
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

### Release the reservation

After the results comment is posted — whether it says verified, failed, or
unverified — stop the app services, then release the browser slot. Re-resolve
the command path because this is normally a different Bash tool call:

```bash
shared_env_bin="$WT/bin/shared-env"
if [ ! -x "$shared_env_bin" ]; then
  shared_env_bin="${DSCOUT_SHARED_ENV_BIN:-$HOME/dscout-wt/shared-docker-resources/bin/shared-env}"
fi

cd "$WT" && "$shared_env_bin" down || down_rc=$?
cd "$WT" && "$shared_env_bin" release \
  --note "manual verification: $TICKET complete"

[ -z "${down_rc:-}" ] || echo "shared-env down failed with $down_rc" >&2
```

If this reports exit `5`, the lock is still yours and the release must be
retried. Report a failed `down`, but do not keep the reservation merely because
the app containers could not be removed. Never use `--force` for normal cleanup.

If uploading fails, **still post the comment** with the local paths and a note that the
upload failed. Losing the results because the attachment step broke is the worse outcome.

### Comment format

```markdown
## 🧪 Manual Verification

**Stack:** worktree `<WT>` @ `<short-sha>` · signed in as `<email>` (`TEST_USER_EMAIL` | seeded dev fallback)
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

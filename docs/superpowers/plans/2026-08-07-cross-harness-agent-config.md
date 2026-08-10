# Cross-harness agent config Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move `~/.dotfiles/claude/` to a harness-neutral `ai/` tree and directory-symlink it into Claude Code, Codex, and opencode via a tested `bin/link-agents`.

**Architecture:** One source directory, symlinked whole rather than per-file. `bin/link-agents` walks a table of `source|destination|harness-root` rows, skipping rows whose harness isn't installed and refusing to overwrite real content. rcm keeps managing the rest of the dotfiles but is excluded from `ai/`.

**Tech Stack:** bash, rcm (`rcup`/`lsrc`), bats-core 1.13 for tests, shellcheck for lint. Both test tools are already in the `Brewfile`.

**Spec:** `docs/superpowers/specs/2026-08-06-cross-harness-agent-config-design.md`

## Global Constraints

- **`bin/link-agents` must honor overridden `$HOME` and `$DOTFILES`.** The entire test suite depends on pointing both at a sandbox. Read them at runtime; never hardcode `/Users/toddprice`.
- **The script never deletes real content.** A destination that is a real file or directory is refused and reported; the run exits non-zero. Only symlinks are ever replaced.
- **`ln -sfn`, never `ln -sf`.** Without `-n`, linking over an existing symlink-to-directory creates the new link *inside* the target instead of replacing it.
- **Exactly these 12 rows**, in this order — `ai/skills` → `~/.claude/skills` and `~/.agents/skills`; `ai/commands` → `~/.claude/commands`, `~/.codex/prompts`, `~/.config/opencode/commands`; `ai/AGENTS.md` → `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, `~/.config/opencode/AGENTS.md`; `ai/claude/{settings.json,statusline-command.sh,agents,scripts}` → the matching `~/.claude/` paths.
- **`~/.agents` is ungated** — always created, because it is tool-neutral and Codex expects it. Every other row is gated on its harness root existing.
- **Nothing in this repo runs in CI.** There is no `.github/`, `.rwx/`, or `.circleci/`. `bats test/` only ever runs when a human types it.

---

## ⚠️ Read before Task 4

**Do not run Task 4 from inside a Claude Code session.** Your `~/.claude/CLAUDE.md`, skills, and commands are symlinks into `~/.dotfiles/claude/`. The instant `git mv claude ai` runs, every one of them dangles. A session that is mid-task when that happens loses its instructions and its skills.

Tasks 1–3 are safe from anywhere. **Run Task 4 from a plain terminal**, then start a fresh Claude Code session for Task 5.

Task 4 is written as one compound command for exactly this reason — it keeps the window where links are broken to milliseconds instead of the several minutes a manual sequence would take.

---

### Task 1: `bin/link-agents` — links safely, refuses real content

**Files:**
- Create: `bin/link-agents`
- Test: `test/link-agents.bats`

**Interfaces:**
- Consumes: nothing.
- Produces: `bin/link-agents [--dry-run]`. Reads `$HOME` and `$DOTFILES` (defaults `$HOME/.dotfiles`). Links `$DOTFILES/ai/*` into harness paths. Exits `0` when every row resolved, `1` when any row was refused or its source was missing. Per-row stdout is `  <status> <path>` where status is one of `ok`, `link`, `repoint`, `gate`, `REFUSE`, `MISSING`.

- [ ] **Step 1: Write the failing test**

Create `test/link-agents.bats`:

```bash
#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../bin/link-agents"
  export HOME="$BATS_TEST_TMPDIR/home"
  export DOTFILES="$HOME/.dotfiles"
  local ai="$DOTFILES/ai"
  mkdir -p "$ai/skills/demo" "$ai/commands" "$ai/claude/agents" "$ai/claude/scripts"
  echo "skill"  > "$ai/skills/demo/SKILL.md"
  echo "cmd"    > "$ai/commands/demo.md"
  echo "agents" > "$ai/AGENTS.md"
  echo "{}"     > "$ai/claude/settings.json"
  echo "line"   > "$ai/claude/statusline-command.sh"
  mkdir -p "$HOME/.claude"
}

@test "links skills into ~/.claude/skills" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -L "$HOME/.claude/skills" ]
  [ "$(readlink "$HOME/.claude/skills")" = "$DOTFILES/ai/skills" ]
  [ -f "$HOME/.claude/skills/demo/SKILL.md" ]
}

@test "links AGENTS.md in as ~/.claude/CLAUDE.md" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.claude/CLAUDE.md")" = "$DOTFILES/ai/AGENTS.md" ]
}

@test "creates ~/.agents/skills even though ~/.agents does not exist" {
  [ ! -d "$HOME/.agents" ]
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.agents/skills")" = "$DOTFILES/ai/skills" ]
}

@test "refuses a real directory and exits non-zero" {
  rm -rf "$HOME/.claude/skills"
  mkdir -p "$HOME/.claude/skills/mine"
  echo "keep me" > "$HOME/.claude/skills/mine/SKILL.md"
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"REFUSE"* ]]
  [ -f "$HOME/.claude/skills/mine/SKILL.md" ]
  [ ! -L "$HOME/.claude/skills" ]
}

@test "one refusal does not stop later rows" {
  # ~/.claude/skills is row 1 and ~/.agents/skills is row 2, so refusing the
  # first proves the loop kept going rather than bailing on the first failure.
  rm -rf "$HOME/.claude/skills"
  mkdir -p "$HOME/.claude/skills/mine"
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"REFUSE"* ]]
  [ "$(readlink "$HOME/.agents/skills")" = "$DOTFILES/ai/skills" ]
}

@test "reports MISSING and exits non-zero when a source is absent" {
  rm -f "$DOTFILES/ai/AGENTS.md"
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"MISSING"* ]]
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
cd ~/.dotfiles && bats test/link-agents.bats
```

Expected: every test fails — bats reports the script does not exist.

- [ ] **Step 3: Write the implementation**

Create `bin/link-agents`:

```bash
#!/usr/bin/env bash
#
# link-agents — symlink the shared agent config into every installed harness.
#
# One source tree (ai/) is linked whole into each tool's own location, so a new
# skill or command is live everywhere the moment it lands in the repo. Rows for
# harnesses that aren't installed are skipped. Real content is never deleted:
# a destination holding a real file or directory is refused and reported, and
# the run exits non-zero so bootstrap.sh fails loudly rather than half-linking.

set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/.dotfiles}"
AI="$DOTFILES/ai"

DRY_RUN=
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

# source (relative to ai/) | destination | harness root ("" = never gated)
ROWS=(
  "skills|$HOME/.claude/skills|$HOME/.claude"
  "skills|$HOME/.agents/skills|"
  "commands|$HOME/.claude/commands|$HOME/.claude"
  "commands|$HOME/.codex/prompts|$HOME/.codex"
  "commands|$HOME/.config/opencode/commands|$HOME/.config/opencode"
  "AGENTS.md|$HOME/.claude/CLAUDE.md|$HOME/.claude"
  "AGENTS.md|$HOME/.codex/AGENTS.md|$HOME/.codex"
  "AGENTS.md|$HOME/.config/opencode/AGENTS.md|$HOME/.config/opencode"
  "claude/settings.json|$HOME/.claude/settings.json|$HOME/.claude"
  "claude/statusline-command.sh|$HOME/.claude/statusline-command.sh|$HOME/.claude"
  "claude/agents|$HOME/.claude/agents|$HOME/.claude"
  "claude/scripts|$HOME/.claude/scripts|$HOME/.claude"
)

tilde() { printf '%s' "${1/#"$HOME"/\~}"; }

status=0

for row in "${ROWS[@]}"; do
  IFS='|' read -r src dst root <<<"$row"
  source_path="$AI/$src"

  if [[ -n "$root" && ! -d "$root" ]]; then
    printf '  %-7s %s (no %s)\n' "gate" "$(tilde "$dst")" "$(tilde "$root")"
    continue
  fi

  if [[ ! -e "$source_path" ]]; then
    printf '  %-7s %s\n' "MISSING" "$(tilde "$source_path")"
    status=1
    continue
  fi

  if [[ -L "$dst" ]]; then
    if [[ "$(readlink "$dst")" == "$source_path" ]]; then
      printf '  %-7s %s\n' "ok" "$(tilde "$dst")"
      continue
    fi
    action="repoint"
  elif [[ -e "$dst" ]]; then
    printf '  %-7s %s is real content — not touching it\n' "REFUSE" "$(tilde "$dst")"
    status=1
    continue
  else
    action="link"
  fi

  printf '  %-7s %s -> %s\n' "$action" "$(tilde "$dst")" "$(tilde "$source_path")"
  [[ -n "$DRY_RUN" ]] && continue

  mkdir -p "$(dirname "$dst")"
  # -n so an existing symlink-to-directory is replaced, not descended into.
  ln -sfn "$source_path" "$dst"
done

exit "$status"
```

- [ ] **Step 4: Make it executable and run the tests**

```bash
cd ~/.dotfiles && chmod +x bin/link-agents && bats test/link-agents.bats
```

Expected: 6 passing.

- [ ] **Step 5: Lint**

```bash
cd ~/.dotfiles && shellcheck bin/link-agents
```

Expected: no output.

- [ ] **Step 6: Commit**

```bash
cd ~/.dotfiles
git add bin/link-agents test/link-agents.bats
git commit -m "Add link-agents to symlink shared agent config into each harness

Links the ai/ tree whole rather than per file, so a new skill is live in
every installed harness the moment it lands in the repo. Refuses to
overwrite real content and exits non-zero so a partial run fails loudly.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Dry-run, harness gating, and idempotency

**Files:**
- Modify: `test/link-agents.bats` (append tests)
- Verify: `bin/link-agents` already implements all three; these tests prove it

**Interfaces:**
- Consumes: `bin/link-agents` from Task 1.
- Produces: no new interface. Locks in that `--dry-run` writes nothing, absent harnesses are gated, and a second run is a no-op.

- [ ] **Step 1: Write the failing tests**

Append to `test/link-agents.bats`:

```bash
@test "--dry-run creates nothing" {
  run "$SCRIPT" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"link"* ]]
  [ ! -e "$HOME/.claude/skills" ]
  [ ! -e "$HOME/.agents" ]
}

@test "gates codex and opencode rows when those harnesses are absent" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"gate"* ]]
  [ ! -e "$HOME/.codex" ]
  [ ! -e "$HOME/.config/opencode" ]
}

@test "links codex rows once ~/.codex exists" {
  mkdir -p "$HOME/.codex"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.codex/prompts")" = "$DOTFILES/ai/commands" ]
  [ "$(readlink "$HOME/.codex/AGENTS.md")" = "$DOTFILES/ai/AGENTS.md" ]
}

@test "second run is a no-op and reports ok" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
  [[ "$output" != *"link "* ]]
}

@test "repoints a symlink that points somewhere else" {
  mkdir -p "$BATS_TEST_TMPDIR/elsewhere"
  ln -sfn "$BATS_TEST_TMPDIR/elsewhere" "$HOME/.claude/skills"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"repoint"* ]]
  [ "$(readlink "$HOME/.claude/skills")" = "$DOTFILES/ai/skills" ]
}

@test "re-linking does not nest a link inside the target directory" {
  run "$SCRIPT"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ ! -e "$DOTFILES/ai/skills/skills" ]
  [ "$(readlink "$HOME/.claude/skills")" = "$DOTFILES/ai/skills" ]
}
```

- [ ] **Step 2: Run the tests**

```bash
cd ~/.dotfiles && bats test/link-agents.bats
```

Expected: 12 passing. These should pass immediately — Task 1's implementation already covers all three behaviors. If any fail, the implementation is wrong and gets fixed here, not the test.

- [ ] **Step 3: Commit**

```bash
cd ~/.dotfiles
git add test/link-agents.bats
git commit -m "Cover dry-run, harness gating, and idempotency in link-agents tests

The no-nesting case is the one worth having: ln -sf without -n would link
into the target directory on the second run instead of replacing the link.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Vendor the third-party skills and exclude `ai/` from rcm

**Files:**
- Create: `claude/skills/{agent-skills,gh-cli,gh-cli-workspace,rwx,slack-gif-creator}/` (copied in)
- Modify: `rcrc`

**Interfaces:**
- Consumes: nothing.
- Produces: `claude/skills/` holding all 29 entries, and an `rcrc` whose `EXCLUDES` contains `ai`. Both are prerequisites for Task 4 and neither touches a live symlink.

This task is safe to run from anywhere. Nothing here breaks an existing link — the vendored skills land beside the ones already tracked, and `ai` in `EXCLUDES` matches nothing until Task 4 creates the directory.

- [ ] **Step 1: Copy the five vendored skills in**

```bash
cd ~/.dotfiles
for s in agent-skills gh-cli gh-cli-workspace rwx slack-gif-creator; do
  cp -R "$HOME/.agents/skills/$s" "claude/skills/$s"
done
find claude/skills -name '.DS_Store' -delete
```

- [ ] **Step 2: Verify the count and that nothing came in as a symlink**

```bash
cd ~/.dotfiles
ls claude/skills | wc -l          # expect 29
find claude/skills -type l        # expect no output
```

Expected: `29`, and no symlinks. `cp -R` on macOS copies symlinks as symlinks rather than following them, so a vendored skill containing an internal link would carry a path that breaks on another machine. If the second command prints anything, re-copy that one skill with `cp -RL` to dereference, then re-run the check.

- [ ] **Step 3: Add `ai` to rcm's EXCLUDES**

Edit `rcrc` so the `EXCLUDES` line reads:

```
EXCLUDES="*.swp .DS_Store README.md LICENSE Brewfile bootstrap.sh ai docs test"
```

`ai` stops `rcup` from per-file-linking the tree into `~/.ai/`. `docs` and `test` are new top-level directories that rcm would otherwise link to `~/.docs` and `~/.test`.

- [ ] **Step 4: Prove the exclude prunes the whole subtree**

```bash
cd ~/.dotfiles && lsrc | grep -c '^/Users/[^:]*/\.\(ai\|docs\|test\)'
```

Expected: `0`. Verified separately in a scratch repo — without the exclude, `lsrc` lists `~/.ai/skills/foo/SKILL.md`, so a `0` here means the pattern really is pruning and not just matching nothing.

- [ ] **Step 5: Commit**

```bash
cd ~/.dotfiles
git add claude/skills rcrc
git commit -m "Vendor five third-party skills and keep rcm out of the new trees

agent-skills, gh-cli, gh-cli-workspace, rwx, and slack-gif-creator were
loaded from the installer-managed ~/.agents/skills, which no fresh machine
has. Copying them in means bootstrap alone is enough.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: The cutover

**Files:**
- Rename: `claude/` → `ai/`, then `ai/{settings.json,statusline-command.sh,agents,scripts}` → `ai/claude/`
- Rename: `ai/CLAUDE.md` → `ai/AGENTS.md`
- Remove: the stale rcm symlinks under `~/.claude/`
- Move aside: `~/.agents/skills` → `~/.agents/skills.pre-dotfiles`

**Interfaces:**
- Consumes: `bin/link-agents` (Task 1), the vendored tree and `rcrc` exclude (Task 3).
- Produces: `~/.dotfiles/ai/` as the single source, with all 12 links live.

**⚠️ Run this from a plain terminal, not from inside a Claude Code session.** See the warning at the top of this plan.

- [ ] **Step 1: Confirm every path about to be removed is a symlink or a directory of symlinks**

```bash
find ~/.claude/skills ~/.claude/commands ~/.claude/agents ~/.claude/scripts \
  ! -type d ! -type l ! -name '.DS_Store' -print
for f in ~/.claude/CLAUDE.md ~/.claude/settings.json ~/.claude/statusline-command.sh; do
  [ -L "$f" ] || echo "NOT A SYMLINK: $f"
done
```

Expected: no output from either command. `find` without `-L` does not descend into the three vendored entries — they are themselves symlinks into `~/.agents/skills`, so `! -type l` excludes them and their contents are never walked. Any output at all means something real lives under a path Step 3 is about to `rm -rf`; stop and deal with it rather than proceeding.

- [ ] **Step 2: Dry-run the post-cutover state in a sandbox**

```bash
cd ~/.dotfiles
SANDBOX=$(mktemp -d)
mkdir -p "$SANDBOX/.dotfiles" "$SANDBOX/.claude"
cp -R claude "$SANDBOX/.dotfiles/ai"          # claude/ has not been renamed yet
mv "$SANDBOX/.dotfiles/ai/CLAUDE.md" "$SANDBOX/.dotfiles/ai/AGENTS.md"
mkdir -p "$SANDBOX/.dotfiles/ai/claude"
for x in settings.json statusline-command.sh agents scripts; do
  mv "$SANDBOX/.dotfiles/ai/$x" "$SANDBOX/.dotfiles/ai/claude/$x"
done
HOME="$SANDBOX" DOTFILES="$SANDBOX/.dotfiles" bin/link-agents --dry-run
rm -rf "$SANDBOX"
```

Expected: every `~/.claude/*` row reports `link`, the `~/.agents/skills` row reports `link`, the Codex and opencode rows report `gate`. No `REFUSE`, no `MISSING`. This is the rehearsal — if it isn't clean, do not run Step 3.

- [ ] **Step 3: Cut over, in one command**

```bash
cd ~/.dotfiles && \
  git mv claude ai && \
  git mv ai/CLAUDE.md ai/AGENTS.md && \
  mkdir -p ai/claude && \
  git mv ai/settings.json ai/statusline-command.sh ai/agents ai/scripts ai/claude/ && \
  rm -rf ~/.claude/skills ~/.claude/commands ~/.claude/agents ~/.claude/scripts && \
  rm -f ~/.claude/CLAUDE.md ~/.claude/settings.json ~/.claude/statusline-command.sh && \
  mv ~/.agents/skills ~/.agents/skills.pre-dotfiles && \
  bin/link-agents
```

Expected: 12 rows, all `link` except the Codex/opencode ones which `gate` (or `link`, if `~/.codex` exists — it does on this machine, so expect `~/.codex/prompts` and `~/.codex/AGENTS.md` to link). Exit 0.

- [ ] **Step 4: Verify the links resolve**

```bash
find -L ~/.claude ~/.agents ~/.codex -maxdepth 2 -type l -print
ls -la ~/.claude/skills ~/.claude/CLAUDE.md ~/.agents/skills
ls ~/.dotfiles/ai/skills | wc -l
```

Expected: the `find` prints nothing (under `-L` a still-reported symlink is a dangling one), `~/.claude/skills` and `~/.agents/skills` both point at `~/.dotfiles/ai/skills`, `~/.claude/CLAUDE.md` points at `~/.dotfiles/ai/AGENTS.md`, and the count is `29`.

- [ ] **Step 5: Verify rcm keeps its hands off**

```bash
cd ~/.dotfiles && rcup -v 2>&1 | grep -i 'claude\|/\.ai/' || echo "rcm touched nothing"
```

Expected: `rcm touched nothing`.

- [ ] **Step 6: Check what's staged, then commit**

`git mv` in Step 3 already staged every rename, and it staged them with the *committed* content — a file carrying an unstaged edit shows as `RM`, with the modification left in the working tree. So there is nothing left to add here, and **no `git add`**: a bare `git add -A` would sweep unrelated working-tree edits into the cutover commit. Confirm that before committing.

```bash
cd ~/.dotfiles
git diff --cached --name-status | grep -v '^R' || echo "renames only — good"
```

Expected: `renames only — good`. Any other line is something you did not mean to commit.

```bash
cd ~/.dotfiles
git commit -m "Move the agent config to a harness-neutral ai/ tree

claude/ became ai/, CLAUDE.md became AGENTS.md, and the four Claude-only
files moved under ai/claude/. link-agents points ~/.claude and ~/.agents
at the same skills directory, which is what gets Codex and opencode for
free — both read ~/.agents/skills, and opencode reads ~/.claude/skills too.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 7: Confirm the harnesses actually read it, then clean up**

Start a fresh Claude Code session and confirm `/speak-as-todd` and `/todd:plan` resolve. Run `codex` and confirm `/skills` lists your skills with nothing appearing twice.

Only once both are confirmed:

```bash
rm -rf ~/.agents/skills.pre-dotfiles ~/.agents/.skill-lock.json
```

**If Step 7 fails: back out.** The Step 6 commit is local and unpushed, and
`~/.agents/skills.pre-dotfiles` hasn't been removed yet, so nothing here is
lost — but the rename is already in history and the live symlinks already
point at `ai/`, so undoing it takes more than a plain `git reset`. Run, in
order:

```bash
cd ~/.dotfiles
git reset --hard HEAD^                                             # restore claude/ in the repo
rm -f ~/.claude/skills ~/.claude/commands ~/.claude/agents ~/.claude/scripts \
      ~/.claude/CLAUDE.md ~/.claude/settings.json ~/.claude/statusline-command.sh
                                                                     # these now dangle — ai/ is gone
rm -f ~/.codex/prompts ~/.codex/AGENTS.md                           # created by Step 3; dangle once ai/ is gone
rm -f ~/.config/opencode/commands ~/.config/opencode/AGENTS.md      # no-op unless opencode is installed
rm -f ~/.agents/skills                                              # the dangling link-agents symlink
mv ~/.agents/skills.pre-dotfiles ~/.agents/skills                   # restore the pre-cutover directory
env RCRC="$HOME/.dotfiles/rcrc" rcup                                # let rcm re-link ~/.claude/* from claude/
```

`$DOTFILES` is set by `bootstrap.sh`, not by the shell — a plain terminal
has no such variable, so this uses `$HOME/.dotfiles` literally rather than
`$DOTFILES/rcrc`, which would silently expand to `/rcrc`.

Then confirm nothing dangles:

```bash
find -L ~/.claude ~/.agents ~/.codex -maxdepth 2 -type l -print
```

Expected: no output — the same idiom Step 4 above uses to prove a real
cutover resolved cleanly. Also spot-check that `~/.claude/CLAUDE.md`
resolves into `~/.dotfiles/claude/` (not `ai/`) before starting a new
Claude Code session. `git reset --hard` is safe here specifically because
nothing besides the Step 6 commit sits on top of it — check `git status`
first if that's no longer true by the time you're reading this.

---

### Task 5: Wire `bootstrap.sh` and simplify `bin/sync`

**Files:**
- Modify: `bootstrap.sh` (after the `rcup` call, around line 44)
- Modify: `bin/sync` (`WATCHED_DIRS`, and a new call before the commit prompt)

**Interfaces:**
- Consumes: `bin/link-agents` (Task 1), the `ai/` tree (Task 4).
- Produces: a `bootstrap.sh` that links whatever agent-harness roots already
  exist at the point in the script where it runs, and a `bin/sync` that
  re-links on every sync and no longer scans directories that can't drift.

**What a fresh machine actually gets from `bootstrap.sh` alone:** the
`link-agents` call goes in right after `rcup` (`bootstrap.sh:44`), before
`brew bundle` (`bootstrap.sh:48`) — and nothing in the `Brewfile` installs
the Claude Code CLI at all (`vscode "anthropic.claude-code"` is the editor
extension, not the CLI). So on a genuinely fresh machine, `~/.claude`
doesn't exist yet when `link-agents` runs: 11 of the 12 rows gate, and only
the ungated `~/.agents/skills` row links. **A second `bin/link-agents` run
— or just `bin/sync`, which Step 3 below wires to call it automatically —
is required after installing each harness.** That second run isn't
optional cleanup; it's the step that actually puts the config in front of
Claude Code, Codex, and opencode.

- [ ] **Step 1: Add the `link-agents` call to `bootstrap.sh`**

Immediately after the `env RCRC="$DOTFILES/rcrc" rcup` line, insert:

```bash

# -- 3b. Agent config ------------------------------------------------------
# rcm is excluded from ai/ — this is what puts the skills, commands, and
# AGENTS.md in front of Claude Code, Codex, and opencode. Only links the
# harnesses that are actually installed, so it's safe on any machine.
# This runs before brew bundle installs anything, so on a fresh machine
# most rows gate here — re-run `bin/link-agents` (or `bin/sync`) after
# installing each harness to actually pick it up.
#
# Non-fatal on purpose. link-agents exits 1 when it refuses a destination
# holding real content, and Claude Code writes a real ~/.claude/settings.json
# on first run — under `set -e` that would abort bootstrap before brew bundle
# and oh-my-zsh, breaking the "safe to re-run" promise at the top of this file.
# The refused rows are printed above; the remaining rows still linked.
info "Linking agent config with link-agents"
"$DOTFILES/bin/link-agents" || info "link-agents refused a row (see above) — continuing"
```

- [ ] **Step 2: Trim `WATCHED_DIRS` in `bin/sync`**

Replace the `WATCHED_DIRS` array with:

```bash
# Directories to scan for new files. Add a path here whenever you start
# managing a new dotfile location.
#
# ~/.claude/skills, ~/.claude/commands, and ~/.claude/agents used to be here.
# They're directory symlinks into ai/ now, so a new file in one is already
# inside the repo — there is nothing left to mkrc and nothing to drift.
WATCHED_DIRS=(
    "$HOME/.config/zed"
)
```

- [ ] **Step 3: Call `link-agents` from `bin/sync`**

In `bin/sync`, immediately after the `cd "$DOTFILES"` line in section 2 and before the `git status --porcelain` check, insert:

```bash
# Wire up any harness that's been installed since the last sync.
# Non-fatal for the same reason as in bootstrap.sh: a refused row shouldn't
# kill the sync before it reaches the commit prompt.
"$DOTFILES/bin/link-agents" || echo "link-agents refused a row (see above) — continuing"
echo
```

- [ ] **Step 4: Lint both scripts**

```bash
cd ~/.dotfiles && shellcheck bootstrap.sh bin/sync bin/link-agents
```

Expected: no output.

- [ ] **Step 5: Run the full test suite**

```bash
cd ~/.dotfiles && bats test/
```

Expected: 16 passing. (Task 1/2 shipped with 12; the final review's fix
wave added the opencode positive-path test and the unrecognized-flag
rejection test; the self-review added destination assertions for the five
uncovered `~/.claude` rows and a test pinning the tilde abbreviation.)

- [ ] **Step 6: Verify `bin/sync` runs clean end to end**

```bash
cd ~/.dotfiles && printf 'n\n' | bin/sync
```

Expected: `No new files in watched dirs.` (true as of this writing — `~/.config/zed` has nothing new), then the `ok`/`link` rows from `link-agents`, then the uncommitted-changes list (Task 5's own edits are still unstaged at this point), then a single `Commit and push? [Y/n]` prompt. One `n` declines it, which keeps this read-only.

If `~/.config/zed` *does* have a new file by the time you run this, the flow is different: the first line reads `Found N new file(s)...` instead, followed by an `mkrc all of them? [Y/n]` prompt — decline that one too, and pipe `printf 'n\nn\n'` so the second `n` reaches the commit prompt that follows. (In `bin/sync`, the `mkrc` prompt and the "No new files" message are mutually exclusive branches — never expect both a new-files count and "No new files" in the same run.)

- [ ] **Step 7: Commit**

```bash
cd ~/.dotfiles
git add bootstrap.sh bin/sync
git commit -m "Link agent config from bootstrap and drop the dead sync scan

bin/sync scanned ~/.claude/skills and friends to catch files rcm didn't
know about. Those are directory symlinks now, so a new skill is tracked
the moment it's written and the scan has nothing left to find.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Verification

Full sequence once every task is done:

```bash
cd ~/.dotfiles
bats test/                                                    # 16 passing
shellcheck bin/link-agents bin/sync bootstrap.sh              # silent
bin/link-agents --dry-run                                     # every row ok
find -L ~/.claude ~/.agents ~/.codex -maxdepth 2 -type l      # silent
ls ai/skills | wc -l                                          # 29
lsrc | grep -c '/\.\(ai\|docs\|test\)'                        # 0
git status --short                                            # only plan.md
```

Then, by hand: a fresh `claude` session resolves `/speak-as-todd`, and `codex` shows `/skills` with no duplicates.

**⚠️ What a green run does not prove.**

- **Nothing here runs in CI.** There is no `.github/`, `.rwx/`, or `.circleci/` in this repo, so `bats test/` only ever executes when a human types it. A passing suite says nothing about what a future commit does.
- **The bats suite proves the script's logic against a sandbox `HOME`, not that any harness reads the result.** It builds fake `ai/` trees and asserts on `readlink`. Only launching `claude` and `codex` proves the tools actually load what got linked — Step 7 of Task 4 is the real test.
- **opencode is untested end to end.** It isn't installed. Its three rows will gate at every run until it is, so a clean `link-agents` says nothing about whether those paths are right. Re-verify against its docs on install.
- **`find -L … -type l` only catches dangling links inside two levels.** A broken link deeper in the tree — inside a vendored skill, say — won't surface. Widen `-maxdepth` if a skill misbehaves.

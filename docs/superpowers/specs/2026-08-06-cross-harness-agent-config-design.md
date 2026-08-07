# Cross-harness agent config — design

**Date:** 2026-08-06
**Status:** approved and reviewed, not yet implemented

Reviewed 2026-08-06. One factual error corrected (Codex does read `~/.codex/skills`), the
opencode open item closed against source, a speculative `--adopt` flag cut, and every count
and removal-safety claim re-checked against the filesystem.

## Problem

`~/.dotfiles/claude/` holds the skills, commands, and global instructions, and `rcm`
symlinks them **per file** into `~/.claude/`. Two things are wrong with that.

First, per-file linking drifts. `rcup` only links files that were explicitly `mkrc`'d, so
every new skill lives outside the repo until something notices. `bin/sync` exists purely to
scan for that gap — it is a workaround for the linking strategy, not a feature. Three skills
in the repo (`eppo-flag`, `explain-diff-notion`, `worktree`) had gone stale and unlinked; they
were reviewed and deleted rather than migrated.

Second, the config only reaches Claude Code. Codex is installed on this machine and reads its
own locations. opencode is not installed yet but will be. Today none of that content is shared.

## Decisions

| Decision | Choice | Why |
|---|---|---|
| What gets shared | Skills, global instructions, commands | Subagents and `settings.json` have no equivalent in the other tools |
| Per-skill opt-in? | No — share everything | Some skills lean on Claude-only features (sub-agent dispatch, specific MCP servers) and will misfire elsewhere. Accepted; fix them as they come up rather than maintain a manifest |
| Link granularity | Whole directory | Removes the new-file drift class entirely |
| Source directory name | `ai/` | `claude/` would misdescribe a tree three tools read |
| Third-party skills in `~/.agents/skills` | Vendor into the repo | A fresh machine works with no extra installers, and they reach every harness. Trade-off: no upstream updates unless re-pulled |
| `braintrust` name collision | Keep the repo version | It is the maintained one; the `~/.agents` copy differs and is dropped |

Vendored in: `agent-skills`, `gh-cli`, `gh-cli-workspace`, `rwx`, `slack-gif-creator`.
Dropped: `find-skills`, `slack-messaging`, and the `~/.agents` copy of `braintrust`.

## Verified harness paths

Checked against vendor docs on 2026-08-06, and — for Codex — against the local install with
throwaway probe skills, because the docs turned out to be incomplete:

- Codex loads user skills from `$HOME/.agents/skills`. It **also** loads `~/.codex/skills`,
  even though the docs' discovery table omits that row: a probe skill placed there appeared in
  the model-visible skill list, and Codex's own `skill-installer` and `skill-creator` default
  to installing into it. So that directory is **not** inert. What is off-limits is
  `~/.codex/skills/.system` — the OpenAI-managed bundle (`imagegen`, `review-agent`,
  `skill-creator`, …), which Codex deletes and rewrites on upgrade.
  Codex does **not** dedupe by skill name: the same `name` under two roots yields two entries
  in the selector. Nothing may live in both `~/.agents/skills` and `~/.codex/skills`.
  Whole-directory symlinks are supported and followed — verified with a probe in exactly the
  shape this design proposes. Global instructions are `~/.codex/AGENTS.md`. Custom prompts
  under `~/.codex/prompts` still work but are **deprecated** in favor of skills.
  — [Build skills](https://learn.chatgpt.com/docs/build-skills),
  [AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md),
  [Custom prompts](https://developers.openai.com/codex/custom-prompts)
- opencode reads `~/.claude/skills/*/SKILL.md` and `~/.agents/skills/*/SKILL.md` natively, so
  it needs **no** skill link of its own. Commands are `~/.config/opencode/commands/` (plural);
  global instructions are `~/.config/opencode/AGENTS.md`.
  — [Skills](https://opencode.ai/docs/skills/), [Commands](https://opencode.ai/docs/commands/),
  [Rules](https://opencode.ai/docs/rules/)
- Claude Code reads `~/.claude/skills/`, `~/.claude/commands/`, `~/.claude/CLAUDE.md`.

Because Codex and opencode both read `~/.agents/skills`, and opencode also reads
`~/.claude/skills`, the whole thing reduces to **one source directory and two skill symlinks**.

## Target layout

```
~/.dotfiles/
  ai/
    AGENTS.md                    (was claude/CLAUDE.md)
    skills/                      24 own + 5 vendored
    commands/                    astro-fixup.md, axon-fixup.md, todd/*
    claude/                      Claude-only, nothing else reads these
      settings.json
      statusline-command.sh
      agents/
      scripts/
  bin/link-agents                new
  bin/sync                       simplified
```

## Link table

| Source | Link created at | Read by |
|---|---|---|
| `ai/skills` | `~/.claude/skills` | Claude Code, opencode |
| `ai/skills` | `~/.agents/skills` | Codex, opencode |
| `ai/commands` | `~/.claude/commands` | Claude Code |
| `ai/commands` | `~/.codex/prompts` | Codex (deprecated surface) |
| `ai/commands` | `~/.config/opencode/commands` | opencode |
| `ai/AGENTS.md` | `~/.claude/CLAUDE.md` | Claude Code |
| `ai/AGENTS.md` | `~/.codex/AGENTS.md` | Codex |
| `ai/AGENTS.md` | `~/.config/opencode/AGENTS.md` | opencode |
| `ai/claude/settings.json` | `~/.claude/settings.json` | Claude Code |
| `ai/claude/statusline-command.sh` | `~/.claude/statusline-command.sh` | Claude Code |
| `ai/claude/agents` | `~/.claude/agents` | Claude Code |
| `ai/claude/scripts` | `~/.claude/scripts` | Claude Code |

Every entry is a plain symlink — a directory link where the source is a directory, a file link
where it is a file. Adding a skill to the repo makes it live in all three tools with no re-run.

## `bin/link-agents`

Idempotent, safe to re-run, no arguments required.

**Behavior per row:**
- Destination is already the correct symlink → skip.
- Destination is a symlink pointing somewhere else → repoint it.
- Destination does not exist → create the parent directory if needed, then link.
- Destination is a real file or directory → **refuse.** Print the path and continue to the
  next row, then exit non-zero at the end.

The script never deletes real content. That is what makes it safe inside `bootstrap.sh`, and
the non-zero exit makes a partial link run fail loudly instead of silently.

**Harness gating:** a row is skipped when its harness root (`~/.claude`, `~/.codex`,
`~/.config/opencode`) does not exist. `~/.agents` is always created, since it is
tool-neutral and Codex expects it. This is what lets the same script run unchanged on a
machine with only Claude installed.

**Flags:** `--dry-run` only — print the plan, change nothing.

No `--adopt` flag. An earlier draft had one that would move conflicting content into the repo
and then link, on the theory the migration would need it. It wouldn't, and it would do damage:
`~/.claude/skills` at migration time is a real directory full of soon-to-be-dangling symlinks,
so adopting it would move that into the repo and clobber the real `ai/skills`. `~/.agents/skills`
is worse — three of its eight entries are being dropped, not vendored. Every real-file conflict
in this migration needs a different judgment, which is exactly what a generic adopt flag can't
make. The script refuses and reports; a human clears the conflict.

**Why this script exists at all.** rcm has a native directory-symlink feature, `SYMLINK_DIRS`
in `rcrc(5)` — "directories matching a pattern are symlinked instead of descended." It was
tested and rejected: rcm derives the destination from the repo path, so `SYMLINK_DIRS="ai"`
produces `~/.ai -> repo/ai` and nothing else. It cannot point one source at `~/.claude/skills`
and `~/.agents/skills` under two different names, which is the entire job here. Worth knowing
that the rename is what forecloses it — had `claude/` stayed, `SYMLINK_DIRS="claude/skills
claude/commands"` would have covered the Claude rows natively.

## Migration

One time, in order:

1. `git mv claude ai`; `git mv ai/CLAUDE.md ai/AGENTS.md`; move `settings.json`,
   `statusline-command.sh`, `agents/`, `scripts/` under `ai/claude/`.
2. Copy the five vendored skills in from `~/.agents/skills/`. Commit.
3. Add `ai` to `EXCLUDES` in `rcrc` so `rcup` stops per-file-linking that tree and does not
   try to create `~/.ai/`. Do this **before** the next `rcup`.
4. Clear the conflicts by hand — `bin/link-agents` will refuse all of these, by design.
   Assert every path is a symlink or a directory of symlinks, then remove
   `~/.claude/{skills,commands,agents,scripts}` and the three file links
   `~/.claude/{CLAUDE.md,settings.json,statusline-command.sh}`. Move `~/.agents/skills` aside
   to `~/.agents/skills.pre-dotfiles` rather than deleting it.
5. Run `$DOTFILES/bin/link-agents`.
6. Once verified, delete `~/.agents/skills.pre-dotfiles` and `~/.agents/.skill-lock.json`.

Step 4 is safe because `~/.claude/commands`, `~/.claude/agents`, and `~/.claude/scripts` were
confirmed to hold zero non-symlink files, and the only real content under `~/.claude/skills`
is the five entries being vendored.

## Knock-on changes

- `rcrc` — add `ai` to `EXCLUDES`.
- `bin/sync` — drop `~/.claude/skills`, `~/.claude/commands`, and `~/.claude/agents` from
  `WATCHED_DIRS`; they cannot drift now. Keep `~/.config/zed`. Call
  `$DOTFILES/bin/link-agents` before the commit prompt so new harnesses get wired on every sync.
- `bootstrap.sh` — call `$DOTFILES/bin/link-agents` immediately after `rcup`.
- `.gitignore` — no change; `.DS_Store` is already covered.

## Out of scope

Subagents (`ai/claude/agents/`), `settings.json`, `statusline-command.sh`, and
`ai/claude/scripts/` stay Claude-only — the formats have no equivalent in Codex or opencode.
Nothing rewrites skill content to be portable; skills that call Claude-specific tools will
misbehave in other harnesses and get fixed reactively.

One thing to keep an eye on rather than solve now: `~/.claude/settings.json` is a symlink into
the repo and Claude Code writes to that file when config changes. It has held as a symlink
since 2026-05-19, so the current write path follows the link. If a future version switches to
an atomic write-temp-then-rename, the symlink is silently replaced by a real file and the repo
quietly stops tracking config edits. `bin/link-agents --dry-run` catches it — the row flips
from "already correct" to a real-file refusal.

## opencode duplicate discovery — resolved

opencode discovers the same skills through both `~/.claude/skills` and `~/.agents/skills`,
which resolve to one directory. It **dedupes by frontmatter `name`** — the registry is a map
keyed by name, so each skill registers once, not twice. The only cost is a "duplicate skill
name" log warning per colliding skill. That is a plain log line, not a session error, so it
never surfaces in the TUI.

Silence it on install, if the log noise is worth removing, with
`OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1` — that drops `~/.claude/skills` and keeps
`~/.agents/skills`, which Codex needs anyway. Use that narrow flag, **not**
`OPENCODE_DISABLE_CLAUDE_CODE=1`: the broad one also disables the `~/.claude/CLAUDE.md`
instruction fallback. There is no flag that drops `.agents` alone, and neither is an
`opencode.json` key — both are environment variables only.

Verified against opencode source (`anomalyco/opencode` @ `b7f9363`), not the docs.

## Verification

`~/.bin` does not exist on this machine, so `link-agents` is not on `PATH` — invoke it as
`$DOTFILES/bin/link-agents`, which is also how `bootstrap.sh` and `bin/sync` call it.

1. `$DOTFILES/bin/link-agents --dry-run` — every row resolves, no refusals.
2. No broken links — must print nothing. Under `-L`, `find` can only still report a symlink
   as `-type l` when it fails to resolve, so any output here is a dangling link:
   `find -L ~/.claude ~/.agents ~/.codex -maxdepth 2 -type l -print`
3. Re-run `$DOTFILES/bin/link-agents` — reports all-skip, proving idempotency.
4. `git status` clean; `ls ai/skills | wc -l` returns 29.
5. Launch `claude` — `/speak-as-todd` and `/todd:plan` resolve.
6. Launch `codex` — `/skills` lists the vendored and own skills, and nothing appears twice.
7. `rcup -v` — does not touch anything under `ai/` or `~/.claude/`. Verified in a scratch repo:
   `EXCLUDES="ai"` prunes the whole subtree, where the unexcluded control lists
   `~/.ai/skills/foo/SKILL.md`.

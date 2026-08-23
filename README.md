# dotfiles

My personal config for zsh, git, Zed, Claude Code, and a few CLI tools. Managed with [rcm](https://github.com/thoughtbot/rcm).

## Bootstrap a new Mac

One command from a clean machine:

```sh
git clone https://github.com/toddwprice/dotfiles.git ~/.dotfiles
~/.dotfiles/bootstrap.sh
```

`bootstrap.sh` is idempotent and safe to re-run. It:

1. Installs Homebrew (if missing) and `rcm`
2. Symlinks everything into `$HOME` with `rcup`. The tracked `rcrc` is passed via `RCRC` on the first run so `EXCLUDES` is honored before `~/.rcrc` exists; that same run links `rcrc` → `~/.rcrc`, so plain `rcup` works from then on
3. Installs the rest of the toolchain from the `Brewfile`
4. Installs oh-my-zsh and the custom plugins the shell config expects (`zsh-autosuggestions`, `zsh-shift-select`) — neither is a brew formula, so a fresh machine needs them or zsh errors on startup

It deliberately does **not** copy secrets — see the next section.

Prefer to do it by hand? The four steps map to `brew install rcm`, `env RCRC=$HOME/.dotfiles/rcrc rcup`, `brew bundle --file=~/.dotfiles/Brewfile`, then the oh-my-zsh installer + plugin clones. Use `lsrc` to preview what will be linked before running `rcup`, and `rcdn` to unlink.

## Secrets and machine-specific config

Nothing secret lives in this repo. The tracked `zshrc` sources three out-of-repo files at the end, none of which are tracked:

```sh
# Environment variables — API keys, tokens, anything sensitive
[[ -f ~/.env ]] && source ~/.env

# Personal and work-specific shell config — aliases, paths, helpers
[[ -r ~/.config/zsh/personal.zsh ]] && source ~/.config/zsh/personal.zsh
[[ -r ~/.config/zsh/dscout.zsh ]]   && source ~/.config/zsh/dscout.zsh
```

If you fork this, mirror that pattern: drop secrets into `~/.env`, host- or context-specific shell config into `~/.config/zsh/*.zsh`, and the public `zshrc` stays portable. The `.gitignore` already covers `.env`, `*.local`, common key formats, and credential filenames as a defense in depth.

## What's in here

- **Shell** &mdash; zsh config and Powerlevel10k prompt, with an oh-my-zsh backup layer
- **Git** &mdash; aliases, diff/rerere config, and a global gitignore
- **Editor** &mdash; Zed settings
- **CLI tools** &mdash; `gh`, taskwarrior, yarn
- **Claude Code** &mdash; personal `settings.json` and a statusline script in `ai/claude/`
- **Agent skills** &mdash; one shared tree at `ai/skills/`, fanned out whole into every installed harness (Claude Code, Codex, OpenCode, ZCode) by `bin/link-agents` &mdash; see below
- **Homebrew** &mdash; `Brewfile` for one-shot toolchain install (`brew bundle --file=Brewfile`)
- **Sync tooling** &mdash; `bin/sync` to catch drift between `$HOME` and this repo (see below)

The manifest is intentionally category-level rather than file-level so adding a new skill doesn't require touching this README.

## Shared agent config (`ai/`)

Skills are the same across every AI coding tool in use here, so they live once, in `ai/skills/`, instead of once per harness. `ai/AGENTS.md` is the equivalent shared instructions file. `rcup` deliberately ignores `ai/` (see `EXCLUDES` in `rcrc`) because rcm only does per-file symlinks into `$HOME/.<dirname>`, and a harness's own directory (`~/.codex`, `~/.zcode`, ...) also holds live app state &mdash; databases, credentials, `node_modules` &mdash; that must never be touched.

Instead, `bin/link-agents` symlinks `ai/skills` and `ai/AGENTS.md` whole into each installed harness's expected location (`~/.claude/skills`, `~/.codex/skills`, `~/.config/opencode/skills`, `~/.zcode/skills`, and the `AGENTS.md`/`CLAUDE.md` equivalents), plus the Claude-only bits in `ai/claude/` (`settings.json`, `statusline-command.sh`, `agents/`, `scripts/`) into `~/.claude`. A harness that isn't installed is skipped (reported as `gate`), and it never overwrites real content &mdash; a destination holding a real file or directory is refused and reported instead. `bootstrap.sh` runs it right after `rcup`; re-run it by hand any time with `~/.dotfiles/bin/link-agents` (add `--dry-run` to preview).

Because skills are a whole-directory symlink rather than per-file ones, a new skill dropped into `ai/skills/` is already "in" every harness the moment it's saved &mdash; no `mkrc` step, just `git add` and commit.

## Keeping it up to date

rcm uses **per-file symlinks**, which creates an asymmetry:

- **Editing a tracked file** (e.g. `~/.zshrc`) &mdash; the change flows through the symlink to the repo automatically. Just commit when you're ready.
- **Adding a new file in a rcm-tracked directory** (e.g. a new `~/.config/zed/foo.json`) &mdash; the new file lives outside the repo until you `mkrc` it.

(`~/.claude/skills` and its siblings are whole-directory symlinks from `link-agents`, not per-file ones &mdash; a new skill there is already inside the repo, so this doesn't apply to it. See "Shared agent config" above.)

`bin/sync` handles both cases: it scans the watched directories for files that aren't yet symlinked into the repo, offers to `mkrc` them, surfaces uncommitted edits, and prompts for a commit.

```sh
~/.dotfiles/bin/sync
```

Run it whenever you remember &mdash; weekly works for most. Add new watched directories at the top of the script as you start managing them. To refresh the Brewfile, run `brew bundle dump --force --file=~/.dotfiles/Brewfile` separately.

## License

MIT &mdash; see [LICENSE](LICENSE).

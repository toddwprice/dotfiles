# dotfiles

My personal config for zsh, git, Zed, Claude Code, and a few CLI tools. Managed with [rcm](https://github.com/thoughtbot/rcm).

## Bootstrap a new Mac

```sh
# 1. Install Homebrew, then rcm
brew install rcm

# 2. Clone this repo
git clone https://github.com/<your-user>/dotfiles ~/.dotfiles

# 3. Symlink everything into $HOME
env RCRC=$HOME/.dotfiles/rcrc rcup

# 4. Install the rest of the toolchain
brew bundle --file=~/.dotfiles/Brewfile
```

After the first `rcup`, the `rcrc` symlink is in place and you can run plain `rcup` from then on. Use `rcup -n` for a dry run, `lsrc` to see what's currently linked, and `rcdn` to unlink.

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
- **Claude Code** &mdash; personal `settings.json`, custom slash commands in `claude/commands/`, custom agents in `claude/agents/`, and a statusline script
- **Homebrew** &mdash; `Brewfile` for one-shot toolchain install (`brew bundle --file=Brewfile`)
- **Sync tooling** &mdash; `bin/sync` to catch drift between `$HOME` and this repo (see below)

The manifest is intentionally category-level rather than file-level so adding a new slash command or agent doesn't require touching this README.

## Keeping it up to date

rcm uses **per-file symlinks**, which creates an asymmetry:

- **Editing a tracked file** (e.g. `~/.zshrc`) &mdash; the change flows through the symlink to the repo automatically. Just commit when you're ready.
- **Adding a new file in a tracked directory** (e.g. a new `~/.claude/commands/foo.md`) &mdash; the new file lives outside the repo until you `mkrc` it.

`bin/sync` handles both cases: it scans the watched directories for files that aren't yet symlinked into the repo, offers to `mkrc` them, surfaces uncommitted edits, and prompts for a commit.

```sh
~/.dotfiles/bin/sync
```

Run it whenever you remember &mdash; weekly works for most. Add new watched directories at the top of the script as you start managing them. To refresh the Brewfile, run `brew bundle dump --force --file=~/.dotfiles/Brewfile` separately.

## License

MIT &mdash; see [LICENSE](LICENSE).

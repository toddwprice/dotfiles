# dotfiles

My personal config for zsh, git, Claude Code, and a few CLI tools. Managed with [rcm](https://github.com/thoughtbot/rcm).

## Bootstrap a new Mac

```sh
# 1. Install rcm
brew install rcm

# 2. Clone this repo
git clone https://github.com/<your-user>/dotfiles ~/.dotfiles

# 3. Symlink everything into $HOME
env RCRC=$HOME/.dotfiles/rcrc rcup
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

- **Shell** &mdash; `zshrc`, `p10k.zsh` (Powerlevel10k), `zshrc-omz` (oh-my-zsh backup layer)
- **Git** &mdash; `gitconfig` with aliases (`br`, `st`, `co`, `hist`), global gitignore at `config/git/ignore`
- **CLI** &mdash; `taskrc`, `yarnrc`, `config/gh/config.yml`
- **Claude Code** &mdash; `claude/statusline-command.sh`

## License

MIT &mdash; see [LICENSE](LICENSE).

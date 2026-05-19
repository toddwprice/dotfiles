# dotfiles

My personal config for zsh, git, Zed, Claude Code, and a few CLI tools. Managed with [rcm](https://github.com/thoughtbot/rcm).

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

## Secrets

Nothing secret lives in this repo. Anything that needs an API key or token gets sourced from `~/.zshrc.local`, which is gitignored:

```sh
# In zshrc (tracked)
[ -f ~/.zshrc.local ] && source ~/.zshrc.local

# In ~/.zshrc.local (NOT tracked)
export ANTHROPIC_AUTH_TOKEN="..."
export SOME_OTHER_TOKEN="..."
```

Same pattern for any host-specific config: drop it in `~/.zshrc.local` and it stays out of git.

## What's in here

- **Shell** &mdash; `zshrc`, `p10k.zsh` (Powerlevel10k), oh-my-zsh backup layers
- **Git** &mdash; `gitconfig` with aliases (`br`, `st`, `co`, `hist`), global gitignore at `config/git/ignore`
- **Editor** &mdash; `config/zed/` (settings, prompts, themes)
- **CLI** &mdash; `taskrc`, `yarnrc`, `config/gh/config.yml`
- **Claude Code** &mdash; `claude/settings.json`, custom commands at `claude/commands/`, `claude/statusline-command.sh`

## License

MIT &mdash; see [LICENSE](LICENSE).

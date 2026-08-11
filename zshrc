# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

source $(brew --prefix)/share/powerlevel10k/powerlevel10k.zsh-theme

# Editor
export EDITOR="zed --wait"

#PATHs
export PATH=$HOME/bin:/usr/local/bin:$PATH
export PATH="/bin:$PATH"
export PATH="/opt/local/bin:$PATH"
export PATH="/opt/local/sbin:$PATH"
export PATH="/opt/X11/bin:$PATH"
export PATH="/sbin:$PATH"
export PATH="/usr/bin:$PATH"
export PATH="/usr/local/sbin:$PATH"
export PATH="/usr/sbin:$PATH"
export PATH="/opt/homebrew/bin:$PATH"
export PATH="$HOME/.asdf/shims:$PATH"
export PATH="$HOME/.claude/scripts:$PATH"

# omz
export ZSH="$HOME/.oh-my-zsh"
#ZSH_THEME="robbyrussell"
plugins=(git zsh-shift-select zsh-autosuggestions async gh-pr-status)
ZSH_THEME="gh-pr-status"
source $ZSH/oh-my-zsh.sh

# keybindings
# This binds the Zsh selection buffer to the macOS clipboard
copy-selection-to-clipboard() {
  zle copy-region-as-kill
  printf "%s" "$CUTBUFFER" | pbcopy
}
zle -N copy-selection-to-clipboard
bindkey "^[c" copy-selection-to-clipboard # Maps Option+C to copy the keyboard selection

# AWS CLI pager disable
export AWS_PAGER=""
# Enable bash completion for AWS CLI v2
autoload -U +X bashcompinit && bashcompinit

# Start Claude Code with official Anthropic models (Default)
ccc() {
    unset ANTHROPIC_BASE_URL
    unset ANTHROPIC_AUTH_TOKEN
    claude "$@"
}

# # Node Version Manager
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

export PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
export PATH="$HOME/.local/bin:$PATH"

export PATH="/opt/homebrew/opt/ffmpeg@6/bin:$PATH"

# Load personal environment variables (secrets, tokens) — kept out of the public repo
[[ -f ~/.env ]] && source ~/.env

# aliases
alias z="zed ~/.zshrc"
alias ll="ls -alh"
alias gitclean='git branch --merged origin/main | grep -vE "^\s*(\*|main)" | xargs -n 1 git branch -d'
alias python="python3"
alias awslocal="aws --endpoint-url=http://localhost:4566"
alias rebaseFromMain="git fetch && git pull && git rebase origin/main && git push --force-with-lease"
alias gp="git push --force-with-lease"
alias gbcp="git branch --show-current | tee >(tr -d '\n' | pbcopy)"
alias ddu="dscout-down && dscout-up"

# Docker compose shorthand
alias dc="docker compose"

# Personal + work zsh config (kept out of the public repo)
[[ -r ~/.config/zsh/personal.zsh ]] && source ~/.config/zsh/personal.zsh
[[ -r ~/.config/zsh/dscout.zsh ]]   && source ~/.config/zsh/dscout.zsh

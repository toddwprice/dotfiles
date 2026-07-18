#!/usr/bin/env bash
#
# Bootstrap a new Mac from this dotfiles repo.
#
#   git clone https://github.com/toddwprice/dotfiles.git ~/.dotfiles
#   ~/.dotfiles/bootstrap.sh
#
# Idempotent — safe to re-run. It installs Homebrew + rcm, symlinks everything
# with rcup, installs the Brewfile toolchain, and sets up oh-my-zsh plus the
# custom plugins the shell config expects.
#
# It deliberately does NOT copy secrets. After it finishes, drop your ~/.env
# and ~/.config/zsh/*.zsh files in by hand (see the closing note).

set -euo pipefail

DOTFILES="${HOME}/.dotfiles"

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }

# -- 1. Homebrew -----------------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
  info "Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Put brew on PATH for the rest of this script (Apple Silicon vs Intel).
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# -- 2. rcm ----------------------------------------------------------------
if ! command -v rcup >/dev/null 2>&1; then
  info "Installing rcm"
  brew install rcm
fi

# -- 3. Symlink dotfiles ---------------------------------------------------
# Pass RCRC explicitly so EXCLUDES is honored before ~/.rcrc exists; this run
# also links the repo's rcrc -> ~/.rcrc, so plain `rcup` works from then on.
info "Linking dotfiles with rcup"
env RCRC="$DOTFILES/rcrc" rcup

# -- 4. Brewfile toolchain -------------------------------------------------
info "Installing Brewfile packages"
brew bundle --file="$DOTFILES/Brewfile"

# -- 5. oh-my-zsh + custom plugins ----------------------------------------
# Neither oh-my-zsh nor these plugins are brew formulae, and the shell config
# sources them unconditionally, so a fresh machine needs them or zsh errors.
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  info "Installing oh-my-zsh"
  # KEEP_ZSHRC: don't clobber the .zshrc symlink rcup just created.
  # RUNZSH/--unattended: don't chsh or drop into a new shell mid-script.
  RUNZSH=no KEEP_ZSHRC=yes sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    "" --unattended
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
clone_plugin() {
  local repo="$1" dir="$ZSH_CUSTOM/plugins/$2"
  if [[ ! -d "$dir" ]]; then
    info "Cloning plugin $2"
    git clone --depth 1 "$repo" "$dir"
  fi
}
clone_plugin https://github.com/zsh-users/zsh-autosuggestions zsh-autosuggestions
clone_plugin https://github.com/jirutka/zsh-shift-select       zsh-shift-select

# -- Done ------------------------------------------------------------------
cat <<'EOF'

✅ Bootstrap complete.

Still to do by hand — secrets, never tracked in this repo:
  • ~/.env                     API keys, tokens
  • ~/.config/zsh/personal.zsh personal aliases / paths
  • ~/.config/zsh/dscout.zsh   work aliases / paths

Then set your terminal font to a Nerd Font (font-hack-nerd-font is installed)
and open a new shell.
EOF

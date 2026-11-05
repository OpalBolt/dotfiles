#!/usr/bin/env bash
# Bootstrap these dotfiles on a Debian server. Safe to run again.
#   ./bootstrap.sh              install packages, plugins, stow, set shell
#   ./bootstrap.sh --stow-only  only re-stow the links
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STOW_DIR="$(dirname "$REPO")"
STOW_PKG="$(basename "$REPO")"

PACKAGES=(zsh git stow tmux fzf ripgrep btop bat vim less curl zoxide direnv gpg)

restow() {
    # --no-folding keeps ~/.ssh a real directory, so only our files are linked
    stow --restow --no-folding -v --dir="$STOW_DIR" --target="$HOME" "$STOW_PKG"
    chmod 700 "$HOME/.ssh"
    chmod 600 "$REPO/.ssh/"* 2>/dev/null || true
}

if [[ ${1:-} == --stow-only ]]; then
    restow
    exit 0
fi

if ! command -v apt-get >/dev/null; then
    echo "This script targets Debian-based systems." >&2
    exit 1
fi

SUDO=""
[[ $EUID -ne 0 ]] && SUDO="sudo"

echo "==> Installing packages"
$SUDO apt-get update
$SUDO apt-get install -y "${PACKAGES[@]}"

# Debian names the binary batcat
mkdir -p "$HOME/.local/bin"
if command -v batcat >/dev/null && ! command -v bat >/dev/null; then
    ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
fi

echo "==> Installing tmux plugin manager and zplug"
[[ -d $HOME/.config/tmux/plugins/tpm ]] ||
    git clone --depth 1 https://github.com/tmux-plugins/tpm "$HOME/.config/tmux/plugins/tpm"
[[ -d $HOME/.config/zsh/.zplug ]] ||
    git clone --depth 1 https://github.com/zplug/zplug.git "$HOME/.config/zsh/.zplug"

echo "==> Linking dotfiles"
mkdir -p "$HOME/.ssh"
restow

echo "==> Installing tmux plugins"
"$HOME/.config/tmux/plugins/tpm/bin/install_plugins" || true

if [[ $(basename "${SHELL:-}") != zsh ]]; then
    echo "==> Setting login shell to zsh"
    chsh -s "$(command -v zsh)" || echo "chsh failed; run it manually."
fi

cat <<'EOF'

Done. Optional tools not in Debian's repos (install as needed):
  starship, mise, atuin, eza, lazygit, delta, nvim (LazyVim)
Install zsh plugins once with: zsh -ic 'zplug install'
EOF

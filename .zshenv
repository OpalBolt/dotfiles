# shellcheck shell=bash # shellcheck has no zsh mode; file is zsh, sourced by zsh (no shebang)
# ~/.zshenv — always sourced by zsh (interactive, scripts, login or not).
# Keep this file minimal: it only redirects zsh to the real, XDG-compliant
# config living under .config/zsh (mirrors how fishold lived under .config).
export ZDOTDIR="$HOME/.config/zsh"
# shellcheck disable=SC1090 # sourced path depends on ZDOTDIR
[ -f "$ZDOTDIR/.zshenv" ] && source "$ZDOTDIR/.zshenv"

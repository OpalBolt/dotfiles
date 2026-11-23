# shellcheck shell=bash # shellcheck has no zsh mode; file is zsh, sourced by zsh (no shebang)
# $ZDOTDIR/.zshenv — sourced for every zsh invocation (interactive or not).
# Only universal env/PATH setup belongs here; interactive-only setup
# (prompt, tool widgets, aliases) lives in .zshrc instead.

# dedupe PATH-like arrays automatically (equivalent to fish_add_path's
# built-in dedup, so re-sourcing never produces duplicate entries)
# shellcheck disable=SC2034 # fpath is zsh's completion path array, consumed by compinit
typeset -U path fpath

# shellcheck disable=SC2206 # zsh never word-splits unquoted expansions; appending $path is idiomatic
path=("$HOME/go/bin" "$HOME/.cargo/bin" "$HOME/.local/bin" "$HOME/scripts" $path)

export EDITOR=nvim
export VISUAL=nvim
export READER=zathura
export TERMINAL=foot
export BROWSER=firefox
export PAGER=bat
export OLLAMA_IGPU_ENABLE=1
export XDG_CONFIG_HOME="$HOME/.config"

# $ZDOTDIR/.zshenv — sourced for every zsh invocation (interactive or not).
# Only universal env/PATH setup belongs here; interactive-only setup
# (prompt, tool widgets, aliases) lives in .zshrc instead.

# dedupe PATH-like arrays automatically (equivalent to fish_add_path's
# built-in dedup, so re-sourcing never produces duplicate entries)
typeset -U path fpath

path=("$HOME/go/bin" "$HOME/.cargo/bin" "$HOME/.local/bin" $path)

export EDITOR=nvim
export VISUAL=nvim
# Debian ships bat as "batcat"; bootstrap.sh links it, but fall back to less.
if command -v bat >/dev/null 2>&1; then export PAGER=bat; else export PAGER=less; fi
export LESS='-R -F -i -M -X'
export XDG_CONFIG_HOME="$HOME/.config"

#!/bin/sh
# zj — fzf picker over zellij sessions + layout files. Attach or create.
# Reusable anywhere with POSIX sh + fzf + zellij:
#   ZJ_LAYOUTS_DIR=/some/dir zj.sh    (default ~/.config/zellij/layouts)
set -eu

dir="${ZJ_LAYOUTS_DIR:-$HOME/.config/zellij/layouts}"

# layouts + session names (first token strips any "(EXITED)" annotation),
# deduped — a running "homelab" and homelab.kdl show as one line.
list=$(
    { ls -- "$dir"/*.kdl 2>/dev/null | sed 's|.*/||; s|\.kdl$||';
      zellij list-sessions -n 2>/dev/null | awk '{print $1}' || :; } | sort -u
)

# nothing to pick yet → the default session (default.kdl → ~/git)
[ -n "$list" ] || exec zellij attach --create main

choice=$(printf '%s\n' "$list" | fzf --prompt='⚡ ' \
    --preview='f="'"$dir"'"/{}.kdl; if [ -f "$f" ]; then command -v bat >/dev/null 2>&1 && bat --color=always -- "$f" || cat -- "$f"; else echo "↩ attach (resurrects if exited) — no layout file"; fi') || exit 0

if zellij list-sessions -n 2>/dev/null | awk '{print $1}' | grep -qx -- "$choice"; then
    exec zellij attach "$choice"                        # running/exited → attach
elif [ -f "$dir/$choice.kdl" ]; then
    exec zellij --session "$choice" --layout "$dir/$choice.kdl"   # layout → create
else
    exec zellij attach --create "$choice"               # typed a new name → default layout
fi

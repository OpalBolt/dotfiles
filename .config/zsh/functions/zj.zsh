# zj — fuzzy-pick a zellij session or layout.
# Port of fishold/functions/zj.fish, using `tv` (television) instead of `fzf`
# per user preference. Keybinds used here are tv's own result-navigation keys
# (arrows/enter) only — nothing that could collide with shell or tv shell
# integration bindings (Ctrl-T/Ctrl-R).
zj() {
    emulate -L zsh
    local dir=~/.config/zellij/layouts
    local -a sessions
    sessions=("${(@f)$(zellij list-sessions -n 2>/dev/null | awk '{print $1}')}")
    sessions=(${sessions:#})

    # no session yet → start the default one (default.kdl → ~/git)
    if (( ${#sessions} == 0 )); then
        exec zellij --session default --layout "$dir/default.kdl"
    fi

    # layouts + session names, deduped — a running "homelab" and homelab.kdl show as one line
    local -a list
    list=("${(@f)$({
        ls "$dir"/*.kdl 2>/dev/null | sed 's|.*/||; s|\.kdl$||'
        printf '%s\n' "${sessions[@]}"
    } | sort -u)}")

    # tv runs the preview with $SHELL (= zsh), so it must be zsh syntax
    local preview='f='"$dir"'/{}.kdl; if [[ -f "$f" ]]; then bat --color=always "$f"; else echo "↩ attach (resurrects if exited) — no layout file"; fi'
    local choice
    choice=$(printf '%s\n' "${list[@]}" | tv --input-prompt='⚡ ' --preview-command="$preview") || return

    if (( ${sessions[(Ie)$choice]} )); then
        exec zellij attach "$choice"                                # running/exited → attach
    elif [[ -f "$dir/$choice.kdl" ]]; then
        exec zellij --session "$choice" --layout "$dir/$choice.kdl" # layout → create
    else
        exec zellij attach --create "$choice"                       # typed a new name → default layout
    fi
}

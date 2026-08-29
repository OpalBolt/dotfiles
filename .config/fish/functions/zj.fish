function zj --description "fuzzy-pick a zellij session or layout"
    set -l dir ~/.config/zellij/layouts
    set -l sessions (zellij list-sessions -n 2>/dev/null | awk '{print $1}')

    # no session yet → start the default one (default.kdl → ~/git)
    if not set -q sessions[1]
        exec zellij --session default --layout $dir/default.kdl
    end

    # layouts + session names, deduped — a running "homelab" and homelab.kdl show as one line
    set -l list (begin
        ls $dir/*.kdl 2>/dev/null | sed 's|.*/||; s|\.kdl$||'
        printf '%s\n' $sessions
    end | sort -u)

    # fzf runs the preview with $SHELL (= fish), so it must be fish syntax
    set -l preview 'set f '$dir'/{}.kdl; if test -f $f; bat --color=always $f; else; echo "↩ attach (resurrects if exited) — no layout file"; end'
    set -l choice (printf '%s\n' $list | fzf --prompt='⚡ ' --preview="$preview")
    or return

    if contains -- $choice $sessions
        exec zellij attach $choice                                 # running/exited → attach
    else if test -f $dir/$choice.kdl
        exec zellij --session $choice --layout $dir/$choice.kdl    # layout → create
    else
        exec zellij attach --create $choice                        # typed a new name → default layout
    end
end

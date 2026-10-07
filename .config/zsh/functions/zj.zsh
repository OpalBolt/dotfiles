# zj — fuzzy-pick a zellij session, layout, or project folder using Television (tv)
zj() {
    emulate -L zsh
    local layout_dir="${ZELLIJ_LAYOUTS_DIR:-$HOME/.config/zellij/layouts}"

    # 1. Fetch active/exited Zellij sessions
    local -a sessions
    sessions=("${(@f)$(zellij list-sessions -n 2>/dev/null | grep -v '^No ' | sed $'s/\x1b\\[[0-9;]*m//g' | awk '{print $1}')}")
    sessions=(${sessions:#})
    sessions=(${sessions:#No*})

    # Unformatted item collectors
    local -a cat_list name_list target_list

    # 2. Defaults Section (Pinned)
    local -a defaults=(default homelab)
    local d d_path
    for d in "${defaults[@]}"; do
        d_path="$layout_dir/$d.kdl"
        cat_list+=("📌 Default")
        name_list+=("$d")
        if [[ -f "$d_path" ]]; then
            target_list+=("$d_path")
        else
            target_list+=("session:$d")
        fi
    done

    # 3. Active Sessions Section
    local s
    for s in "${sessions[@]}"; do
        if (( ! ${defaults[(Ie)$s]} )); then
            cat_list+=("⚡ Session")
            name_list+=("$s")
            target_list+=("session:$s")
        fi
    done

    # 4. Standard Git Projects (~/git/*) — Exclude custproj container folder
    if [[ -d "$HOME/git" ]]; then
        local g
        for g in "$HOME/git"/*(/N:t); do
            [[ "$g" == "custproj" ]] && continue
            cat_list+=("📁 git")
            name_list+=("$g")
            target_list+=("$HOME/git/$g")
        done
    fi

    # 5. Customer Business Projects (~/git/custproj/<Customer>/<Project>)
    if [[ -d "$HOME/git/custproj" ]]; then
        local c_dir p_dir c_name p_name
        for c_dir in "$HOME/git/custproj"/*(/N); do
            c_name="${c_dir:t}"
            for p_dir in "$c_dir"/*(/N); do
                p_name="${p_dir:t}"
                cat_list+=("💼 $c_name")
                name_list+=("$p_name")
                target_list+=("$p_dir")
            done
        done
    fi

    # 6. Other Projects (~/projects/*)
    if [[ -d "$HOME/projects" ]]; then
        local pr
        for pr in "$HOME/projects"/*(/N:t); do
            cat_list+=("📁 projects")
            name_list+=("$pr")
            target_list+=("$HOME/projects/$pr")
        done
    fi

    # 7. Standalone Layout Files Section
    if [[ -d "$layout_dir" ]]; then
        local l
        for l in "$layout_dir"/*.kdl(N:t:r); do
            if (( ! ${defaults[(Ie)$l]} )); then
                cat_list+=("📐 Layout")
                name_list+=("$l")
                target_list+=("$layout_dir/$l.kdl")
            fi
        done
    fi

    if (( ${#cat_list} == 0 )); then
        exec zellij
    fi

    # 8. Dynamic Column Width Alignment
    integer max_cat=0
    integer max_name=0
    integer i len_c len_n

    for (( i=1; i<=${#cat_list}; i++ )); do
        len_c=${#cat_list[i]}
        len_n=${#name_list[i]}
        (( len_c > max_cat )) && max_cat=$len_c
        (( len_n > max_name )) && max_name=$len_n
    done

    # Cap widths so overly wide names don't push content off-screen
    (( max_cat > 28 )) && max_cat=28
    (( max_name > 30 )) && max_name=30

    # 9. Format Final List with Padded Separators
    local -a formatted_list
    local c_str n_str
    for (( i=1; i<=${#cat_list}; i++ )); do
        c_str="${cat_list[i]}"
        n_str="${name_list[i]}"

        if (( ${#c_str} > max_cat )); then
            c_str="${c_str[1,$((max_cat-1))]}…"
        fi
        if (( ${#n_str} > max_name )); then
            n_str="${n_str[1,$((max_name-1))]}…"
        fi

        formatted_list+=("${(r:max_cat:)c_str} │ ${(r:max_name:)n_str} │ ${target_list[i]}")
    done

    # 10. Dynamic Preview Pane for Television
    local preview='
line="{}"
target=$(echo "$line" | awk -F "│" "{print \$3}" | xargs)
name=$(echo "$line" | awk -F "│" "{print \$2}" | xargs)

if [[ -d "$target" ]]; then
    echo "📁 Directory: $target"
    echo "────────────────────────────────────────"
    if command -v eza &>/dev/null; then
        eza --tree --level=2 --color=always --icons "$target" 2>/dev/null || eza -la "$target"
    else
        ls -la "$target"
    fi
elif [[ -f "$target" ]]; then
    echo "📄 Layout File: $target"
    echo "────────────────────────────────────────"
    bat --color=always --style=snip "$target" 2>/dev/null || cat "$target"
else
    echo "⚡ Zellij Session: $name"
    echo "────────────────────────────────────────"
    echo "↩ Attach or resurrect active session"
fi'

    # 11. Fuzzy Selection via Television
    local choice
    choice=$(printf '%s\n' "${formatted_list[@]}" | tv --input-prompt='⚡ ' --preview-command="$preview") || return 0

    [[ -z "$choice" ]] && return 0

    # 12. Parse Selection Natively in Zsh (100% Reliable Path Extraction)
    local -a parts=("${(s:│:)choice}")
    local selected_name="${${parts[2]##[[:space:]]#}%%[[:space:]]#}"
    local target="${${parts[3]##[[:space:]]#}%%[[:space:]]#}"

    # 13. Execute Zellij Action
    if [[ -d "$target" ]]; then
        cd "$target" || return 1
        if (( ${sessions[(Ie)$selected_name]} )); then
            exec zellij attach "$selected_name"
        else
            # Explicitly set --default-cwd so Zellij layouts don't reset CWD to ~/git
            exec zellij attach --create "$selected_name" options --default-cwd "$target"
        fi
    elif [[ "$target" == session:* ]]; then
        local s_name="${target#session:}"
        exec zellij attach "$s_name"
    elif [[ -f "$target" ]]; then
        exec zellij --session "$selected_name" --layout "$target"
    else
        exec zellij attach --create "$selected_name"
    fi
}

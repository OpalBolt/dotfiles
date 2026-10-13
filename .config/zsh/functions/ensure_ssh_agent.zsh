# ensure_ssh_agent — start and populate the local SSH agent.
# Usage: ensure_ssh_agent [-c|--clear] [key_name ...]
# Keys not found in Bitwarden are skipped with a notice.
ensure_ssh_agent() {
    emulate -L zsh
    setopt local_options pipefail

    local clear=0
    local -a key_names
    while (( $# )); do
        case "$1" in
            -c|--clear) clear=1 ;;
            --) shift; key_names+=("$@"); break ;;
            -*)
                print -u2 "ensure_ssh_agent: unknown option: $1"
                return 1
                ;;
            *) key_names+=("$1") ;;
        esac
        shift
    done

    [[ -o interactive ]] || return 0

    # A forwarded or otherwise configured agent always takes precedence.
    if [[ -n "$SSH_AUTH_SOCK" ]]; then
        (( clear )) || return 0
    else
        export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
    fi

    if ! (( $+commands[ssh-add] )); then
        print -u2 "Cannot initialize SSH agent: ssh-add is unavailable."
        return 1
    fi

    ssh-add -l >/dev/null 2>&1
    local agent_status=$?

    # Exit 2 means no agent is reachable. Exit 1 means it has no keys.
    if (( agent_status == 2 )); then
        rm -f -- "$SSH_AUTH_SOCK"

        local agent_output
        agent_output="$(ssh-agent -a "$SSH_AUTH_SOCK")"
        if (( $? != 0 )); then
            print -u2 "Failed to start SSH agent."
            return 1
        fi

        eval "$agent_output" >/dev/null
        agent_status=1
    fi

    if (( clear )) && (( agent_status == 0 )); then
        ssh-add -D >/dev/null
        if (( $? != 0 )); then
            print -u2 "Failed to clear SSH agent keys."
            return 1
        fi
        agent_status=1
    fi

    if (( agent_status == 1 )); then
        (( ${#key_names} )) || return 0

        if ! (( $+commands[bw] && $+commands[jq] )); then
            print -u2 "Cannot load SSH key: bw or jq is unavailable."
            return 1
        fi

        local bw_session="$BW_SESSION"
        if [[ -z "$bw_session" ]]; then
            bw_session="$(bw unlock --raw)"
            if (( $? != 0 )) || [[ -z "$bw_session" ]]; then
                print -u2 "Failed to unlock Bitwarden."
                return 1
            fi
        fi

        local -a key_lines
        key_lines=("${(@f)$(
            bw list items --session "$bw_session" \
                | jq -r --args '
                    ($ARGS.positional | unique) as $names
                    | [.[] | select(.name as $name | $names | index($name))
                       | select(.sshKey.privateKey? != null)]
                    | unique_by(.name)[]
                    | .name + "\t" + (.sshKey.privateKey | @base64)
                ' "${key_names[@]}"
        )}")
        if (( $? != 0 )); then
            print -u2 "Failed to retrieve SSH keys from Bitwarden."
            return 1
        fi

        local -A loaded_keys
        local -a loaded_names failed_names missing_names
        local line key_name encoded_key
        for line in "${key_lines[@]}"; do
            key_name="${line%%$'\t'*}"
            encoded_key="${line#*$'\t'}"
            if printf '%s' "$encoded_key" | base64 --decode | ssh-add -t 12h -; then
                loaded_keys[$key_name]=1
                loaded_names+=("$key_name")
            else
                loaded_keys[$key_name]=2
                failed_names+=("$key_name")
            fi
        done

        local key
        for key in "${(@u)key_names[@]}"; do
            [[ -n "${loaded_keys[$key]}" ]] || missing_names+=("$key")
        done

        (( ${#loaded_names} )) && print "ensure_ssh_agent: loaded ${loaded_names[*]}"
        (( ${#missing_names} )) && print "ensure_ssh_agent: skipped ${missing_names[*]} (not found in Bitwarden)"
        (( ${#failed_names} )) && print -u2 "ensure_ssh_agent: failed to load ${failed_names[*]}"
        (( ${#failed_names} )) && return 1
        return 0
    fi
}

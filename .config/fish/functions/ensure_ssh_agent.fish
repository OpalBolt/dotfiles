function ensure_ssh_agent --description "Start and populate the local SSH agent"
    argparse --name=ensure_ssh_agent 'c/clear' -- $argv; or return
    set -l key_names $argv

    status is-interactive; or return

    # A forwarded or otherwise configured agent always takes precedence.
    if test -n "$SSH_AUTH_SOCK"
        if not set -q _flag_clear
            return
        end
    else
        set -gx SSH_AUTH_SOCK "$HOME/.ssh/agent.sock"
    end

    if not type -q ssh-add
        echo "Cannot initialize SSH agent: ssh-add is unavailable." >&2
        return 1
    end

    ssh-add -l >/dev/null 2>&1
    set -l agent_status $status

    # Exit 2 means no agent is reachable. Exit 1 means it has no keys.
    if test $agent_status -eq 2
        rm -f -- "$SSH_AUTH_SOCK"

        set -l agent_output (ssh-agent -a "$SSH_AUTH_SOCK" -c)
        if test $status -ne 0
            echo "Failed to start SSH agent." >&2
            return 1
        end

        eval $agent_output >/dev/null
        set agent_status 1
    end

    if set -q _flag_clear; and test $agent_status -eq 0
        ssh-add -D >/dev/null
        if test $status -ne 0
            echo "Failed to clear SSH agent keys." >&2
            return 1
        end

        set agent_status 1
    end

    if test $agent_status -eq 1
        if test (count $key_names) -eq 0
            return
        end

        if not type -q bw jq
            echo "Cannot load SSH key: bw or jq is unavailable." >&2
            return 1
        end

        set -l bw_session "$BW_SESSION"
        if test -z "$bw_session"
            set bw_session (bw unlock --raw)
            if test $status -ne 0; or test -z "$bw_session"
                echo "Failed to unlock Bitwarden." >&2
                return 1
            end
        end

        set -l encoded_keys (
            bw list items --session "$bw_session" \
                | jq -er --args '
                    . as $items
                    | ($ARGS.positional | unique) as $names
                    | [$items[] | select(.name as $name | $names | index($name))
                       | select(.sshKey.privateKey? != null)
                       | .name] | unique as $found
                    | ($names - $found) as $missing
                    | if $missing != [] then
                        error("Missing SSH keys in Bitwarden: " + ($missing | join(", ")))
                      else
                        $items[] | select(.name as $name | $names | index($name))
                        | .sshKey.privateKey | @base64
                      end
                ' $key_names
        )
        if test $status -ne 0
            echo "Failed to retrieve SSH keys from Bitwarden." >&2
            return 1
        end

        for encoded_key in $encoded_keys
            printf '%s' "$encoded_key" \
                | base64 --decode \
                | ssh-add -t 12h -
            set -l key_status $pipestatus

            if string match -rqv '^0$' -- $key_status
                echo "Failed to load an SSH key from Bitwarden." >&2
                return 1
            end
        end
    end
end

function ensure_ssh_agent --description "Start and populate the local SSH agent"
    status is-interactive; or return

    # A forwarded or otherwise configured agent always takes precedence.
    if test -n "$SSH_AUTH_SOCK"
        return
    end

    if not type -q ssh-add
        echo "Cannot initialize SSH agent: ssh-add is unavailable." >&2
        return 1
    end

    set -gx SSH_AUTH_SOCK "$HOME/.ssh/agent.sock"

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

    if test $agent_status -eq 1
        if not type -q bw jq
            echo "Cannot load SSH key: bw or jq is unavailable." >&2
            return 1
        end

        bw get item main-ssh \
            | jq -er '.sshKey.privateKey' \
            | ssh-add -t 12h -
        set -l key_status $pipestatus

        if string match -rqv '^0$' -- $key_status
            echo "Failed to load main-ssh from Bitwarden." >&2
            return 1
        end
    end
end

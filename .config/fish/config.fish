if status is-interactive
    fastfetch
    # Commands to run in interactive sessions can go here
end

# Ensure that we do not get Fish splash screen
set fish_greeting

zoxide init fish | source
starship init fish | source
direnv hook fish | source
fzf --fish | source
mise activate fish | source
envoke shell-init --shell fish | source

# one local agent per machine, reused across shells; never clobber a forwarded socket
if test -z "$SSH_AUTH_SOCK"
    set -gx SSH_AUTH_SOCK $HOME/.ssh/agent.sock
end
if not ssh-add -l >/dev/null 2>&1
    rm -f $SSH_AUTH_SOCK
    eval (ssh-agent -a $SSH_AUTH_SOCK -c) >/dev/null
    bw get item main-ssh | jq -r '.sshKey.privateKey' | ssh-add -t 12h -
end

# uv
fish_add_path "/home/mads/.local/bin"

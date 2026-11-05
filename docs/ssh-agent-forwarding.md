# SSH agent forwarding

Agent forwarding lets the server use the keys on your workstation. The keys never
leave your workstation. The server only gets a socket that asks your agent to sign.

## How it works

1. Your workstation runs an agent with your keys loaded (`ssh-add -l` shows them).
2. You connect with forwarding on: `ssh -A server`, or `ForwardAgent yes` for that host in `~/.ssh/config`.
3. `sshd` creates a socket on the server and sets `SSH_AUTH_SOCK` to it.
4. Tools on the server, such as `git` or `ssh`, use that socket.

## Setup

Workstation, `~/.ssh/config`:

```
Host myserver
    HostName myserver.example.com
    ForwardAgent yes
```

Enable it only for hosts you trust. Root on the server can use your forwarded agent
while you are connected. For a jump host, prefer `ProxyJump` over forwarding.

Server, `/etc/ssh/sshd_config` (this is the default):

```
AllowAgentForwarding yes
```

## Verify

On the server:

```sh
echo $SSH_AUTH_SOCK   # a path under /tmp/ssh-XXXX/ or ~/.ssh/ssh_auth_sock
ssh-add -l            # lists your workstation keys
ssh -T git@github.com
```

## tmux and reconnects

Each SSH login gets a new socket path. A tmux session started earlier keeps the old
path, so forwarding breaks after you reconnect. `.zshrc` fixes this. On login it points
`~/.ssh/ssh_auth_sock` at the new socket and exports that stable path. Panes in the
attached tmux session keep working.

If it still fails, check that your workstation agent has keys, and that you
connected with forwarding on.

## Bitwarden keys

On the workstation, `ensure_ssh_agent` loads keys from Bitwarden. On the server
(`$SSH_CONNECTION` set) it is skipped.

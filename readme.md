# dotfiles

Shell, tmux and git config for headless Debian servers. Desktop config lives in the NixOS repo: <https://codeberg.org/OpalBolt/nixos-config>.

## Install

```sh
git clone <this repo> ~/git/dotfiles
~/git/dotfiles/bootstrap.sh
```

Re-link only: `stup` (or `bootstrap.sh --stow-only`).

## What is in here

- `zsh`: zplug plugins, zoxide, fzf, tmux auto-attach on SSH login
- `tmux`: TPM plugins, `tj` and the sessionizer
- `git`, `lazygit`, `starship`, `btop`, `.vimrc`, `.inputrc`, `~/.ssh/config`

## Docs

- [SSH agent forwarding](docs/ssh-agent-forwarding.md)
- [Server notes](docs/server-notes.md): sshd, journald, logrotate

Put host-specific shell settings in `~/.config/zsh/.zshrc.local` (git ignores it).

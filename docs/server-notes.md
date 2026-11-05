# Server notes

Unattended upgrades and fail2ban are documented elsewhere.

## sshd hardening

Not stowed, because it lives outside `$HOME`. Put this in `/etc/ssh/sshd_config.d/10-hardening.conf`:

```
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AllowAgentForwarding yes
X11Forwarding no
MaxAuthTries 3
```

Check and reload. Keep a second session open while you test:

```sh
sudo sshd -t && sudo systemctl reload ssh
```

`~/.ssh/authorized_keys` is a symlink into this repo after stow. `sshd` accepts that
if the repo and its parent directories are not writable by group or others.
`bootstrap.sh` sets safe permissions.

## journald

Cap the journal size. Create `/etc/systemd/journald.conf.d/size.conf`:

```
[Journal]
SystemMaxUse=500M
MaxRetentionSec=1month
Compress=yes
```

```sh
sudo systemctl restart systemd-journald
journalctl --disk-usage
sudo journalctl --vacuum-size=500M   # trim now
```

Make logs survive reboot: `sudo mkdir -p /var/log/journal`.

## logrotate

Put one file per app in `/etc/logrotate.d/`. Example for `/var/log/myapp/*.log`:

```
/var/log/myapp/*.log {
    weekly
    rotate 8
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
```

Test without changing anything: `sudo logrotate -d /etc/logrotate.d/myapp`.
Force a run: `sudo logrotate -f /etc/logrotate.d/myapp`.

## Per-host overrides

Put host-specific shell settings in `~/.config/zsh/.zshrc.local`. Git ignores it.
To stop tmux auto-attach on login, run `touch ~/.no-tmux` or connect with `NO_TMUX=1`.

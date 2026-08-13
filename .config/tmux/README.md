# tmux setup

A fresh, dependency-light tmux config. The status bar is
[binoymanoj/tmux-minimal-theme](https://github.com/binoymanoj/tmux-minimal-theme)
**ported inline** (no plugin, no external scripts to source); pane/session
ideas come from [binoymanoj/dotfiles](https://github.com/binoymanoj/dotfiles),
structure and nvim-friendliness from the old OpalBolt config.

**What's gone vs. before:** no `rose-pine` theme plugin, no
`tmux-mem-cpu-load` binary, and no theme *plugin* at all — the bar is plain
tmux options + shell calls (`free`, `date`, `cat`), so there's nothing extra to
compile, clone, or source.

---

## 1. Install

```sh
# a) tmux plugin manager (XDG location this config expects)
git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm

# b) tmux-sessionizer — make sure it's executable
chmod +x ~/scripts/tmux-sessionizer.sh

# c) start / reload tmux, then install plugins:
tmux source ~/.config/tmux/tmux.conf
# inside tmux press:  prefix + I      (capital I = Install)
```

### Prerequisites
- `tmux` (≥ 3.4; you have 3.7b) and `fzf` — present.
- **A Nerd Font in your terminal** (kitty). The status bar icons are written as
  `\uXXXX` escapes (e.g. `\uf489` terminal, `\uf07b` folder, `\uefc5` memory,
  `\uf073`/`\uf017` date/clock, `\uf240` battery) so the config file itself stays
  pure ASCII. They need a Nerd Font to render — if you see boxes, set one in kitty.
- `tmux-sessionizer.sh` at `~/scripts/`. **Verify that exact path** — it's
  referenced once near the top of `tmux.conf` (`bind-key f …`). If your copy
  lives elsewhere, edit that one line.

---

## 2. Plugins

| Plugin | What it does |
|---|---|
| `tpm` | Plugin manager. `prefix + I` install, `prefix + U` update, `prefix + alt + u` remove. |
| `tmux-sensible` | Defaults everyone agrees on: `escape-time 0`, `history-limit 50000`, `focus-events on`, etc. |
| `tmux-pain-control` | All pane bindings (splits, navigate, resize). Replaces hand-written resize keys. |
| `tmux-resurrect` | Save/restore whole tmux sessions across reboots. |
| `tmux-continuum` | Auto-saves every 15 min; restores last session when tmux starts. |
| `vim-tmux-navigator` *(optional)* | `Ctrl+h/j/k/l` moves seamlessly between nvim splits and tmux panes. Needs the matching nvim plugin. **Drop this line if you don't use it.** |

---

## 3. Keybindings

Prefix is the default **`Ctrl+b`**. (To change it, see §5.)

### Panes — provided by tmux-pain-control
| Keys | Action |
|---|---|
| `prefix + \|` | split side-by-side (in current dir) |
| `prefix + -`  | split top/bottom (in current dir) |
| `prefix + \` / `_` | same splits, but full-width/height |
| `prefix + h j k l` | move to pane left/down/up/right |
| `prefix + Ctrl-h/j/k/l` | same, no release of Ctrl needed |
| `prefix + H J K L` (shift) | resize that direction 5 cells (repeatable) |
| `prefix + {` / `}` | swap pane with prev/next (tmux default) |
| `prefix + !` | break pane into its own window (tmux default) |
| `prefix + x` | kill pane (tmux default, asks for confirmation) |
| `prefix + X` (shift) | kill pane **without** confirming |

### Windows
| Keys | Action |
|---|---|
| `Alt + 1..9` | jump to window **N** (no prefix) |
| `prefix + c` | new window |
| `prefix + ,` | rename window |
| `prefix + n` / `p` | next / previous window |
| `prefix + <` / `>` | swap window left / right (pain-control) |
| `prefix + &` | kill window |

### Sessions & tools
| Keys | Action |
|---|---|
| `prefix + f` | **tmux-sessionizer** popup (fuzzy-pick a project → session) |
| `prefix + r` | reload this config |
| `prefix + s` | list/switch sessions (tmux default) |
| `prefix + d` | detach |
| `prefix + R` | rename session (prompt prefilled with current name) |
| `prefix + $` | rename session (tmux default, clears the name) |

### Copy mode (`prefix + [`)
Vi keys: `v` select, `y` copy & exit, `r` rectangle-toggle, `q` exit. Mouse is
on, so selection also works by drag.

---

## 4. Session persistence (resurrect + continuum)

- **Auto-save:** continuum snapshots your windows/panes every 15 min to
  `~/.local/share/tmux/resurrect/`.
- **Auto-restore:** `@continuum-restore 'on'` means the next time you start
  tmux it replays the last snapshot automatically.
- **Manual:** `prefix + Ctrl-s` save now, `prefix + Ctrl-r` restore now.

To turn auto-restore off (some find it surprising), set
`@continuum-restore 'off'` in `tmux.conf` and reload.

---

## 5. Common tweaks

- **Prefix key** — to use `Ctrl+a` instead of `Ctrl+b`, add:
  ```tmux
  unbind C-b
  set -g prefix C-a
  bind C-a send-prefix
  ```
- **nvim swallows Esc** — tmux-sensible sets `escape-time 0`. Uncomment the last
  line of `tmux.conf` (`set -sg escape-time 10`) and reload.
- **Drop vim-tmux-navigator** — delete its `@plugin` line, reload, then
  `prefix + alt + u` to clean it up. `Ctrl+h/j/k/l` then fall back to pain-control's
  prefixed navigation.
- **Status bar palette** — colours live in the `set-environment -g …` block at
  the top of the status section. Default is **Catppuccin Mocha**. To switch,
  edit the six hex values, e.g. **Dracula**:
  ```
  bg #282a36  active/accent #bd93f9  inactive #6272a4  text #f8f8f2  border #44475a
  ```
  …or the **Nordic** bg the old standalone binoymanoj config used: `bg #242933`.
  Widgets are shell `#(...)` calls in `status-right` — add/remove freely.
- **Battery segment** — auto-hidden when `/sys/class/power_supply/BAT*` is absent
  (desktops). It's appended at config-load via `if-shell`, so it shows up
  automatically on a laptop with no config change.
- **Resize step** — `set -g @pane_resize 10` anywhere before TPM init.

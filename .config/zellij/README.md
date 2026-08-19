# zellij

```
~/.config/zellij/
├── config.kdl        # kanagawa theme, no pane frames, Alt+1..9, Ctrl+hjkl nav
├── zj.sh             # fzf session/layout picker (POSIX sh, portable)
└── layouts/          # the session catalog — the files ARE the list
    ├── default.kdl   # bare `zellij` → slim tab bar on top + shell in ~/git
    └── homelab.kdl   # project example: 2 tabs, serve pane at 20%
```

## Look

- Theme: builtin **kanagawa** (matches the kitty theme).
- One-row compact tab bar at the **top**, nothing at the bottom, no pane
  frames. Swap `compact-bar` → `tab-bar` in the layouts if you ever want
  the new-tab button back; `pane_frames true` in config.kdl for borders.

## Keys (on top of zellij defaults)

| Action | Keys |
|---|---|
| Switch to tab 1–9 | `Alt+1` … `Alt+9` (positional; disabled in locked mode) |
| Move between panes/tabs | `Ctrl+h/j/k/l` — seamless with nvim splits |
| Everything else | zellij defaults: `Ctrl+p` pane mode, `Ctrl+t` tab mode, `Ctrl+g` locked |

Locked mode (`Ctrl+g`) passes *all* keys through — that's the escape hatch
if a program inside needs Alt+digits or Ctrl+hjkl itself.

## nvim half of Ctrl+hjkl

Zellij side is done (config.kdl, hiasr/vim-zellij-navigator plugin — version-pinned so it can't 404 again). Neovim side —
in your nvim config, **remove vim-tmux-navigator** and add:

```lua
{
  "swaits/zellij-nav.nvim",
  lazy = true,
  event = "VeryLazy",
  keys = {
    { "<c-h>", "<cmd>ZellijNavigateLeftTab<cr>" },
    { "<c-j>", "<cmd>ZellijNavigateDown<cr>" },
    { "<c-k>", "<cmd>ZellijNavigateUp<cr>" },
    { "<c-l>", "<cmd>ZellijNavigateRightTab<cr>" },
  },
  opts = {},
},
```

## Usage

| Action | Command |
|---|---|
| Default session in `~/git` | `zellij` |
| Fuzzy pick / switch sessions | `zj` (or `~/.config/zellij/zj.sh` anywhere) |
| Direct launch | `zj` → type `homelab` → enter |
| Built-in session manager | `Ctrl+o` then `w` (inside zellij) |

## Adding a project

Copy `layouts/homelab.kdl` → `layouts/<name>.kdl`, edit tabs/panes, keep the
`compact-bar` block on top. It appears in `zj` automatically. New panes:

```kdl
pane                                    # plain shell
pane size="30%"                         # sized split
pane { command "htop" }                 # running app
pane split_direction="vertical" { }     # nested split
```

Full reference: `zellij setup --dump-layout default`.

## Moving zj.sh elsewhere

It's plain POSIX sh with one knob: `ZJ_LAYOUTS_DIR`. Update the path in
`fish/functions/zj.fish` when you move it.

## tmux removal — done 2025, what's left to run

Config dirs (`tmux/`, `sesh/`, `tmuxinator/`, `tmux-sessionizer/`) and
`sesh.fish` are deleted. Remaining system-level cleanup:

    sudo pacman -Rns tmux tmuxinator sesh   # or your package manager's equivalent
    rm -rf ~/.tmux ~/.local/share/tmux-resurrect

If muscle memory types `tmux` anyway, an alias helps:
`alias tmux 'echo "it's zellij now — zj"'` (or just `alias tmux=zellij`).

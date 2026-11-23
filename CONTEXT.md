# dotfiles scripts

Shell tooling in this repo: the tmux config with its tj picker, and hag, the sandboxed agent launcher.

## Language — tmux & tj

**Session**:
A tmux session, listed as a ⚡ row in tj. Picking a directory row creates one named after that directory.
_Avoid_: workspace, project (those mean the directory)

**Workspace directory**:
A git repo, customer project, or `projects/` directory that tj lists as 📁 / 💼 rows.
_Avoid_: project, repo

**Prune**:
Kill every session except the highlighted one, after a confirmation showing how many will die. Bound to Ctrl-P.
_Avoid_: kill all, cleanup

**Session preview**:
The right-hand pane of the picker for session rows: window headers plus a live capture of each pane's visible screen.
_Avoid_: window list (that's the metadata-only view)

**Own session**:
The session the tj popup itself runs in. tj never kills it; the guard stops tmux from yanking the client away.
_Avoid_: current session (that means whichever one is highlighted)

## Language — hag

**Harness**:
A coding agent CLI hag can launch inside a nono sandbox (pi, opencode, copilot, claude, vibe).
_Avoid_: agent, tool

**Agent kind**:
Herdr's identifier for a harness, delivered through the HERDR_AGENT environment variable.
_Avoid_: agent type, manifest

**nono profile**:
The sandbox preset nono runs a harness under (`nono run -p …`).
_Avoid_: sandbox config

**Sandbox extras**:
nono flags passed right of hag's `--` (`hag pi -- --allow /dir`); NONO_* env vars reach nono as well.
_Avoid_: passthrough flags, parameters

**Foreground process**:
The pane's outermost process. Herdr reads its environ for the agent kind, so hag's own shell must hold this role for the whole session.
_Avoid_: parent shell, wrapper process

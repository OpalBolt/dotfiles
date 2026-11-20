# tmux & tj

The tmux config and tj, its fzf-based picker for tmux sessions and workspace directories.

## Language

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

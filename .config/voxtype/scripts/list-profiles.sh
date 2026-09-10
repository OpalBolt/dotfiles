#!/bin/sh
# List available VoxType profile names, in a stable menu order: "raw" first
# (bypasses the LLM entirely), then every profile defined by a .txt file in
# ~/.config/voxtype/profiles/, alphabetically.
#
# Both voxtype-profile-menu.sh and voxtype-redo-menu.sh read this list
# instead of hard-coding profile names, so adding a new profile (just drop a
# new .txt file in that directory, plus a matching [profiles.<name>] stanza
# in config.toml) makes it show up in both menus automatically.
set -eu

profiles_dir="$HOME/.config/voxtype/profiles"

printf '%s\n' raw
# -L: ~/.config/voxtype/profiles is typically a symlink into a dotfiles
# repo. Without -L, find's default -P mode treats a symlinked starting
# directory as a non-directory and silently finds nothing inside it.
find -L "$profiles_dir" -maxdepth 1 -name '*.txt' -printf '%f\n' 2>/dev/null |
    sed 's/\.txt$//' |
    sort

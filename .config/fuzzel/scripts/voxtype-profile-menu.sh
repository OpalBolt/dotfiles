#!/bin/sh
# Pick the active VoxType post-processing profile from a fuzzel menu.
# The choice is persisted to a state file that
# ~/.config/voxtype/scripts/toggle-with-profile.sh reads on every
# record-toggle invocation, so it stays selected until changed again.
#
# Profile names come from ~/.config/voxtype/scripts/list-profiles.sh, which
# reads ~/.config/voxtype/profiles/*.txt -- add or rename a profile there
# (plus its matching [profiles.<name>] stanza in config.toml) and it shows
# up here automatically.
#
# The currently active profile is shown both in the prompt and tagged
# "(current)" on its own line, so a stale selection (e.g. left on "raw"
# from before a profile existed) is obvious at a glance instead of silently
# persisting unnoticed.
set -eu

state_dir="$HOME/.local/state/voxtype"
state_file="$state_dir/profile"
list_script="$HOME/.config/voxtype/scripts/list-profiles.sh"
mkdir -p "$state_dir"

notify() {
    notify-send 'VoxType profile' "$1" 2>/dev/null || true
}

current=$(cat "$state_file" 2>/dev/null || true)
[ -n "$current" ] || current=default

# Build the display list, always keeping the profile name as the first
# whitespace-separated field so the later `awk '{print $1}'` extraction
# stays correct regardless of which labels get appended.
menu=$(
    "$list_script" | while IFS= read -r name; do
        label=$name
        [ "$name" = raw ] && label="$label (no post-processing)"
        [ "$name" = "$current" ] && label="$label (current)"
        printf '%s\n' "$label"
    done
)

profile=$(
    printf '%s\n' "$menu" |
        fuzzel --dmenu \
            --prompt="Voxtype profile [current: $current]  " \
            --lines=10 \
            --minimal-lines \
            --no-sort \
            --only-match |
        awk '{print $1}'
) || exit 0
[ -n "$profile" ] || exit 0

printf '%s' "$profile" > "$state_file"
notify "Active profile: $profile"

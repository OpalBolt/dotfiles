#!/bin/sh
# Toggle VoxType recording using whichever profile was last chosen via
# ~/.config/fuzzel/scripts/voxtype-profile-menu.sh. Falls back to the
# "default" profile if none has been selected yet this session.
set -eu

state_dir="$HOME/.local/state/voxtype"
state_file="$state_dir/profile"

profile=$(cat "$state_file" 2>/dev/null || true)
[ -n "$profile" ] || profile=default

exec voxtype record toggle --profile "$profile"

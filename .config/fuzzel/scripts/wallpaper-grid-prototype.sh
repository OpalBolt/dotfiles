#!/bin/sh

# PROTOTYPE: compare Waypaper's large thumbnail grid with the Fuzzel picker.
set -eu

wallpaper_dir=${WALLPAPER_DIR:-"$HOME/Pictures/backgrounds"}
state_dir=${XDG_STATE_HOME:-"$HOME/.local/state"}/waypaper

if [ ! -d "$wallpaper_dir" ]; then
    message="Wallpaper directory does not exist: $wallpaper_dir"
    notify-send 'Wallpaper grid' "$message" 2>/dev/null || true
    printf '%s\n' "$message" >&2
    exit 1
fi

mkdir -p "$state_dir"

exec waypaper \
    --config-file="$HOME/.config/fuzzel/waypaper-grid-prototype.ini" \
    --state-file="$state_dir/grid-prototype.ini" \
    --backend=awww \
    --folder "$wallpaper_dir"

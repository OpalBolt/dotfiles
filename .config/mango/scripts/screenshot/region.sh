#!/usr/bin/env bash
# Region screenshot -> satty for editing.
#
# No freeze step: wayfreeze is intentionally not used here, so the live
# screen is visible while slurp is up (same tradeoff hyprshot makes). Select
# a region, crop it with grim, and hand the image straight to satty so it
# can always be annotated before saving.
set -euo pipefail

screenshot_dir="$HOME/Pictures/Screenshots"
mkdir -p "$screenshot_dir"

geometry=$(slurp -d)
[ -z "$geometry" ] && exit 1

filepath="$screenshot_dir/$(date +%Y%m%d%H%M%S).png"

grim -g "$geometry" - | satty --filename - --output-filename "$filepath" \
    --early-exit --actions-on-enter save-to-file

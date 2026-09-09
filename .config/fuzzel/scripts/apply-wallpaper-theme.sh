#!/bin/sh

set -eu

wallpaper=${1:?usage: apply-wallpaper-theme.sh WALLPAPER}

matugen image "$wallpaper" --prefer saturation

for waypaper_pid in $(pgrep -x waypaper 2>/dev/null || true); do
    kill -USR1 "$waypaper_pid"
done

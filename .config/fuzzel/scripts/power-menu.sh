#!/bin/sh

set -eu

choice=$(
    printf '%s\n' \
        '󰐥  Shut down' \
        '󰜉  Reboot' \
        '󰒲  Sleep' \
        '󰤄  Sleep then hibernate' |
        fuzzel --dmenu \
            --prompt='Power  ' \
            --lines=4 \
            --width=30 \
            --minimal-lines \
            --no-sort \
            --only-match
) || exit 0

case "$choice" in
    '󰐥  Shut down')
        systemctl poweroff
        ;;
    '󰜉  Reboot')
        systemctl reboot
        ;;
    '󰒲  Sleep')
        systemctl suspend
        ;;
    '󰤄  Sleep then hibernate')
        systemctl suspend-then-hibernate
        ;;
esac

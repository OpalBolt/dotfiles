#!/bin/bash
# Reports mako's do-not-disturb state as waybar custom module JSON,
# and toggles it when invoked with the "toggle" argument.

if [ "$1" = "toggle" ]; then
    makoctl mode -t do-not-disturb >/dev/null
    pkill -RTMIN+8 waybar
    exit 0
fi

if makoctl mode 2>/dev/null | grep -qx "do-not-disturb"; then
    echo "{\"text\":\"󰂛\",\"tooltip\":\"Notifications paused\",\"class\":\"paused\"}"
else
    echo "{\"text\":\"󰂚\",\"tooltip\":\"Notifications active\",\"class\":\"active\"}"
fi

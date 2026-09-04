#!/usr/bin/env bash
# Prints a separator only when a bluetooth device is connected, so the
# bluetooth section's leading separator disappears instead of dangling
# next to an empty bluetooth icon. Kept as its own custom module (rather
# than baking "|" into bluetooth's format-connected) so it can use the
# neutral #custom-separator styling instead of inheriting bluetooth's
# @primary "connected" glow color.
if [ -n "$(bluetoothctl devices Connected 2>/dev/null)" ]; then
    echo "|"
fi

#!/bin/sh
# Fix up the last VoxType dictation after the fact: restore the original
# (pre-LLM) wording, or re-run it through a different profile's prompt.
#
# Reads the raw transcription and the text that was actually typed for the
# last recording (saved by ~/.config/voxtype/scripts/process-profile.sh),
# then replaces the on-screen text by backspacing exactly as many characters
# as were typed and typing the newly chosen result in their place.
#
# Only works right after a dictation, before you've typed anything else in
# the target field -- there is no way to know what else changed focus/cursor
# position in between.
set -eu

STATE_DIR="$HOME/.local/state/voxtype"
PROCESS_SCRIPT="$HOME/.config/voxtype/scripts/process-profile.sh"
LIST_SCRIPT="$HOME/.config/voxtype/scripts/list-profiles.sh"

notify() {
    notify-send 'VoxType redo' "$1" 2>/dev/null || true
}

if [ ! -s "$STATE_DIR/last-raw.txt" ] || [ ! -s "$STATE_DIR/last-output.txt" ]; then
    notify 'No previous dictation found'
    exit 0
fi

raw=$(cat "$STATE_DIR/last-raw.txt")
previous_output=$(cat "$STATE_DIR/last-output.txt")

profile=$(
    "$LIST_SCRIPT" |
        sed 's/^raw$/raw (restore original wording, no LLM)/' |
        fuzzel --dmenu \
            --prompt='Redo last dictation  ' \
            --lines=10 \
            --minimal-lines \
            --no-sort \
            --only-match |
        awk '{print $1}'
) || exit 0
[ -n "$profile" ] || exit 0

new_text=$(printf '%s' "$raw" | "$PROCESS_SCRIPT" "$profile")

if [ -z "$new_text" ]; then
    notify 'Reprocessing produced no text; left the original in place'
    exit 0
fi

if ! command -v wtype >/dev/null 2>&1; then
    printf '%s' "$new_text" | wl-copy
    notify 'wtype not found; copied new text to clipboard instead'
    exit 0
fi

# Count characters (not bytes) of what was typed last, so the right number
# of backspaces removes exactly that text and nothing more.
char_count=$(printf '%s' "$previous_output" | wc -m)

set --
i=0
while [ "$i" -lt "$char_count" ]; do
    set -- "$@" -P BackSpace -p BackSpace
    i=$((i + 1))
done
[ $# -eq 0 ] || wtype "$@"

wtype -- "$new_text"

notify "Replaced with: $profile"

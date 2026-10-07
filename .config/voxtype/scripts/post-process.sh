#!/bin/sh
set -eu
umask 077

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
state_dir="${XDG_RUNTIME_DIR:-$HOME/.local/state}/voxtype"
session_dir=
trap '[ -z "$session_dir" ] || rm -rf "$session_dir"' EXIT

report() {
    printf 'VoxType: %s\n' "$1" >&2
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u critical 'VoxType' "$1" || true
    fi
}

fail() {
    report "$1"
    exit 1
}

for cmd in mmsg jq wtype foot tv curl; do
    command -v "$cmd" >/dev/null 2>&1 || fail "missing $cmd"
done

mkdir -p "$state_dir" || fail 'cannot create VoxType runtime directory'
session_dir=$(mktemp -d "$state_dir/cleanup.XXXXXXXX") ||
    fail 'cannot create VoxType cleanup session'
raw_file="$session_dir/raw"
clean_file="$session_dir/clean"
undo_file="$session_dir/undo"
cat >"$raw_file" || fail 'cannot read transcript'
[ -n "$(tr -d '[:space:]' <"$raw_file")" ] || exit 0

client=$(mmsg get focusing-client | jq -er '.id | select(type == "number" and . > 0)') ||
    fail 'cannot find the text destination'

raw=$(cat "$raw_file"; printf '.')
raw=${raw%.}
wtype -- "$raw" || {
    report 'cannot type the transcript'
    exit 0
}

if ! foot -a voxtype-popup -W 42x8 -T 'VoxType cleanup' -- \
    "$script_dir/cleanup-prompt.sh" "$raw_file" "$clean_file"; then
    report 'cleanup popup failed; original text is unchanged'
    exit 0
fi
[ -s "$clean_file" ] || exit 0

focus_target() {
    mmsg get client "$client" >/dev/null &&
        mmsg dispatch focusid "client,$client" >/dev/null
}

erase_text() {
    count=$(printf '%s' "$1" | wc -m)
    set --
    while [ "$count" -gt 0 ]; do
        set -- "$@" -k BackSpace
        count=$((count - 1))
    done
    wtype "$@"
}

if ! focus_target; then
    report 'text destination closed; original text is unchanged'
    exit 0
fi

erase_text "$raw" || {
    report 'cannot remove the transcript; text may be incomplete'
    exit 0
}
clean=$(cat "$clean_file"; printf '.')
clean=${clean%.}
wtype -- "$clean" || {
    report 'cannot type the cleaned text; text may be incomplete'
    exit 0
}

if ! foot -a voxtype-popup -W 42x8 -T 'VoxType undo cleanup' -- \
    "$script_dir/cleanup-prompt.sh" --undo "$undo_file"; then
    report 'undo popup failed; cleaned text remains'
    exit 0
fi
[ -f "$undo_file" ] || exit 0

if ! focus_target; then
    report 'text destination closed; cleaned text remains'
    exit 0
fi
erase_text "$clean" || {
    report 'cannot remove the cleaned text; text may be incomplete'
    exit 0
}
wtype -- "$raw" || report 'cannot restore the original text'

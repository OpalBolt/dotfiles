#!/bin/sh
# Toggle VoxType recording while capturing the focused Mango client safely.
set -eu
umask 077

state_root=${XDG_RUNTIME_DIR:-$HOME/.local/state}
state_dir="$state_root/voxtype"
state_file="$state_dir/pending-recording-target.json"
lock_dir="$state_dir/record-toggle.lock"
log_file="$state_dir/record-toggle.log"

lock_acquired=
tmp_state_file=

require_cmd() {
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || fail "missing dependency: $cmd"
    done
}

log_error() {
    printf '%s\n' "$1" >>"$log_file" 2>/dev/null || true
}

notify_error() {
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -u critical 'VoxType' "$1" >/dev/null 2>&1 || true
}

fail() {
    printf '%s\n' "record-toggle.sh: $1" >&2
    log_error "$1"
    notify_error "$1"
    exit 1
}

cleanup() {
    if [ "${lock_acquired:-}" = yes ]; then
        rmdir "$lock_dir" 2>/dev/null || true
    fi
    if [ -n "${tmp_state_file:-}" ] && [ -f "$tmp_state_file" ]; then
        rm -f "$tmp_state_file"
    fi
}

trap cleanup EXIT HUP INT TERM

acquire_lock() {
    if mkdir "$lock_dir" 2>/dev/null; then
        lock_acquired=yes
    else
        fail 'another VoxType recording toggle is already running'
    fi
}

read_status() {
    status_json=$(voxtype status --format json 2>/dev/null) || fail 'unable to read VoxType status'
    status=$(printf '%s' "$status_json" | jq -re '(.alt // .state // .status // empty) | tostring') || fail 'unable to parse VoxType status'
    case "$status" in
        idle|recording|transcribing|stopped)
            printf '%s\n' "$status"
            ;;
        *)
            fail "unexpected VoxType status '$status'"
            ;;
    esac
}

read_focused_client_id() {
    focus_json=$(mmsg get focusing-client 2>/dev/null) || fail 'unable to read focused Mango client'
    client_id=$(printf '%s' "$focus_json" | jq -re '(.id // .client.id // .client_id // .focus.id // .clientId // empty) | tostring') || fail 'focused Mango client has no valid id'
    case "$client_id" in
        ''|*[!0-9]*|0)
            fail "focused Mango client id is not a positive integer: $client_id"
            ;;
    esac

    client_json=$(mmsg get client "$client_id" 2>/dev/null) || fail "focused Mango client $client_id no longer exists"
    verified_id=$(printf '%s' "$client_json" | jq -re '(.id // .client.id // .client_id // .focus.id // .clientId // empty) | tostring') || fail "unable to verify Mango client $client_id"
    case "$verified_id" in
        ''|*[!0-9]*|0)
            fail "verified Mango client id is not a positive integer: $verified_id"
            ;;
    esac
    [ "$verified_id" = "$client_id" ] || fail "focused Mango client changed during validation: $client_id -> $verified_id"

    printf '%s\n' "$client_id"
}

write_pending_state() {
    client_id=$1
    tmp_state_file="$state_file.$$"
    state_json=$(jq -n --arg client_id "$client_id" '{client_id: $client_id}')
    printf '%s\n' "$state_json" >"$tmp_state_file" || fail 'unable to write pending target state'
    mv "$tmp_state_file" "$state_file" || fail 'unable to store pending target state'
    tmp_state_file=
}

read_pending_client_id() {
    [ -f "$state_file" ] || fail 'missing pending recording target'
    pending_client_id=$(jq -re '.client_id | tostring' <"$state_file") || fail 'pending target state is malformed'
    case "$pending_client_id" in
        ''|*[!0-9]*|0)
            fail "pending target id is not a positive integer: $pending_client_id"
            ;;
    esac
    printf '%s\n' "$pending_client_id"
}

post_process_running() {
    post_process_lock_dir="$state_dir/post-process.lock"
    [ -d "$post_process_lock_dir" ] || return 1
    lock_pid=$(cat "$post_process_lock_dir/pid" 2>/dev/null || true)
    case "$lock_pid" in
        ''|*[!0-9]*)
            return 1
            ;;
    esac
    kill -0 "$lock_pid" 2>/dev/null
}

start_recording() {
    if [ -e "$state_file" ]; then
        if post_process_running; then
            fail 'a previous dictation is still being reviewed; finish or cancel it first'
        fi
        # post-process.sh normally removes this file once a dictation is
        # reviewed. If it never ran (e.g. empty/silent transcript) or was
        # killed before it could clean up, the file is orphaned and the
        # review popup is not active, so it is safe to clear and continue.
        log_error 'clearing stale pending recording target left by an interrupted or skipped review'
        rm -f "$state_file"
    fi
    client_id=$(read_focused_client_id)
    write_pending_state "$client_id"

    if ! voxtype record start; then
        rm -f "$state_file"
        fail 'voxtype record start failed'
    fi
}

stop_recording() {
    pending_client_id=$(read_pending_client_id)
    [ -n "$pending_client_id" ] || fail 'missing pending recording target'

    if ! voxtype record stop; then
        fail 'voxtype record stop failed'
    fi
}

require_cmd voxtype mmsg jq
mkdir -p "$state_dir" || fail "unable to create state directory: $state_dir"
chmod 700 "$state_dir" 2>/dev/null || true

acquire_lock

status=$(read_status)

case "$status" in
    idle)
        start_recording
        ;;
    recording)
        stop_recording
        ;;
    transcribing|stopped)
        fail "voxtype is currently $status; refusing to toggle"
        ;;
esac

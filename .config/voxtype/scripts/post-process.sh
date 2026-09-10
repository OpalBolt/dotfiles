#!/bin/sh
# Blocking post-process entry for VoxType raw dictation delivery.
set -eu
umask 077

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
controller_script="$script_dir/controller.sh"

state_root=${XDG_RUNTIME_DIR:-$HOME/.local/state}
state_dir="$state_root/voxtype"
pending_target_file="$state_dir/pending-recording-target.json"
lock_dir="$state_dir/post-process.lock"
log_file="$state_dir/post-process.log"
failure_meta_file="$state_dir/last-failure.txt"
failure_raw_file="$state_dir/last-failure.raw"

raw_text=
pending_client_id=
session_id=
session_dir=
raw_file=
candidate_file=
outcome_file=
popup_stderr=
lock_acquired=no
pending_bound=no
handled=no
last_action=
last_candidate=
selected_profile=
last_named_profile=
candidate_state=unknown

mkdir -p "$state_dir" || {
    printf '%s\n' "post-process.sh: unable to create state directory: $state_dir" >&2
    exit 1
}
chmod 700 "$state_dir" 2>/dev/null || true

log_error() {
    printf '%s\n' "$1" >>"$log_file" 2>/dev/null || true
}

notify_user() {
    message=$1
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u normal 'VoxType' "$message" >/dev/null 2>&1 || true
    fi
}

notify_error() {
    message=$1
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u critical 'VoxType' "$message" >/dev/null 2>&1 || true
    fi
}

fail() {
    message=$1
    if [ "${pending_bound:-no}" = yes ]; then
        record_failure_evidence "$message" ''
        remove_pending_target
    fi
    printf '%s\n' "post-process.sh: $message" >&2
    log_error "$message"
    notify_error "$message"
    exit 1
}

cleanup() {
    if [ -n "${session_dir:-}" ] && [ -d "$session_dir" ]; then
        rm -rf "$session_dir" 2>/dev/null || true
    fi
    if [ "${lock_acquired:-no}" = yes ]; then
        rm -rf "$lock_dir" 2>/dev/null || true
    fi
}

trap cleanup EXIT HUP INT TERM

record_failure_evidence() {
    reason=$1
    detail=${2:-}
    {
        printf 'reason=%s\n' "$reason"
        printf 'detail=%s\n' "$detail"
        printf 'session_id=%s\n' "${session_id:-}"
        printf 'client_id=%s\n' "${pending_client_id:-}"
        printf 'action=%s\n' "${last_action:-}"
        printf 'candidate_state=%s\n' "${candidate_state:-unknown}"
        printf 'selected_profile=%s\n' "${selected_profile:-}"
        printf 'last_named_profile=%s\n' "${last_named_profile:-}"
    } >"$failure_meta_file" 2>/dev/null || true
    if [ -n "${raw_text:-}" ]; then
        printf '%s' "$raw_text" >"$failure_raw_file" 2>/dev/null || true
    fi
}

add_missing() {
    if [ -n "$missing_dependencies" ]; then
        missing_dependencies="$missing_dependencies, $1"
    else
        missing_dependencies=$1
    fi
}

check_dependencies() {
    missing_dependencies=

    if ! command -v footclient >/dev/null 2>&1 && ! command -v foot >/dev/null 2>&1; then
        add_missing 'foot or footclient'
    fi

    for cmd in fzf gum mmsg jq wtype wl-copy curl; do
        command -v "$cmd" >/dev/null 2>&1 || add_missing "$cmd"
    done

    if [ -n "$missing_dependencies" ]; then
        fail "missing dependencies: $missing_dependencies"
    fi
}

acquire_lock() {
    if mkdir "$lock_dir" 2>/dev/null; then
        printf '%s\n' "$$" >"$lock_dir/pid" 2>/dev/null || true
        lock_acquired=yes
        return 0
    fi

    if [ -f "$lock_dir/pid" ]; then
        lock_pid=$(cat "$lock_dir/pid" 2>/dev/null || true)
        case "$lock_pid" in
            ''|*[!0-9]*)
                ;;
            *)
                if kill -0 "$lock_pid" 2>/dev/null; then
                    fail 'another VoxType post-process session is already running'
                fi
                ;;
        esac
    fi

    rm -rf "$lock_dir" 2>/dev/null || true
    if mkdir "$lock_dir" 2>/dev/null; then
        printf '%s\n' "$$" >"$lock_dir/pid" 2>/dev/null || true
        lock_acquired=yes
    else
        fail 'unable to acquire VoxType post-process lock'
    fi
}

read_pending_target() {
    [ -f "$pending_target_file" ] || fail 'missing pending recording target'

    pending_client_id=$(
        jq -re '.client_id | tostring' <"$pending_target_file"
    ) || fail 'pending target state is malformed'

    case "$pending_client_id" in
        ''|*[!0-9]*|0)
            fail "pending target id is not a positive integer: $pending_client_id"
            ;;
    esac

    pending_bound=yes
}

write_session_files() {
    session_id=$(date +%s)-$$
    session_dir="$state_dir/session-$session_id"
    mkdir "$session_dir" || fail "unable to create session directory: $session_dir"
    raw_file="$session_dir/raw.txt"
    candidate_file="$session_dir/candidate.txt"
    outcome_file="$session_dir/outcome.json"
    popup_stderr="$session_dir/popup.stderr"

    printf '%s' "$raw_text" >"$raw_file" || fail 'unable to write raw transcript file'
    printf '%s' "$raw_text" >"$candidate_file" || fail 'unable to write candidate transcript file'
}

remove_pending_target() {
    rm -f "$pending_target_file"
}

read_outcome_field() {
    field=$1
    jq -re "$field" <"$outcome_file"
}

popup_visible() {
    clients_json=$(mmsg get clients 2>/dev/null) || return 1
    printf '%s' "$clients_json" | jq -e '.. | objects | select((.app_id? // .appId? // .appid? // .title? // empty) == "voxtype-popup")' >/dev/null 2>&1
}

launch_controller_with_terminal() {
    terminal=$1
    shift
    terminal_stderr=$1

    VOXTYPE_RAW_FILE=$raw_file \
    VOXTYPE_CANDIDATE_FILE=$candidate_file \
    VOXTYPE_OUTCOME_FILE=$outcome_file \
    VOXTYPE_SESSION_DIR=$session_dir \
    "$terminal" -a voxtype-popup -T 'VoxType raw dictation' -- env \
        VOXTYPE_RAW_FILE="$raw_file" \
        VOXTYPE_CANDIDATE_FILE="$candidate_file" \
        VOXTYPE_OUTCOME_FILE="$outcome_file" \
        VOXTYPE_SESSION_DIR="$session_dir" \
        "$controller_script" 2>"$terminal_stderr"
}

launch_popup() {
    if command -v footclient >/dev/null 2>&1; then
        if launch_controller_with_terminal footclient "$popup_stderr"; then
            return 0
        fi

        if grep -Eqi 'connect|connection refused|could not connect|failed to connect|server socket' "$popup_stderr" 2>/dev/null; then
            : # fall through to foot
        else
            return 1
        fi
    fi

    if command -v foot >/dev/null 2>&1; then
        launch_controller_with_terminal foot "$popup_stderr"
        return $?
    fi

    fail 'no usable foot or footclient binary is available'
}

blank_input() {
    if [ -f "$pending_target_file" ]; then
        rm -f "$pending_target_file"
    fi
    notify_user 'VoxType received no text to deliver'
    handled=yes
    exit 0
}

prepare_input() {
    raw_text=$(cat)
    case "$(printf '%s' "$raw_text" | tr -d '[:space:]')" in
        '')
            blank_input
            ;;
    esac
}

process_insert() {
    if [ -n "${last_candidate:-}" ]; then
        candidate_text=$last_candidate
    else
        candidate_text=$(cat "$candidate_file")
    fi
    candidate_state=raw
    if [ "$candidate_text" != "$raw_text" ]; then
        candidate_state=edited
    fi

    if [ "$(printf '%s' "$candidate_text" | tr -d '[:space:]')" = '' ]; then
        candidate_state=blank
        notify_user 'VoxType edited text is empty; nothing was delivered'
        remove_pending_target
        handled=yes
        return 0
    fi

    if ! mmsg get client "$pending_client_id" >/dev/null 2>&1; then
        if printf '%s' "$candidate_text" | wl-copy; then
            last_action=missing-target-copy
            record_failure_evidence 'original Mango client disappeared before insertion' 'copy fallback'
            log_error 'original Mango client disappeared before insertion; copied candidate to clipboard'
            notify_error 'original Mango client disappeared before insertion; copied candidate to clipboard'
            remove_pending_target
            handled=yes
            return 0
        fi
        fail 'unable to copy candidate text after original Mango client disappeared'
    fi

    if ! mmsg dispatch focusid "client,$pending_client_id" >/dev/null 2>&1; then
        if printf '%s' "$candidate_text" | wl-copy; then
            last_action=missing-target-copy
            record_failure_evidence 'original Mango client disappeared before focus restoration' 'copy fallback'
            log_error 'original Mango client disappeared before focus restoration; copied candidate to clipboard'
            notify_error 'original Mango client disappeared before focus restoration; copied candidate to clipboard'
            remove_pending_target
            handled=yes
            return 0
        fi
        fail "unable to focus Mango client $pending_client_id"
    fi

    if ! wtype "$candidate_text"; then
        fail 'wtype failed while inserting candidate text'
    fi

    remove_pending_target
    handled=yes
}

process_copy() {
    if [ -n "${last_candidate:-}" ]; then
        candidate_text=$last_candidate
    else
        candidate_text=$(cat "$candidate_file")
    fi
    candidate_state=raw
    if [ "$candidate_text" != "$raw_text" ]; then
        candidate_state=edited
    fi

    if [ "$(printf '%s' "$candidate_text" | tr -d '[:space:]')" = '' ]; then
        candidate_state=blank
        notify_user 'VoxType edited text is empty; clipboard was not changed'
        remove_pending_target
        handled=yes
        return 0
    fi

    if ! printf '%s' "$candidate_text" | wl-copy; then
        fail 'wl-copy failed while copying candidate text'
    fi

    remove_pending_target
    handled=yes
}

process_cancel() {
    remove_pending_target
    handled=yes
}

main() {
    acquire_lock
    prepare_input
    check_dependencies
    read_pending_target
    write_session_files

    if ! launch_popup; then
        record_failure_evidence 'terminal popup failed before the controller completed' "$(cat "$popup_stderr" 2>/dev/null || true)"
        remove_pending_target
        fail 'unable to open the VoxType raw dictation popup'
    fi

    if ! [ -s "$outcome_file" ]; then
        record_failure_evidence 'controller did not write an outcome file' ''
        remove_pending_target
        fail 'missing controller outcome'
    fi

    last_action=$(read_outcome_field '.action | tostring') || {
        record_failure_evidence 'controller outcome was malformed' 'missing action'
        remove_pending_target
        fail 'controller outcome was malformed'
    }
    last_candidate=$(read_outcome_field '.candidate // empty') || {
        record_failure_evidence 'controller outcome was malformed' 'missing candidate'
        remove_pending_target
        fail 'controller outcome was malformed'
    }
    selected_profile=$(read_outcome_field '.selected_profile // empty') || selected_profile=
    last_named_profile=$(read_outcome_field '.last_named_profile // empty') || last_named_profile=
    case "$selected_profile" in
        '')
            ;;
        default|casual|formal|code)
            ;;
        *)
            record_failure_evidence 'controller outcome contained an invalid selected profile' "$selected_profile"
            remove_pending_target
            fail 'controller outcome contained an invalid selected profile'
            ;;
    esac
    case "$last_named_profile" in
        '')
            ;;
        default|casual|formal|code)
            ;;
        *)
            record_failure_evidence 'controller outcome contained an invalid last named profile' "$last_named_profile"
            remove_pending_target
            fail 'controller outcome contained an invalid last named profile'
            ;;
    esac
    candidate_state=$(read_outcome_field '.candidate_state // "unknown"') || candidate_state=unknown

    if popup_visible; then
        record_failure_evidence 'voxtype-popup client was still visible after the controller exited' ''
        remove_pending_target
        fail 'voxtype popup still visible after controller exit'
    fi

    case "$last_action" in
        insert)
            process_insert
            ;;
        copy)
            process_copy
            ;;
        cancel)
            process_cancel
            ;;
        *)
            record_failure_evidence 'controller selected an unknown action' "$last_action"
            remove_pending_target
            fail "unknown controller action: $last_action"
            ;;
    esac

    if [ "${handled:-no}" = yes ]; then
        exit 0
    fi
}

main "$@"

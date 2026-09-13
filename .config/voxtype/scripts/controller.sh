#!/bin/sh
# Terminal-only controller for VoxType raw dictation delivery.
set -eu
umask 077

raw_file=${VOXTYPE_RAW_FILE:?VOXTYPE_RAW_FILE is required}
candidate_file=${VOXTYPE_CANDIDATE_FILE:?VOXTYPE_CANDIDATE_FILE is required}
outcome_file=${VOXTYPE_OUTCOME_FILE:?VOXTYPE_OUTCOME_FILE is required}
session_dir=${VOXTYPE_SESSION_DIR:?VOXTYPE_SESSION_DIR is required}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
history_script="$script_dir/history.sh"
process_profile_script="$script_dir/process-profile.sh"
profile_state_file="$session_dir/current-named-profile.txt"
history_record_path_file="$session_dir/history-record-path.txt"
preview_profiles_dir=${VOXTYPE_PROFILES_DIR:-$HOME/.config/voxtype/profiles}
editor_file=
history_record_file=${VOXTYPE_HISTORY_RECORD_FILE:-}

. "$history_script"

export PROFILES_DIR="$preview_profiles_dir"

cleanup() {
    if [ -n "${editor_file:-}" ]; then
        rm -f "$editor_file" 2>/dev/null || true
    fi
}

trap cleanup EXIT HUP INT TERM

fail() {
    printf '%s\n' "controller.sh: $1" >&2
    exit 1
}

read_file() {
    file=$1
    [ -f "$file" ] || fail "missing file: $file"
    cat "$file"
}

write_file_atomic() {
    file=$1
    content=$2
    tmp_file="$file.$$"
    printf '%s' "$content" >"$tmp_file" || fail "unable to write file: $file"
    mv "$tmp_file" "$file" || fail "unable to update file: $file"
}

trimmed_is_empty() {
    value=$1
    case $(printf '%s' "$value" | tr -d '[:space:]') in
        '') return 0 ;;
    esac
    return 1
}

sanitize_error() {
    printf '%s' "$1" | tr -d '\000-\010\013\014\016-\037\177'
}

profile_label() {
    case $1 in
        default) printf '%s\n' 'Default' ;;
        casual) printf '%s\n' 'Casual' ;;
        formal) printf '%s\n' 'Formal' ;;
        code) printf '%s\n' 'Code' ;;
        *) return 1 ;;
    esac
}

editor_command() {
    if [ -n "${VISUAL:-}" ]; then
        printf '%s\n' "$VISUAL"
        return 0
    fi

    if [ -n "${EDITOR:-}" ]; then
        printf '%s\n' "$EDITOR"
        return 0
    fi

    return 1
}

validate_profile() {
    case $1 in
        default|casual|formal|code) return 0 ;;
        '') return 1 ;;
    esac
    return 1
}

read_current_profile() {
    current_profile=
    if [ -f "$profile_state_file" ]; then
        current_profile=$(cat "$profile_state_file" 2>/dev/null || true)
        validate_profile "$current_profile" || current_profile=
    fi
}

write_current_profile() {
    profile=$1
    validate_profile "$profile" || fail "invalid profile state: $profile"
    tmp_file="$profile_state_file.$$"
    printf '%s\n' "$profile" >"$tmp_file" || fail 'unable to write profile state'
    mv "$tmp_file" "$profile_state_file" || fail 'unable to update profile state'
}

read_history_record_file() {
    if [ -f "$history_record_path_file" ]; then
        history_record_file=$(cat "$history_record_path_file" 2>/dev/null || true)
    fi
    if [ -z "${history_record_file:-}" ] && [ -n "${VOXTYPE_HISTORY_RECORD_FILE:-}" ]; then
        history_record_file=$VOXTYPE_HISTORY_RECORD_FILE
    fi
}

write_history_record_file() {
    record_file=$1
    history_record_file=$record_file
    tmp_file="$history_record_path_file.$$"
    printf '%s\n' "$record_file" >"$tmp_file" || fail 'unable to update history record path'
    mv "$tmp_file" "$history_record_path_file" || fail 'unable to update history record path'
}

update_history_last_named_profile() {
    profile=$1
    [ -n "${history_record_file:-}" ] || return 0
    voxtype_history_update_last_named_profile "$history_record_file" "$profile"
}

update_history_accepted_final_text() {
    candidate_text=$1
    [ -n "${history_record_file:-}" ] || return 0
    voxtype_history_update_accepted_final_text "$history_record_file" "$candidate_text"
}

candidate_state() {
    if [ "$(read_file "$candidate_file")" = "$(read_file "$raw_file")" ]; then
        printf '%s\n' raw
    else
        printf '%s\n' edited
    fi
}

write_outcome() {
    action=$1
    candidate=$2
    state=$3
    selected_profile=${4:-}
    last_named_profile=${5:-}

    case "$selected_profile" in
        '')
            ;;
        *)
            validate_profile "$selected_profile" || fail "invalid selected profile: $selected_profile"
            ;;
    esac
    case "$last_named_profile" in
        '')
            ;;
        *)
            validate_profile "$last_named_profile" || fail "invalid last named profile: $last_named_profile"
            ;;
    esac

    jq -n \
        --arg action "$action" \
        --arg candidate "$candidate" \
        --arg candidate_state "$state" \
        --arg selected_profile "$selected_profile" \
        --arg last_named_profile "$last_named_profile" \
        '{action: $action, candidate: $candidate, candidate_state: $candidate_state, selected_profile: $selected_profile, last_named_profile: $last_named_profile}' \
        >"$outcome_file.$$" || fail 'unable to write controller outcome'
    mv "$outcome_file.$$" "$outcome_file" || fail 'unable to update controller outcome'
}

finish() {
    action=$1
    candidate=$2
    state=$3
    selected_profile=${4:-}
    last_named_profile=${5:-}
    case "$action" in
        insert|copy)
            update_history_accepted_final_text "$candidate"
            ;;
    esac
    write_outcome "$action" "$candidate" "$state" "$selected_profile" "$last_named_profile"
    exit 0
}

main_menu() {
    selection=$(
        printf '%s\n' \
            'Transform with Default' \
            'Transform with Casual' \
            'Transform with Formal' \
            'Transform as Code' \
            'Recover recent dictation' \
            'Clear history' \
            'Insert raw' \
            'Edit raw' \
            'Copy raw' \
            'Cancel' |
            fzf \
                --height=10 \
                --layout=reverse \
                --border \
                --prompt='Action> ' \
                --preview='cat "$VOXTYPE_CANDIDATE_FILE"' \
                --preview-window='right,wrap,60%'
    ) || selection=

    printf '%s\n' "$selection"
}

review_success_menu() {
    header=$1
    menu_items='Insert
Apply another named profile
Enter a standalone follow-up instruction
Reset to raw
Copy
Discard'
    if editor_command >/dev/null 2>&1; then
        menu_items='Insert
Apply another named profile
Enter a standalone follow-up instruction
Reset to raw
Copy
Open in external editor
Discard'
    fi

    selection=$(
        printf '%s\n' "$menu_items" |
            fzf \
                --height=10 \
                --layout=reverse \
                --border \
                --prompt='Review> ' \
                --header="$header" \
                --preview='cat "$VOXTYPE_CANDIDATE_FILE"' \
                --preview-window='right,wrap,60%'
    ) || selection=

    printf '%s\n' "$selection"
}

prompt_follow_up_instruction() {
    header=$1
    instruction=$(
        gum write \
            --height=10 \
            --header="$header" \
            --placeholder='Enter a follow-up instruction' \
            --show-cursor-line \
            --show-line-numbers
    ) || instruction=

    trimmed_is_empty "$instruction" && return 1

    printf '%s\n' "$instruction"
}

open_external_editor() {
    editor_cmd=$(editor_command) || return 1
    editor_file="$session_dir/external-editor.$$.txt"
    cp "$candidate_file" "$editor_file" || {
        printf '%s\n' 'Unable to prepare the external editor file.' >&2
        editor_file=
        return 1
    }

    (
        set -f
        set -- $editor_cmd
        [ "$#" -gt 0 ] || exit 127
        command -v "$1" >/dev/null 2>&1 || exit 127
        "$@" "$editor_file"
    ) || {
        printf '%s\n' "External editor failed; keeping the previous candidate." >&2
        rm -f "$editor_file" 2>/dev/null || true
        editor_file=
        return 1
    }

    [ -f "$editor_file" ] || {
        printf '%s\n' "External editor removed its file; keeping the previous candidate." >&2
        rm -f "$editor_file" 2>/dev/null || true
        editor_file=
        return 1
    }

    edited_candidate=$(cat "$editor_file") || {
        printf '%s\n' "Unable to read the external editor result; keeping the previous candidate." >&2
        rm -f "$editor_file" 2>/dev/null || true
        editor_file=
        return 1
    }
    if trimmed_is_empty "$edited_candidate"; then
        printf '%s\n' "External editor returned empty text; keeping the previous candidate." >&2
        rm -f "$editor_file" 2>/dev/null || true
        editor_file=
        return 1
    fi

    write_file_atomic "$candidate_file" "$edited_candidate"
    rm -f "$editor_file" 2>/dev/null || true
    editor_file=
}

failure_menu() {
    header=$1
    selection=$(
        printf '%s\n' \
            'Retry' \
            'Insert raw' \
            'Copy raw' \
            'Cancel' |
            fzf \
                --height=10 \
                --layout=reverse \
                --border \
                --prompt='Transform failed> ' \
                --header="$header"
    ) || selection=

    printf '%s\n' "$selection"
}

choose_history_record() {
    history_rows=$(
        voxtype_history_list_records |
            while IFS= read -r record_file; do
                voxtype_history_record_row "$record_file"
            done
    )

    [ -n "$history_rows" ] || return 1

    selection=$(
        printf '%s\n' "$history_rows" |
            fzf \
                --height=10 \
                --layout=reverse \
                --border \
                --prompt='Recover> ' \
                --header='Select a recent dictation to recover' \
                --delimiter="$(printf '\t')" \
                --with-nth=2,3,4,5 \
                --preview='record_file=$(printf %s {1} | cut -f1); cat "$record_file"' \
                --preview-window='right,wrap,60%'
    ) || selection=

    case "$selection" in
        '')
            return 1
            ;;
        *)
            printf '%s\n' "$selection" | cut -f1
            ;;
    esac
}

clear_history_confirmation() {
    gum confirm \
        --default=false \
        'Clear all recoverable VoxType history?' \
        >/dev/null 2>&1
}

recover_history_record() {
    record_file=$1
    if ! voxtype_history_validate_record "$record_file"; then
        printf '%s\n' "controller.sh: cannot recover invalid history record: $record_file" >&2
        return 1
    fi

    raw_text=$(jq -r '.raw // empty' <"$record_file" 2>/dev/null || true)
    [ -n "$raw_text" ] || return 1

    candidate_text=$(jq -r '.accepted_final_text // .raw // empty' <"$record_file" 2>/dev/null || true)
    [ -n "$candidate_text" ] || candidate_text=$raw_text
    recovered_profile=$(jq -r '.last_named_profile // empty' <"$record_file" 2>/dev/null || true)

    write_file_atomic "$raw_file" "$raw_text"
    write_file_atomic "$candidate_file" "$candidate_text"

    if [ -n "$recovered_profile" ] &&
        voxtype_history_valid_profile "$recovered_profile"; then
        write_current_profile "$recovered_profile"
        current_profile=$recovered_profile
    else
        rm -f "$profile_state_file" 2>/dev/null || true
        current_profile=
    fi

    write_history_record_file "$record_file"
}

edit_candidate() {
    header=$1
    current_candidate=$(read_file "$candidate_file")
    edited_candidate=$(
        printf '%s' "$current_candidate" |
            gum write \
                --height=12 \
                --header="$header" \
                --placeholder='Edit the transcript' \
                --show-cursor-line \
                --show-line-numbers \
                --value="$current_candidate"
    ) || return 0

    trimmed_is_empty "$edited_candidate" && return 0

    write_file_atomic "$candidate_file" "$edited_candidate"
}

reset_candidate_to_raw() {
    tmp_file="$candidate_file.$$"
    cp "$raw_file" "$tmp_file" || fail 'unable to reset candidate to raw'
    mv "$tmp_file" "$candidate_file" || fail 'unable to reset candidate to raw'
}

run_transform_command() {
    transform_kind=$1
    transform_value=$2
    transform_title=$3
    output_file="$session_dir/transform.out"
    error_file="$session_dir/transform.err"

    if gum spin --title="Transforming with $transform_title" --show-error -- sh -c '
        set -eu
        process_profile_script=$1
        transform_kind=$2
        transform_value=$3
        input_file=$4
        output_file=$5
        error_file=$6
        case "$transform_kind" in
            profile)
                "$process_profile_script" "$transform_value" <"$input_file" >"$output_file" 2>"$error_file"
                ;;
            follow-up)
                "$process_profile_script" --follow-up "$transform_value" <"$input_file" >"$output_file" 2>"$error_file"
                ;;
            *)
                exit 2
                ;;
        esac
    ' sh "$process_profile_script" "$transform_kind" "$transform_value" "$candidate_file" "$output_file" "$error_file"; then
        transformed_candidate=$(cat "$output_file" 2>/dev/null || true)
        if trimmed_is_empty "$transformed_candidate"; then
            error_text=
            if [ -s "$error_file" ]; then
                error_text=$(cat "$error_file")
            fi
            handle_transform_failure "$transform_kind" "$transform_value" "$transform_title" "$error_text"
            return 0
        fi

        write_file_atomic "$candidate_file" "$transformed_candidate"
        case "$transform_kind" in
            profile)
                write_current_profile "$transform_value"
                current_profile=$transform_value
                update_history_last_named_profile "$transform_value"
                ;;
        esac
        run_review_loop "$transform_kind" "$transform_value" "$transform_title"
        return 0
    fi

    error_text=$(cat "$error_file" 2>/dev/null || true)
    handle_transform_failure "$transform_kind" "$transform_value" "$transform_title" "$error_text"
}

run_review_loop() {
    transform_kind=$1
    transform_value=$2
    transform_title=$3
    needs_editor=yes

    while :; do
        if [ "$needs_editor" = yes ]; then
            edit_candidate "Review transformed text ($transform_title)"
            needs_editor=no
        fi

        review_choice=$(review_success_menu "Review transformed text ($transform_title)")
        case "$review_choice" in
            Insert)
                finish insert "$(read_file "$candidate_file")" "$(candidate_state)" "${current_profile:-}" "${current_profile:-}"
                ;;
            'Apply another named profile')
                if next_profile=$(choose_profile); then
                    run_transform_command profile "$next_profile" "$(profile_label "$next_profile")"
                    return 0
                fi
                ;;
            'Enter a standalone follow-up instruction')
                if follow_up_instruction=$(prompt_follow_up_instruction "Follow-up instruction for $transform_title"); then
                    run_transform_command follow-up "$follow_up_instruction" 'Follow-up instruction'
                    return 0
                fi
                ;;
            'Reset to raw')
                reset_candidate_to_raw
                return 0
                ;;
            Copy)
                finish copy "$(read_file "$candidate_file")" "$(candidate_state)" "${current_profile:-}" "${current_profile:-}"
                ;;
            'Open in external editor')
                open_external_editor || true
                ;;
            Discard|'')
                return 0
                ;;
            *)
                return 0
                ;;
        esac
    done
}

run_transform() {
    profile=$1
    profile_title=$(profile_label "$profile") || fail "unknown profile: $profile"
    run_transform_command profile "$profile" "$profile_title"
}

handle_transform_failure() {
    transform_kind=$1
    transform_value=$2
    transform_title=$3
    error_text=$(sanitize_error "${4:-}")
    failed_selected_profile=

    case "$transform_kind" in
        profile)
            failed_selected_profile=$transform_value
            if [ -n "$error_text" ]; then
                header="Transform with $transform_title failed:
$error_text"
            else
                header="Transform with $transform_title failed: transform returned empty output"
            fi
            ;;
        follow-up)
            failed_selected_profile=${current_profile:-}
            if [ -n "$error_text" ]; then
                header="Follow-up instruction failed:
$error_text"
            else
                header='Follow-up instruction failed: transform returned empty output'
            fi
            ;;
        *)
            failed_selected_profile=${current_profile:-}
            header='Transform failed'
            ;;
    esac

    while :; do
        choice=$(failure_menu "$header")
        case "$choice" in
            Retry)
                run_transform_command "$transform_kind" "$transform_value" "$transform_title"
                return 0
                ;;
            'Insert raw')
                finish insert "$(read_file "$raw_file")" raw "$failed_selected_profile" "${current_profile:-}"
                ;;
            'Copy raw')
                finish copy "$(read_file "$raw_file")" raw "$failed_selected_profile" "${current_profile:-}"
                ;;
            Cancel|'')
                finish cancel "$(read_file "$candidate_file")" "$(candidate_state)" "$failed_selected_profile" "${current_profile:-}"
                ;;
            *)
                finish cancel "$(read_file "$candidate_file")" "$(candidate_state)" "$failed_selected_profile" "${current_profile:-}"
                ;;
        esac
    done
}

choose_profile() {
    read_current_profile
    selection=$(
        {
            if [ -n "${current_profile:-}" ]; then
                printf '%s\t%s\t%s\n' "$current_profile" "$(profile_label "$current_profile") (current)" 'current'
            fi
            for profile in default casual formal code; do
                [ "$profile" = "${current_profile:-}" ] && continue
                printf '%s\t%s\t%s\n' "$profile" "$(profile_label "$profile")" ''
            done
        } |
            fzf \
                --height=10 \
                --layout=reverse \
                --border \
                --prompt='Profile> ' \
                --delimiter="$(printf '\t')" \
                --with-nth=2,3 \
                --preview='profile=$(printf %s {1} | cut -f1); cat "$PROFILES_DIR/$profile.txt"' \
                --preview-window='right,wrap,60%'
    ) || selection=

    case "$selection" in
        '')
            return 1
            ;;
        *)
            printf '%s\n' "$selection" | cut -f1
            ;;
    esac
}

main() {
    [ -f "$raw_file" ] || fail "missing raw file: $raw_file"
    [ -f "$candidate_file" ] || fail "missing candidate file: $candidate_file"
    mkdir -p "$session_dir" || fail "unable to create session directory: $session_dir"

    read_current_profile
    read_history_record_file
    voxtype_history_purge_old_records

    while :; do
        choice=$(main_menu)
        case "$choice" in
            'Transform with Default')
                run_transform default
                continue
                ;;
            'Transform with Casual')
                run_transform casual
                continue
                ;;
            'Transform with Formal')
                run_transform formal
                continue
                ;;
            'Transform as Code')
                run_transform code
                continue
                ;;
            'Recover recent dictation')
                if record_file=$(choose_history_record); then
                    recover_history_record "$record_file"
                fi
                continue
                ;;
            'Clear history')
                if clear_history_confirmation; then
                    voxtype_history_clear_all
                    history_record_file=
                    rm -f "$history_record_path_file" 2>/dev/null || true
                fi
                continue
                ;;
            'Insert raw')
                finish insert "$(read_file "$candidate_file")" "$(candidate_state)" '' "${current_profile:-}"
                ;;
            'Copy raw')
                finish copy "$(read_file "$candidate_file")" "$(candidate_state)" '' "${current_profile:-}"
                ;;
            'Edit raw')
                edit_candidate 'Edit raw dictation'
                ;;
            'Cancel'|'')
                finish cancel "$(read_file "$candidate_file")" "$(candidate_state)" '' "${current_profile:-}"
                ;;
            *)
                finish cancel "$(read_file "$candidate_file")" "$(candidate_state)" '' "${current_profile:-}"
                ;;
        esac
    done
}

main "$@"

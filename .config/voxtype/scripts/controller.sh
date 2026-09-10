#!/bin/sh
# Terminal-only controller for VoxType raw dictation delivery.
set -eu
umask 077

raw_file=${VOXTYPE_RAW_FILE:?VOXTYPE_RAW_FILE is required}
candidate_file=${VOXTYPE_CANDIDATE_FILE:?VOXTYPE_CANDIDATE_FILE is required}
outcome_file=${VOXTYPE_OUTCOME_FILE:?VOXTYPE_OUTCOME_FILE is required}
session_dir=${VOXTYPE_SESSION_DIR:?VOXTYPE_SESSION_DIR is required}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
process_profile_script="$script_dir/process-profile.sh"
profile_state_file="$session_dir/current-named-profile.txt"
preview_profiles_dir=${VOXTYPE_PROFILES_DIR:-$HOME/.config/voxtype/profiles}

export PROFILES_DIR="$preview_profiles_dir"

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
    selection=$(
        printf '%s\n' \
            'Insert' \
            'Apply another named profile' \
            'Reset to raw' \
            'Copy' \
            'Discard' |
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

run_transform() {
    profile=$1
    profile_title=$(profile_label "$profile") || fail "unknown profile: $profile"
    output_file="$session_dir/transform.out"
    error_file="$session_dir/transform.err"

    if gum spin --title="Transforming with $profile_title" --show-error -- sh -c '
        set -eu
        process_profile_script=$1
        profile=$2
        input_file=$3
        output_file=$4
        error_file=$5
        "$process_profile_script" "$profile" <"$input_file" >"$output_file" 2>"$error_file"
    ' sh "$process_profile_script" "$profile" "$candidate_file" "$output_file" "$error_file"; then
        transformed_candidate=$(cat "$output_file" 2>/dev/null || true)
        if trimmed_is_empty "$transformed_candidate"; then
            error_text=
            if [ -s "$error_file" ]; then
                error_text=$(cat "$error_file")
            fi
            handle_transform_failure "$profile" "$error_text"
            return 0
        fi

        write_file_atomic "$candidate_file" "$transformed_candidate"
        write_current_profile "$profile"
        current_profile=$profile
        needs_editor=yes
        while :; do
            if [ "$needs_editor" = yes ]; then
                edit_candidate "Review transformed text ($profile_title)"
                needs_editor=no
            fi
            review_choice=$(review_success_menu "Review transformed text ($profile_title)")
            case "$review_choice" in
                Insert)
                    finish insert "$(read_file "$candidate_file")" "$(candidate_state)" "$profile" "$profile"
                    ;;
                'Apply another named profile')
                    if next_profile=$(choose_profile); then
                        profile=$next_profile
                        profile_title=$(profile_label "$profile") || fail "unknown profile: $profile"
                        output_file="$session_dir/transform.out"
                        error_file="$session_dir/transform.err"
                        if gum spin --title="Transforming with $profile_title" --show-error -- sh -c '
                            set -eu
                            process_profile_script=$1
                            profile=$2
                            input_file=$3
                            output_file=$4
                            error_file=$5
                            "$process_profile_script" "$profile" <"$input_file" >"$output_file" 2>"$error_file"
                        ' sh "$process_profile_script" "$profile" "$candidate_file" "$output_file" "$error_file"; then
                            transformed_candidate=$(cat "$output_file" 2>/dev/null || true)
                            if trimmed_is_empty "$transformed_candidate"; then
                                error_text=
                                if [ -s "$error_file" ]; then
                                    error_text=$(cat "$error_file")
                                fi
                                handle_transform_failure "$profile" "$error_text"
                                return 0
                            fi
                            write_file_atomic "$candidate_file" "$transformed_candidate"
                            write_current_profile "$profile"
                            current_profile=$profile
                            needs_editor=yes
                            continue
                        fi
                        error_text=$(cat "$error_file" 2>/dev/null || true)
                        handle_transform_failure "$profile" "$error_text"
                        return 0
                    fi
                    ;;
                'Reset to raw')
                    reset_candidate_to_raw
                    return 0
                    ;;
                Copy)
                    finish copy "$(read_file "$candidate_file")" "$(candidate_state)" "$profile" "$profile"
                    ;;
                Discard|'')
                    return 0
                    ;;
                *)
                    return 0
                    ;;
            esac
        done
    fi

    error_text=$(cat "$error_file" 2>/dev/null || true)
    handle_transform_failure "$profile" "$error_text"
}

handle_transform_failure() {
    profile=$1
    error_text=$(sanitize_error "${2:-}")
    if [ -n "$error_text" ]; then
        header="Transform with $(profile_label "$profile") failed:
$error_text"
    else
        header="Transform with $(profile_label "$profile") failed: transform returned empty output"
    fi

    while :; do
        choice=$(failure_menu "$header")
        case "$choice" in
            Retry)
                run_transform "$profile"
                return 0
                ;;
            'Insert raw')
                finish insert "$(read_file "$raw_file")" raw "$profile" "${current_profile:-}"
                ;;
            'Copy raw')
                finish copy "$(read_file "$raw_file")" raw "$profile" "${current_profile:-}"
                ;;
            Cancel|'')
                finish cancel "$(read_file "$candidate_file")" "$(candidate_state)" "$profile" "${current_profile:-}"
                ;;
            *)
                finish cancel "$(read_file "$candidate_file")" "$(candidate_state)" "$profile" "${current_profile:-}"
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

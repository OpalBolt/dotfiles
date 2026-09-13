# VoxType history helpers.
#
# This file is meant to be sourced from POSIX shell scripts.

voxtype_history_state_root() {
    printf '%s\n' "${XDG_STATE_HOME:-$HOME/.local/state}"
}

voxtype_history_dir() {
    printf '%s\n' "$(voxtype_history_state_root)/voxtype/history"
}

voxtype_history_ensure_dir() {
    history_dir=$(voxtype_history_dir)
    mkdir -p "$history_dir" || return 1
    chmod 700 "$history_dir" 2>/dev/null || true
}

voxtype_history_record_path() {
    timestamp=$1
    suffix=$2
    printf '%s/%s-%s.json\n' "$(voxtype_history_dir)" "$timestamp" "$suffix"
}

voxtype_history_valid_profile() {
    case ${1:-} in
        ''|default|casual|formal|code) return 0 ;;
    esac
    return 1
}

voxtype_history_validate_record() {
    record_file=$1
    [ -f "$record_file" ] || return 1

    jq -e '
        (.timestamp | type == "number") and
        (.raw | type == "string") and
        ((has("accepted_final_text") | not) or
            (.accepted_final_text | type == "string")) and
        ((has("last_named_profile") | not) or
            (.last_named_profile |
                . == "default" or . == "casual" or
                . == "formal" or . == "code"))
    ' <"$record_file" >/dev/null 2>&1
}

voxtype_history_list_records() {
    history_dir=$(voxtype_history_dir)
    [ -d "$history_dir" ] || return 0

    for record_file in "$history_dir"/*.json; do
        [ -f "$record_file" ] || continue
        printf '%s\n' "$record_file"
    done | sort -r
}

voxtype_history_purge_old_records() {
    retention_secs=$((30 * 24 * 60 * 60))
    current_epoch=$(date +%s)
    cutoff_epoch=$((current_epoch - retention_secs))
    history_dir=$(voxtype_history_dir)

    [ -d "$history_dir" ] || return 0

    for record_file in "$history_dir"/*.json; do
        [ -f "$record_file" ] || continue
        record_name=${record_file##*/}
        record_timestamp=${record_name%%-*}
        case "$record_timestamp" in
            ''|*[!0-9]*)
                continue
                ;;
        esac
        if [ "$record_timestamp" -lt "$cutoff_epoch" ]; then
            rm -f "$record_file" 2>/dev/null || true
        fi
    done
}

voxtype_history_create_record() {
    raw_text=$1
    last_named_profile=${2:-}

    voxtype_history_ensure_dir || return 1

    timestamp=$(date +%s)
    record_file=$(voxtype_history_record_path "$timestamp" "$$")
    tmp_file="$record_file.$$"

    if [ -n "$last_named_profile" ]; then
        voxtype_history_valid_profile "$last_named_profile" || return 1
        jq -n \
            --argjson timestamp "$timestamp" \
            --arg raw "$raw_text" \
            --arg last_named_profile "$last_named_profile" \
            '{timestamp: $timestamp, raw: $raw, last_named_profile: $last_named_profile}' \
            >"$tmp_file" || return 1
    else
        jq -n \
            --argjson timestamp "$timestamp" \
            --arg raw "$raw_text" \
            '{timestamp: $timestamp, raw: $raw}' \
            >"$tmp_file" || return 1
    fi
    mv "$tmp_file" "$record_file" || return 1

    printf '%s\n' "$record_file"
}

voxtype_history_update_last_named_profile() {
    record_file=$1
    last_named_profile=${2:-}

    [ -f "$record_file" ] || return 0

    voxtype_history_valid_profile "$last_named_profile" || return 1
    tmp_file="$record_file.$$"
    if [ -n "$last_named_profile" ]; then
        jq --arg last_named_profile "$last_named_profile" \
            '.last_named_profile = $last_named_profile' \
            <"$record_file" >"$tmp_file" || return 1
    else
        jq 'del(.last_named_profile)' <"$record_file" >"$tmp_file" || return 1
    fi
    mv "$tmp_file" "$record_file" || return 1
}

voxtype_history_update_accepted_final_text() {
    record_file=$1
    final_text=${2:-}

    [ -f "$record_file" ] || return 0

    tmp_file="$record_file.$$"
    if [ -n "$(printf '%s' "$final_text" | tr -d '[:space:]')" ]; then
        jq --arg accepted_final_text "$final_text" \
            '.accepted_final_text = $accepted_final_text' \
            <"$record_file" >"$tmp_file" || return 1
    else
        jq 'del(.accepted_final_text)' <"$record_file" >"$tmp_file" || return 1
    fi
    mv "$tmp_file" "$record_file" || return 1
}

voxtype_history_clear_all() {
    history_dir=$(voxtype_history_dir)
    [ -d "$history_dir" ] || return 0

    for record_file in "$history_dir"/*.json; do
        [ -f "$record_file" ] || continue
        rm -f "$record_file" 2>/dev/null || true
    done
}

voxtype_history_record_row() {
    record_file=$1
    if ! voxtype_history_validate_record "$record_file"; then
        printf '%s\n' "history.sh: skipping invalid history record: $record_file" >&2
        return 1
    fi

    timestamp=$(jq -r '.timestamp // empty' <"$record_file" 2>/dev/null || true)
    last_named_profile=$(jq -r '.last_named_profile // empty' <"$record_file" 2>/dev/null || true)

    if jq -e 'has("accepted_final_text") and (.accepted_final_text | type == "string") and (.accepted_final_text | length > 0)' \
        <"$record_file" >/dev/null 2>&1; then
        status=accepted
        text=$(jq -r '.accepted_final_text // empty' <"$record_file" 2>/dev/null || true)
    else
        status=raw
        text=$(jq -r '.raw // empty' <"$record_file" 2>/dev/null || true)
    fi

    preview=$(printf '%s' "$text" | tr '\r\n' '  ' | tr -s '[:space:]' ' ' | cut -c1-80)
    [ -n "$last_named_profile" ] || last_named_profile='-'

    printf '%s\t%s\t%s\t%s\t%s\n' "$record_file" "$timestamp" "$status" "$last_named_profile" "$preview"
}

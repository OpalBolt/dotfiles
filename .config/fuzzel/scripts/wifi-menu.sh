#!/bin/sh

set -eu

notify() {
    notify-send 'Wi-Fi' "$1" 2>/dev/null || true
}

run_nmcli() {
    if output=$(nmcli "$@" 2>&1); then
        notify "$output"
    else
        notify "$output"
        printf '%s\n' "$output" >&2
        exit 1
    fi
}

saved_networks() {
    if ! connections=$(nmcli --terse --fields UUID,TYPE connection show 2>&1); then
        notify "$connections"
        printf '%s\n' "$connections" >&2
        exit 1
    fi

    printf '%s\n' "$connections" |
        while IFS=: read -r uuid type; do
            case "$type" in
                802-11-wireless|wifi)
                    ssid=$(nmcli --escape no --get-values 802-11-wireless.ssid connection show uuid "$uuid")
                    name=$(nmcli --escape no --get-values connection.id connection show uuid "$uuid")
                    [ -n "$ssid" ] && printf '%s\t%s\t%s\n' "$ssid" "$uuid" "$name"
                    ;;
            esac
        done
}

is_visible() {
    ssid=$1
    printf '%s\n' "$visible_networks" | grep -F -x -q -- "$ssid"
}

select_saved_network() {
    visibility=$1
    choices=$(
        printf '%s\n' "$saved" |
            while IFS="$(printf '\t')" read -r ssid uuid name; do
                if { [ "$visibility" = visible ] && is_visible "$ssid"; } ||
                    { [ "$visibility" = hidden ] && ! is_visible "$ssid"; }; then
                    printf '%s (%s)\t%s\n' "$ssid" "$name" "$uuid"
                fi
            done
    )

    if [ -z "$choices" ]; then
        if [ "$visibility" = visible ]; then
            notify 'No saved networks are currently visible'
        else
            notify 'No saved networks are currently hidden'
        fi
        exit 0
    fi

    uuid=$(
        printf '%s\n' "$choices" |
            fuzzel --dmenu \
                --prompt='Wi-Fi  ' \
                --with-nth=1 \
                --accept-nth=2 \
                --match-nth=1 \
                --lines=10 \
                --minimal-lines \
                --no-sort \
                --only-match
    ) || exit 0

    run_nmcli connection up uuid "$uuid"
}

select_visible_network() {
    if [ -z "$visible_networks" ]; then
        notify 'No visible Wi-Fi networks found'
        exit 0
    fi

    ssid=$(
        printf '%s\n' "$visible_networks" |
            fuzzel --dmenu \
                --prompt='Visible Wi-Fi  ' \
                --lines=12 \
                --minimal-lines \
                --no-sort \
                --only-match
    ) || exit 0

    saved_uuid=$(
        printf '%s\n' "$saved" |
            awk -F '\t' -v selected="$ssid" '$1 == selected { print $2; exit }'
    )

    if [ -n "$saved_uuid" ]; then
        run_nmcli connection up uuid "$saved_uuid"
        return
    fi

    if ! security_scan=$(nmcli --terse --escape no --fields SSID,SECURITY device wifi list --rescan no 2>&1); then
        notify "$security_scan"
        printf '%s\n' "$security_scan" >&2
        exit 1
    fi

    security=$(
        printf '%s\n' "$security_scan" |
            awk -v selected="$ssid" '
                {
                    security = $0
                    sub(/^.*:/, "", security)
                    network = $0
                    sub(/:[^:]*$/, "", network)
                    if (network == selected) {
                        print security
                        exit
                    }
                }
            '
    )

    case "$security" in
        ''|--)
            run_nmcli device wifi connect "$ssid"
            ;;
        *)
            password=$(
                fuzzel --dmenu \
                    --prompt-only="Password for $ssid  " \
                    --password
            ) || exit 0
            [ -n "$password" ] || exit 0
            run_nmcli device wifi connect "$ssid" password "$password"
            ;;
    esac
}

mode=$(
    printf '%s\n' \
        'Known and visible' \
        'Saved but not visible' \
        'All visible networks' |
        fuzzel --dmenu \
            --prompt='Wi-Fi menu  ' \
            --lines=3 \
            --minimal-lines \
            --no-sort \
            --only-match
) || exit 0

notify 'Scanning for Wi-Fi networks...'

if ! visible_scan=$(nmcli --terse --escape no --fields SSID device wifi list --rescan yes 2>&1); then
    notify "$visible_scan"
    printf '%s\n' "$visible_scan" >&2
    exit 1
fi

visible_networks=$(printf '%s\n' "$visible_scan" | awk 'NF && !seen[$0]++')
saved=$(saved_networks)

case "$mode" in
    'Known and visible')
        select_saved_network visible
        ;;
    'Saved but not visible')
        select_saved_network hidden
        ;;
    'All visible networks')
        select_visible_network
        ;;
esac

#!/bin/sh

set -eu

wallpaper_dir=${WALLPAPER_DIR:-"$HOME/Pictures/backgrounds"}

if [ ! -d "$wallpaper_dir" ]; then
    message="Wallpaper directory does not exist: $wallpaper_dir"
    notify-send 'Wallpaper picker' "$message" 2>/dev/null || true
    printf '%s\n' "$message" >&2
    exit 1
fi

if ! command -v awww >/dev/null 2>&1; then
    message='awww is required to set the wallpaper'
    notify-send 'Wallpaper picker' "$message" 2>/dev/null || true
    printf '%s\n' "$message" >&2
    exit 1
fi

if ! command -v matugen >/dev/null 2>&1; then
    message='matugen is required to generate the desktop theme'
    notify-send 'Wallpaper picker' "$message" 2>/dev/null || true
    printf '%s\n' "$message" >&2
    exit 1
fi

thumbnail_for() {
    wallpaper=$1

    if ! command -v ffmpeg >/dev/null 2>&1; then
        case "$wallpaper" in
        *.[Pp][Nn][Gg] | *.[Ss][Vv][Gg])
            printf '%s\n' "$wallpaper"
            ;;
        *)
            printf '%s\n' 'image-x-generic'
            ;;
        esac
        return
    fi

    cache_dir=${XDG_CACHE_HOME:-"$HOME/.cache"}/fuzzel-wallpaper-thumbnails
    if ! mkdir -p "$cache_dir"; then
        printf '%s\n' 'image-x-generic'
        return
    fi

    cache_key=$(printf '%s' "$wallpaper" | sha256sum | cut -d' ' -f1)
    thumbnail=$cache_dir/$cache_key.png

    if [ ! -f "$thumbnail" ] || [ "$wallpaper" -nt "$thumbnail" ]; then
        temporary_thumbnail=$thumbnail.$$.png
        if ffmpeg -loglevel error -nostdin -y \
            -i "$wallpaper" \
            -frames:v 1 \
            -vf 'scale=480:270:force_original_aspect_ratio=decrease' \
            "$temporary_thumbnail"; then
            mv "$temporary_thumbnail" "$thumbnail"
        else
            rm -f "$temporary_thumbnail"
            printf '%s\n' 'image-x-generic'
            return
        fi
    fi

    printf '%s\n' "$thumbnail"
}

entries=$(
    find "$wallpaper_dir" -type f \
        \( -iname '*.avif' -o -iname '*.gif' -o -iname '*.jpeg' \
        -o -iname '*.jpg' -o -iname '*.png' -o -iname '*.webp' \) \
        -printf '%P\n' |
        LC_ALL=C sort
)

if [ -z "$entries" ]; then
    message="No supported images found in: $wallpaper_dir"
    notify-send 'Wallpaper picker' "$message" 2>/dev/null || true
    printf '%s\n' "$message" >&2
    exit 1
fi

selection=$(
    printf '%s\n' "$entries" |
        while IFS= read -r relative_path; do
            preview=$(thumbnail_for "$wallpaper_dir/$relative_path")
            printf '%s\0icon\037%s\n' \
                "$relative_path" \
                "$preview"
        done |
        fuzzel --dmenu \
            --prompt='Wallpaper  ' \
            --placeholder='Type to filter' \
            --width=72 \
            --lines=5 \
            --line-height=72px \
            --override=image-size-ratio=0.75 \
            --minimal-lines \
            --no-sort \
            --only-match
) || exit 0

wallpaper=$wallpaper_dir/$selection
[ -f "$wallpaper" ] || exit 1

matugen image --quiet "$wallpaper" --prefer value

awww img \
    --resize=crop \
    --transition-type=fade \
    --transition-duration=1 \
    "$wallpaper"

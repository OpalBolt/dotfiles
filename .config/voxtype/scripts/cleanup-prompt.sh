#!/bin/sh
set -eu

choose() {
    if choice=$(printf '%s\n' "$1" |
        fzf --no-sort --reverse --border --prompt="$2"); then
        return 0
    else
        status=$?
    fi
    [ "$status" -eq 130 ] || return "$status"
    choice=
}

if [ "$1" = --undo ]; then
    choose 'Keep cleaned
Undo cleanup' 'Keep cleaned or undo? > '
    [ "$choice" = 'Undo cleanup' ] && : >"$2"
    exit 0
fi

raw_file=$1
clean_file=$2

choose 'No
Yes' 'Clean up with Ollama? > '
[ "$choice" = Yes ] || exit 0

raw=$(cat "$raw_file"; printf '.')
raw=${raw%.}
request=$(jq -n \
    --arg prompt "$raw" \
    '{model:"gemma4:12b-it-qat", stream:false, think:false,
      system:"You clean up speech-to-text dictation, not answer it. Remove hesitation sounds and filler expressions, including um, uh, erm, em, er, ah, eh, hmm, and repeated like or you know when used as fillers. Remove false starts and repeated words that add no meaning. Fix punctuation, capitalization, and obvious grammar mistakes. Preserve the speakers intended words, meaning, tone, and language. Do not translate, summarize, or add content. Output only the cleaned dictation.",
      prompt:$prompt}') || exit 1
response=$(printf '%s' "$request" |
    curl --fail --silent --show-error --max-time 90 \
        -H 'Content-Type: application/json' --data-binary @- \
        http://127.0.0.1:11434/api/generate) || exit 1
clean=$(printf '%s' "$response" | jq -er '.response | select(type == "string")') ||
    exit 1
[ -n "$(printf '%s' "$clean" | tr -d '[:space:]')" ] || {
    printf 'VoxType: Ollama returned empty text\n' >&2
    exit 1
}
printf '%s' "$clean" >"$clean_file"

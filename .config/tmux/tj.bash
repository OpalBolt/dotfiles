#!/usr/bin/env bash
# tj - tmux workspace navigator (bash edition, Television as picker)
# Use it in any shell:
#   bash/zsh:  source /path/to/tj.bash     (zsh gets a small wrapper that runs it with bash)
#   or run it directly:  chmod +x tj.bash && ln -s $PWD/tj.bash ~/.local/bin/tj

# zsh: BASH_SOURCE doesn't exist and the syntax differs, so just define a wrapper
if [ -n "${ZSH_VERSION:-}" ]; then
  _tj_file="${(%):-%x}"
  eval 'tj() { bash "'"${_tj_file:A}"'" "$@"; }'
  return 0
fi

TJ_SELF=$(realpath "${BASH_SOURCE[0]}")
SEP=' │ '

_tj_expand() { printf '%s' "${1/#\~/$HOME}"; }          # ~/x -> /home/u/x
_tj_trunc()  { # str max
  if (( ${#1} > $2 )); then printf '%s…' "${1:0:$2-1}"; else printf '%s' "$1"; fi
}

# ---------- list: prints the aligned entries (tv's source command) ----------
_tj_list() {
  local git=${TJ_GIT_DIR:-$HOME/git}
  local cust=${TJ_CUST_DIR:-$git/custproj}
  local proj=${TJ_PROJECTS_DIR:-$HOME/projects}
  local max1=${TJ_COL1_MAX:-28} max2=${TJ_COL2_MAX:-30}
  git=${git%/}; cust=${cust%/}; proj=${proj%/}

  # rows: parallel arrays emoji / tag / name / target
  local E=() T=() N=() P=()
  _add() { E+=("$1"); T+=("$(_tj_trunc "$2" $((max1-3)))"); N+=("$(_tj_trunc "$3" "$max2")"); P+=("$4"); }

  local s d c
  # 1. sessions (most recent activity first)
  while IFS= read -r s; do
    [[ -n $s ]] && _add "⚡" "Session" "$s" "session:$s"
  done < <(tmux list-sessions -F '#{session_activity} #{session_name}' 2>/dev/null | sort -rn | cut -d' ' -f2-)

  # 2. git repos (skip the customer container)
  for d in "$git"/*/; do
    d=${d%/}; [[ -d $d && $d != "$cust" ]] && _add "📁" "git" "${d##*/}" "${d/#$HOME/\~}"
  done
  # 3. customer projects
  for c in "$cust"/*/; do
    c=${c%/}
    for d in "$c"/*/; do
      d=${d%/}; [[ -d $d ]] && _add "💼" "${c##*/}" "${d##*/}" "${d/#$HOME/\~}"
    done
  done
  # 4. other projects
  for d in "$proj"/*/; do
    d=${d%/}; [[ -d $d ]] && _add "📁" "projects" "${d##*/}" "${d/#$HOME/\~}"
  done

  # column widths (emoji = 2 cells + 1 space = 3 before the tag text)
  local w1=0 w2=0 i
  for i in "${!P[@]}"; do
    (( 3 + ${#T[i]} > w1 )) && w1=$(( 3 + ${#T[i]} ))
    (( ${#N[i]} > w2 )) && w2=${#N[i]}
  done
  for i in "${!P[@]}"; do
    printf '%s %s%*s%s%s%*s%s%s\n' "${E[i]}" "${T[i]}" $((w1-3-${#T[i]})) '' "$SEP" \
           "${N[i]}" $((w2-${#N[i]})) '' "$SEP" "${P[i]}"
  done
}

# ---------- preview ----------
_tj_preview() {
  local t=${1##*"$SEP"}
  if [[ $t == session:* ]]; then
    local name=${t#session:} a w n found=0
    # list-sessions is the reliable way to get exact-name info (no target parsing quirks)
    while read -r a w n; do
      [[ $n == "$name" ]] || continue
      found=1
      (( a > 0 )) && echo "Status: attached ($a client(s))" || echo "Status: detached"
      echo "Windows: $w"
      tmux list-windows -t "=$name" -F \
        '  #{window_index}: #{window_name}#{?window_active, *,} (#{window_panes} panes) #{pane_current_path}'
      echo; echo "Attach: tmux attach -t $name"
    done < <(tmux list-sessions -F '#{session_attached} #{session_windows} #{session_name}' 2>/dev/null)
    (( found )) || echo "Session '$name' is not running."
  else
    t=$(_tj_expand "$t")
    local r found=0
    for r in "$t"/[Rr][Ee][Aa][Dd][Mm][Ee]*; do
      [[ -f $r ]] && { head -n 10 "$r"; found=1; break; }
    done
    (( found )) || echo "(no README)"
    echo "────────────────────────────────"
    ls -la "$t"
  fi
}

# ---------- main ----------
tj() {
  command -v tv   >/dev/null || { echo "tj: tv not found" >&2; return 1; }
  command -v tmux >/dev/null || { echo "tj: tmux not found" >&2; return 1; }
  [[ $(locale charmap 2>/dev/null) == UTF-8 ]] || echo "tj: warning: locale is not UTF-8" >&2

  # export config so tv's child commands see the same settings
  export TJ_GIT_DIR=${TJ_GIT_DIR:-$HOME/git}
  export TJ_CUST_DIR=${TJ_CUST_DIR:-$TJ_GIT_DIR/custproj}
  export TJ_PROJECTS_DIR=${TJ_PROJECTS_DIR:-$HOME/projects}
  export TJ_COL1_MAX TJ_COL2_MAX

  # one-off tv channel in a temp cable dir
  local dir sel; dir=$(mktemp -d)
  local nosort=false; [[ ${TJ_KEEP_ORDER:-1} == 1 ]] && nosort=true
  cat > "$dir/tj.toml" <<TOML
[metadata]
name = "tj"
description = "tmux workspace navigator"

[source]
command = "bash \"$TJ_SELF\" --list"
no_sort = $nosort
frecency = false

[preview]
command = "bash \"$TJ_SELF\" --preview '{}'"
TOML

  # shellcheck disable=SC2086
  sel=$(tv --cable-dir "$dir" ${TJ_TV_OPTS:-} tj)
  rm -rf "$dir"
  sel=${sel%%$'\n'*}
  [[ -z $sel ]] && return 0

  # act on column 3 only
  local t=${sel##*"$SEP"} name
  if [[ $t == session:* ]]; then
    name=${t#session:}
    if [[ -n $TMUX ]]; then tmux switch-client -t "=$name"; else tmux attach-session -t "=$name"; fi
    return
  fi

  local d; d=$(_tj_expand "$t"); d=${d%/}
  name=${d##*/}
  if [[ ${TJ_QUALIFY_CUSTOMER:-0} == 1 && $(dirname "$(dirname "$d")") == "${TJ_CUST_DIR%/}" ]]; then
    name="$(basename "$(dirname "$d")")-$name"
  fi
  name=${name//[.:]/_}

  if [[ -n $TMUX ]]; then
    tmux has-session -t "=$name" 2>/dev/null || tmux new-session -d -s "$name" -c "$d"
    tmux switch-client -t "=$name"
  else
    tmux new-session -A -s "$name" -c "$d"
  fi
}

# executed directly -> helper modes for tv, or run tj itself
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  case $1 in
    --list)    _tj_list ;;
    --preview) _tj_preview "$2" ;;
    *)         tj "$@" ;;
  esac
fi

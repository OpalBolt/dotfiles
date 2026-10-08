#!/usr/bin/env zsh
# ============================================================================
# zj — tmux session / project navigator, powered by Television (tv)
#
# Setup:   source /path/to/zj.zsh        # from ~/.zshrc, then run:  zj
# Needs:   zsh (UTF-8 locale), tmux, tv (Television). Optional: eza
#
# Source it (don't execute it). The same file doubles as tv's preview helper:
#   zsh zj.zsh --preview '<picker line>'
#
# Configuration (set before sourcing):
#   ZJ_GIT_DIR=~/git                 ZJ_CUST_DIR=$ZJ_GIT_DIR/custproj
#   ZJ_PROJECTS_DIR=~/projects
#   ZJ_COL1_MAX=28   ZJ_COL2_MAX=30  display caps (visual columns)
#   ZJ_TV_OPTS=(--layout portrait)   extra flags passed to tv
#   ZJ_KEEP_ORDER=1                  1 = keep category order (adds tv's
#                                    --no-sort when supported); 0 = let tv
#                                    rank by match quality
#   ZJ_QUALIFY_CUSTOMER=0            1 = name customer sessions
#                                    "<Customer>-<Project>" so that
#                                    AcmeCorp/website and Beta/website don't
#                                    collide on the session name "website"
# ============================================================================

# ── Configuration ───────────────────────────────────────────────────────────
typeset -g ZJ_SELF=${${(%):-%x}:A}
: ${ZJ_GIT_DIR:=$HOME/git}
: ${ZJ_CUST_DIR:=${ZJ_GIT_DIR%/}/custproj}
: ${ZJ_PROJECTS_DIR:=$HOME/projects}
: ${ZJ_COL1_MAX:=28}
: ${ZJ_COL2_MAX:=30}
: ${ZJ_KEEP_ORDER:=1}
: ${ZJ_QUALIFY_CUSTOMER:=0}
(( ${+ZJ_TV_OPTS} )) || typeset -ga ZJ_TV_OPTS=()

# ── Small helpers ───────────────────────────────────────────────────────────

# /home/me/x -> ~/x   (result in REPLY)
_zj_tilde() {
  emulate -L zsh
  if [[ $1 == "$HOME"/* ]]; then REPLY='~/'${1#"$HOME"/}; else REPLY=$1; fi
}

# ~/x -> /home/me/x   (result in REPLY)
_zj_untilde() {
  emulate -L zsh
  if   [[ $1 == '~' ]];   then REPLY=$HOME
  elif [[ $1 == '~/'* ]]; then REPLY=$HOME/${1#'~/'}
  else REPLY=$1; fi
}

# Truncate $1 to at most $2 *visual* columns, ending in "…" (result in REPLY).
_zj_trunc() {
  emulate -L zsh
  local s=$1 cap=$2
  if (( ${(m)#s} > cap )); then
    while (( ${(m)#s} > cap - 1 )); do s=${s%?}; done
    s+='…'
  fi
  REPLY=$s
}

# Session name for a project directory (result in REPLY). tmux silently turns
# "." and ":" in session names into "_", so do the same up front; that way our
# exact-match lookups (-t =name) agree with what tmux actually created.
_zj_dir_session_name() {
  emulate -L zsh
  local d=${1%/} name
  name=${d:t}
  if [[ $ZJ_QUALIFY_CUSTOMER == 1 && $d == "${ZJ_CUST_DIR%/}"/*/* ]]; then
    name=${${d:h}:t}-$name
  fi
  REPLY=${name//[.:]/_}
}

# Running tmux session names, most recently active first.
_zj_sessions() {
  emulate -L zsh
  (( $+commands[tmux] )) || return 0
  local raw line
  raw=$(command tmux list-sessions -F '#{session_activity} #{session_name}' 2>/dev/null \
        | command sort -rn)
  for line in "${(@f)raw}"; do
    [[ -n $line ]] && print -r -- "${line#* }"
  done
}

# ── Picker list ─────────────────────────────────────────────────────────────
# Prints "<category> │ <name> │ <target>" lines, pipes aligned.
_zj_build_list() {
  emulate -L zsh
  local -a c1 c2 c3
  local d name

  # 1. tmux sessions
  for name in "${(@f)$(_zj_sessions)}"; do
    [[ -n $name ]] || continue
    c1+='⚡ Session'; c2+=$name; c3+="session:$name"
  done

  # 2. ~/git/*  (the custproj container itself is excluded)
  for d in "${ZJ_GIT_DIR%/}"/*(N-/); do
    [[ $d == "${ZJ_CUST_DIR%/}" ]] && continue
    _zj_tilde "$d"
    c1+='📁 git'; c2+=${d:t}; c3+=$REPLY
  done

  # 3. ~/git/custproj/<Customer>/<Project>
  for d in "${ZJ_CUST_DIR%/}"/*/*(N-/); do
    _zj_tilde "$d"
    c1+="💼 ${${d:h}:t}"; c2+=${d:t}; c3+=$REPLY
  done

  # 4. ~/projects/*
  for d in "${ZJ_PROJECTS_DIR%/}"/*(N-/); do
    _zj_tilde "$d"
    c1+='📁 projects'; c2+=${d:t}; c3+=$REPLY
  done

  # Truncate (display columns only — column 3 is never touched), then measure.
  local i w1=0 w2=0
  for (( i = 1; i <= ${#c1}; i++ )); do
    _zj_trunc "${c1[i]}" $ZJ_COL1_MAX; c1[i]=$REPLY
    _zj_trunc "${c2[i]}" $ZJ_COL2_MAX; c2[i]=$REPLY
    (( ${(m)#c1[i]} > w1 )) && w1=${(m)#c1[i]}
    (( ${(m)#c2[i]} > w2 )) && w2=${(m)#c2[i]}
  done

  # (m) makes the padding width-aware, so emoji / wide chars line the pipes up.
  local sep=' │ '
  for (( i = 1; i <= ${#c1}; i++ )); do
    print -r -- "${(mr:$w1:)c1[i]}${sep}${(mr:$w2:)c2[i]}${sep}${c3[i]}"
  done
}

# Column 3 of a picker line, with ~ expanded (result in REPLY).
# Splitting is on the literal " │ " byte sequence, so it is UTF-8 safe, and the
# name column is never consulted (it may have been truncated with "…").
_zj_target_of() {
  emulate -L zsh
  local line=$1 rest
  rest=${line#* │ }
  [[ $rest == "$line" ]] && return 1
  [[ $rest == *' │ '* ]] || return 1
  _zj_untilde "${rest#* │ }"
}

# ── Preview (called by tv for the highlighted entry) ────────────────────────
_zj_preview() {
  emulate -L zsh
  _zj_target_of "$1" || { print -r -- "Cannot parse entry."; return 0 }
  local target=$REPLY name line
  local -a f

  if [[ $target == session:* ]]; then
    name=${target#session:}
    print -r -- "⚡ Session: $name"
    print
    if command tmux has-session -t "=$name" 2>/dev/null; then
      for line in "${(@f)$(command tmux list-sessions -F $'#{session_name}\t#{session_windows}\t#{session_attached}' 2>/dev/null)}"; do
        f=("${(@ps:\t:)line}")
        [[ ${f[1]} == "$name" ]] || continue
        if (( ${f[3]:-0} > 0 )); then
          print -r -- "Status:   attached (${f[3]} client(s))"
        else
          print -r -- "Status:   detached"
        fi
        print -r -- "Windows:  ${f[2]}"
        break
      done
      print
      command tmux list-windows -t "=$name" \
        -F '  #{window_index}: #{window_name}#{?window_active,*,}  (#{window_panes} panes)  #{pane_current_path}' 2>/dev/null
    else
      print -r -- "Status:   not running"
    fi
    print
    print -r -- "Attach:   tmux attach -t ${(q)name}"

  elif [[ -d $target ]]; then
    print -r -- "📁 $target"
    print
    if (( $+commands[eza] )); then
      command eza --tree --level=2 --color=always "$target"
    else
      command ls -la "$target"
    fi

  else
    print -r -- "Not found: $target"
  fi
}

# ── Launch the selected entry ───────────────────────────────────────────────

# _zj_enter <session> [<cwd>]
#   Outside tmux: attach (creating it in <cwd> if needed).
#   Inside tmux:  create it detached if needed, then switch the client to it.
# We deliberately do NOT `cd` in the calling shell: the session's start
# directory is set with -c, so your shell's directory hooks (auto-venv etc.)
# don't fire in the parent shell and leak into the new session's environment.
_zj_enter() {
  emulate -L zsh
  local name=$1 cwd=${2-}
  [[ -n $name ]] || { print -u2 "zj: empty session name"; return 1 }

  if [[ -z ${TMUX-} ]]; then
    if [[ -n $cwd ]]; then
      command tmux new-session -A -s "$name" -c "$cwd"
    else
      command tmux attach-session -t "=$name"
    fi
  else
    if ! command tmux has-session -t "=$name" 2>/dev/null; then
      [[ -n $cwd ]] || { print -u2 "zj: session not found: $name"; return 1 }
      command tmux new-session -d -s "$name" -c "$cwd" || return 1
    fi
    command tmux switch-client -t "=$name"
  fi
}

_zj_launch() {
  emulate -L zsh
  _zj_target_of "$1" || { print -u2 "zj: cannot parse selection: $1"; return 1 }
  local target=$REPLY

  if [[ $target == session:* ]]; then
    _zj_enter "${target#session:}"
  elif [[ -d $target ]]; then
    # Name comes from the (untruncated) path, not from the display column.
    _zj_dir_session_name "$target"
    _zj_enter "$REPLY" "$target"
  else
    print -u2 "zj: target not found: $target"
    return 1
  fi
}

# ── Entry point ─────────────────────────────────────────────────────────────
zj() {
  emulate -L zsh

  case ${1-} in
    --preview) _zj_preview "${2-}"; return 0 ;;
    --list)    _zj_build_list; return 0 ;;
    -h|--help)
      print -r -- 'usage: zj            pick a tmux session or project and jump in
       zj --list      print the picker entries (debugging)'
      return 0 ;;
  esac

  (( $+commands[tv] ))   || { print -u2 "zj: 'tv' (Television) not found in PATH"; return 127 }
  (( $+commands[tmux] )) || { print -u2 "zj: 'tmux' not found in PATH"; return 127 }

  # Width math (and "…" truncation) assumes a UTF-8 locale.
  if zmodload zsh/langinfo 2>/dev/null && [[ ${(L)langinfo[CODESET]} != utf(-|)8 ]]; then
    print -u2 "zj: warning: locale is not UTF-8; column alignment may be off"
  fi

  local list sel
  list=$(_zj_build_list)
  [[ -n $list ]] || return 0

  local -a opts=("${ZJ_TV_OPTS[@]}")
  if [[ $ZJ_KEEP_ORDER == 1 ]] && command tv --help 2>&1 | command grep -q -- '--no-sort'; then
    opts+=(--no-sort)
  fi

  # tv runs the preview through `sh -c`, so call back into this file via zsh.
  local preview="zsh -f ${(q)ZJ_SELF} --preview '{}'"

  sel=$(print -r -- "$list" | command tv --preview-command "$preview" "${opts[@]}")
  sel=${sel%%$'\n'*}   # first line only

  # Esc / Ctrl+C in tv → empty selection → back to the prompt, quietly.
  [[ -n $sel ]] || return 0

  _zj_launch "$sel"
}

# When executed (not sourced) this file only serves tv's `--preview` callback.
[[ $ZSH_EVAL_CONTEXT == *file* ]] || zj "$@"

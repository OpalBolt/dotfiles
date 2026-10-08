#!/usr/bin/env zsh
# ==============================================================================
# tj — terminal workspace navigator (tmux edition)
#
# Pick a running tmux session or a project directory with Television (tv) and
# jump straight into the matching tmux session (created on demand).
#
# Usage:      source this file from ~/.zshrc, then run `tj`.
#               source ~/git/dotfiles/tj.zsh
# Executed directly, the file only serves tv's callbacks (--preview, --action).
#
# Entry format (3 columns, pipe-aligned, display-width aware):
#   [Category] │ [Name (display only)] │ [session:<name> | ~/path/to/dir]
#
# Fuzzy search only matches columns 1-2: tj hands tv a generated channel whose
# display template ({split:│:..2}) shows just those columns. Column 3 stays in
# the raw entry, which tv returns on selection and passes to preview/actions.
#
# Quick actions (tv's Ctrl-X action picker; kill also has a direct key):
#   kill    TJ_KILL_KEY (default ctrl-d)   kill the highlighted session, reload
#   detach  picker only                    detach every client from the session
# They only act on "⚡ Session" rows, and never on the session you are sitting
# in. A row killed via the picker disappears after a reload of the list.
#
# Configuration (all optional; read on every call):
#   TJ_GIT_DIR           ~/git                 root of general git repositories
#   TJ_CUST_DIR          $TJ_GIT_DIR/custproj  root of <Customer>/<Project> dirs
#   TJ_PROJECTS_DIR      ~/projects            root of other project dirs
#   TJ_COL1_MAX          28                    visual width cap, category column
#   TJ_COL2_MAX          30                    visual width cap, name column
#   TJ_TV_OPTS           (empty)               extra flags passed straight to tv
#   TJ_KEEP_ORDER        1                     1 = keep priority order (no_sort)
#   TJ_QUALIFY_CUSTOMER  0                     1 = name sessions <Customer>-<Project>
#   TJ_README_LINES      25                    README lines shown in the dir preview
#   TJ_KILL_KEY          ctrl-d                direct key for the kill action
#
# Requires: zsh (UTF-8 locale), tmux, and a recent tv (needs --cable-dir and
# --source-display). An older tv still works in plain mode, with a warning: no
# quick actions, and the search also matches the path column.
# Optional: eza (directory listing).
# ==============================================================================

# Absolute path of this file, captured at source time. tv's preview calls back
# into it via `zsh -f`, so it must be resolved here at top level, not in a function.
typeset -g _TJ_SCRIPT=${${(%):-%x}:A}

# ------------------------------------------------------------------------------
# Small helpers. Convention: results are returned in $REPLY (no subshell);
# every entry point declares `local REPLY` so the user's own $REPLY is untouched.
# ------------------------------------------------------------------------------

# _tj_path <value>  ->  REPLY: leading ~ expanded, trailing slash removed
_tj_path() {
  local p=$1 rest
  if [[ $p == '~' ]]; then
    p=$HOME
  elif [[ $p == '~/'* ]]; then
    rest=${p#'~/'}
    p=$HOME/$rest
  fi
  REPLY=${p%/}
}

# _tj_tilde <abs-path>  ->  REPLY: $HOME prefix abbreviated to ~
_tj_tilde() {
  local rest
  if [[ $1 == "$HOME"/* ]]; then
    rest=${1#"$HOME"/}
    REPLY="~/$rest"
  else
    REPLY=$1
  fi
}

# _tj_clean <string>  ->  REPLY: safe for display columns (no line breaks, no
# literal │), so the first two " │ " in a line are always the real delimiters.
_tj_clean() {
  local s=${1//[$'\t\r\n']/ }
  REPLY=${s//│/¦}
}

# _tj_fit <string> <cap>  ->  REPLY: truncated to <cap> display columns,
# ending in … when something was cut. Width-aware (emoji count as 2).
_tj_fit() {
  emulate -L zsh
  setopt extended_glob
  local s=$1
  local -i cap=$2
  if (( ${(m)#s} > cap )); then
    while (( ${#s} > 0 && ${(m)#s} > cap - 1 )); do
      s=${s[1,-2]}
    done
    s=${s%%[[:space:]]##}      # no dangling space before the ellipsis
    s+='…'
  fi
  REPLY=$s
}

# _tj_target <entry-line>  ->  REPLY: column 3, split on the literal " │ "
# sequence (never on offsets). Columns 1 and 2 are sanitised by _tj_clean, so
# the first two delimiters are always the real ones.
_tj_target() {
  local rest=${1#* │ }
  REPLY=${rest#* │ }
}

# _tj_dir_session_name <abs-dir> <cust-dir> <qualify 0|1>  ->  REPLY
# tmux silently rewrites "." and ":" in session names to "_", so do it up front.
_tj_dir_session_name() {
  local dir=${1%/} cust=$2 qualify=$3 name
  name=${dir:t}
  if [[ $qualify == 1 && -n $cust && ${dir:h:h} == "$cust" ]]; then
    name=${dir:h:t}-${dir:t}
  fi
  REPLY=${name//[.:]/_}
}

_tj_check_locale() {
  emulate -L zsh
  zmodload zsh/langinfo 2>/dev/null
  local cs=${langinfo[CODESET]:-${LC_ALL:-${LC_CTYPE:-${LANG:-}}}}
  cs=${${cs:l}//-/}
  [[ $cs == *utf8* ]] || \
    print -u2 "tj: warning: locale is not UTF-8; column alignment may be off"
}

# ------------------------------------------------------------------------------
# List building
# ------------------------------------------------------------------------------

# Prints the aligned entry list on stdout, in priority order:
#   1 sessions (most recent activity first)  2 ~/git  3 customers  4 ~/projects
_tj_build_list() {
  emulate -L zsh
  local REPLY

  local git_dir cust_dir proj_dir
  _tj_path "${TJ_GIT_DIR:-$HOME/git}";           git_dir=$REPLY
  _tj_path "${TJ_CUST_DIR:-$git_dir/custproj}";  cust_dir=$REPLY
  _tj_path "${TJ_PROJECTS_DIR:-$HOME/projects}"; proj_dir=$REPLY

  local -i max1=28 max2=30
  [[ $TJ_COL1_MAX == <-> ]] && max1=$TJ_COL1_MAX
  [[ $TJ_COL2_MAX == <-> ]] && max2=$TJ_COL2_MAX
  (( max1 < 2 )) && max1=2
  (( max2 < 2 )) && max2=2

  local -a c1 c2 c3 rows
  local line name label d cust p

  # 1) tmux sessions. No server / no sessions is not an error: stderr is
  #    discarded and the category stays empty. Plain -F output, so there is no
  #    ANSI to strip. Tab-separated (names may contain spaces).
  if (( $+commands[tmux] )); then
    rows=( ${(f)"$(command tmux list-sessions \
            -F $'#{session_activity}\t#{session_name}' 2>/dev/null \
            | sort -s -t $'\t' -k1,1nr)"} )
    for line in $rows; do
      [[ -z $line ]] && continue
      name=${line#*$'\t'}
      [[ -z $name ]] && continue
      _tj_clean "$name"
      c1+=('⚡ Session')
      c2+=("$REPLY")
      c3+=("session:$name")
    done
  fi

  # 2) ~/git/*, excluding the custproj container itself
  for d in $git_dir/*(-/N); do
    [[ ${d:t} == custproj || ${d:A} == "${cust_dir:A}" ]] && continue
    [[ $d == *$'\n'* ]] && continue
    _tj_clean "${d:t}"; name=$REPLY
    _tj_tilde "$d"
    c1+=('📁 git')
    c2+=("$name")
    c3+=("$REPLY")
  done

  # 3) ~/git/custproj/<Customer>/<Project>
  for cust in $cust_dir/*(-/N); do
    for p in $cust/*(-/N); do
      [[ $p == *$'\n'* ]] && continue
      _tj_clean "💼 ${cust:t}"; label=$REPLY
      _tj_clean "${p:t}";       name=$REPLY
      _tj_tilde "$p"
      c1+=("$label")
      c2+=("$name")
      c3+=("$REPLY")
    done
  done

  # 4) ~/projects/*
  for d in $proj_dir/*(-/N); do
    [[ $d == *$'\n'* ]] && continue
    _tj_clean "${d:t}"; name=$REPLY
    _tj_tilde "$d"
    c1+=('📁 projects')
    c2+=("$name")
    c3+=("$REPLY")
  done

  # Truncate to the caps, then measure the widest survivors. Column 3 is never
  # touched: it must resolve exactly at execution time.
  local -i n=$#c3 i w1=0 w2=0
  for (( i = 1; i <= n; i++ )); do
    _tj_fit "${c1[i]}" $max1; c1[i]=$REPLY
    (( ${(m)#REPLY} > w1 )) && w1=${(m)#REPLY}
    _tj_fit "${c2[i]}" $max2; c2[i]=$REPLY
    (( ${(m)#REPLY} > w2 )) && w2=${(m)#REPLY}
  done

  # Pad by display width (not bytes/code points) so every │ lines up.
  local a b
  for (( i = 1; i <= n; i++ )); do
    a=${c1[i]}; b=${c2[i]}
    print -r -- "${(mr:$w1:)a} │ ${(mr:$w2:)b} │ ${c3[i]}"
  done
}

# ------------------------------------------------------------------------------
# Preview (invoked by tv through: sh -c "zsh -f tj.zsh --preview '{}'")
# ------------------------------------------------------------------------------

_tj_preview_session() {
  emulate -L zsh
  local REPLY name=$1

  if ! command tmux has-session -t "=$name" 2>/dev/null; then
    print -r -- "Session '$name' is not running."
    print -r -- "It may have been closed since the list was built."
    return 0
  fi

  local -i clients
  clients=$(command tmux display-message -p -t "=$name:" '#{session_attached}' 2>/dev/null)
  local state=detached plural=s
  (( clients == 1 )) && plural=
  (( clients > 0 )) && state="attached ($clients client$plural)"

  local -a wins f
  local wl nm mark pl
  local -i w=0
  wins=( ${(f)"$(command tmux list-windows -t "=$name" -F \
          $'#{window_index}\t#{window_name}\t#{window_active}\t#{window_panes}\t#{pane_current_path}' \
          2>/dev/null)"} )

  # widest window name, for alignment
  for wl in $wins; do
    f=( "${(@ps:\t:)wl}" )
    nm=$f[2]
    (( ${(m)#nm} > w )) && w=${(m)#nm}
  done

  print -r -- "Session  $name"
  print -r -- "Status   $state"
  print -r -- "Windows  $#wins"
  print
  for wl in $wins; do
    f=( "${(@ps:\t:)wl}" )
    nm=$f[2]
    mark=' '; [[ $f[3] == 1 ]] && mark='*'
    pl=panes; [[ $f[4] == 1 ]] && pl=pane
    _tj_tilde "$f[5]"
    print -r -- "  ${(l:3:)f[1]}  ${(mr:$w:)nm} $mark  ${(l:2:)f[4]} ${(r:5:)pl}  $REPLY"
  done
  print
  print -r -- "Attach manually:"
  print -r -- "  tmux attach -t ${(q-)name}"
}

_tj_preview() {
  emulate -L zsh
  local REPLY target dir
  [[ -z $1 ]] && return 0
  _tj_target "$1"; target=$REPLY

  if [[ $target == session:* ]]; then
    _tj_preview_session "${target#session:}"
    return 0
  fi

  _tj_path "$target"; dir=$REPLY
  if [[ ! -d $dir ]]; then
    print -r -- "Directory not found:"
    print -r -- "  $target"
    return 0
  fi

  print -r -- "$target"
  builtin cd -q -- "$dir" || return 0   # separate process: parent shell unaffected

  local out readme
  local -a lines cand
  local -i ls_max=40 n=25
  [[ $TJ_README_LINES == <-> ]] && n=$TJ_README_LINES

  # Top of the README first: prefer README*.md, else any README* (any case)
  cand=( [Rr][Ee][Aa][Dd][Mm][Ee]*.[Mm][Dd](-.N) [Rr][Ee][Aa][Dd][Mm][Ee]*(-.N) )
  readme=$cand[1]
  if [[ -n $readme ]]; then
    print
    print -r -- "── $readme ──"
    command head -n $n -- "$readme" 2>/dev/null
  fi

  # Then the directory listing (capped so a huge dir stays tidy)
  print
  print -r -- "── Files ──"
  if (( $+commands[eza] )); then
    out=$(command eza -la --group-directories-first --color=always 2>&1)
  else
    out=$(command ls -lA 2>&1)
  fi
  if [[ -z $out ]]; then
    print -r -- "(empty directory)"
  else
    lines=( "${(@f)out}" )
    print -rl -- "${(@)lines[1,$ls_max]}"
    (( $#lines > ls_max )) && print -r -- "… $(( $#lines - ls_max )) more entries"
  fi
}

# ------------------------------------------------------------------------------
# Execution: the shell's cwd is never changed; -c sets the session start dir.
# ------------------------------------------------------------------------------

# _tj_open <column-3 target>
_tj_open() {
  emulate -L zsh
  local REPLY target=$1 name dir cust_dir

  if [[ $target == session:* ]]; then
    name=${target#session:}
    if [[ -n ${TMUX:-} ]]; then
      command tmux switch-client -t "=$name"
    else
      command tmux attach-session -t "=$name"
    fi
    return
  fi

  _tj_path "$target"; dir=$REPLY
  if [[ ! -d $dir ]]; then
    print -u2 "tj: directory not found: $dir"
    return 1
  fi

  _tj_path "${TJ_CUST_DIR:-${TJ_GIT_DIR:-$HOME/git}/custproj}"; cust_dir=$REPLY
  # Always derived from the real path, never from the (truncatable) name column.
  _tj_dir_session_name "$dir" "$cust_dir" "${TJ_QUALIFY_CUSTOMER:-0}"; name=$REPLY

  if [[ -z ${TMUX:-} ]]; then
    command tmux new-session -A -s "$name" -c "$dir"
  else
    # Never a nested attach: create detached if needed, then switch.
    if ! command tmux has-session -t "=$name" 2>/dev/null; then
      command tmux new-session -d -s "$name" -c "$dir" || return
    fi
    command tmux switch-client -t "=$name"
  fi
}

# ------------------------------------------------------------------------------
# Quick actions and the generated tv channel
# ------------------------------------------------------------------------------

# _tj_toml <string>  ->  REPLY: a TOML basic-string literal (quotes included)
_tj_toml() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  REPLY="\"$s\""
}

# _tj_write_channel <dir> <self-cmd> <preview-cmd> <keep-order 0|1>
# Writes <dir>/tj.toml. Actions need a channel file (they cannot be given as
# CLI flags), so tj generates one per run and points tv at it with --cable-dir.
_tj_write_channel() {
  emulate -L zsh
  local REPLY dir=$1 self=$2 preview=$3
  local -i keep=$4
  local list=$dir/list
  local q_src q_prev q_kill q_det q_key
  _tj_toml "cat -- ${(q)list}";                      q_src=$REPLY
  _tj_toml "$preview";                               q_prev=$REPLY
  _tj_toml "$self --action kill '{}' ${(q)list}";    q_kill=$REPLY
  _tj_toml "$self --action detach '{}' ${(q)list}";  q_det=$REPLY
  _tj_toml "${TJ_KILL_KEY:-ctrl-d}";                 q_key=$REPLY
  {
    print -r -- '[metadata]'
    print -r -- 'name = "tj"'
    print -r -- 'description = "tmux sessions and project directories"'
    print
    print -r -- '[source]'
    print -r -- "command = $q_src"
    print -r -- 'display = "{split:│:..2}"'
    print -r -- 'output = "{}"'
    (( keep )) && print -r -- 'no_sort = true'
    print
    print -r -- '[preview]'
    print -r -- "command = $q_prev"
    print
    print -r -- '[keybindings]'
    print -r -- "$q_key = [\"actions:kill\", \"reload_source\"]"
    print
    print -r -- '[actions.kill]'
    print -r -- 'description = "Kill tmux session"'
    print -r -- "command = $q_kill"
    print -r -- 'mode = "fork"'
    print
    print -r -- '[actions.detach]'
    print -r -- 'description = "Detach all clients from tmux session"'
    print -r -- "command = $q_det"
    print -r -- 'mode = "fork"'
  } >| "$dir/tj.toml"
}

# _tj_forget <list-file> <column-3 target>: drop that row from the list file
# that tv's source command cats, so a following reload no longer shows it.
_tj_forget() {
  emulate -L zsh
  local REPLY file=$1 target=$2 line
  local -a kept
  [[ -r $file ]] || return 0
  for line in "${(@f)$(<$file)}"; do
    [[ -z $line ]] && continue
    _tj_target "$line"
    [[ $REPLY == "$target" ]] || kept+=("$line")
  done
  if (( $#kept )); then
    print -rl -- "${kept[@]}" >| "$file"
  else
    : >| "$file"
  fi
}

# _tj_action <kill|detach> <entry-line> <list-file>
# Called by tv through `zsh -f tj.zsh --action ...`; must stay silent, because
# tv's stdout is captured by tj. The session name comes straight from column 3,
# so it never depends on TJ_* settings.
_tj_action() {
  emulate -L zsh
  local REPLY act=$1 entry=$2 listfile=$3 target name current
  local -a pane
  [[ -z $entry ]] && return 0
  _tj_target "$entry"; target=$REPLY
  [[ $target == session:* ]] || return 0      # only session rows have actions
  name=${target#session:}

  # Never act on the session this client is sitting in.
  if [[ -n ${TMUX:-} ]]; then
    [[ -n ${TMUX_PANE:-} ]] && pane=(-t "$TMUX_PANE")
    current=$(command tmux display-message -p $pane '#{session_name}' 2>/dev/null)
    [[ $current == "$name" ]] && return 0
  fi

  case $act in
    kill)
      command tmux kill-session -t "=$name" 2>/dev/null
      [[ -n $listfile ]] && _tj_forget "$listfile" "$target"
      ;;
    detach)
      command tmux detach-client -s "=$name" 2>/dev/null
      ;;
  esac
  return 0
}

# ------------------------------------------------------------------------------
# Entry point
# ------------------------------------------------------------------------------

tj() {
  emulate -L zsh
  local REPLY

  if [[ $1 == -h || $1 == --help ]]; then
    print -r -- "usage: tj   (pick a tmux session or project directory; see header of ${(D)_TJ_SCRIPT})"
    return 0
  fi

  local -a missing
  (( $+commands[tv] ))   || missing+=(tv)
  (( $+commands[tmux] )) || missing+=(tmux)
  if (( $#missing )); then
    print -u2 "tj: missing dependency in PATH: ${(j:, :)missing}"
    return 127
  fi
  if [[ -z $_TJ_SCRIPT || ! -r $_TJ_SCRIPT ]]; then
    print -u2 "tj: cannot locate tj.zsh for the preview callback (source it from a file)"
    return 1
  fi

  _tj_check_locale

  local list
  list=$(_tj_build_list)
  if [[ -z $list ]]; then
    print -u2 "tj: nothing to show (no sessions, no directories found)"
    return 0
  fi

  # tv substitutes {} verbatim (preview and actions alike), hence the single
  # quotes around it below. The README length travels on the command line
  # because TJ_* variables are usually not exported.
  local zsh_bin=${commands[zsh]:-zsh}
  local -i readme_lines=25 keep=0
  [[ $TJ_README_LINES == <-> ]] && readme_lines=$TJ_README_LINES
  [[ ${TJ_KEEP_ORDER:-1} == 1 ]] && keep=1
  local self="${(q)zsh_bin} -f ${(q)_TJ_SCRIPT}"
  local preview="TJ_README_LINES=$readme_lines $self --preview '{}'"
  local -a extra=( ${(Q)${(z)TJ_TV_OPTS}} )

  local tv_help
  tv_help=$(command tv --help 2>&1)

  # Esc / Ctrl+C -> empty selection -> clean no-op. First line only, by plain
  # string stripping ({(f)}[1] would index *characters*, yielding one emoji).
  local sel work
  if [[ $tv_help == *--cable-dir* && $tv_help == *--source-display* ]]; then
    # Channel mode: column-restricted search + quick actions (see header).
    work=$(command mktemp -d "${TMPDIR:-/tmp}/tj.XXXXXX") || {
      print -u2 "tj: cannot create a temporary directory"
      return 1
    }
    {
      print -r -- "$list" >| "$work/list"
      _tj_write_channel "$work" "$self" "$preview" $keep
      sel=$(command tv tj --cable-dir "$work" "${extra[@]}")
    } always {
      command rm -rf -- "$work"
    }
  else
    print -u2 "tj: warning: this tv is too old for quick actions; search also matches the path column"
    local -a tv_args=(--preview-command "$preview")
    (( keep )) && [[ $tv_help == *--no-sort* ]] && tv_args+=(--no-sort)
    sel=$(print -r -- "$list" | command tv "${tv_args[@]}" "${extra[@]}")
  fi
  sel=${sel%%$'\n'*}
  [[ -z $sel ]] && return 0

  if [[ $sel != *' │ '* ]]; then
    print -u2 "tj: unexpected selection: $sel"
    return 1
  fi
  _tj_target "$sel"
  _tj_open "$REPLY"
}

# ------------------------------------------------------------------------------
# Direct execution: serve the tv preview callback only.
# ZSH_EVAL_CONTEXT is exactly "toplevel" for a script run as `zsh file`; when
# sourced it ends in ":file". Anything else (eval, ...) is left alone, so we
# can never `exit` a user's interactive shell by mistake.
# ------------------------------------------------------------------------------
if [[ $ZSH_EVAL_CONTEXT == toplevel ]]; then
  if [[ ${1-} == --preview ]]; then
    _tj_preview "${2-}"
    exit 0
  fi
  if [[ ${1-} == --action ]]; then
    _tj_action "${2-}" "${3-}" "${4-}" >/dev/null 2>&1
    exit 0
  fi
  print -u2 "tj: source this file (e.g. from ~/.zshrc) to get the 'tj' function"
  exit 1
fi

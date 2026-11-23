#!/usr/bin/env bash
# tj - session/workspace navigator for tmux AND herdr (bash edition, fzf as picker)
# Backend: TJ_BACKEND=tmux|herdr, else herdr env -> herdr, $TMUX -> tmux, plain shell -> herdr.
# Use it in any shell:
#   bash/zsh:  source /path/to/tj.bash     (zsh gets a small wrapper that runs it with bash)
#   or run it directly:  chmod +x tj.bash && ln -s $PWD/tj.bash ~/.local/bin/tj

# zsh: BASH_SOURCE doesn't exist and the syntax differs, so just define a wrapper
if [ -n "${ZSH_VERSION:-}" ]; then
	# zsh-only syntax stays inside this string so bash/shfmt never parse it
	eval '_tj_file="${(%):-%x}"; tj() { bash "${_tj_file:A}" "$@"; }; return 0'
fi

TJ_SELF=$(realpath "${BASH_SOURCE[0]}")
SEP=' │ '

_tj_expand() { printf '%s' "${1/#\~/$HOME}"; } # ~/x -> /home/u/x
_tj_trunc() {                                  # str max
	if ((${#1} > $2)); then printf '%s…' "${1:0:$2-1}"; else printf '%s' "$1"; fi
}

# ---------- backend layer: tmux | herdr ----------
# Session ids: tmux = session name, herdr = workspace id (labels are not unique).
_tj_backend() {
	if [[ -n ${TJ_BACKEND:-} ]]; then
		printf '%s' "$TJ_BACKEND"
	elif [[ -n ${HERDR_ACTIVE_WORKSPACE_ID:-}${HERDR_PANE_ID:-}${HERDR_ENV:-} ]]; then
		printf herdr
	elif [[ -n ${TMUX:-} ]]; then
		printf tmux
	else printf herdr; fi
}
TJ_B=$(_tj_backend)
_tj_inside() { [[ $TJ_B == herdr ]] && [[ -n ${HERDR_ACTIVE_WORKSPACE_ID:-}${HERDR_PANE_ID:-}${HERDR_ENV:-} ]] || [[ $TJ_B == tmux && -n ${TMUX:-} ]]; }
_tj_hws() { herdr workspace list 2>/dev/null; } # JSON

_tj_sessions() { # prints "id<TAB>display name", most relevant first
	if [[ $TJ_B == tmux ]]; then
		tmux list-sessions -F '#{session_activity} #{session_name}' 2>/dev/null | sort -rn | cut -d' ' -f2- | awk '{print $0 "\t" $0}'
	else
		_tj_hws | jq -r '.result.workspaces[]? | "\(.workspace_id)\t\(.label) · \(.agent_status) · \(.tab_count)t"'
	fi
}
_tj_own() {
	if [[ $TJ_B == tmux ]]; then
		[[ -n $TMUX ]] && tmux display-message -p '#{session_name}' 2>/dev/null
	else _tj_hws | jq -r '.result.workspaces[]? | select(.focused) | .workspace_id'; fi
}
_tj_label() { # id -> plain name
	if [[ $TJ_B == tmux ]]; then
		printf '%s' "$1"
	else _tj_hws | jq -r --arg i "$1" '.result.workspaces[]? | select(.workspace_id==$i) | .label'; fi
}
_tj_switch() { # id
	if [[ $TJ_B == tmux ]]; then
		if [[ -n $TMUX ]]; then tmux switch-client -t "=$1"; else tmux attach-session -t "=$1"; fi
	else
		herdr workspace focus "$1" >/dev/null && { _tj_inside || exec herdr; }
	fi
}
_tj_open_dir() { # name dir -> reuse a session/workspace of that name, else create
	local name=$1 d=$2 id
	if [[ $TJ_B == tmux ]]; then
		if [[ -n $TMUX ]]; then
			tmux has-session -t "=$name" 2>/dev/null || tmux new-session -d -s "$name" -c "$d"
			tmux switch-client -t "=$name"
		else
			tmux new-session -A -s "$name" -c "$d"
		fi
		return
	fi
	# herdr: no server yet -> just start it in the project dir
	_tj_hws >/dev/null || { cd "$d" && exec herdr; }
	id=$(_tj_hws | jq -r --arg n "$name" 'first(.result.workspaces[]? | select(.label==$n)) | .workspace_id // empty')
	[[ -n $id ]] || id=$(herdr workspace create --cwd "$d" --label "$name" | jq -r '.result.workspace.workspace_id // empty')
	[[ -n $id ]] || {
		echo "tj: could not create workspace" >&2
		return 1
	}
	_tj_switch "$id"
}
_tj_close() { # id
	if [[ $TJ_B == tmux ]]; then tmux kill-session -t "=$1"; else herdr workspace close "$1" >/dev/null; fi
}
_tj_do_rename() { # id new
	if [[ $TJ_B == tmux ]]; then tmux rename-session -t "=$1" "${2//[.:]/_}"; else herdr workspace rename "$1" "$2" >/dev/null; fi
}
_tj_session_preview() { # id
	local id=$1
	if [[ $TJ_B == tmux ]]; then
		local a w n found=0
		while read -r a w n; do
			[[ $n == "$id" ]] || continue
			found=1
			((a > 0)) && echo "Status: attached ($a client(s))" || echo "Status: detached"
			echo "Windows: $w"
			# shortcut: 15 lines/pane caps tall screens; bump if previews feel short
			while IFS= read -r wid; do
				tmux display-message -p -t "$wid" \
					'  #{window_index}: #{window_name}#{?window_active, *,} (#{window_panes} panes) #{pane_current_path}'
				while IFS= read -r pid; do
					tmux capture-pane -p -t "$pid" |
						sed -e 's/[[:space:]]*$//' -e '/^[[:space:]]*$/d' -e 's/^/    /' | head -n 15
				done < <(tmux list-panes -t "$wid" -F '#{pane_id}')
				echo
			done < <(tmux list-windows -t "=$id" -F '#{window_id}' 2>/dev/null)
			echo "Attach: tmux attach -t $id"
		done < <(tmux list-sessions -F '#{session_attached} #{session_windows} #{session_name}' 2>/dev/null)
		((found)) || echo "Session '$id' is not running."
	else
		_tj_hws | jq -r --arg i "$id" '.result.workspaces[]? | select(.workspace_id==$i) | "Status: \(.agent_status)\nTabs: \(.tab_count)  Panes: \(.pane_count)"'
		local pid cwd
		while IFS=$'\t' read -r pid cwd; do
			echo "  $pid  $cwd"
			herdr pane read "$pid" --source visible --lines 15 2>/dev/null |
				sed -e 's/[[:space:]]*$//' -e '/^[[:space:]]*$/d' -e 's/^/    /' | head -n 15
			echo
		done < <(herdr pane list --workspace "$id" 2>/dev/null | jq -r '.result.panes[]? | "\(.pane_id)\t\(.cwd)"')
	fi
}

# ---------- list: prints the aligned entries (piped into fzf) ----------
_tj_list() {
	local git=${TJ_GIT_DIR:-$HOME/git}
	local cust=${TJ_CUST_DIR:-$git/custproj}
	local proj=${TJ_PROJECTS_DIR:-$HOME/projects}
	local max1=${TJ_COL1_MAX:-28} max2=${TJ_COL2_MAX:-30}
	git=${git%/}
	cust=${cust%/}
	proj=${proj%/}

	# rows: parallel arrays emoji / tag / name / target
	local E=() T=() N=() P=()
	_add() {
		E+=("$1")
		T+=("$(_tj_trunc "$2" $((max1 - 3)))")
		N+=("$(_tj_trunc "$3" "$max2")")
		P+=("$4")
	}

	local s d c
	# 1. sessions / workspaces
	local sid
	while IFS=$'\t' read -r sid s; do
		[[ -n $sid ]] && _add "⚡" "Session" "$s" "session:$sid"
	done < <(_tj_sessions)

	# 2. git repos (skip the customer container)
	for d in "$git"/*/; do
		d=${d%/}
		[[ -d $d && $d != "$cust" ]] && _add "📁" "git" "${d##*/}" "${d/#$HOME/\~}"
	done
	# 3. customer projects
	for c in "$cust"/*/; do
		c=${c%/}
		for d in "$c"/*/; do
			d=${d%/}
			[[ -d $d ]] && _add "💼" "${c##*/}" "${d##*/}" "${d/#$HOME/\~}"
		done
	done
	# 4. other projects
	for d in "$proj"/*/; do
		d=${d%/}
		[[ -d $d ]] && _add "📁" "projects" "${d##*/}" "${d/#$HOME/\~}"
	done

	# column widths (emoji = 2 cells + 1 space = 3 before the tag text)
	local w1=0 w2=0 i
	for i in "${!P[@]}"; do
		((3 + ${#T[i]} > w1)) && w1=$((3 + ${#T[i]}))
		((${#N[i]} > w2)) && w2=${#N[i]}
	done
	for i in "${!P[@]}"; do
		printf '%s %s%*s%s%s%*s%s%s\n' "${E[i]}" "${T[i]}" $((w1 - 3 - ${#T[i]})) '' "$SEP" \
			"${N[i]}" $((w2 - ${#N[i]})) '' "$SEP" "${P[i]}"
	done
}

# ---------- preview ----------
_tj_preview() {
	local t=${1##*"$SEP"}
	if [[ $t == session:* ]]; then
		_tj_session_preview "${t#session:}"
	else
		t=$(_tj_expand "$t")
		local r found=0
		for r in "$t"/[Rr][Ee][Aa][Dd][Mm][Ee]*; do
			[[ -f $r ]] && {
				head -n 10 "$r"
				found=1
				break
			}
		done
		((found)) || echo "(no README)"
		echo "────────────────────────────────"
		ls -la "$t"
	fi
}

# ---------- row actions (bound to keys inside fzf; see tj) ----------
_tj_target() { printf '%s' "${1##*"$SEP"}"; }

_tj_kill() { # selection line -> kill that session (no-op on directory rows)
	local t id
	t=$(_tj_target "$1")
	[[ $t == session:* ]] || return 0
	id=${t#session:}
	[[ $id == "$(_tj_own)" ]] && return 0 # never kill the session we run in
	_tj_close "$id"
}

_tj_rename() { # selection line -> rename that session, prompt prefilled
	local t id new
	t=$(_tj_target "$1")
	[[ $t == session:* ]] || return 0
	id=${t#session:}
	printf '\nrename to: '
	IFS= read -e -i "$(_tj_label "$id")" -r new </dev/tty || return 0
	[[ -n $new ]] || return 0
	_tj_do_rename "$id" "$new"
}

_tj_prune() { # selection line -> kill every session except the highlighted one
	local t keep own s ans victims=()
	t=$(_tj_target "$1")
	[[ $t == session:* ]] || return 0
	keep=${t#session:}
	own=$(_tj_own)
	while IFS=$'\t' read -r s _; do
		[[ -n $s && $s != "$keep" && $s != "$own" ]] && victims+=("$s")
	done < <(_tj_sessions)
	((${#victims[@]})) || return 0
	printf '\nkill %d session(s), keep "%s"? [y/N] ' "${#victims[@]}" "$(_tj_label "$keep")"
	IFS= read -r ans </dev/tty
	[[ $ans == [yY] ]] || return 0
	for s in "${victims[@]}"; do _tj_close "$s"; done
}

# ---------- main ----------
tj() {
	command -v fzf >/dev/null || {
		echo "tj: fzf not found" >&2
		return 1
	}
	command -v "$TJ_B" >/dev/null || {
		echo "tj: $TJ_B not found" >&2
		return 1
	}
	[[ $TJ_B == herdr ]] && { command -v jq >/dev/null || {
		echo "tj: jq not found" >&2
		return 1
	}; }
	[[ $(locale charmap 2>/dev/null) == UTF-8 ]] || echo "tj: warning: locale is not UTF-8" >&2

	local sel args=(--preview "bash \"$TJ_SELF\" --preview {}")
	# picker keys (session rows only; directory rows ignore them)
	args+=(
		--header "ctrl-x kill · ctrl-r rename · ctrl-p prune others"
		--bind "ctrl-x:execute-silent(bash \"$TJ_SELF\" --kill {})+reload(bash \"$TJ_SELF\" --list)"
		--bind "ctrl-r:execute(bash \"$TJ_SELF\" --rename {})+reload(bash \"$TJ_SELF\" --list)"
		--bind "ctrl-p:execute(bash \"$TJ_SELF\" --prune {})+reload(bash \"$TJ_SELF\" --list)"
	)
	[[ ${TJ_KEEP_ORDER:-1} == 1 ]] && args+=(--no-sort)
	# shellcheck disable=SC2086
	sel=$(_tj_list | fzf "${args[@]}" ${TJ_FZF_OPTS:-})
	[[ -z $sel ]] && return 0

	# act on column 3 only
	local t=${sel##*"$SEP"} name
	if [[ $t == session:* ]]; then
		_tj_switch "${t#session:}"
		return
	fi

	local d
	d=$(_tj_expand "$t")
	d=${d%/}
	name=${d##*/}
	if [[ ${TJ_QUALIFY_CUSTOMER:-0} == 1 && $(dirname "$(dirname "$d")") == "${TJ_CUST_DIR%/}" ]]; then
		name="$(basename "$(dirname "$d")")-$name"
	fi
	name=${name//[.:]/_}

	_tj_open_dir "$name" "$d"
}

# executed directly -> helper modes for fzf, or run tj itself
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
	case $1 in
	--list) _tj_list ;;
	--preview) _tj_preview "$2" ;;
	--kill) _tj_kill "$2" ;;
	--rename) _tj_rename "$2" ;;
	--prune) _tj_prune "$2" ;;
	*) tj "$@" ;;
	esac
fi

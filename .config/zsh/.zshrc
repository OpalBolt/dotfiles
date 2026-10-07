# $ZDOTDIR/.zshrc — interactive shell config.
# Zsh port of fishold/config.fish + conf.d/{abbr,env}.fish.
#
# Television (tv) keybinding check — see also: user-guide/keybindings.
#   - Shell integration binds Ctrl-T (smart autocomplete) and Ctrl-R (history
#     search). These are the exact same bindings fzf used, and fzf is no
#     longer sourced in this config, so there's no fzf/tv clash.
#   - Ctrl-T overrides zsh's builtin `transpose-chars` binding. This matches
#     the behavior already in use on fish (fzf did the same override there),
#     so it's an intentional, pre-existing tradeoff rather than a new one.
#   - Checked niri/mango/zellij/foot/kitty/wezterm configs in this repo: all
#     Ctrl-T/Ctrl-R-shaped bindings there are Mod/Super combos, not plain
#     Ctrl-T/Ctrl-R, so nothing at the WM/terminal/multiplexer layer competes
#     with tv's shell widgets.
#   - zoxide's own interactive `zi`/`cdi` picker is hardcoded to fzf (no tv
#     support upstream), so fzf is still a required dependency even though
#     nothing in this config invokes it directly.

[[ -o interactive ]] || return

# Kitty keyboard protocol reset — foot (and kitty/wezterm) support this
# protocol purely opt-in: a TUI program (nvim, zellij, ...) pushes an
# "enhanced" reporting mode on entry and is supposed to pop it on exit. If
# that program crashes or is killed instead of exiting cleanly, the terminal
# is left in enhanced mode. zsh's emacs keymap only binds the legacy C0
# bytes, so e.g. Ctrl-A then arrives as a literal CSI-u escape sequence
# ("[97;5u"-ish text) instead of running beginning-of-line — happens with or
# without zellij in between, and persists until something resets the flags.
# `\e[=0u` sets the enhancement flags back to 0 (legacy) without touching
# any push/pop stack depth, so it's safe to run unconditionally before every
# prompt; terminals that don't support the protocol just ignore it.
# foot has no config option for this (opt-in is per-app, not configurable
# from foot.ini), so the reset has to happen shell-side.
_reset_kitty_keyboard_protocol() { print -n '\e[=0u' }
precmd_functions+=(_reset_kitty_keyboard_protocol)

if (( $+commands[fastfetch] )); then
    fastfetch
fi

bindkey -e

# --- completions -------------------------------------------------------
# completions/_copilot is pre-generated (like fishold/completions/copilot.fish
# was for fish) since `copilot completion zsh` takes ~300ms — too slow to
# regenerate on every shell startup. Regenerate it after upgrading copilot:
#   copilot completion zsh > "$ZDOTDIR/completions/_copilot"
fpath=("$ZDOTDIR/completions" $fpath)
autoload -Uz compinit
compinit

# --- prompt / navigation / env tooling ----------------------------------
(( $+commands[zoxide] )) && eval "$(zoxide init zsh --cmd cd)"
(( $+commands[starship] )) && eval "$(starship init zsh)"
(( $+commands[direnv] )) && eval "$(direnv hook zsh)"
(( $+commands[mise] )) && eval "$(mise activate zsh)"
(( $+commands[atuin] )) && eval "$(atuin init zsh --disable-up-arrow)"
#(( $+commands[tv] )) && eval "$(tv init zsh)"
(( $+commands[wt] )) && eval "$(wt config shell init zsh)"

# lazy tab-completion for tools that generate their own script on the fly
if (( $+commands[uv] )); then
    eval "$(uv generate-shell-completion zsh)"
fi
if (( $+commands[mise] )); then
    eval "$(mise completion zsh)"
fi

if (( $+commands[time-helper] )); then
    eval "$(_TIME_HELPER_COMPLETE=source_zsh time-helper)"
fi

# --- zplug ----------------------------------------------------------------
# Same plugin manager as the old config (see commit 8e0540a for reference).
# zplug lives in $HOME/.config/zsh/.zplug. Clone it on first use, but never
# let a stalled download prevent an interactive shell from starting.
# oh-my-zsh plugins are loaded straight through
# zplug's `from:oh-my-zsh` source — it just clones ohmyzsh/ohmyzsh and
# sources the one plugin file — instead of bootstrapping the whole
# oh-my-zsh framework (oh-my-zsh.sh's own update/compinit/theme machinery
# running alongside zplug's installer is what was causing shells to hang).
#
# Dropped from the old config's plugin list, each for a reason already
# documented elsewhere in this file/repo:
#   - fzf: replaced by tv (see header comment above)
#   - ssh-agent: superseded by the Bitwarden-integrated
#     ensure_ssh_agent function below (a plugin would fight it)
#   - kitty: terminal switched to foot (see commit history)

# Keep zplug's writable repos/cache next to its installation.
export ZPLUG_HOME="$HOME/.config/zsh/.zplug"
if [[ ! -e "$ZPLUG_HOME" ]]; then
    if ! mkdir -p "${ZPLUG_HOME:h}" || ! GIT_TERMINAL_PROMPT=0 timeout -k 2s 10s git clone --quiet --depth 1 \
        https://github.com/zplug/zplug.git "$ZPLUG_HOME"; then
        print -u2 "zplug: installation failed or timed out; continuing without plugins."
    fi
fi
if [[ -r "$ZPLUG_HOME/init.zsh" ]] && source "$ZPLUG_HOME/init.zsh"; then
    # Use oh-my-zsh plugins
    zplug "lib/*", from:oh-my-zsh

    # oh-my-zsh
    zplug "plugins/colored-man-pages", from:oh-my-zsh
    zplug "plugins/command-not-found", from:oh-my-zsh
    zplug "plugins/git", from:oh-my-zsh
    zplug "plugins/git-extras", from:oh-my-zsh
    zplug "plugins/aws", from:oh-my-zsh
    zplug "plugins/docker", from:oh-my-zsh
    zplug "plugins/docker-compose", from:oh-my-zsh

    # other plugins
    zplug "zsh-users/zsh-autosuggestions", from:github, as:plugin
    zplug "zsh-users/zsh-syntax-highlighting", from:github, as:plugin, defer:2
    zplug "MichaelAquilina/zsh-autoswitch-virtualenv", from:github, as:plugin
    zplug "djui/alias-tips", from:github, as:plugin
    zplug "svenXY/timewarrior", from:github, as:plugin

    # Never prompt or install during shell startup. Install missing plugins
    # deliberately with `zplug install`, then start a new shell.
    if ! zplug check; then
        print -u2 "zplug: plugins are missing; run 'zplug check --verbose' and 'zplug install' when ready."
    fi
    if ! zplug load; then
        print -u2 "zplug: some plugins failed to load; run 'zplug load --verbose' to diagnose."
    fi
else
    print -u2 "zplug: unavailable at $ZPLUG_HOME/init.zsh; continuing without plugins."
fi

# envoke starts a watcher; zplug load must finish before it starts.
(( $+commands[envoke] )) && eval "$(envoke shell-init --shell zsh)"

# --- functions -----------------------------------------------------------
for _zj_fn in "$ZDOTDIR"/functions/*.zsh(N); do
    source "$_zj_fn"
done
unset _zj_fn

ensure_ssh_agent work-ssh

# --- fix for special characters -------------------------------------------
zmodload zsh/terminfo
bindkey "${terminfo[kRIT5]:-^[[1;5C}" forward-word
bindkey "${terminfo[kLFT5]:-^[[1;5D}" backward-word

# --- aliases / abbreviations ----------------------------------------------
# zsh has no fish-style `abbr` (visible expansion on space); these are plain
# aliases, which run identically but won't rewrite the command line.
alias ls='eza -mh1la --classify=always --icons=always --color=always --group-directories-first --git'

alias vim=nvim
alias vi=nvim

alias g=git
alias lg=lazygit
alias gs='git status'

# clipboard — wl-copy/wl-paste on Wayland, xclip on X11
# c/v = PRIMARY selection (mouse), cx = CLIPBOARD (Ctrl+C/Y)
if [[ -n "$WAYLAND_DISPLAY" ]]; then
    alias c='wl-copy --primary'
    alias v='wl-paste --primary'
    alias cx=wl-copy
else
    alias c=xclip
    alias v='xclip -o'
    alias cx='xclip -selection clipboard'
fi

alias ping='prettyping --nolegend'
alias ipa='ip -br -c a && echo --- && ip -br -c l'

alias k=kubectl
alias knr="kubectl describe nodes | grep '^  Resource' -A3"

alias terraform=tofu
alias gle='podman run --rm -v $PWD:/path docker.io/zricethezav/gitleaks:latest git --verbose /path'

alias stup="stow --restow -v --dir=/home/$USER/git --target=/home/$USER dotfiles"
alias dt='bash ~/scripts/date.sh'
alias power-menu="$HOME/.config/fuzzel/scripts/power-menu.sh"
alias wallpaper-menu="$HOME/.config/fuzzel/scripts/wallpaper-menu.sh"
alias wallpaper-grid="$HOME/.config/fuzzel/scripts/wallpaper-grid-prototype.sh"
alias wifi-menu="$HOME/.config/fuzzel/scripts/wifi-menu.sh"
# Stolen from: https://github.com/zanderhavgaard/dotfiles/blob/master/.aliases
alias sync_pacman_mirrors='reflector --country Denmark,Sweden,Norway,Germany --fastest 10 --protocol https --verbose'
alias neofetch=fastfetch

alias th=time-helper
alias tw=timew

# $ZDOTDIR/.zshrc — interactive shell config.

[[ -o interactive ]] || return

bindkey -e

# --- completions -------------------------------------------------------
# completions/_copilot is pre-generated; regenerate after upgrading copilot:
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
# Clone zplug on first use, but never let a stalled download block startup.
export ZPLUG_HOME="$HOME/.config/zsh/.zplug"
if [[ ! -e "$ZPLUG_HOME" ]]; then
    if ! mkdir -p "${ZPLUG_HOME:h}" || ! GIT_TERMINAL_PROMPT=0 timeout -k 2s 10s git clone --quiet --depth 1 \
        https://github.com/zplug/zplug.git "$ZPLUG_HOME"; then
        print -u2 "zplug: installation failed or timed out; continuing without plugins."
    fi
fi
if [[ -r "$ZPLUG_HOME/init.zsh" ]] && source "$ZPLUG_HOME/init.zsh"; then
    zplug "lib/*", from:oh-my-zsh

    zplug "plugins/colored-man-pages", from:oh-my-zsh
    zplug "plugins/command-not-found", from:oh-my-zsh
    zplug "plugins/git", from:oh-my-zsh
    zplug "plugins/git-extras", from:oh-my-zsh
    zplug "plugins/aws", from:oh-my-zsh
    zplug "plugins/docker", from:oh-my-zsh
    zplug "plugins/docker-compose", from:oh-my-zsh

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

# Esnure that atuin is loaded last to fix history search
(( $+commands[atuin] )) && bindkey '^R' atuin-search

# Load tj to provide us with Tmux app
(( $+commands[tmux] )) && source ~/.config/tmux/tj.bash

# --- functions -----------------------------------------------------------
for _zj_fn in "$ZDOTDIR"/functions/*.zsh(N); do
    source "$_zj_fn"
done
unset _zj_fn

ensure_ssh_agent main-ssh work-ssh

# --- fix for special characters -------------------------------------------
zmodload zsh/terminfo
bindkey "${terminfo[kRIT5]:-^[[1;5C}" forward-word
bindkey "${terminfo[kLFT5]:-^[[1;5D}" backward-word

# --- aliases ---------------------------------------------------------------
alias g=git
alias lg=lazygit
alias gs='git status'
alias ipa='ip -br -c a && echo --- && ip -br -c l'
alias stup="stow --restow -v --dir=$HOME/git --target=$HOME dotfiles"
(( $+commands[nvim] )) && alias vim=nvim vi=nvim
(( $+commands[eza] )) && alias ls='eza -mh1la --classify=always --icons=always --color=always --group-directories-first --git'

pfetch
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

# Source zplug
source ~/.zplug/init.zsh

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
zplug "romkatv/powerlevel10k", as:theme, depth:1
zplug "MichaelAquilina/zsh-autoswitch-virtualenv", from:github, as:plugin
zplug "djui/alias-tips", from:github, as:plugin


# Install plugins if there are plugins that have not been installed
if ! zplug check --verbose; then
    printf "Install? [y/N]: "
    if read -q; then
        echo; zplug install
    fi
fi

# load zplug plugins
# zplug load --verbose
zplug load


# source other files
source ~/.config/.alias
source ~/.config/.env
export PATH=$PATH:/home/mads/bin
source /usr/share/fzf/key-bindings.zsh
source /usr/share/fzf/completion.zsh


# Enable zoxide in shell
eval "$(zoxide init zsh)"

# Disable auto title
ZSH_THEME_TERM_TITLE_IDLE="%~"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

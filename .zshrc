fastfetch
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
zplug "MichaelAquilina/zsh-autoswitch-virtualenv", from:github, as:plugin
zplug "djui/alias-tips", from:github, as:plugin
zplug "svenXY/timewarrior", from:github, as:plugin


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

# Enable commands run with space being ignored from history
setopt HIST_IGNORE_SPACE

eval "$(starship init zsh)"

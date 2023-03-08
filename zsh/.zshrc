# Source nix
if [ -e /home/mads/.nix-profile/etc/profile.d/nix.sh ]; then . /home/mads/.nix-profile/etc/profile.d/nix.sh; fi # added by Nix installer

# Source Antigen
source /usr/share/zsh/share/antigen.zsh

# Use oh-my-zsh plugins
antigen use oh-my-zsh

# oh-my-zsh
antigen bundle colored-man-pages
antigen bundle command-not-found
antigen bundle git
antigen bundle git-extras

# zsh plugins
antigen bundle zsh-users/zsh-autosuggestions
antigen bundle zsh-users/zsh-completions
antigen bundle zsh-users/zsh-syntax-highlighting

# commit antigen commands
antigen apply

# source other files
source ~/.alias

# Use starship prompt
# Starship config is seperate
# Located in: ~/.config/starship.toml
eval "$(starship init zsh)"


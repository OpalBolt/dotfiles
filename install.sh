
# Install packages
#nix-env -iA \
#	nixpkgs.zsh \
#	nixpkgs.git \
#	nixpkgs.neovim \
#	nixpkgs.tmux \
#	nixpkgs.stow \
#	nixpkgs.fzf \
#	nixpkgs.ripgrep \
#	nixpkgs.bat \
#	nixpkgs.direnv \
#	nixpkgs.zoxide \
#	nixpkgs.starship \
#	nixpkgs.lsd \
#	nixpkgs.zig \
#	nixpkgs.fd

# Install oneoff apps
curl -L https://raw.githubusercontent.com/warrensbox/terraform-switcher/release/install.sh | bash

# set up zplug
mkdir -p /usr/share/zsh/scripts/zplug
export ZPLUG_HOME=/usr/share/zsh/scripts/zplug/
git clone https://github.com/zplug/zplug $ZPLUG_HOME

# Add zsh to valid login shells
command -v zsh | sudo tee -a /etc/shells

# Use zsh as default shell
sudo chsh -s $(which zsh) $USER

# Create config folder
mkdir ~/.config

# Create nvim folders
mkdir -p ~/.config/nvim/lua

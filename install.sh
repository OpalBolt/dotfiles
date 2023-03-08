# Install nix, package manager/installer
sh <(curl -L https://nixos.org/nix/install) --no-daemon

# Source nix (Sourcing is running the .sh file)
. /home/mads/.nix-profile/etc/profile.d/nix.sh



# Install packages
nix-env -iA \
	nixpkgs.zsh \
	nixpkgs.git \
	nixpkgs.neovim \
	nixpkgs.tmux \
	nixpkgs.stow \
	nixpkgs.fzf \
	nixpkgs.ripgrep \
	nixpkgs.bat \
	nixpkgs.direnv \
	nixpkgs.zoxide \
	nixpkgs.starship \
	nixpkgs.lsd \
	nixpkgs.zig \
	nixpkgs.fd

# Make Antigen folder path
mkdir -p /usr/share/zsh/share

# Install antigen
curl -L git.io/antigen > antigen.zsh
mv antigen.zsh /usr/share/zsh/share/antigen.zsh

# Add zsh to valid login shells
command -v zsh | sudo tee -a /etc/shells

# Use zsh as default shell
sudo chsh -s $(which zsh) $USER

# Create config folder
mkdir ~/.config

# Create nvim folders
mkdir -p ~/.config/nvim/lua

# Install nvim package manager
git clone --depth 1 https://github.com/wbthomason/packer.nvim\
 ~/.local/share/nvim/site/pack/packer/start/packer.nvim

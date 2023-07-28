#!/bin/bash
# Install file for setting up my enviroment.

# Install misc packages
sudo dnf -y install mpv
sudo dnf -y install shellcheck
sudo dnf -y install yamllint
sudo dnf -y install pylint

nix-env -iA \
	nixpkgs.tealdeer \ # better tldr is used to get short informaiton about a program
	nixpkgs.volumeicon \ # applet with support for global keybindings
	nixpkgs.zsh \ # better shell
	nixpkgs.git \ # Versioning system
	nixpkgs.neovim \ # Text editor
	nixpkgs.tmux \ # console multiplexing
	nixpkgs.stow \ # symlink farm manager
	nixpkgs.skim \ # fuzzy search im RUST
	nixpkgs.ripgrep \ # recursive regex search
	nixpkgs.bat \ # cat but smarter
	nixpkgs.direnv \ # set up different variables based on folder
	nixpkgs.zoxide \ # cd alternative
	nixpkgs.exa \ # ls alternative
	nixpkgs.fd \ # find alternative
	nixpkgs.prettyping \ # Pretty formatted ping
	nixpkgs.figlet \ # Text to ascii art
	nixpkgs.htop \ # better top
	nixpkgs.neofetch \ # system information
	nixpkgs.onefetch \ # Neofetch but for git
	nixpkgs.speedtest-cli \ # speedtest cli tool
	nixpkgs.calcurse \ # cli calendar
	nixpkgs.duf \ # Disk usage and info
	nixpkgs.docker \
	nixpkgs.docker-compose \
	nixpkgs.feh \ # lightweight image viewer
	nixpkgs.deno \ # javascript and typescript runtime
	nixpkgs.tfswitch \ # switch between terraform versions
	nixpkgs. \

# Install virtualization packages
dnf -y install qemu-kvm
dnf -y install iptables
dnf -y install dmidecode
dnf -y install virt-manager
dnf -y install virt-viewer
dnf -y install dnsmasq
nix-env -iA \
	nixpkgs.vde2 \
	nixpkgs.bridge-utils \
	nixpkgs.netcat-openbsd \
	nixpkgs.ebtables \

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

#!/bin/bash
# Install file for setting up my enviroment.

# Install misc packages
sudo dnf -y install mpv
sudo dnf -y install shellcheck
sudo dnf -y install yamllint
sudo dnf -y install pylint
sudo dnf -y group install 'Development Tools'
sudo dnf -y install exa

nix-env -iA nixpkgs.tealdeer # information text for command
nix-env -iA nixpkgs.git # Versioning system
nix-env -iA nixpkgs.neovim # Text editor
nix-env -iA nixpkgs.tmux # console multiplexing
nix-env -iA nixpkgs.stow # symlink farm manager
nix-env -iA nixpkgs.skim # fuzzy search im RUST
nix-env -iA nixpkgs.ripgrep # recursive regex search
nix-env -iA nixpkgs.bat # cat but smarter
nix-env -iA nixpkgs.direnv # set up different variables based on folder
nix-env -iA nixpkgs.zoxide # cd alternative
#nix-env -iA nixpkgs.exa # ls alternative
nix-env -iA nixpkgs.fd # find alternative
nix-env -iA nixpkgs.prettyping # Pretty formatted ping
nix-env -iA nixpkgs.figlet # Text to ascii art
nix-env -iA nixpkgs.htop # better top
nix-env -iA nixpkgs.neofetch # system information
nix-env -iA nixpkgs.onefetch # Neofetch but for git
nix-env -iA nixpkgs.speedtest-cli # speedtest cli tool
nix-env -iA nixpkgs.calcurse # cli calendar
nix-env -iA nixpkgs.duf # Disk usage and info
nix-env -iA nixpkgs.docker
nix-env -iA nixpkgs.docker-compose
nix-env -iA nixpkgs.feh # lightweight image viewer
nix-env -iA nixpkgs.deno # javascript and typescript runtime
nix-env -iA nixpkgs.tfswitch # switch between terraform versions

# Install virtualization packages
sudo dnf -y install qemu-kvm
sudo dnf -y install iptables
sudo dnf -y install dmidecode
sudo dnf -y install virt-manager
sudo dnf -y install virt-viewer
sudo dnf -y install dnsmasq

nix-env -iA nixpkgs.vde2
nix-env -iA nixpkgs.bridge-utils
nix-env -iA nixpkgs.netcat-openbsd
nix-env -iA nixpkgs.ebtables

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

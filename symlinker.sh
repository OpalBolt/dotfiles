#!/bin/bash
#
#Script to create symbolic links to dotfiles

# user
user="mads"
# dotfiles directory
dfd="/home/$user/git/dotfiles"
# config files directory
cfd="/home/$user/.config"
# .local directory
ldf="/home/$user/.local"

echo -e "\nSymlinking .aliases ..."
rm ~/.alias
ln -sv $dfd/.alias /home/$user/.alias

echo -e "\nSymlinking .env ..."
rm ~/.env
ln -sv $dfd/.env /home/$user/.env

echo -e "\nSymlinking .zshrc ..."
rm ~/.zshrc
ln -sv $dfd/.zshrc /home/$user/.zshrc

echo -e "\nSymlinking tmux config ..."
rm ~/.tmux.conf
ln -sv $dfd/.tmux.conf /home/$user/.tmux.conf

echo -e "\nSymlinking kitty config ..."
rm $cfd/kitty/kitty.conf
ln -sv $dfd/kitty/kitty.conf $cfd/kitty/kitty.conf

echo -e "\nSymlinking git congfig ..."
rm ~/.gitconfig
ln -sv $dfd/.gitconfig /home/$user/.gitconfig

echo -e "\nSynlinking p10k conifg ..."
rm ~/.p10k.zsh
ln -sv $dfd/.p10k.zsh /home/$user/.p10k.zsh

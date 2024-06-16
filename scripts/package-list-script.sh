#! /bin/bash
# Shamelessly stolen from: https://github.com/Hashino/dotfiles/blob/desktop/.config/fish/config.fish
# Script that lists all packages installed, and provides options to remove the
# package and its dependencies
# explanation of the commands
#
# Explanation: recieve a list of all packages installed by the user
# Paru -Qqent
#   -Q: Query database
#    q: Quiet, shows less information
#    e: List packages explicited installed
#    n: List packages only found in sync db (Native)
#    t: List only packages that are orphans (not required by any other package)
#
# Explanation: Lists information about a package
# Paru -Qil
#   -Q: Query database
#    i: Show information about package
#    l: List files owned by package
#
# Explanation: Finds all packages that are not installed by a user
# Paru -Qtdq
#   -Q: Query database
#    t: List only packages that are orphans (not required by any other package)
#    d: List packages installed as dependencies
#    q: Quiet, shows less information
#
# Explanation: Removes package and its dependencies
# paru -Rns
#   -R: Remove packages
#    n: No save (Remove configuration files)
#    s: Recursive (Removes unessary dependencies)
#

paru -Qqent | fzf \
	--preview 'paru -Qil {}' \
	--layout=reverse \
	--bind 'enter:execute(paru -Qil {} | bat --paging=always)' \
	--bind 'ctrl-u:execute(paru -Rns {})' \
	--bind 'ctrl-o:execute(paru -Qtdq | paru -Rns - )' \
	--header='[ENTER] = Details    [CTRL+U] = Uninstall    [CTRL+O] = Remove Orphans'

# ls (eza over ls, always -al)
alias ls 'eza -mh1la --classify=always --icons=always --color=always --group-directories-first --git'

# editors (nvim over vim)
abbr -a vim nvim
abbr -a vi nvim

# navigation (zoxide over cd)
alias cd z

# git
abbr -a g git
abbr -a lg lazygit
abbr -a gs 'git status'

# clipboard — wl-copy/wl-paste on Wayland, xclip on X11
# c/v = PRIMARY selection (mouse), cx = CLIPBOARD (Ctrl+C/Y)
if set -q WAYLAND_DISPLAY
    abbr -a c 'wl-copy --primary'
    abbr -a v 'wl-paste --primary'
    abbr -a cx wl-copy
else
    abbr -a c xclip
    abbr -a v 'xclip -o'
    abbr -a cx 'xclip -selection clipboard'
end

# networking
abbr -a ping 'prettyping --nolegend'
abbr -a ipa 'ip -br -c a && echo --- && ip -br -c l'

# kubernetes
abbr -a k kubectl
abbr -a knr "kubectl describe nodes |grep '^  Resource' -A3"

# infrastructure / IaC
abbr -a terraform tofu
abbr -a gle 'podman run --rm -v $PWD:/path docker.io/zricethezav/gitleaks:latest git --verbose /path'

# system / dotfiles
abbr -a stup 'stow --restow -v --dir=/home/$USER/git --target=/home/$USER dotfiles'
abbr -a dt 'bash ~/scripts/date.sh'
alias power-menu '$HOME/.config/fuzzel/scripts/power-menu.sh'
alias wallpaper-menu '$HOME/.config/fuzzel/scripts/wallpaper-menu.sh'
alias wallpaper-grid '$HOME/.config/fuzzel/scripts/wallpaper-grid-prototype.sh'
alias wifi-menu '$HOME/.config/fuzzel/scripts/wifi-menu.sh'
# Stolen from: https://github.com/zanderhavgaard/dotfiles/blob/master/.aliases
abbr -a sync_pacman_mirrors 'reflector --country Denmark,Sweden,Norway,Germany --fastest 10 --protocol https --verbose'
abbr -a neofetch fastfetch

# Timewarrior helper
abbr -a th time-helper
abbr -a tw timew

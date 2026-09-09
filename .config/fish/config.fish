if status is-interactive
    fastfetch
    # Commands to run in interactive sessions can go here
end

# Ensure that we do not get Fish splash screen
set fish_greeting

zoxide init fish | source
starship init fish | source
direnv hook fish | source
fzf --fish | source
mise activate fish | source
envoke shell-init --shell fish | source

ensure_ssh_agent main-ssh work-ssh

# uv
fish_add_path "/home/mads/.local/bin"

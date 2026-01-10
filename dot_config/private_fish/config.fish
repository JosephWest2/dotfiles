if status is-interactive
    bind \cy 'commandline -f accept-autosuggestion'
    export EDITOR=nvim
    export SDL_VIDEODRIVER=wayland
    export QT_QPA_PLATFORMTHEME=qt6ct
end

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH

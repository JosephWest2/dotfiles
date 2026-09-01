set --export BUN_INSTALL "$HOME/.bun"
if test -d "$BUN_INSTALL/bin"
    fish_add_path --global --move "$BUN_INSTALL/bin"
end

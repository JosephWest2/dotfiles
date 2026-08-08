#!/usr/bin/env bash

set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_contains() {
    local value=$1
    local expected=$2
    local context=$3

    case "$value" in
        *"$expected"*) ;;
        *) fail "$context: expected to contain '$expected'" ;;
    esac
}

assert_not_contains() {
    local value=$1
    local unexpected=$2
    local context=$3

    case "$value" in
        *"$unexpected"*) fail "$context: did not expect '$unexpected'" ;;
        *) ;;
    esac
}

is_ignored() {
    local ignored=$1
    local target=$2
    local line

    while IFS= read -r line; do
        if [[ "$line" == "$target" || "$line" == "$target/"* || "$target" == "$line/"* ]]; then
            return 0
        fi
    done <<< "$ignored"

    return 1
}

assert_ignored() {
    local ignored=$1
    local target=$2
    local profile=$3

    is_ignored "$ignored" "$target" || fail "$profile: expected $target to be ignored"
}

assert_included() {
    local ignored=$1
    local target=$2
    local profile=$3

    if is_ignored "$ignored" "$target"; then
        fail "$profile: expected $target to be included"
    fi
}

profile_data() {
    case "$1" in
        wet-leg)
            echo '{"chezmoi":{"hostname":"wet-leg","fqdnHostname":"wet-leg.local","os":"darwin"}}'
            ;;
        MacBookAir)
            echo '{"chezmoi":{"hostname":"MacBookAir","fqdnHostname":"MacBookAir.ht.home","os":"darwin"}}'
            ;;
        joeyarchlinux)
            echo '{"chezmoi":{"hostname":"joeyarchlinux","fqdnHostname":"joeyarchlinux","os":"linux"}}'
            ;;
        *)
            fail "unknown profile $1"
            ;;
    esac
}

render_source() {
    local data=$1
    local source_file=$2

    chezmoi execute-template \
        --source "$repo_dir" \
        --override-data "$data" \
        --file "$repo_dir/$source_file"
}

check_workspace_configs() {
    local aerospace
    local hyprland
    local letter
    local upper
    local waybar

    aerospace=$(<"$repo_dir/dot_config/aerospace/aerospace.toml")
    hyprland=$(<"$repo_dir/dot_config/hypr/hyprland.lua")
    waybar=$(<"$repo_dir/dot_config/waybar/config.jsonc")

    for letter in {a..z}; do
        upper=$(printf '%s' "$letter" | tr '[:lower:]' '[:upper:]')
        assert_contains "$aerospace" "alt-$letter = 'workspace $letter'" "aerospace lowercase workspace $letter"
        assert_contains "$aerospace" "alt-shift-$letter = 'workspace $upper'" "aerospace uppercase workspace $upper"
        assert_contains "$aerospace" "alt-ctrl-$letter = 'move-node-to-workspace $letter'" "aerospace lowercase move $letter"
        assert_contains "$aerospace" "alt-ctrl-shift-$letter = 'move-node-to-workspace $upper'" "aerospace uppercase move $upper"
    done

    assert_contains "$hyprland" 'hl.exec_cmd("wezterm", { workspace = "name:t silent" })' "hyprland wezterm workspace"
    assert_contains "$hyprland" 'hl.exec_cmd("google-chrome-stable", { workspace = "name:b silent" })' "hyprland chrome workspace"
    assert_contains "$hyprland" 'hl.dispatch(hl.dsp.focus({ workspace = "name:t" }))' "hyprland startup workspace"
    assert_contains "$hyprland" 'hl.workspace_rule({ workspace = "name:b", monitor = "HDMI-A-1", default = true })' "hyprland default browser workspace"
    assert_not_contains "$hyprland" 'hl.exec_cmd("firefox"' "hyprland autostart"
    assert_contains "$hyprland" 'local workspaceLetters = "abcdefghijklmnopqrstuvwxyz"' "hyprland letter workspaces"
    assert_contains "$hyprland" 'hl.bind(mainMod .. " + SHIFT + " .. upperLetter' "hyprland uppercase workspace binding"
    assert_contains "$hyprland" 'hl.bind(mainMod .. " + CTRL + SHIFT + " .. upperLetter' "hyprland uppercase workspace move"
    assert_contains "$hyprland" 'hl.bind(mainMod .. " + left"' "hyprland arrow focus"
    assert_contains "$hyprland" 'hl.bind(mainMod .. " + CTRL + left"' "hyprland arrow swap"
    assert_contains "$waybar" "<span color='#ff4f4f'>{name}</span>" "waybar named workspaces"
}

check_profile() {
    local profile=$1
    local data
    local ignored
    local kitty
    local zsh
    local fish
    local fnm
    local zoxide
    local wezterm

    data=$(profile_data "$profile")
    ignored=$(chezmoi ignored --source "$repo_dir" --override-data "$data")

    assert_ignored "$ignored" "README.md" "$profile"
    assert_ignored "$ignored" "CLAUDE.md" "$profile"
    assert_ignored "$ignored" "AGENTS.md" "$profile"
    assert_ignored "$ignored" "tests/test-machine-matrix.sh" "$profile"

    assert_included "$ignored" ".config/fish/config.fish" "$profile"
    assert_included "$ignored" ".config/kitty/kitty.conf" "$profile"
    assert_included "$ignored" ".wezterm.lua" "$profile"
    assert_included "$ignored" ".zshrc" "$profile"

    kitty=$(render_source "$data" "dot_config/kitty/kitty.conf.tmpl")
    zsh=$(render_source "$data" "dot_zshrc.tmpl")
    fish=$(render_source "$data" "dot_config/private_fish/config.fish.tmpl")
    fnm=$(render_source "$data" "dot_config/private_fish/conf.d/fnm.fish")
    zoxide=$(render_source "$data" "dot_config/private_fish/conf.d/zoxide.fish")
    wezterm=$(render_source "$data" "dot_wezterm.lua.tmpl")

    assert_contains "$zsh" '[[ -s "$ZSH/oh-my-zsh.sh" ]]' "$profile zsh"
    assert_contains "$zsh" 'command -v zoxide' "$profile zsh"
    assert_contains "$fish" 'test -d "$BUN_INSTALL/bin"' "$profile fish"
    assert_contains "$fnm" 'type -q fnm' "$profile fnm"
    assert_contains "$zoxide" 'type -q zoxide' "$profile zoxide"
    assert_contains "$wezterm" "mods = 'SUPER|SHIFT'" "$profile wezterm"

    case "$profile" in
        wet-leg)
            assert_ignored "$ignored" ".config/hypr" "$profile"
            assert_ignored "$ignored" ".config/waybar" "$profile"
            assert_ignored "$ignored" ".local/share/applications/zen-private.desktop" "$profile"
            assert_ignored "$ignored" ".config/fish/conf.d/conda-archlinux.fish" "$profile"
            assert_ignored "$ignored" ".config/fish/conf.d/dotnet.fish" "$profile"
            assert_included "$ignored" ".config/aerospace" "$profile"
            assert_contains "$zsh" '/Users/joseph.west/.lando/bin' "$profile zsh"
            assert_not_contains "$fish" 'SDL_VIDEODRIVER' "$profile fish"
            assert_not_contains "$kitty" 'font_size 24.0' "$profile kitty"
            assert_contains "$wezterm" "CommitMono Nerd Font Mono" "$profile wezterm"
            ;;
        MacBookAir)
            assert_ignored "$ignored" ".config/hypr" "$profile"
            assert_ignored "$ignored" ".config/waybar" "$profile"
            assert_ignored "$ignored" ".local/share/applications/zen-private.desktop" "$profile"
            assert_ignored "$ignored" ".config/fish/conf.d/conda-archlinux.fish" "$profile"
            assert_ignored "$ignored" ".config/fish/conf.d/dotnet.fish" "$profile"
            assert_included "$ignored" ".config/aerospace" "$profile"
            assert_not_contains "$zsh" '/Users/joseph.west/.lando/bin' "$profile zsh"
            assert_not_contains "$fish" 'SDL_VIDEODRIVER' "$profile fish"
            assert_contains "$kitty" 'font_size 24.0' "$profile kitty"
            assert_contains "$kitty" 'window_padding_width 6' "$profile kitty"
            assert_contains "$wezterm" "CommitMono Nerd Font Mono" "$profile wezterm"
            ;;
        joeyarchlinux)
            assert_included "$ignored" ".config/hypr" "$profile"
            assert_included "$ignored" ".config/waybar" "$profile"
            assert_included "$ignored" ".local/share/applications/zen-private.desktop" "$profile"
            assert_included "$ignored" ".config/fish/conf.d/conda-archlinux.fish" "$profile"
            assert_included "$ignored" ".config/fish/conf.d/dotnet.fish" "$profile"
            assert_ignored "$ignored" ".config/aerospace" "$profile"
            assert_not_contains "$zsh" '/Users/joseph.west/.lando/bin' "$profile zsh"
            assert_contains "$fish" 'SDL_VIDEODRIVER wayland' "$profile fish"
            assert_contains "$kitty" 'font_size 12.0' "$profile kitty"
            assert_contains "$kitty" 'map alt+1 goto_tab 1' "$profile kitty"
            assert_contains "$wezterm" "CommitMonoNerdFontMono" "$profile wezterm"
            ;;
    esac

    echo "ok - $profile"
}

command -v chezmoi >/dev/null 2>&1 || fail "chezmoi is required"
[[ ! -e "$repo_dir/dot_config/kitty/kitty.conf.bak" ]] || fail "kitty.conf.bak must not be managed"

check_workspace_configs
check_profile wet-leg
check_profile MacBookAir
check_profile joeyarchlinux

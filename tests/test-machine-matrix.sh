#!/usr/bin/env bash

set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
    echo "FAIL: $*" >&2
    exit 1
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

assert_managed() {
    local managed=$1
    local target=$2
    local profile=$3

    grep -qxF "$target" <<< "$managed" || fail "$profile: expected $target to be managed"
}

assert_unmanaged() {
    local managed=$1
    local target=$2
    local profile=$3

    if grep -qxF "$target" <<< "$managed"; then
        fail "$profile: expected $target to be unmanaged"
    fi
}

profile_data() {
    case "$1" in
        MacBookAir)
            echo '{"devboxSync":false,"chezmoi":{"hostname":"MacBookAir","fqdnHostname":"MacBookAir.ht.home","os":"darwin"}}'
            ;;
        joeyarchlinux)
            echo '{"devboxSync":false,"chezmoi":{"hostname":"joeyarchlinux","fqdnHostname":"joeyarchlinux","os":"linux"}}'
            ;;
        *)
            fail "unknown profile $1"
            ;;
    esac
}

check_profile() {
    local profile=$1
    local data
    local ignored
    local managed

    data=$(profile_data "$profile")
    ignored=$(chezmoi ignored --source "$repo_dir" --override-data "$data")
    managed=$(chezmoi managed --source "$repo_dir" --override-data "$data")

    assert_ignored "$ignored" "README.md" "$profile"
    assert_ignored "$ignored" "CLAUDE.md" "$profile"
    assert_ignored "$ignored" "AGENTS.md" "$profile"
    assert_ignored "$ignored" "tests/test-machine-matrix.sh" "$profile"

    # config.fish is installer-appended, so it is deliberately unmanaged;
    # everything authored lives in conf.d/ instead.
    assert_unmanaged "$managed" ".config/fish/config.fish" "$profile"
    assert_managed "$managed" ".config/fish/conf.d/bun.fish" "$profile"
    assert_managed "$managed" ".config/fish/conf.d/interactive.fish" "$profile"
    assert_managed "$managed" ".config/kitty/shared.conf" "$profile"
    assert_managed "$managed" ".config/kitty/default-theme.conf" "$profile"
    assert_included "$ignored" ".wezterm.lua" "$profile"
    assert_managed "$managed" ".config/zsh/shared.zsh" "$profile"
    for target in .zshrc .config/kitty/kitty.conf .config/kitty/current-theme.conf .config/vocalinux/config.json .config/opencode/opencode.json .codex/config.toml; do
        assert_unmanaged "$managed" "$target" "$profile"
    done
    assert_ignored "$ignored" "setup/local-configs.py" "$profile"
    assert_ignored "$ignored" "examples/vocalinux-config.json" "$profile"
    for target in .config/devbox/config.toml .config/devbox/deployment.json .ssh/devbox_ed25519 .ssh/devbox_ed25519.pub; do
        assert_unmanaged "$managed" "$target" "$profile"
    done

    case "$profile" in
        MacBookAir)
            assert_ignored "$ignored" ".config/uwsm" "$profile"
            assert_ignored "$ignored" ".config/hypr" "$profile"
            assert_ignored "$ignored" ".config/vocalinux" "$profile"
            assert_ignored "$ignored" ".config/waybar" "$profile"
            assert_ignored "$ignored" ".local/share/applications/zen-private.desktop" "$profile"
            assert_ignored "$ignored" ".config/fish/conf.d/conda-archlinux.fish" "$profile"
            assert_ignored "$ignored" ".config/fish/conf.d/dotnet.fish" "$profile"
            assert_included "$ignored" ".config/aerospace" "$profile"
            ;;
        joeyarchlinux)
            assert_included "$ignored" ".config/uwsm" "$profile"
            assert_included "$ignored" ".config/hypr" "$profile"
            assert_ignored "$ignored" ".config/vocalinux" "$profile"
            assert_included "$ignored" ".config/waybar" "$profile"
            assert_included "$ignored" ".local/share/applications/zen-private.desktop" "$profile"
            assert_included "$ignored" ".config/fish/conf.d/conda-archlinux.fish" "$profile"
            assert_included "$ignored" ".config/fish/conf.d/dotnet.fish" "$profile"
            assert_ignored "$ignored" ".config/aerospace" "$profile"
            ;;
    esac

    # Claude Code rewrites settings.json itself; only CLAUDE.md/skills are ours.
    assert_unmanaged "$managed" ".claude/settings.json" "$profile"
    assert_included "$ignored" ".claude/CLAUDE.md" "$profile"

    echo "ok - $profile"
}

command -v chezmoi >/dev/null 2>&1 || fail "chezmoi is required"

check_profile MacBookAir
check_profile joeyarchlinux

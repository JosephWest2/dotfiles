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

check_profile() {
    local profile=$1
    local data
    local ignored

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

    case "$profile" in
        wet-leg|MacBookAir)
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
            assert_included "$ignored" ".config/vocalinux" "$profile"
            assert_included "$ignored" ".config/waybar" "$profile"
            assert_included "$ignored" ".local/share/applications/zen-private.desktop" "$profile"
            assert_included "$ignored" ".config/fish/conf.d/conda-archlinux.fish" "$profile"
            assert_included "$ignored" ".config/fish/conf.d/dotnet.fish" "$profile"
            assert_ignored "$ignored" ".config/aerospace" "$profile"
            ;;
    esac

    echo "ok - $profile"
}

command -v chezmoi >/dev/null 2>&1 || fail "chezmoi is required"

check_profile wet-leg
check_profile MacBookAir
check_profile joeyarchlinux

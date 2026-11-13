#!/usr/bin/env bash
# Snapshot joeyarchlinux's explicitly installed packages. Run after installing
# or removing packages you want to keep track of, then commit the lists.
#
# Restore on a fresh install (official repos first; yay from yay-bin):
#   sudo pacman -S --needed - < setup/pkglist-repo.txt
#   yay -S --needed - < setup/pkglist-aur.txt
# Packages from third-party repos go to pkglist-thirdparty.txt; install them
# after setting up the repo (see README "Arch rebuild notes").
set -euo pipefail
cd "$(dirname "$0")"

official=$(mktemp); trap 'rm -f "$official"' EXIT
for repo in core extra multilib; do
    pacman -Slq "$repo" 2>/dev/null || true
done | sort -u > "$official"

pacman -Qqen | grep -xFf "$official" > pkglist-repo.txt || true
pacman -Qqen | grep -vxFf "$official" > pkglist-thirdparty.txt || true
pacman -Qqem | grep -v -- '-debug$' > pkglist-aur.txt || true
wc -l pkglist-repo.txt pkglist-thirdparty.txt pkglist-aur.txt

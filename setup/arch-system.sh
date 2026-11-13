#!/usr/bin/env bash
# Recreate joeyarchlinux's system-level setup that lives outside $HOME.
# Safe to re-run: every step checks first or rewrites identical content.
# Never runs automatically. Run it as your user after installing packages;
# it calls sudo itself (user services need your own systemd instance):
#
#   bash setup/arch-system.sh
#
# The steps that need judgment or interaction (Secure Boot, snapper, Tailscale
# login, databases) are in README.md under "Arch rebuild notes".
set -euo pipefail

[[ $(uname -s) == Linux && -f /etc/arch-release ]] || { echo "Arch Linux only" >&2; exit 1; }
[[ $EUID -ne 0 ]] || { echo "run as your user, not via sudo" >&2; exit 1; }

write_root_file() { # path content
    if [[ ! -f $1 ]] || [[ $(sudo cat "$1") != "$2" ]]; then
        printf '%s\n' "$2" | sudo tee "$1" >/dev/null
        echo "wrote $1"
    fi
}

# 8 GiB zram is the primary swap; the 64 GiB /swap/swapfile is overflow.
# zswap is disabled on the kernel command line (zswap.enabled=0).
write_root_file /etc/systemd/zram-generator.conf $'[zram0]\nzram-size = 8192'
# zram tuning from the Arch wiki: swapping to compressed RAM is cheap, so swap
# eagerly and one page at a time.
write_root_file /etc/sysctl.d/99-vm-zram-parameters.conf \
    $'vm.swappiness = 180\nvm.watermark_boost_factor = 0\nvm.watermark_scale_factor = 125\nvm.page-cluster = 0'
sudo sysctl -q --system

# sshd: keys only, only your user. The only authorized key is the MacBook's,
# limited to tailnet addresses. Drop-ins are read in order; the first value wins.
write_root_file /etc/ssh/sshd_config.d/10-key-only.conf \
    "$(printf 'PasswordAuthentication no\nKbdInteractiveAuthentication no\nPermitRootLogin no\nAllowUsers %s' "$USER")"
# Host keys appear on sshd's first start; until then there is nothing to test.
if compgen -G '/etc/ssh/ssh_host_*_key' >/dev/null; then sudo sshd -t; fi

# Supplementary groups (each is created by its package). input gives
# ydotool access to /dev/uinput via ydotool's own udev rule (80-uinput.rules).
for group in input docker libvirt wireshark; do
    if getent group "$group" >/dev/null && ! id -nG "$USER" | tr ' ' '\n' | grep -qx "$group"; then
        sudo usermod -aG "$group" "$USER"
        echo "added $USER to $group (log out to apply)"
    fi
done

# The hardware clock stays in UTC (LocalRTC=no), the systemd default; nothing to do.

# System services. Databases are left out: they need initialization first (README).
for unit in NetworkManager.service systemd-timesyncd.service sshd.service \
            tailscaled.service libvirtd.socket \
            snapper-timeline.timer snapper-cleanup.timer; do
    if systemctl cat "$unit" >/dev/null 2>&1; then
        systemctl is-enabled --quiet "$unit" || sudo systemctl enable "$unit"
    else
        echo "skip $unit (not installed)"
    fi
done
# --force replaces a display-manager.service alias left by sddm/gdm.
if systemctl cat plasmalogin.service >/dev/null 2>&1; then
    systemctl is-enabled --quiet plasmalogin.service || sudo systemctl enable --force plasmalogin.service
fi

# User services.
for unit in ydotool.service docker-desktop.service; do
    if systemctl --user cat "$unit" >/dev/null 2>&1; then
        systemctl --user is-enabled --quiet "$unit" || systemctl --user enable "$unit"
    else
        echo "skip user $unit (not installed)"
    fi
done

echo "System setup done."

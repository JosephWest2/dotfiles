# Dotfiles managed with chezmoi

This is a single chezmoi source state for two machines. Portable tools are shared; `.chezmoiignore` controls whether whole files or directories exist on a machine, while templates handle smaller content differences.

## Machines

Chezmoi's `.chezmoi.hostname` is the short hostname, up to the first dot.

| Machine | Full hostname | Template hostname | Host-specific configuration |
| --- | --- | --- | --- |
| Personal macOS | `MacBookAir.ht.home` | `MacBookAir` | AeroSpace and larger Kitty sizing |
| Personal Arch Linux | `joeyarchlinux` | `joeyarchlinux` | KDE Plasma settings (Baloo, power), Zen desktop entry, Conda, Linux .NET certificates, cargo, and system setup notes |

Zsh, Fish, Kitty, WezTerm, tmux, Neovim, Yazi, Claude and Codex instructions/skills, and clang-format are shared by both machines. Optional shell integrations are guarded so a missing tool does not break shell startup.

The shared Codex skill `claude-subagents` delegates tasks to the installed Claude
Code CLI. After applying, invoke `$claude-subagents` in Codex; its Python 3.9+
runner supports read/edit tasks, isolated worktrees, logs, timeouts, and session
follow-ups. See `dot_codex/skills/claude-subagents/SKILL.md` for usage. Run the
offline behavior tests with `python3 tests/test-claude-agent.py`.

The shared Codex skill `cloud-subagents` submits work to published Codex Cloud
environments using the CLI's ChatGPT login. Its runner saves task records,
retrieves reports and patches, and can watch in the background and queue a
completion notice to the parent session. See
`dot_codex/skills/cloud-subagents/SKILL.md` for setup and notification limits.
Run its offline tests with `python3 tests/test-cloud-agent.py`.

The `tailnet-ssh` skill (Claude and Codex) lets an agent on either machine reach
the other over Tailscale with plain OpenSSH. Both copies render from
`.chezmoitemplates/tailnet-ssh/`. The keys (`~/.ssh/tailnet_ed25519`) are set up by
hand on each machine; see the skill for details.

## Machine-selection rules

- `.chezmoiignore` entries are target-relative paths such as `.config/aerospace`, not source-state names such as `dot_config/aerospace`.
- AeroSpace is managed on Darwin hosts.
- The Linux desktop stack and Arch-specific Fish fragments are managed only on `joeyarchlinux`.
- Unknown hosts receive shared configuration but do not receive the Arch desktop stack.

Run the machine-matrix smoke test after changing an ignore rule or template condition:

```sh
bash tests/test-machine-matrix.sh
```

Before applying changes on a machine, inspect them with:

```sh
chezmoi apply --dry-run --verbose
```

## AeroSpace workspace keybindings (macOS)

`Alt` is the workspace modifier. Number key `0` targets workspace 10. Letter workspace names are case-sensitive.

| Action | Keybinding |
| --- | --- |
| Switch to numbered workspace | `Alt + 1–9/0` |
| Switch to lowercase workspace | `Alt + a–z` |
| Switch to uppercase workspace | `Alt + Shift + A–Z` |
| Move window to numbered workspace | `Alt + Ctrl + 1–9/0` |
| Move window to lowercase workspace | `Alt + Ctrl + a–z` |
| Move window to uppercase workspace | `Alt + Ctrl + Shift + A–Z` |
| Move current workspace to left monitor | `Alt + Cmd + 1` |
| Move current workspace to right monitor | `Alt + Cmd + 2` |
| Switch to previous workspace | `Alt + Tab` |

The left monitor is the main display and the right monitor is the secondary display.

## One-time cleanup after the matrix fix

Correcting `.chezmoiignore` stops managing a wrong-host file but does not remove a copy that was applied previously. Back up and remove only the following paths after confirming they are stale:

- macOS: `~/.config/hypr/`, `~/.config/waybar/`, and `~/.local/share/applications/zen-private.desktop`.
- Arch: `~/.config/aerospace/aerospace.toml`.
- All machines: `~/.config/kitty/kitty.conf.bak`.

No cleanup is automated by this repository.

## Shared preferences and local settings

Chezmoi manages authored preferences. Applications and installers own these live files:

- `~/.config/fish/config.fish` (shared Fish setup remains in `conf.d/`).
- `~/.zshrc` (shared Zsh setup is `~/.config/zsh/shared.zsh`).
- `~/.config/kitty/kitty.conf` and `current-theme.conf` (shared defaults are
  `shared.conf` and `default-theme.conf`; local settings follow the shared include).
- Vocalinux's configuration directory, Claude's `settings.json`, and Codex's
  `config.toml`.

After applying the shared files on each machine, connect the local entry points:

```sh
python3 setup/local-configs.py
```

Run this from the chezmoi source directory; Python 3 is required. The helper creates
missing entry points, or backs up and migrates recognized previous dotfiles. It
leaves already connected files alone. Customized entry points are preserved and
reported for manual migration using `setup/zshrc.example` and
`setup/kitty.conf.example`. Remove duplicate shared definitions when merging, while
retaining installer hooks and local overrides. SDKMAN initialization stays in the
local Zsh entry point. The helper never runs automatically during apply.

Kitty's default theme is copied to the local current theme only if missing. Future
interactive theme/font changes belong to the local files. Shared keybindings and
host-specific font sizes remain in chezmoi.

`examples/vocalinux-config.json` records the previous desired starting preferences.
It is not applied or merged automatically. On a fresh Arch installation, it can be
used as a reference when configuring Vocalinux; existing app settings remain local.

The Conda Fish fragment supports `$HOME/miniconda3` only when its executable exists.
If `conda init` also adds initialization to local `config.fish`, remove the duplicate
initialization so Conda loads once.
The fragment caches `conda shell.fish hook` output in `~/.cache/fish/conda-hook.fish`
(regenerated when `conda-meta/history` or `bin/conda` changes), because running the hook
took ~390 ms of every shell start. Delete that file to force regeneration.

On `joeyarchlinux`, `modify_baloofilerc` enforces two keys in `~/.config/baloofilerc`:
Baloo indexes file names only and excludes code and toolchain directories. Baloo's own
keys stay app-owned, and `chezmoi status` flags it if those two ever drift. A full content index of those trees once
saturated the disk and made every app launch slow. To rebuild the index after changing
exclusions: `balooctl6 disable; balooctl6 purge; balooctl6 enable`.

Personal `PATH` directories (`~/bin`, `~/.local/bin`, `~/.cargo/bin`, `~/go/bin`,
`~/.npm-global/bin`, …) are added by `conf.d/paths.fish`, skipping any that don't
exist. Installers may still append to the universal `fish_user_paths`; that is fine.
npm's global prefix is local: `npm config set prefix ~/.npm-global` (an `npm login`
token would land in `~/.npmrc`, so it is not managed).

Git is split so tools never fight chezmoi. `~/.config/git/config` (managed) holds
the personal identity, shared settings, the `gh` credential helper, and on
`joeyarchlinux` the personal SSH key. `~/.gitconfig` is created once if missing and is
otherwise local: anything `git config --global` or `gh auth setup-git` writes, and
any key there overrides the managed file. On `joeyarchlinux` the seed is just the
`~/homework` include; keep it last in `~/.gitconfig` so the school identity and key in
the local `~/.gitconfig-homework` win inside `~/homework`.

Kitty's per-tab colors (`identity-colors.conf` plus the `auto-colors.py` watcher) are
shared files but only active when the local `kitty.conf` includes `identity-colors.conf`
after the theme, as `setup/kitty.conf.example` does.

## Arch rebuild notes (`joeyarchlinux`)

Chezmoi covers `$HOME`. The rest of the machine is recorded here and in `setup/`;
none of it runs automatically.

1. **Disk.** btrfs on the NVMe with subvolumes `@` → `/`, `@home`, `@pkg` →
   `/var/cache/pacman/pkg`, `@log` → `/var/log`, `@swap` → `/swap`; mount options
   `compress=zstd:3,ssd,discard=async,space_cache=v2` (`/swap`: `noatime`, no
   compression). `/swap/swapfile` is 64 GiB at `pri=10`, overflow behind zram.
   `~/.cargo-target` is a nested subvolume so snapshots of `/home` don't pin build
   output: `btrfs subvolume create ~/.cargo-target` before building. The managed
   `~/.cargo/config.toml` puts each workspace's intermediate build files in
   `~/.cargo-target/<workspace-path-hash>` (cargo `build-dir`); final binaries stay
   in each project's `target/`.
   `/boot` (vfat ESP) is mounted with `fmask=0077,dmask=0077` so the systemd-boot
   random seed and kernel aren't world-readable; genfstab writes `0022`, so edit
   `/etc/fstab` after install.
2. **Boot.** systemd-boot (from archinstall) on a 1 GiB ESP shared with Windows.
   The kernel command line includes `zswap.enabled=0` because zram is the swap.
   `/etc/mkinitcpio.conf` has `MODULES=(btrfs)` and `BINARIES=(/usr/bin/btrfs)`.
3. **Secure Boot** uses sbctl with custom keys plus Microsoft's (`-m`). From firmware
   Setup Mode: `sbctl create-keys`, `sbctl enroll-keys -m`, then `sbctl sign -s` only
   systemd-boot (`/boot/EFI/systemd/systemd-bootx64.efi`), `/boot/EFI/BOOT/BOOTX64.EFI`
   and `/boot/vmlinuz-linux`. Don't sign Windows' files: Microsoft's keys already let
   them boot, and re-signing files Windows owns risks BitLocker recovery prompts.
   sbctl's pacman hook re-signs after updates. Initramfs images aren't verified (no
   UKI). Back up `/var/lib/sbctl/keys` offline; never put it in this repo.
   `/etc/mkinitcpio.d/linux.preset` builds both `default` and `fallback` images so
   the `linux-fallback` boot entry works.
4. **Packages.** Restore with the commands in `setup/update-pkglists.sh`; refresh
   the lists by running it. No multilib; AUR helper is yay (`yay-bin`).
   `setup/pkglist-thirdparty.txt` holds packages from non-Arch repos: `chatgpt-bin`
   comes from `[openai-chatgpt]`, set up by OpenAI's Arch installer script (ChatGPT
   download page). It writes `/etc/pacman.d/openai-chatgpt.conf` (`SigLevel = Required
   DatabaseRequired TrustedOnly`, `Server = https://persistent.oaistatic.com/codex-app-prod/linux/arch/$arch`),
   adds `Include = /etc/pacman.d/openai-chatgpt.conf` to `/etc/pacman.conf`, and
   imports and locally signs its key. No package owns these files. The Doppler CLI was installed by hand to `/usr/local/bin/doppler`
   (AUR alternative: `doppler-cli-bin`).
5. **System setup.** `bash setup/arch-system.sh` (as your user; it calls sudo) writes
   the 8 GiB zram config and the zram sysctls from the Arch wiki (`vm.swappiness=180`,
   `page-cluster=0`, watermark tuning), an sshd drop-in (keys only, `AllowUsers`
   your user, no root login), adds group memberships (input
   for ydotool's uinput rule, docker, libvirt, wireshark), and enables the system and
   user services. The display manager is `plasmalogin`. The hardware clock is UTC
   (`LocalRTC=no`); if Windows shows the wrong time, set its `RealTimeIsUniversal`
   registry value rather than switching Linux to local time.
   Mirrors come from reflector (`--country US --protocol https --latest 20 --sort rate`).
6. **By hand.**
   - Snapper: `snapper -c root create-config /` and `snapper -c home create-config /home`;
     timeline limits root 5 hourly / 3 daily, home 3 hourly / 2 daily, no weekly or
     monthly; number cleanup keeps 10.
   - Tailscale: `sudo tailscale up`, then `sudo tailscale set --operator=$USER`.
     Tailscale SSH stays off; the tailnet-ssh skill uses OpenSSH.
   - MariaDB and PostgreSQL: initialize them (`mariadb-install-db`, `initdb`), restore
     data from backups, then enable `mariadb.service` and `postgresql.service`.
   - Proton VPN (`proton.VPN.service`) and Docker Desktop come from their packages.
7. **Desktop.** `bash setup/kde-settings.sh` seeds shortcuts, focus-follows-mouse,
   lock screen, mouse, and splash settings. No auto-suspend on AC and the display
   timeout are enforced by chezmoi (`modify_powerdevilrc`) instead, because a silent
   reset there would suspend the machine and cut SSH and long-running jobs. GTK apps use Orchis-Dark (`orchis-theme`) with
   Breeze Dark icons and Breeze cursors, chosen in System Settings → Application
   Style → GTK.
8. **Claude Code and Codex.** Their settings files are app-owned and ignored here.
   Re-create by hand, through the apps:
   - Claude Code `settings.json`: `disableBundledSkills: true`; the `rust-analyzer-lsp`
     plugin; status line `~/.claude/abtop-statusline.sh` (from `abtop --setup`);
     hooks for herdr (SessionStart, from herdr's installer) and tokentracker
     `notify.cjs` (Stop, SessionEnd); voice in hold mode.
   - Codex `config.toml`: `personality = "pragmatic"`, high reasoning effort,
     `[features] hooks = true`, tokentracker `notify`, the `[tui] status_line` list,
     and the Blender MCP server from `~/src/blender_mcp`.

Hardware, for sizing parallel work: i5-13600KF (logical CPUs 0–11 are P-cores,
12–19 E-cores), Radeon RX 9070 (amdgpu/RADV), 31 GiB RAM. Several parallel Rust
builds at once have run out of memory. `/tmp` is a 16 GiB tmpfs.

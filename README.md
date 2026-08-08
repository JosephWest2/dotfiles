# Dotfiles managed with chezmoi

This is a single chezmoi source state for three machines. Portable tools are shared; `.chezmoiignore` controls whether whole files or directories exist on a machine, while templates handle smaller content differences.

## Machines

Chezmoi's `.chezmoi.hostname` is the short hostname, up to the first dot.

| Machine | Full hostname | Template hostname | Host-specific configuration |
| --- | --- | --- | --- |
| Work macOS | `wet-leg.local` | `wet-leg` | AeroSpace and the Zsh Lando path |
| Personal macOS | `MacBookAir.ht.home` | `MacBookAir` | AeroSpace and larger Kitty sizing |
| Personal Arch Linux | `joeyarchlinux` | `joeyarchlinux` | Hyprland, Waybar, Vocalinux, Zen desktop entry, Conda, Linux .NET certificates, and Wayland settings |

Zsh, Fish, Kitty, WezTerm, tmux, Neovim, Yazi, Codex skills, opencode, and clang-format are shared by all three machines. Optional shell integrations are guarded so a missing tool does not break shell startup.

## Machine-selection rules

- `.chezmoiignore` entries are target-relative paths such as `.config/hypr`, not source-state names such as `dot_config/hypr`.
- AeroSpace is managed on Darwin hosts.
- The Linux desktop stack, Vocalinux configuration, and Arch-specific Fish fragments are managed only on `joeyarchlinux`.
- Unknown hosts receive shared configuration but do not receive the Arch desktop stack.

Run the machine-matrix smoke test after changing an ignore rule or template condition:

```sh
bash tests/test-machine-matrix.sh
```

Before applying changes on a machine, inspect them with:

```sh
chezmoi apply --dry-run --verbose
```

## Workspace keybindings

Hyprland uses `Super` as its main workspace modifier; AeroSpace uses `Alt`. Number key `0` targets workspace 10. Letter workspace names are case-sensitive.

| Action | Hyprland (Arch) | AeroSpace (macOS) |
| --- | --- | --- |
| Switch to numbered workspace | `Super + 1–9/0` | `Alt + 1–9/0` |
| Switch to lowercase workspace | `Super + a–z` | `Alt + a–z` |
| Switch to uppercase workspace | `Super + Shift + A–Z` | `Alt + Shift + A–Z` |
| Move window to numbered workspace | `Super + Ctrl + 1–9/0` | `Alt + Ctrl + 1–9/0` |
| Move window to lowercase workspace | `Super + Ctrl + a–z` | `Alt + Ctrl + a–z` |
| Move window to uppercase workspace | `Super + Ctrl + Shift + A–Z` | `Alt + Ctrl + Shift + A–Z` |
| Move current workspace to left monitor | `Super + Alt + 1` | `Alt + Cmd + 1` |
| Move current workspace to right monitor | `Super + Alt + 2` | `Alt + Cmd + 2` |
| Switch to previous workspace | — | `Alt + Tab` |
| Cycle through existing workspaces | `Super + mouse wheel` | — |
| Toggle the `magic` scratchpad | `Super + Alt + S` | — |
| Move window to the `magic` scratchpad | `Super + Alt + Shift + S` | — |

On Arch, the left monitor is the secondary `HDMI-A-1` output and the right monitor is the primary `DP-1` output. On the work Mac, the left monitor is the main laptop display and the right monitor is the secondary display.

### Hyprland application and window controls

| Action | Keybinding |
| --- | --- |
| Quit the focused application process with `SIGTERM` | `Super + Alt + Q` |
| Gracefully close the focused window | `Super + Alt + W` |

`SIGTERM` asks the focused window's owning process to terminate, but applications may still exit without presenting an unsaved-work prompt.

## One-time cleanup after the matrix fix

Correcting `.chezmoiignore` stops managing a wrong-host file but does not remove a copy that was applied previously. Back up and remove only the following paths after confirming they are stale:

- Both Macs: `~/.config/hypr/`, `~/.config/waybar/`, and `~/.local/share/applications/zen-private.desktop`.
- Arch: `~/.config/aerospace/aerospace.toml`.
- All machines: `~/.config/kitty/kitty.conf.bak`.

No cleanup is automated by this repository.

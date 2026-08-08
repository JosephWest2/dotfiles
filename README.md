# Dotfiles managed with chezmoi

This is a single chezmoi source state for three machines. Portable tools are shared; `.chezmoiignore` controls whether whole files or directories exist on a machine, while templates handle smaller content differences.

## Machines

Chezmoi's `.chezmoi.hostname` is the short hostname, up to the first dot.

| Machine | Full hostname | Template hostname | Host-specific configuration |
| --- | --- | --- | --- |
| Work macOS | `wet-leg.local` | `wet-leg` | AeroSpace and the Zsh Lando path |
| Personal macOS | `MacBookAir.ht.home` | `MacBookAir` | AeroSpace and larger Kitty sizing |
| Personal Arch Linux | `joeyarchlinux` | `joeyarchlinux` | Hyprland, Waybar, Zen desktop entry, Conda, Linux .NET certificates, and Wayland settings |

Zsh, Fish, Kitty, WezTerm, tmux, Neovim, Yazi, Codex skills, opencode, and clang-format are shared by all three machines. Optional shell integrations are guarded so a missing tool does not break shell startup.

## Machine-selection rules

- `.chezmoiignore` entries are target-relative paths such as `.config/hypr`, not source-state names such as `dot_config/hypr`.
- AeroSpace is managed on Darwin hosts.
- The Linux desktop stack and its Fish fragments are managed only on `joeyarchlinux`.
- Unknown hosts receive shared configuration but do not receive the Arch desktop stack.

Run the machine-matrix smoke test after changing an ignore rule or template condition:

```sh
bash tests/test-machine-matrix.sh
```

Before applying changes on a machine, inspect them with:

```sh
chezmoi apply --dry-run --verbose
```

## One-time cleanup after the matrix fix

Correcting `.chezmoiignore` stops managing a wrong-host file but does not remove a copy that was applied previously. Back up and remove only the following paths after confirming they are stale:

- Both Macs: `~/.config/hypr/`, `~/.config/waybar/`, and `~/.local/share/applications/zen-private.desktop`.
- Arch: `~/.config/aerospace/aerospace.toml`.
- All machines: `~/.config/kitty/kitty.conf.bak`.

No cleanup is automated by this repository.

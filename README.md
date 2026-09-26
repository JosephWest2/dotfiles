# Dotfiles managed with chezmoi

This is a single chezmoi source state for two machines. Portable tools are shared; `.chezmoiignore` controls whether whole files or directories exist on a machine, while templates handle smaller content differences.

## Machines

Chezmoi's `.chezmoi.hostname` is the short hostname, up to the first dot.

| Machine | Full hostname | Template hostname | Host-specific configuration |
| --- | --- | --- | --- |
| Personal macOS | `MacBookAir.ht.home` | `MacBookAir` | AeroSpace and larger Kitty sizing |
| Personal Arch Linux | `joeyarchlinux` | `joeyarchlinux` | Hyprland, Waybar, Zen desktop entry, Conda, Linux .NET certificates, and Wayland settings |

Zsh, Fish, Kitty, WezTerm, tmux, Neovim, Yazi, Claude instructions/skills, opencode agents, and clang-format are shared by both machines. Optional shell integrations are guarded so a missing tool does not break shell startup.

## Machine-selection rules

- `.chezmoiignore` entries are target-relative paths such as `.config/hypr`, not source-state names such as `dot_config/hypr`.
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

On Arch, the left monitor is the secondary `HDMI-A-1` output and the right monitor is the primary `DP-1` output. On macOS, the left monitor is the main display and the right monitor is the secondary display.

### Hyprland application and window controls

| Action | Keybinding |
| --- | --- |
| Quit the focused application process with `SIGTERM` | `Super + Alt + Q` |
| Gracefully close the focused window | `Super + Alt + W` |

`SIGTERM` asks the focused window's owning process to terminate, but applications may still exit without presenting an unsaved-work prompt.

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
- Vocalinux's configuration directory, OpenCode's `opencode.json`, Claude's
  `settings.json`, and Codex's `config.toml`.

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

## Devbox configuration sync

Devbox sync is optional on each machine. The deployment manifest and dedicated
SSH key pair are stored as GPG-encrypted files because this repository is public.
They use the existing personal GPG identity ending in `5A2BD71941F8A418`, also
used by `pass`. The decryption key is never stored in this repository. New machines
need that existing GPG identity available through your normal secure key setup;
cloning dotfiles alone does not provide it.

Run `chezmoi init` and choose whether to enable encrypted devbox sync. On an
enabled machine, enter the **operator** AWS profile name printed by devbox setup
(for example, `devbox-operator`). This is separate from the source login profile
such as `devbox-profile`. The local choices are stored in
`~/.config/chezmoi/chezmoi.toml` as `data.devboxSync` and
`data.devboxOperatorProfile`. Enabling sync does not install devbox or provision
AWS resources; current devbox releases support Linux clients.

Only these devbox files are managed:

- `~/.config/devbox/deployment.json`, copied exactly from its encrypted source.
- `~/.config/devbox/config.toml`, generated from the manifest's account, region,
  deployment and owner, with this machine's operator profile and home directory.
- `~/.ssh/devbox_ed25519` and its adjacent `.pub` file, decrypted from their
  encrypted sources. The private key and devbox config/manifest remain mode 0600.

AWS credentials, login/SSO caches, OpenTofu state, setup journals and encryption
private keys are not synchronized. Authenticate separately on every machine.
The config template owns its fields; put future shared options in that template
and keep per-machine operator names in the local chezmoi data.

For an already initialized dotfiles checkout, apply just the devbox files with:

```sh
chezmoi apply --exclude=scripts \
  ~/.config/devbox/config.toml ~/.config/devbox/deployment.json \
  ~/.ssh/devbox_ed25519 ~/.ssh/devbox_ed25519.pub
```

This avoids running unrelated dotfile setup scripts during a clean devbox test.
If the operator profile has not been configured yet, use devbox's existing-manifest
setup after syncing the files, then set `data.devboxOperatorProfile` to the operator
name it prints. Sync does not create AWS profiles or extend their permissions.

After a reviewed foundation change, export the updated manifest and capture only
that file from the publishing machine:

```sh
chezmoi add --encrypt ~/.config/devbox/deployment.json
```

Commit and push the encrypted update. Other enrolled machines receive it through
their normal `chezmoi update` workflow. This is explicit file distribution, not
automatic AWS discovery or monitoring of new exports. Use one publishing machine
for a deployment to avoid overwriting a newer manifest with a stale copy.

To opt out, set `data.devboxSync = false`. Existing files are preserved and become
unmanaged; disabling sync does not revoke copies of SSH keys already on a device.
Never remove `--encrypt` when capturing the manifest or private key, and never
print decrypted key contents in diffs or logs.

To validate this configuration without AWS or personal keys, run
`python3 tests/test-devbox-sync.py` (Python 3.11+, GPG and chezmoi required).
It checks two simulated clients, encrypted updates, file permissions and opt-out.

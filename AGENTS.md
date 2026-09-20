# AGENTS.md

This repo is a [chezmoi](https://www.chezmoi.io/) source directory — dotfiles for multiple machines, applied with `chezmoi apply`.

## Machines

Templated files branch on `.chezmoi.hostname` / `.chezmoi.os` to vary behavior per machine:

- Personal macOS: `MacBookAir.ht.home` (`.chezmoi.hostname` is `MacBookAir`)
- Personal Arch Linux: `joeyarchlinux` (`.chezmoi.hostname` is `joeyarchlinux`)

## Layout

- `dot_*`, `private_dot_*` — map to `~/.*` (chezmoi's naming convention; `dot_` → `.`, `private_` → mode 600, `executable_` → `+x`).
- `*.tmpl` files are Go templates evaluated by chezmoi; check for `{{- if eq .chezmoi.hostname ... }}` or `{{- if eq .chezmoi.os ... }}` blocks before assuming a config applies to all machines.
- `.chezmoiignore` is the machine-selection seam for whole files and directories. Its patterns use target paths (`.config/hypr`), not source names (`dot_config/hypr`).
- `.chezmoiscripts/` — scripts chezmoi runs on apply (e.g. installing tmux plugins).
- `bin/` — personal scripts mapped to `~/bin`, which `dot_config/zsh/shared.zsh` puts on `PATH`.
- `dot_config/hypr`, `dot_config/waybar` — Arch/Hyprland only.
- `private_dot_local/private_share/applications/zen-private.desktop` — Arch only.
- `dot_config/aerospace` — macOS only.
- `dot_claude` — Claude Code config (global `CLAUDE.md`, `skills/`). `settings.json` is
  ignored: Claude Code rewrites it on `/model` etc., so it drifted every session.
- `dot_wezterm.lua.tmpl`, `dot_config/kitty`, `dot_config/zsh`, `dot_config/private_fish` — shared, with host/OS fragments gated by templates or ignore rules.
- Fish config lives entirely in `dot_config/private_fish/conf.d/`; `config.fish` itself is
  ignored so tool installers can append to it without causing drift.
- Zsh and Kitty main configs are local. Shared defaults live in `dot_config/zsh/shared.zsh`
  and `dot_config/kitty/shared.conf.tmpl`; `setup/local-configs.py` connects them after apply.
- Vocalinux live config, OpenCode settings, Codex settings, and Kitty's current theme are ignored.
  `examples/vocalinux-config.json` is a reference only, never applied.
- `dot_config/opencode` — authored opencode agent definitions.

## Working in this repo

- After editing a `dot_*` file, changes aren't live until `chezmoi apply` runs.
- When adding a machine-specific config, prefer a template conditional over a new file unless the divergence is large.
- Don't assume a file applies to both machines — verify against the hostname/os conditionals above.
- Run `bash tests/test-machine-matrix.sh` after changing machine selection or `.chezmoiignore`.
- Add tests only when they provide meaningful validation beyond restating the current configuration; avoid highly brittle assertions coupled to exact config text or formatting.

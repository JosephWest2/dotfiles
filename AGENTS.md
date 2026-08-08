# AGENTS.md

This repo is a [chezmoi](https://www.chezmoi.io/) source directory — dotfiles for multiple machines, applied with `chezmoi apply`.

## Machines

Templated files branch on `.chezmoi.hostname` / `.chezmoi.os` to vary behavior per machine:

- Work macOS: `wet-leg.local`
- Personal macOS: `MacBookAir.ht.home`
- Personal Arch Linux: `joeyarchlinux`

## Layout

- `dot_*`, `private_dot_*` — map to `~/.*` (chezmoi's naming convention; `dot_` → `.`, `private_` → mode 600, `executable_` → `+x`).
- `*.tmpl` files are Go templates evaluated by chezmoi; check for `{{- if eq .chezmoi.hostname ... }}` or `{{- if eq .chezmoi.os ... }}` blocks before assuming a config applies to all machines.
- `.chezmoiignore` excludes Arch/Linux-only files when the target host isn't `joeyarchlinux`.
- `.chezmoiscripts/` — scripts chezmoi runs on apply (e.g. installing tmux plugins).
- `dot_config/hypr`, `dot_config/waybar` — Arch/Hyprland only.
- `dot_config/aerospace`, `dot_wezterm.lua.tmpl`, `dot_config/kitty` — macOS-relevant (kitty and wezterm are also used on Arch, gated by template conditionals).
- `dot_codex/skills`, `dot_config/opencode` — agent/skill configs for Codex and opencode.

## Working in this repo

- After editing a `dot_*` file, changes aren't live until `chezmoi apply` runs.
- When adding a machine-specific config, prefer a template conditional over a new file unless the divergence is large.
- Don't assume a file applies to all three machines — verify against the hostname/os conditionals above.

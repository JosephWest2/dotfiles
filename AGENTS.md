# AGENTS.md

This repo is a [chezmoi](https://www.chezmoi.io/) source directory — dotfiles for multiple machines, applied with `chezmoi apply`.

## Machines

Templated files branch on `.chezmoi.hostname` / `.chezmoi.os` to vary behavior per machine:

- Personal macOS: `MacBookAir.ht.home` (`.chezmoi.hostname` is `MacBookAir`)
- Personal Arch Linux: `joeyarchlinux` (`.chezmoi.hostname` is `joeyarchlinux`)

## Layout

- `dot_*`, `private_dot_*` — map to `~/.*` (chezmoi's naming convention; `dot_` → `.`, `private_` → mode 600, `executable_` → `+x`).
- `*.tmpl` files are Go templates evaluated by chezmoi; check for `{{- if eq .chezmoi.hostname ... }}` or `{{- if eq .chezmoi.os ... }}` blocks before assuming a config applies to all machines.
- `.chezmoiignore` is the machine-selection seam for whole files and directories. Its patterns use target paths (`.config/aerospace`), not source names (`dot_config/aerospace`).
- `.chezmoiscripts/` — scripts chezmoi runs on apply (e.g. installing tmux plugins).
- `bin/` — personal scripts mapped to `~/bin`, which `dot_config/zsh/shared.zsh` puts on `PATH`.
- `private_dot_local/private_share/applications/zen-private.desktop` — Arch only.
- `dot_claude/skills/desktop-use`, `dot_codex/skills/desktop-use` — Arch only; wrappers around
  `.chezmoitemplates/desktop-use/SKILL.md`. It drives GUI apps through the kde_agent checkout at
  `~/src/kde_agent`, which chezmoi doesn't manage.
- `dot_config/aerospace` — macOS only.
- `setup/arch-system.sh`, `setup/kde-settings.sh`, `setup/update-pkglists.sh` and `setup/pkglist-*.txt` —
  manual, Arch-only. They record system-level and KDE setup that chezmoi can't own (see README
  "Arch rebuild notes"). Never wire them into `.chezmoiscripts`.
- Don't manage files an app or installer rewrites (KDE rc files, Claude `settings.json`, Codex
  `config.toml`, `fish_variables`, `mimeapps.list`, GTK settings, `~/.gitconfig`): they drift
  on first use. Capture the deliberate values in a manual `setup/` script or README note,
  or use a `create_` file that only seeds a missing file.
  Exception: when silent drift would be harmful, enforce just those keys with a `modify_`
  script (`dot_config/modify_private_baloofilerc.tmpl`, `modify_private_powerdevilrc.tmpl`,
  sharing `.chezmoitemplates/kconfig-set.py`). KDE keeps the rest of the file, and
  `chezmoi status` flags drift in the enforced keys.
- `dot_config/git/config.tmpl` — shared git settings and the personal identity (already public in
  commit history). `~/.gitconfig` is local (`create_dot_gitconfig` only seeds it); on Arch it ends
  with the `~/homework` include, which must stay last. The school identity is never in this repo.
- `dot_cargo/config.toml.tmpl`, `dot_codex/skills/muse-subagents`, `private_dot_gnupg` — Arch only
  (the Mac's `gpg-agent.conf` may need `pinentry-mac`).
- `dot_config/modify_private_baloofilerc.tmpl` — Arch only. KDE's Baloo indexer is limited to file names and
  excludes code/toolchain trees (`~/development`, `~/homework`, `~/miniconda3`, `~/go`, `~/vulkan`,
  `~/src`). Indexing those trees grew the index to 22 GiB and kept the NVMe ~90% busy, making
  app and terminal launches take seconds. Add new large code trees to its exclude list.
- `dot_claude` — Claude Code config (global `CLAUDE.md`, `skills/`). `dot_codex/AGENTS.md.tmpl` holds the
  same global rules for Codex; keep the two in sync. It appends the unmanaged
  `~/.codex/AGENTS.local.md` when present, for machine-private additions. `settings.json` is
  ignored: Claude Code rewrites it on `/model` etc., so it drifted every session.
- `dot_wezterm.lua.tmpl`, `dot_config/kitty`, `dot_config/zsh`, `dot_config/private_fish` — shared, with host/OS fragments gated by templates or ignore rules.
- Fish config lives entirely in `dot_config/private_fish/conf.d/`; `config.fish` itself is
  ignored so tool installers can append to it without causing drift.
  The fnm startup hook is also ignored so Node version manager selection stays local.
- Zsh and Kitty main configs are local. Shared defaults live in `dot_config/zsh/shared.zsh`
  and `dot_config/kitty/shared.conf.tmpl`; `setup/local-configs.py` connects them after apply.
- Vocalinux live config, Codex settings, and Kitty's current theme are ignored.
  `examples/vocalinux-config.json` is a reference only, never applied.
- `dot_codex/skills/claude-subagents` — shared Codex skill and Python runner for
  delegating tasks to Claude Code. Test with `python3 tests/test-claude-agent.py`.
- `dot_claude/skills/tailnet-ssh`, `dot_codex/skills/tailnet-ssh` — thin wrappers around the shared
  `.chezmoitemplates/tailnet-ssh/` (SKILL.md + helper script). Edit the shared templates. The
  remote host is chosen by `.chezmoi.os` (Linux targets the Mac, macOS targets Linux).

## Working in this repo

- After editing a `dot_*` file, changes aren't live until `chezmoi apply` runs.
- When adding a machine-specific config, prefer a template conditional over a new file unless the divergence is large.
- Don't assume a file applies to both machines — verify against the hostname/os conditionals above.
- Run `bash tests/test-machine-matrix.sh` after changing machine selection or `.chezmoiignore`.
- Add tests only when they provide meaningful validation beyond restating the current configuration; avoid highly brittle assertions coupled to exact config text or formatting.

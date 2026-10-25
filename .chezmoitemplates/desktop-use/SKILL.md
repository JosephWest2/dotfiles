---
name: desktop-use
description: Drive GUI applications on this Arch Linux machine through agent-desktop (kde_agent), a private headless KWin session with screenshots, keyboard and mouse input. Use when a task needs an app's interactive UI or a visual check of it.
---

# agent-desktop

`agent-desktop` runs apps in a private, headless KWin desktop (1280×720), never the
user's own. Checkout: `~/src/kde_agent` (JosephWest2/kde_agent). Docs there:
`README.md` (quickstart), `docs/AGENT_RECIPES.md`, `docs/TARGET_APPS.md`
(per-app notes), `docs/CLI.md`.

- CLI: `AD="$HOME/src/kde_agent/.local/dependencies/venv/bin/agent-desktop --json"`.
  KWin here is 6.8, which sends RGBX8888 screenshots: a build older than PR #110
  fails every `session start` with `capture_failed`.
- From outside the checkout:
  `$AD session start --dependency-root ~/src/kde_agent/.local/dependencies --artifacts ~/src/kde_agent/.agent-desktop/artifacts`.
- `type` only sends US-layout ASCII: KWin 6.8 doesn't advertise the input method
  used for other characters.

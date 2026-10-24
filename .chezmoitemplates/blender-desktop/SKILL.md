---
name: blender-desktop
description: Drive the Blender GUI on this Arch Linux desktop through agent-desktop (kde_agent), a private headless KWin session with screenshots, keyboard and mouse input. Use when a Blender task needs the interactive UI (viewport, sculpting, menus, renders, visual checks) rather than only `blender -b` scripting.
---

# Blender through agent-desktop

`agent-desktop` runs apps in a private, headless KWin desktop (1280×720), never the
user's own. Checkout: `~/src/kde_agent` (JosephWest2/kde_agent). Docs there:
`README.md` (quickstart), `docs/AGENT_RECIPES.md`, `docs/TARGET_APPS.md` (Blender
section), `docs/CLI.md`.

- CLI: `AD="$HOME/src/kde_agent/.local/dependencies/venv/bin/agent-desktop --json"`.
  The venv holds a non-editable install built by `tools/setup.sh`: switching
  branches changes nothing until setup runs again. It was built from the local
  branch `local-kwin-6.8`: `main` plus PR #110 (KWin 6.8 sends RGBX8888
  screenshots) and PR #112 (slow KWin health replies). Built without #110, every
  `session start` fails with `capture_failed`.
- `launch` needs a running session. `session start` resolves `.local/dependencies`
  and the artifacts dir against the cwd, so from elsewhere run
  `$AD session start --dependency-root ~/src/kde_agent/.local/dependencies --artifacts ~/src/kde_agent/.agent-desktop/artifacts`
  (`doctor` takes only `--dependency-root`).
- A ready session fails if KWin or the private bus doesn't answer a health check
  for about 5s, which heavy host load (e.g. parallel `blender -b` jobs) can cause:
  commands return `session_unavailable` and `session status` shows a `timeout`
  failure for `compositor` or `bus` (issue #111). A new session works.
- `launch` returns `.result.application.ref` and `.result.windows[].ref`. Rows from
  `windows` use `.window.ref`. `screenshot` returns a PNG at `.result.path`.
- `type` only sends US-layout ASCII: KWin 6.8 doesn't advertise the input method
  used for other characters.

## Blender

`docs/TARGET_APPS.md` covers geometry, splashes, menus, keys under the pointer,
titles and Save As. Its profile recipe, with the safeguard:

```bash
P=$WORK/blender-user  # WORK: any scratch dir for the task
# If $P doesn't exist, save_userpref writes to the real ~/.config/blender/VERSION/config.
mkdir -p "$P/config"
BLENDER_USER_RESOURCES="$P" blender -b --factory-startup --python-expr 'import bpy; bpy.ops.wm.save_userpref()'
$AD launch --wait-window --cwd "$WORK" --env BLENDER_USER_RESOURCES="$P" \
  -- blender --factory-startup --offline-mode [FILE.blend]
```

Not in the docs:

- `shift+f4` over an area turns it into a Python console whose typed lines run in
  the live session. Over the timeline it's only two lines tall, too small to read
  output.
- `f12` opens a separate `Blender Render` window that takes focus. `escape` over it
  closes it, and the main window is active again.

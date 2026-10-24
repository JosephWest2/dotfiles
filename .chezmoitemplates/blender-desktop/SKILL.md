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
  `tools/setup.sh` in the checkout rebuilds or reinstalls it.
- The checkout is on the local branch `kwin-6.8-rgbx-capture`. KWin 6.8 sends
  screenshots in RGBX8888, which upstream `main` rejects (`capture_failed` at
  `session start`).
- `launch` needs a running session. `session start` and `doctor` resolve
  `.local/dependencies` and the artifacts dir against the cwd, so from elsewhere run
  `$AD session start --dependency-root ~/src/kde_agent/.local/dependencies --artifacts ~/src/kde_agent/.agent-desktop/artifacts`.
  End with `$AD session stop`.
- The worker gives KWin 1s to answer a health check about once a second. Under
  heavy CPU load (e.g. parallel `blender -b` jobs) a ready session can fail:
  commands return `session_unavailable` and `session status` shows
  `failure.code: timeout`, component `compositor`. Stop, start and relaunch.
- `launch` returns `.result.application.ref` and `.result.windows[].ref`. Rows from
  `windows` use `.window.ref`. `screenshot` returns a PNG at `.result.path`.
- `type` only sends US-layout ASCII: KWin 6.8 doesn't advertise the input method
  used for other characters.

## Launching Blender

Blender 5.2 runs natively on Wayland with GPU rendering (EEVEE works). A profile
with a `userpref.blend` stops the quick-setup splash. Create `config/` first:
without it, `save_userpref` silently writes to the real
`~/.config/blender/5.2/config/userpref.blend` instead.

```bash
P=$WORK/blender-user;  # WORK: any scratch dir for the task
mkdir -p "$P/config"
BLENDER_USER_RESOURCES="$P" blender -b --factory-startup --python-expr 'import bpy; bpy.ops.wm.save_userpref()'
$AD launch --wait-window --cwd "$WORK" --env BLENDER_USER_RESOURCES="$P" \
  -- blender --factory-startup --offline-mode [FILE.blend]
```

Without a file argument the regular splash still opens a moment after the window.
Press `escape` with the pointer over the viewport.

## Blender behaviour in the session

- The window fills the screen: client 1280×684 at y 36. Client coordinates match
  `screenshot --window` pixels.
- Keys go to the area under the pointer, so `move` into the target area first.
- Menus, pies, F3 search and splashes are drawn inside the window and don't
  appear in `windows`. A menu opens under the pointer, and `return` picks the
  item under the pointer.
- `shift+f4` over an area turns it into a Python console. Typed `bpy` lines
  followed by `return` run in the live session. Over the timeline it's only two
  lines tall, too small to read output. `bpy.ops.wm.save_as_mainfile(filepath=...)`
  saves without the file browser. Once the file has a path, `ctrl+s` saves with
  no dialog. Titles look like `name [/path/name.blend] - Blender 5.2.2 LTS`, with a
  leading `* ` when there are unsaved changes.
- `f12` opens a separate `Blender Render` window that takes focus. `escape` with
  the pointer over it closes it. Then `focus` the main window again.
- Check saved files headlessly. Put the file before `--python-expr`:
  `blender -b --factory-startup FILE --python-expr '...'`.

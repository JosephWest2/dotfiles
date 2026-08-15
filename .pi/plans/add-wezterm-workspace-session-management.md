# Add WezTerm Workspace Session Management

## Goal

Add lightweight, native WezTerm session management while preserving all existing WezTerm and tmux behavior. Use WezTerm **workspaces** as the session equivalent, make `Ctrl-Space` the WezTerm leader, and provide leader bindings to create, rename, and fuzzy-switch workspaces. Session persistence and a one-for-one recreation of every tmux session command are out of scope.

## Current behavior and scope

- `dot_wezterm.lua.tmpl` is shared by the two macOS machines and the Arch Linux machine, with only font and macOS keyboard behavior templated by OS.
- It currently defines mouse/link behavior, `Alt-1` through `Alt-9` tab activation, a link-copy binding, and macOS Option-key compatibility bindings. It has no leader or workspace bindings.
- `dot_tmux.conf` uses `Ctrl-a` as its prefix and provides `fzf`-based session switching plus create, rename, kill, and persistence commands.
- The tmux configuration, TPM plugins, persistence, and bindings must remain unchanged. WezTerm workspaces are additive and can be used independently of tmux.
- WezTerm’s native workspace launcher is preferred over invoking the external `fzf` executable. `ShowLauncherArgs` with `FUZZY|WORKSPACES` provides the requested fuzzy selection workflow without a helper script or parser dependency.
- No workspace kill command, persistence setup, startup layout, shell integration, helper executable, package installation, or new test file is needed.

## Proposed approach and key decisions

1. Configure `Ctrl-Space` as `config.leader`, with an explicit short timeout so the leader state cannot remain active indefinitely.
2. Add bindings to the existing `config.keys` table rather than replacing or restructuring current bindings:
   - `Leader-f`: open `ShowLauncherArgs { flags = 'FUZZY|WORKSPACES' }` to fuzzy-filter and switch among current workspaces.
   - `Leader-c`: open `PromptInputLine`; on a non-empty name, perform `SwitchToWorkspace { name = name }`. WezTerm creates a workspace when the name is new and switches to it when it already exists, which is close to tmux’s current create-or-attach behavior.
   - `Leader-r`: prompt for a new name and rename the active workspace with `wezterm.mux.rename_workspace`.
3. Treat a cancelled or empty prompt as a no-op. Keep callbacks local to the WezTerm configuration. If rename failure reporting is necessary for the installed WezTerm API, use `pcall` and a concise toast rather than allowing a callback error to disrupt the workflow.
4. Do not add duplicate control-key variants after the leader. The single-letter `f`, `c`, and `r` bindings are sufficient and mirror the memorable tmux session keys.
5. Do not modify `dot_tmux.conf`; its `Ctrl-a` workflow and external `fzf` integration continue to work exactly as they do now.

## Files expected to change

- `dot_wezterm.lua.tmpl`
  - Add the leader declaration.
  - Add native workspace switch/create/rename bindings while retaining all existing key and mouse bindings and all current chezmoi template conditionals.

No other repository file should need modification. In particular, do not change `dot_tmux.conf`, `.chezmoiignore`, scripts, or files under `tests/`, and do not create tests.

## Ordered implementation steps

1. In `dot_wezterm.lua.tmpl`, add `config.leader` near the other top-level configuration settings using `key = 'Space'`, `mods = 'CTRL'`, and an explicit timeout.
2. Keep `config.keys = {}` and its existing incremental `table.insert` pattern intact. Add the workspace bindings before the OS-specific macOS bindings so all three machines receive them.
3. Add `Leader-f` using `wezterm.action.ShowLauncherArgs` with only the `FUZZY` and `WORKSPACES` flags, plus a clear title such as `Switch workspace` if supported by the project’s installed WezTerm version.
4. Add `Leader-c` using `wezterm.action.PromptInputLine` and an `action_callback`:
   - Label the prompt clearly as workspace/session creation.
   - Return without action when input is cancelled or empty.
   - Call `window:perform_action(wezterm.action.SwitchToWorkspace { name = input }, pane)` for valid input.
5. Add `Leader-r` using `PromptInputLine` and an `action_callback`:
   - Obtain the current name from `window:active_workspace()`.
   - Return without action when input is cancelled, empty, or unchanged.
   - Rename with `wezterm.mux.rename_workspace(current_name, input)`.
   - Handle a name collision or API error cleanly if manual validation shows that WezTerm surfaces it to the callback.
6. Review the final diff to confirm that the existing `Alt-1..9`, link handling, mouse handling, and Darwin-only Option bindings are untouched and that `dot_tmux.conf` has no diff.

## Validation

Do not create test files. Run the following checks:

1. Render `dot_wezterm.lua.tmpl` for representative Darwin and Linux chezmoi data using `chezmoi execute-template --override-data ...`, saving the output only to temporary files. This verifies both template branches.
2. Load each temporary rendered configuration with `wezterm --config-file <temporary-file> show-keys --lua` (or the equivalent non-GUI config-loading command) and confirm there are no Lua/configuration errors and that `LEADER-f`, `LEADER-c`, and `LEADER-r` appear.
3. Run `chezmoi apply --dry-run --verbose` and verify that the expected target is only `~/.wezterm.lua` and no tmux configuration is removed or rewritten.
4. Run the existing repository smoke test as a regression check: `bash tests/test-machine-matrix.sh`. No machine-selection behavior should change.
5. After applying on a machine, manually verify in a normal WezTerm window:
   - `Ctrl-Space`, then `c`, creates and enters a named workspace.
   - Reusing an existing name switches to that workspace rather than creating a duplicate.
   - `Ctrl-Space`, then `r`, renames the active workspace; cancelling and empty input do nothing.
   - Create at least two workspaces, then use `Ctrl-Space`, then `f`; typing filters the workspace list and Enter switches to the selected workspace.
   - Existing `Alt-1..9` tab switching and the tmux `Ctrl-a` session workflow still work.

## Risks, edge cases, and dependencies

- **Terminology:** WezTerm calls these containers workspaces, but they are the documented analogue of tmux sessions. A workspace is a label on mux windows, not a persistent session database.
- **No persistence:** Workspaces disappear when their associated mux windows/processes exit or WezTerm shuts down. This is intentional.
- **Leader interception:** `Ctrl-Space` will be consumed by WezTerm as a leader and will no longer reach terminal applications as the usual NUL key. tmux remains unaffected because its prefix is `Ctrl-a`.
- **Name handling:** Cancelled, empty, and unchanged names should be no-ops. Renaming to an already-used workspace name may fail; validate the installed API behavior and report the failure without crashing the callback.
- **Create semantics:** `SwitchToWorkspace` switches to an existing workspace when given an existing name. This avoids duplicate names and intentionally resembles tmux’s `new-session -A` behavior.
- **Version dependency:** The configuration relies on `PromptInputLine`, `SwitchToWorkspace`, `ShowLauncherArgs` with `FUZZY|WORKSPACES`, `window:active_workspace()`, and `wezterm.mux.rename_workspace`. These are documented native APIs and are available in the currently inspected WezTerm build (`20260805-104032-4b1c3c15`), but config loading should still be checked on each managed machine if their versions differ.
- **Nested tmux:** WezTerm workspace boundaries and tmux session boundaries are independent. Users can run tmux inside a workspace, but switching one does not switch the other.

## Unresolved questions

None. The requested scope was clarified to favor native WezTerm functionality and only requires create, rename, and switch operations; a literal external `fzf` process and exact tmux command parity are not required.

# Pi Critical-Command Permission Gate Implementation Plan

## Findings and decisions

The current policy in `dot_pi/agent/extensions/pi-permission-system/config.json` asks for 50+ command families, asks for all outside-CWD access, and hard-denies `rm -rf`. Package version `@gotgenes/pi-permission-system@24.0.0` also forces prompts for opaque wrappers and unparseable shell input; configuration cannot disable those safeguards.

Agreed direction:

- Replace the package with a repository-owned critical-command gate.
- Allow file tools, external-directory access, networking, installers, ordinary Git operations, and other commands silently.
- Change `rm -rf` from `deny` to `ask`.
- Forward critical-command approval requests from subagents to the parent UI.
- Treat this as protection against accidental destructive commands, not a sandbox or adversarial-command boundary.

## Critical commands retained on `ask`

Use semantic classification rather than literal command globs:

1. `rm` with both:
   - recursive: `-r`, `-R`, or `--recursive`
   - forced: `-f` or `--force`
2. Destructive Git:
   - `git reset --hard`
   - executing `git clean` with force, excluding dry-run forms
   - force pushes: `-f`, `--force`, `--force-with-lease`, and `--force-if-includes`
3. Raw disk/filesystem destruction:
   - `dd`
   - `mkfs` and `mkfs.*`
   - `shred`
4. Container cleanup:
   - `docker system prune`
5. Remote infrastructure destruction:
   - `kubectl delete`, excluding explicit dry-run invocations
   - `helm uninstall`
   - `terraform destroy`

All other existing `ask` rules become silent allows, including ordinary `rm`, push/rebase/restore, package installation, downloads, SSH, publishing, service/process management, cloud CLIs generally, and outside-CWD access.

## Affected files

### 1. Package configuration

**Modify `dot_pi/agent/settings.json`**

- Remove `npm:@gotgenes/pi-permission-system@24.0.0`.
- Do not add another permission package; the new extension will be auto-discovered from `~/.pi/agent/extensions/`.
- Leave unrelated packages and the optional `pi-subagents` setup unchanged.

### 2. Retire the old policy

**Remove `dot_pi/agent/extensions/pi-permission-system/config.json`**

**Add/update `.chezmoiremove`**

- Ensure the previously managed target `.pi/agent/extensions/pi-permission-system/config.json` is removed on apply rather than left as misleading inactive configuration.
- Do not forcibly delete Pi’s cached npm package directory; once absent from `settings.json`, it should no longer load. Cache cleanup can remain a manual package-manager concern.

### 3. Add the custom extension

Create:

```text
dot_pi/agent/extensions/critical-command-gate/
├── index.ts
├── command-parser.ts
├── critical-command-classifier.ts
├── forwarding.ts
├── package.json
└── package-lock.json
```

Responsibilities:

- `index.ts`
  - Register the `tool_call` handler.
  - Inspect only `bash` tool calls.
  - Prompt directly when `ctx.hasUI` is true.
  - Forward approval when running without UI but with a known parent session.
  - Block on denial, cancellation, timeout, or unavailable parent.
  - Register and clean up the parent forwarding poller during session lifecycle events.

- `command-parser.ts`
  - Initialize `web-tree-sitter` with `tree-sitter-bash`.
  - Enumerate commands in chains, pipelines, substitutions, subshells, and control-flow bodies.
  - Recursively inspect literal `sh`/`bash`/`zsh`/`dash`/`ksh -c` payloads with a depth limit.
  - Normalize executable basenames and Git global options such as `git -C path …`.
  - Extract wrapped commands where statically visible, including `sudo`, `env`, `command`, `exec`, `time`, `nohup`, `timeout`, `nice`, `xargs`, and `find -exec`.
  - Fall back to a conservative whole-command/token scanner if parser initialization fails. Warn once, but do not prompt for every command merely because parsing is unavailable.

- `critical-command-classifier.ts`
  - Keep the policy as named predicates rather than scattered regular expressions.
  - Return structured match information: category, matched command unit, and human-readable risk explanation.
  - Aggregate multiple command units and prompt once with all detected critical operations.
  - Distinguish safe inspection flags such as Git clean or kubectl dry runs.
  - Export pure functions for testing independently of Pi.

- `forwarding.ts`
  - Implement parent/subagent request and response transport.
  - Use `PI_SUBAGENT_PARENT_SESSION` and Pi session IDs to route requests.
  - Store transient IPC beneath an owner-only runtime/temp directory, not the chezmoi source tree.
  - Use random request IDs, atomic writes/renames, `0700` directories, and `0600` files.
  - Serialize or queue concurrent UI prompts.
  - Poll with cancellation support and a bounded timeout.
  - Reject malformed, stale, incorrectly targeted, or duplicate requests.
  - Remove completed/stale request artifacts and stop polling on `session_shutdown`.

### 4. Install local extension dependencies

**Add `.chezmoiscripts/run_onchange_after_install-critical-command-gate-dependencies.sh.tmpl`**

Follow the existing Gondolin dependency-install pattern:

- Include the lockfile hash so the script reruns only when dependencies change.
- Run `npm ci --ignore-scripts` in the applied extension directory.
- Pin the parser dependencies through `package-lock.json`.
- Fail the chezmoi apply if dependency installation fails rather than leaving a partially functional gate.

Dependencies:

- `web-tree-sitter`
- `tree-sitter-bash`
- Pi SDK only as a type/peer dependency; use the host-provided runtime.

### 5. Add tests

Place repository-only tests under ignored `tests/`, for example:

```text
tests/critical-command-gate/
├── classifier.test.ts
├── parser.test.ts
├── forwarding.test.ts
└── extension.test.ts
```

Test matrices should include:

#### Commands that must ask

- `rm -rf dir`, `rm -fr dir`, split short flags, long flags, absolute executable paths
- Critical commands after `&&`, `||`, `;`, pipes, and newlines
- Nested command substitutions and subshells
- Literal shell `-c` payloads
- Visible wrapper forms such as `sudo rm -rf`, `env X=1 git reset --hard`, and `find … -exec rm -rf …`
- Git global options and all selected force-push spellings
- `dd`, `mkfs.ext4`, `shred`
- Selected Docker/Kubernetes/Helm/Terraform commands

#### Commands that must not ask

- `rm file`, `rm -r dir` without force, `rm -f file`
- ordinary `git push`, rebase, restore, checkout, stash, and branch operations
- `git clean -n` / `--dry-run`
- `kubectl delete … --dry-run=client`
- installers, curl/wget, SSH, chmod/chown, kill/systemctl
- file tools inside and outside the working directory
- extension and MCP tools

#### Forwarding behavior

- Direct interactive approval and denial
- Child request reaches the correct parent session
- Concurrent child requests do not overwrite one another
- Parent denial propagates back as a blocked tool call
- Timeout, parent shutdown, malformed IPC, and aborted turns fail closed
- Stale responses cannot approve a newer request
- Runtime files have owner-only permissions

#### Parser degradation

- Parser initialization failure uses the fallback scanner.
- Obvious critical commands remain detected by the fallback.
- Ordinary commands remain silent rather than causing a prompt storm.

## Validation sequence

1. Run the extension’s pure unit and integration tests.
2. Validate `dot_pi/agent/settings.json` and generated package metadata as JSON.
3. Run `npm ci --ignore-scripts` from a clean extension directory and rerun tests against the locked dependency tree.
4. Run `bash tests/test-machine-matrix.sh` because this shared Pi configuration applies across all three machines.
5. Inspect `chezmoi diff` for each machine profile, confirming:
   - the old package entry and policy disappear;
   - the custom extension and dependency script apply everywhere;
   - no unrelated machine-specific configuration changes.
6. Apply in a disposable/test home or isolated `PI_CODING_AGENT_DIR`.
7. Start Pi and verify ordinary bash/file/outside-CWD operations do not prompt.
8. Submit representative critical tool calls and deny them, confirming they are blocked without executing.
9. Enable `pi-subagents`, have a child request a harmless representative critical invocation, and verify the prompt appears in the parent and the decision returns to the child.
10. Confirm `/reload`, session switching, and shutdown do not leave pollers or pending IPC behind.

## Risks and limitations

- Shell analysis cannot reliably understand commands assembled dynamically through variables, aliases, functions, sourced scripts, generated scripts, or arbitrary `eval`. These may evade classification.
- Allowed commands can still destroy data through unlisted mechanisms, such as `find -delete`, language runtimes, cloud CLI delete operations, SQL clients, or file overwrites.
- Forwarding is security-sensitive and introduces timeout, concurrency, stale-request, and filesystem-permission concerns.
- Removing the current package loses its path protection, audit log, per-agent policy, MCP gating, session approvals, and mature forwarding implementation.
- Parser dependency installation must succeed on macOS and Arch Linux.
- Because the intended UX is permissive, parser uncertainty will not prompt universally; this deliberately favors low friction over fail-closed security.

---
name: cloud-subagents
description: Delegate work to Codex workers in OpenAI-hosted Cloud environments through the Codex CLI, track completion, retrieve reports and diffs, and queue notices to the parent session. Use for Codex cloud workers; Claude delegation uses claude-subagents.
---

# Codex Cloud workers

Use the installed Codex CLI and the user's ChatGPT login. The parent owns the
brief, tracking, verification, and integration. These workers are separate Cloud
tasks; they do not inherit this conversation or share local files.

## Start and track

Requires Python 3.9+, Git, a CLI-discoverable Codex Cloud environment with the
intended repository, and `codex login` with ChatGPT. CLI commands/output were checked
against 0.164.0 on 2026-10-25. The runner strips API-key/endpoint overrides from
its child environment and checks ChatGPT login; it never reads OAuth tokens or
falls back to API billing. This does not assert a particular plan's entitlement
or remaining cloud allowance.

Choose the environment using `codex cloud`, then `o` for its environment picker.
`codex cloud list --json` lists tasks, not environments. Pass a discovered
environment's ID or unambiguous label with `--env`. Optionally save a repository's
default with `git config --local cloud-agent.environment ENV_ID`; it stays local
to that clone and is shared by its worktrees. This setting does not register an
environment with Codex or make it discoverable. The runner does not create or
publish environments, change setup scripts, or synchronize personal skills.

### Current Cloud environments may be invisible to the CLI

Live check on 2026-10-26 with CLI 0.164.0: a published private environment was
visible in desktop/web Settings > Codex Cloud and selectable in the web Cloud
composer, while the CLI picker showed only `All Environments (Global)`.
Submission returned `no cloud environments are available for this workspace`.
This matches [upstream issue #50182](https://github.com/openai/codex/issues/50182).
The released CLI queries the legacy `/wham/environments` catalog and rejects an
empty result before matching `--env`; an explicit current-environment ID or
saved Git setting cannot bypass that check. Desktop visibility alone does not
establish CLI compatibility. Do not assume this symptom requires recreating the
environment or updating the desktop app.

When discovery is empty, check the account/workspace and the current upstream
issue before requesting a new environment. OpenAI documents
[current](https://learn.chatgpt.com/docs/environments/cloud-environments) and
[legacy](https://learn.chatgpt.com/docs/environments/cloud-environment) Cloud
environments separately. If the user's task permits browser delegation, use an
available browser tool to select the published environment in the current Cloud
composer. Track and retrieve that task through the UI; the runner's task IDs,
artifact collection and parent notifications are not verified for this route.
Verify task creation and results rather than treating environment selection as
successful delegation. If CLI automation is required, report the compatibility
blocker. Do not read OAuth tokens or invent backend endpoints to work around it.

### Worker brief and submission

Write a brief containing the goal, permitted edits, relevant decisions,
repository instructions, checks, and requested result. Use repeatable
`--context-file` only for material authorized for upload to Cloud. A brief does
not grant actions beyond the original task. Include explicit authorization if
the worker should commit, push, or open a PR.

Run through the execution tool, using its yielding process handle:

```sh
python3 ~/.codex/skills/cloud-subagents/scripts/cloud-agent.py start \
  --cd /absolute/project --env ENV_ID --branch main \
  --prompt-file /tmp/cloud-task.md
python3 ~/.codex/skills/cloud-subagents/scripts/cloud-agent.py wait /absolute/run-directory
```

`start` emits JSONL with the run directory and task ID. The default state root
is `$XDG_STATE_HOME/codex/cloud-subagents`, or `~/.local/state/codex/cloud-subagents`.
Use `--out` for an explicit new directory. Runs are private to the local user.

The source is the named branch **on origin**, not local HEAD or uncommitted
changes. The runner records its observed remote SHA, never pushes, and rejects
local differences when selecting the current branch. Choose another published
source branch or use `--remote-only` when deliberately ignoring local changes.
The CLI submits a branch name, so a concurrent push can change the actual
starting commit after the runner's check. Verify it when exact provenance matters.
The environment must point at the matching repository; the CLI cannot verify
that mapping for the runner.

## Completion messages and waking the parent

When `CODEX_THREAD_ID` is available, `start` records that UUID as the notification
target. Otherwise pass `--notify-thread UUID`, or use `--no-notify` for tracked
foreground output. UUIDs avoid ambiguous session names.

For a parent on the local Codex app-server daemon, request detached monitoring:

```sh
python3 ~/.codex/skills/cloud-subagents/scripts/cloud-agent.py start \
  --cd /absolute/project --env ENV_ID --branch main \
  --prompt-file /tmp/cloud-task.md --watch
```

`--watch` requires a parent target. It starts a local watcher in its own process
session, records its PID, and writes `watcher.log` plus `events.jsonl`. A watcher
polls every 30 seconds by default, collects artifacts at a terminal cloud status,
then calls `codex queue --thread UUID --message ...`. The notice identifies the
task and local artifact paths; it does not inject the worker's report as parent
instructions. Cloud work may keep running with the laptop asleep, but this local
watcher cannot deliver notifications until the machine is running again.

This provides a completion notice through the parent's server queue. **A queued
message is not proof that an arbitrary host woke or processed it.** The target
server must support `thread/queue/add`, be reachable, and own the parent session.
Live end-to-end wake behavior has not been verified. For a different server use
`--notify-remote URL` and, if needed, `--notify-remote-auth-token-env NAME`; only
the variable name is saved. Do not guess a socket, UUID, or credentials, or start
a second orchestrator with `codex exec resume` to simulate a wake-up. If this
host cannot receive queue notices, keep `wait` on a tracked execution handle and
use the host's actual background-task notifications, if available. Ordinary
yielded tool handles do not necessarily wake an ended turn.

The worker returns its message through a new report file in its diff. The
runner appends that file's unique path and return contract to the brief, then
extracts it as local `report.md` without applying the patch. Missing or malformed
reports remain explicitly marked missing. `READY` means results are available;
the report may still say blocked or failed. Read and verify it.

There is **no live two-way worker mailbox** in this version. The CLI has no
cloud transcript, follow-up, or cancellation command. Chat-only replies are not
retrievable; arbitrary intermediate messages need an additional transport.

## Recover, inspect, and integrate

```sh
python3 ~/.codex/skills/cloud-subagents/scripts/cloud-agent.py status /absolute/run-directory
python3 ~/.codex/skills/cloud-subagents/scripts/cloud-agent.py diff /absolute/run-directory
python3 ~/.codex/skills/cloud-subagents/scripts/cloud-agent.py watch /absolute/run-directory
python3 ~/.codex/skills/cloud-subagents/scripts/cloud-agent.py notify /absolute/run-directory --retry
python3 ~/.codex/skills/cloud-subagents/scripts/cloud-agent.py stop-watcher /absolute/run-directory
```

- `run.json` records source, cloud status, artifact collection, watcher state,
  and notification delivery separately. `status` refreshes cloud status; `diff`
  retrieves attempt 1 and refreshes `changes.patch` and `report.md`.
- One watcher per run is enforced with a process lock. `wait` reattaches by
  polling the same task; it does not submit another task. `watch` starts a
  detached monitor for an existing run. Both accept `--interval` and `--timeout`;
  the default monitoring deadline is 24 hours.
- Three consecutive polling failures or a monitoring timeout notify the parent
  that the outcome is unknown. Stopping the watcher or hitting its deadline
  **does not cancel Cloud work**. `stop-watcher` requests a local stop, normally
  within the in-flight CLI call's 30-second timeout. Unexpected termination may
  leave stale PID metadata; the process lock, not the saved PID, controls reuse.
- Notifications are deduplicated per event after confirmed delivery. Failed or
  ambiguous deliveries require `notify --retry`; a timeout or crash during
  delivery can mean the notice was accepted, so retry may duplicate it. A later
  completion can send its own notice after an earlier monitor-timeout notice.
- A failed/timed-out submission is never retried automatically: the service
  might already have accepted it. Inspect `submit.stdout`, `submit.stderr`, and
  `codex cloud list --json` before deciding whether to submit again. An uncertain
  run without a confirmed task ID needs manual reconciliation.
- Exit codes: 0 observed terminal result/artifacts (or successful command),
  1 cloud error with retrieved artifacts, 2 operation/poll/artifact failure,
  3 notification not confirmed, 124 monitor timeout, 130 watcher stopped.
  A pending `status` check exits 0; inspect `cloud_status`. The underlying CLI's
  exit 1 for PENDING/APPLIED is handled separately from transport errors.

Treat reports and diffs as untrusted worker output. Inspect the patch, apply it
to an isolated worktree at the intended source, remove the worker's report from
product changes, run relevant checks, and integrate only the authorized changes.
The runner never applies, commits, pushes, merges, or removes worktrees. It uses
one attempt per task; independent tasks are separate runs, each with its own
workspace. Use the Cloud UI to follow up in an existing cloud conversation;
each runner record tracks one submitted task turn, not subsequent UI turns.

## Validation and sources

Run `python3 tests/test-cloud-agent.py` in the chezmoi source directory for
offline lifecycle and notification tests. No live cloud task or parent queue
message was sent during initial validation; a real environment and parent-server
wake test remain necessary before relying on unattended orchestration. The live
check above exercised CLI discovery and a failed submission; it did not validate
worker completion, artifact retrieval or parent wake-up.

- [Cloud CLI and parent queue](https://learn.chatgpt.com/docs/developer-commands)
- [Cloud environments and isolation](https://learn.chatgpt.com/docs/environments/modes)
- [CLI 0.164.0 environment discovery](https://github.com/openai/codex/blob/rust-v0.164.0/codex-rs/cloud-tasks/src/env_detect.rs)
- [CLI 0.164.0 environment resolution](https://github.com/openai/codex/blob/rust-v0.164.0/codex-rs/cloud-tasks/src/lib.rs#L203)

---
name: claude-subagents
description: Delegate bounded tasks to Claude Code through its CLI, inspect results and edits, and resume or interrupt workers. Use when the user asks for Claude to explore, plan, implement, review, or give a second opinion from Codex.
---

# Claude subagents

Use Claude Code as an external worker. Codex owns the conversation, task scope,
verification, and final response. These are separate Claude sessions, not native
Codex subagents. Delegate when requested; do not silently substitute Claude for
another requested model or recursively delegate back to Codex.

## Launch

Requires Python 3.9+ and a recent `claude` CLI with `--safe-mode` and
`--permission-prompts` (tested with 2.1.289). This skill uses the user's Claude
subscription. The runner removes API-key, bearer-token, endpoint, and provider
overrides from its child environment, preserves the default model, and checks
`claude auth status` in that same environment before every launch and resume.
It requires a first-party `claude.ai` login with a reported subscription, and
sets `forceLoginMethod` to `claudeai` for the invocation. It never falls back to
API billing or changes the parent environment, saved settings, or credentials.
If login is missing, ask the user to run
`env -u ANTHROPIC_API_KEY -u ANTHROPIC_AUTH_TOKEN claude auth login` locally with
their subscribed account. Do not extract OAuth tokens for direct API calls.

```bash
python3 ~/.codex/skills/claude-subagents/scripts/claude-agent.py \
  --cd /absolute/project --prompt-file /tmp/task.md
```

Brief Claude with the objective, relevant paths and context, allowed edits,
constraints, requested checks, and expected report. It does not inherit this
conversation. Pass applicable `AGENTS.md` and `CLAUDE.md` instructions using
repeatable `--context-file`, including relevant ancestor/nested instructions;
safe mode disables their automatic discovery. For reviews, capture the desired
diff into a context file so the default read worker does not need shell access.

| Task | Options |
| --- | --- |
| Exploration, planning, review | `--mode read` (default): Read, Glob, Grep |
| Implementation | `--mode write`: also Edit and Write |
| Run a specific test command | `--mode write --allow-command 'python3 -m unittest discover -s tests'` |
| Isolated implementation | `--mode write --worktree` |
| Follow-up | `--resume /path/to/previous/run --prompt-file /tmp/follow-up.md` |
| Model or effort choice | `--model <alias-or-id> --effort <level>`; otherwise retain defaults |
| Inspect invocation without launching | `--dry-run` |

Prompt text may also be positional or supplied with `-` for stdin. Run `--help`
for timeouts, output directory, and JSON-schema output options.

## Permissions and isolation

- Read mode exposes only file-reading tools. Write mode adds file edits, with
  Bash available only when `--allow-command` is supplied. No permission bypass
  mode is provided. `dontAsk` and `--permission-prompts none` deny calls that
  would need interactive approval; report blocked work instead of broadening
  permissions automatically.
- `--allow-command` is a Claude Bash permission pattern, not an OS sandbox.
  Existing Claude permission grants and managed rules still apply. A test
  command can itself write files or access the network. Select patterns only
  within the user's authorized scope, and preserve Codex's outer sandbox and
  approval requirements. Do not describe these modes as filesystem isolation.
- Safe mode disables user/project customizations, hooks, skills, and plugins;
  MCP tools and Chrome are also explicitly disabled. Claude can still write
  its own session state. Native Agent tools are not exposed.
- Use a trusted workspace. `--worktree` creates a detached Git worktree from
  committed HEAD in the run directory and requires a clean source tree. It
  leaves the worktree intact for review and follow-ups. Concurrent writers
  need separate worktrees. No commits, merges, or removals are automatic.
- Resume takes a **previous run directory**, not a bare session UUID. It
  restores the workspace and invocation settings and writes new logs to a new
  directory. Do not override permissions on resume or run two turns of the
  same session concurrently. Work on a different task in a new session.

## Track and verify

Launch using the execution tool's yielding process handle; poll it while keeping
the user informed. Do not use Claude's `--bg` with `-p`, or detach an untracked
worker. The runner prints its run directory immediately and saves `prompt.md`,
`events.jsonl`, `stderr.log`, `last-message.txt`, and `run.json` there. The latter
records session ID, workspace, invocation settings, process ID, and final status.

The default timeout is 1800 seconds. Send SIGINT or SIGTERM to the tracked runner
to cancel. It signals its Claude process group, waits briefly, then kills any
remaining members. Timeout exits 124; interruption exits 130/143. Partial logs
and edits remain. Confirm the worker has stopped and inspect partial changes
before resuming with explicit continuation instructions. Detached descendants
may require separate inspection; do not start background services in a worker.

Only a successful final `result` event plus a zero process exit count as success.
Permission denials, malformed output, limits, and missing results are reported
as incomplete/failure, with logs retained. Verify the report and relevant tests;
for write runs inspect `git diff` and untracked files in the recorded workspace.
The runner does not attribute pre-existing changes to Claude. Cost metadata is
an estimate and can include previous turns; it is not proof of actual billing.

For a second opinion, explain where Claude agrees or disagrees with your own
assessment rather than forwarding its report without review.

## References

Checked against the installed CLI and official documentation on 2026-10-03:

- [Headless execution, streaming, and continuation](https://code.claude.com/docs/en/headless)
- [CLI flags, safe mode, and tool selection](https://code.claude.com/docs/en/cli-reference)
- [Permissions and rule precedence](https://code.claude.com/docs/en/permissions)
- [Authentication and credential precedence](https://code.claude.com/docs/en/authentication)

Offline tests cover the runner's lifecycle, result handling, and subscription
authentication on launch and resume. A live 2.1.289 smoke test verified a Pro
`claude.ai` login and successfully read a file through the Read tool. Resume
arguments and settings are tested offline; live conversation recall is unverified.

If flags or events change, check `claude --help` and these references. Do not
fall back to `--bare` for login issues: it ignores subscription OAuth credentials.

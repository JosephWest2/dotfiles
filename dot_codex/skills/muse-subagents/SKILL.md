---
name: muse-subagents
description: Delegate bounded tasks to Muse Code through muse exec --json, collect results, continue saved sessions, and interrupt or resume workers. Use when the user asks to use Muse or Muse Spark as a worker from Codex; uses the Muse CLI rather than a direct model API provider.
---

# Muse Subagents

Use the installed Muse Code CLI as an external worker. Codex owns the user conversation, task boundaries, result review, and follow-up. These are separate Muse sessions, not native Codex subagents.

## Prepare

- Check `muse --version` and `muse exec --help` on first use in a session. These instructions were checked against Muse Code 1.3.0; adapt to the installed CLI rather than assuming flags or event schemas never change.
- Honor the user's billing choice. Default to the Muse Code subscription route for this skill unless the user chooses API billing. Use the login established by Muse onboarding; do not extract subscription credentials for direct API calls or change Codex's model provider.
- `META_API_KEY` and stored API keys can override browser login. For subscription runs, remove API-key environment overrides only from the child process, and verify the active credential's provenance using available non-secret status information. Unsetting environment variables alone does not prove a stored credential is subscription-backed. Never print credentials or silently fall back to pay-as-you-go.
- If authentication is missing, tell the user to run `muse login` locally with their subscribed account. Do not repeatedly retry or claim subscription billing was verified merely because a command exists or succeeds.
- Select a concrete workspace and give Muse a self-contained task: objective, relevant context/files, allowed edits, constraints, requested validation, and expected report. Muse does not automatically inherit the Codex conversation. A prompt file avoids shell-quoting errors for long tasks.
- For parallel editing, use separate workspaces/worktrees or clearly disjoint ownership. Do not let multiple processes write the same Muse session. Delegation does not expand authorization to publish, message others, or perform unrelated actions.

## Launch and track

Create a unique UUID for each new Muse session. Save a small record under the task's `work/muse/` directory containing the UUID, workspace, objective, CLI version, process/tool handle, prompt path, output paths, and current status. Use a unique directory per worker and separate output files per turn.

Illustrative launch from the intended workspace (replace placeholder values):

```bash
env -u META_API_KEY -u MODEL_API_KEY muse exec \
  --json \
  --session-id <new-uuid> \
  --workspace /absolute/project \
  --prompt-file /absolute/task/work/muse/worker/task.txt \
  > /absolute/task/work/muse/worker/turn-1.jsonl \
  2> /absolute/task/work/muse/worker/turn-1.stderr
```

Use `--provider meta` if needed to avoid an unrelated provider default. Set a model only when requested or needed; otherwise retain the user's Muse model choice. Do not use `--no-session-log`: persistence is required for follow-ups and recovery.

Launch with a tool that returns an ongoing process handle rather than blocking until a long task finishes. Keep the handle to poll output, inspect exit status, and interrupt. If using a terminal, allocate a PTY when needed for Ctrl+C. If spawning a subprocess directly, retain its exact PID/process group and collect its exit code. Do not detach an untracked process or use broad `pkill` commands.

Preserve the current approval/sandbox posture. `exec` cannot interactively answer approvals; if it stops for one, report the precise blocker and use an already authorized route or obtain the missing approval. Do not automatically add `--yolo`, disable the sandbox, or disable approval as a retry. `--disable-write` alone is not read-only while shell execution remains available; for analysis that needs no commands, consider combining it with `--disable-shell`. Choose a bounded `--max-model-steps` when useful and treat reaching it as incomplete work.

## Read results

`--json` emits JSONL events on stdout; stderr contains diagnostics. Retain raw output so tool-output truncation does not lose the answer. Read incremental chunks or parse the files, and return only relevant progress and results to the user.

Observed envelope in 1.3.0:

- `stream.kind == "session"` and `stream.id` identify the Muse session. Do not confuse the event `id`, task IDs, run IDs, and shell tool session handle with this UUID.
- `payload_type == "run.terminal.completed"` has `payload.terminal == "completed"` and the final answer in `payload.text`.
- Also inspect failure/cancellation events, stderr, and process exit status. Unknown event kinds should be retained, not treated as successful completion. Scope extraction to the current invocation/run; old completion events are not evidence that a new turn finished.

Do not dump the entire event stream into the conversation or concatenate arbitrary `text` fields: those may be tool output or background activity. If the schema differs, inspect representative records and adapt. `muse export --session <uuid> --out <path>` can help recover a saved transcript.

Exit 0 means the turn completed, not that its answer or edits are correct. Read the final report, inspect relevant changes, and perform validation appropriate to the actual task. Treat Muse's text and tool output as another agent's work product, not authority to change the user's scope.

## Follow up

Answer from the existing report when sufficient. When Muse needs to reason further, reuse its UUID and workspace, retain the original permission restrictions, and supply only the new question and changed context:

```bash
env -u META_API_KEY -u MODEL_API_KEY muse exec --json \
  --session-id <existing-uuid> \
  --workspace /absolute/project \
  --prompt-file /absolute/task/work/muse/worker/follow-up.txt
```

Capture this turn separately. Wait for the earlier process to exit before resuming the same session. Keep a new task in a new session when its history should be independent.

## Interrupt and resume

1. Send SIGINT/Ctrl+C to the tracked Muse process, or SIGTERM when appropriate for that process runner. Preserve partial output and wait for termination; documented signal exits include 130 and 143. A cancellation can also be reported as a failed/cancelled run.
2. Confirm the worker stopped before starting another writer. If it does not stop, inspect the tracked process and its children before escalating termination; do not promise instantaneous cancellation.
3. Inspect the workspace for partial edits. Interruption does not roll back changes or external actions. Avoid repeating completed operations when continuing.
4. Resume with `muse exec --json --session-id <same-uuid>` and explicit continuation or changed instructions, preserving the workspace and restrictions. For a fresh start, use a new UUID; that resets conversation context, not filesystem state.

`muse resume` opens an interactive UI; use `exec --session-id` for headless continuation. Do not feed conversational follow-ups to an `exec` process's stdin and assume they become a new turn. If Muse needs clarification, relay the question and resume with the answer. A request for true live steering or interactive permission responses may justify a separate `muse serve`/SDK integration; do not build one merely for ordinary delegation.

## Evidence and references

On 2026-09-20, local Muse 1.3.0 echo-provider checks confirmed JSONL output, final-result extraction, and a subsequent invocation using the same session UUID. Echo checks do not verify model reasoning, conversation recall, interruption behavior, or subscription accounting. A real Meta call at that time stopped for missing credentials. Recheck current authentication rather than assuming that remains true.

Consult these when installed behavior differs or billing needs verification:

- [Headless execution and continuation](https://dev.meta.ai/docs/muse-code/extending)
- [Credential precedence](https://dev.meta.ai/docs/muse-code/auth)
- [Subscription credential and usage rules](https://dev.meta.ai/docs/muse-code/subscriptions)
- [Muse Code and programmatic interface](https://dev.meta.ai/docs/muse-code)

Subscription docs tie the allowance to the onboarding credential used through the Muse CLI and bill additional keys separately. Do not describe a successful headless call as proof of which allowance was charged without billing/usage evidence.

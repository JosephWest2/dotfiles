---
name: codex
description: Delegate a task to an OpenAI Codex agent (GPT models via the Codex CLI) running as a subagent — exploration, research, planning, implementation, code review, or a second opinion. Use when the user asks for Codex, OpenAI, or GPT to do or check something, or proposes cross-checking work with another model. Works on Linux, WSL, and macOS.
argument-hint: "[task for the Codex agent]"
---

# Codex subagents

Run OpenAI's Codex CLI headlessly (`codex exec`) as a subagent, the same way you would use the Agent tool. The wrapper script handles the CLI's sharp edges (stdin hangs, sandbox flags, git checks, timeouts, result parsing):

```
bash ~/.claude/skills/codex/scripts/codex-agent.sh [options] "<prompt>"
```

It prints the agent's final message, then a footer with status, session id, files changed, token usage, and a run directory holding `prompt.md`, `events.jsonl` (every command and edit the agent made), `last-message.txt`, and `stderr.log`. Run `--help` for every option.

## When to use

- The user asks for Codex / OpenAI / GPT to do, review, or weigh in on something.
- A second opinion from a different model family would add real value (a risky diff, a contested design, a bug you're stuck on). Suggest it; run it when the user agrees or has asked for cross-checking.
- Don't silently substitute Codex for your own Agent-tool subagents.

If `$ARGUMENTS` is non-empty, treat it as the task to delegate.

## Choosing the invocation

| Claude subagent equivalent | Codex invocation |
|---|---|
| `Explore` (find/understand code) | `--mode read --effort low` |
| `Plan` (design an approach) | `--mode read --effort high` |
| `general-purpose` research | `--mode read --search` (add `--effort medium`+ for hard questions) |
| `general-purpose` implementation | `--mode write` (in a git repo) |
| `isolation: "worktree"` | `--mode write --worktree` |
| Code review / second opinion on a diff | `--review uncommitted`, `--review base:main`, `--review commit:<sha>` (no prompt allowed), or `--review custom "<what to review and focus areas>"` |
| `SendMessage` to continue an agent | `--resume <session-id> "<follow-up>"` |
| Structured result | `--schema schema.json` (final message is JSON matching the schema) |

**Modes (sandbox):**
- `read` (default): read-only sandbox. Safe for any analysis.
- `write`: edits allowed in the `--cd` directory, `/tmp`, and any `--add-dir`; no network unless `--network`. Refuses outside a git repo unless `--skip-git-check`.
- `full`: no sandbox at all (`danger-full-access`). **Only when the user explicitly asks for it in this conversation**, and say so before running.

**Effort:** `low` | `medium` | `high` | `xhigh` | `max` | `ultra`. Omit it to use the Codex default. `ultra` lets Codex spawn its own sub-agents: slow and expensive, so only for large tasks. Model: omit `--model` to use the user's Codex default. List the available slugs with `grep -o '"slug":"[^"]*"' ~/.codex/models_cache.json`.

## Writing the prompt

Codex starts cold: it sees the repo, plus `AGENTS.md` (or `CLAUDE.md` as a fallback, which the wrapper turns on by default), but **none of this conversation**. Brief it like a capable colleague who just walked in:

- The goal and why it matters, what you've already ruled out, and the relevant paths and symbols.
- Scope limits ("don't touch tests", "don't run git commands", "report, don't fix").
- The return format you need ("list file:line findings ranked by severity", "under 200 words").

For long briefs, write the prompt to a file in your scratchpad and pass `--prompt-file`. Pass logs or other material with `--context-file` (repeatable), or pipe it in with `-`.

## Running

- **Short tasks** (read mode, low/medium effort): run in the foreground with Bash `timeout: 600000` and `--timeout 570`.
- **Anything longer** (write mode, high effort, reviews of big diffs): run with Bash `run_in_background: true`. You'll be notified when it finishes, then read the output file. The wrapper's own `--timeout` defaults to 1800s.
- **Parallel fan-out:** launch several background Bash calls in one message, one per independent subtask. Read-only agents can share a directory. Concurrent **write** agents must each use `--worktree` (or separate directories) so they don't clobber each other.

Example calls:

```bash
# Explore
bash ~/.claude/skills/codex/scripts/codex-agent.sh --mode read --effort low --timeout 570 \
  "Find where HTTP retries are configured in this repo and explain the backoff policy. Cite file:line."

# Implement in an isolated worktree
bash ~/.claude/skills/codex/scripts/codex-agent.sh --mode write --worktree --prompt-file /path/to/brief.md

# Second-opinion review of uncommitted changes
bash ~/.claude/skills/codex/scripts/codex-agent.sh --review uncommitted

# Review with focus areas (Codex rejects extra instructions alongside a review target)
bash ~/.claude/skills/codex/scripts/codex-agent.sh --review custom \
  "Review the uncommitted changes in this repo, focusing on concurrency and error handling."

# Follow up with the same agent
bash ~/.claude/skills/codex/scripts/codex-agent.sh --resume 01a1... "Now also check the retry tests."
```

## Handling results

- Treat the output as a subagent report: **verify** claims before acting on them or passing them on. Spot-check cited files, and re-run tests yourself.
- After write-mode runs, inspect the actual changes (`git diff`, or `git -C <worktree> diff` for worktrees) before telling the user the work is done. `files changed` in the footer lists what Codex touched.
- To see what Codex actually did, grep `events.jsonl` for `command_execution` items: each has `command`, `aggregated_output`, and `exit_code`.
- Report a failure faithfully (status `failed` or `timeout`, a non-zero exit): include the `error:` line instead of guessing at the cause.
- When relaying a second opinion, say where Codex agrees and disagrees with your own analysis. Don't just forward its text.

## Troubleshooting

- `codex CLI not found`: install with `npm install -g @openai/codex` (or on macOS, `brew install --cask codex`), then run `codex login`, or set `CODEX_API_KEY` for API-key billing. Don't log in on the user's behalf. Tell them what to run.
- Authentication errors: the user needs to run `codex login` (interactive) or check with `codex login status`.
- WSL: use the Linux build inside WSL, not the Windows `codex.exe` (the wrapper warns about this). Repos under `/mnt/c` work but are slow. Prefer the Linux filesystem.
- "not a git repository" in write mode: confirm with the user, then add `--skip-git-check`.
- Calling `codex exec` directly instead of through the wrapper: always give it stdin (`< /dev/null` or a prompt pipe with `-`), or it hangs on "Reading additional input from stdin...". Note that `--search` is not an `exec` flag; use `-c web_search="live"`.
- Dry-run any invocation with `--dry-run` to see the exact `codex` command.

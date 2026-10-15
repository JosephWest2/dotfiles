---
name: gh-watch
description: Wait for a GitHub event from a Claude Code background Bash task — a marker commit on a branch, a marker line in a PR body or comment, a PR opening or closing, CI checks on a commit finishing, or workflow runs finishing (including cancellations). Reports gh errors instead of hiding them, keeps dedup state outside the session scratchpad, and prints heartbeats. Use whenever a session must act once a branch, PR or CI run reaches a state, e.g. watching cloud implementer sessions or waiting for CI before a merge.
---

# Watching GitHub from a background task

Run the watcher with Bash `run_in_background: true`; you're notified when it exits.

```
bash ~/.claude/skills/gh-watch/scripts/gh-watch.sh MODE --repo OWNER/REPO [options]
```

It polls `gh api` (REST only, so it also works where GraphQL `gh pr …` fails), prints
`EVENT …` lines and exits 0 when the event happens. `--help` lists every option.

## Pick the mode

| Waiting for | Command |
|---|---|
| A marker commit ("Ready for review", "Review round 3 fixed") | `branch-marker --branch B --marker 'review round 3 fixed'` |
| The same on a stacked branch | `--branch B@PARENT` (else the parent's markers fire) |
| A branch that isn't pushed yet | add `--allow-missing` |
| A marker in the PR description, or in a comment | `pr-marker --pr N` or `--head B`, `--marker …`, optionally `--comments`. Also fires `pr-closed`. |
| A PR opened for a branch | `pr-open --head B` |
| CI on a commit finished | `checks --sha SHA --require 'canonical' --require 'postgres'`; `--ref B` follows new pushes |
| One workflow run, or its rerun | `run --run-id ID`; after `gh run rerun`, add `--min-attempt 2` |
| Dispatched runs on a branch | `runs --workflow scale.yml --ref B --since <ISO time before the first dispatch> --min <count>` |

Repeat `--branch`, `--pr`, `--head` and `--marker` to watch several targets with one task. The
first poll that finds anything new prints all of it, and then the watcher exits.

## Exit codes

- **0**: the event happened. Read every `EVENT`, `CHECK`, `RUN` and `NOTE` line, because `result=failure` and `cancelled=N` are reported there, not in the exit code.
- **2**: bad arguments, auth failure, or the repo, branch, commit or run was not found. Fix the command; don't re-arm unchanged.
- **3**: gave up after `--max-failures` (8) consecutive gh failures, about 35 min of backoff. Check `gh auth status` and the network, then re-arm.
- **4**: `--timeout` (24 h) passed with no event.
- **5**: a watcher with this `--name` is already running. Leave it, or pass `--replace`.
- **-1** from Claude Code: the task was detached when the session moved (e.g. a compaction into a new session ID). The process usually ran to the end. Read its output file, or run `gh-watch.sh log`, before re-arming.

## Rules (each comes from a watcher that failed)

- **An empty or failed response is never "done".** Old loops used `2>/dev/null`, so auth, rate-limit and network errors looked like "no event yet". Loops like `[ "$(…|length)" != 0 ]` and `gh pr checks | grep -q pending` also exited before CI had registered. This script fires only on positive evidence. In `checks` mode that means at least `--min` runs, every `--require` name present, nothing pending, and the same set again after `--settle` (90 s). In one case main's fast project-sync checks finished before the real CI appeared. Pass `--require` for the checks that matter.
- **Markers are case-insensitive, unanchored extended regexes.** "Round 2 fixed" vs "round 2 fixed" stalled a PR for 3.5 h, and a marker appended to an existing line was missed for 2 h. Match the round you're waiting for, e.g. `'round 3 fixed'`, not `'round [0-9]+ fixed'`.
- **Deduplication** uses commit SHAs, PR-body line text and comment IDs. It's stored under `~/.local/state/gh-watch/<name>/`, outside any scratchpad. Re-arm with the same `--name` and handled markers stay handled. On a fresh name, `--since-now` treats matches that already exist as handled, which covers stale PR-body text. With `--comments`, your own comments that quote the marker match too.
- **Cancelled is not finished.** A push cancels the older SHA's CI (`cancel-in-progress`). A concurrency group keeps only one pending run, so a newer dispatch cancels the older pending one. In Verdance this cancelled 2 of 4 scale dispatches. Watch the new head with `--ref`, and dispatch to one ref one at a time.
- **Restart with `--replace`, not `pkill -f`.** A `pkill -f` pattern once matched the watcher's own command line and killed it.
- **Pair each watcher with a long fallback**, a separate background task: `sleep 7200; echo "fallback: check watchers"`. Overnight, use a ladder of fallbacks (2, 4, 6, 8 h), so a lost notification or a stuck watcher still wakes you.
- **Don't block on AskUserQuestion while watchers are armed.** Notifications queue behind an unanswered question: in Verdance, 34 were held, for up to 8 h. Ask in plain text and end the turn.
- **After a session move, compaction or usage limit:** run `gh-watch.sh status` to see running watchers and their last poll. Their processes survive the move. Run `gh-watch.sh log` to see events that fired while you weren't listening. Re-arm only the stopped ones, with the same `--name`.
- **Output:** `WATCH` at start, `HEARTBEAT` after the first poll and every 30 min, `ERROR`, `GIVEUP` or `TIMEOUT` before a failure exit, and gh errors on stderr. Each poll costs about one REST call per target, against a limit of 5000 per hour.
- **GitHub MCP doesn't replace this.** MCP tools answer only when called and can't wake a session. Use them for reads in cloud sandboxes, where `gh` GraphQL fails, and keep watching in background Bash.

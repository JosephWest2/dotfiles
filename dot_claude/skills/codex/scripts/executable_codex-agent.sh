#!/usr/bin/env bash
# codex-agent.sh — run an OpenAI Codex CLI agent as a non-interactive subagent.
#
# Portable across Linux, WSL and macOS (bash 3.2+, no jq/python/GNU-only tools).
# Prints the agent's final message on stdout, followed by a metadata footer.
# Full event log, prompt and stderr are kept in a per-run directory.

usage() {
  cat <<'EOF'
Usage: codex-agent.sh [options] [--] [PROMPT...]

Prompt: positional args, --prompt-file FILE, or "-" to read stdin.

Options:
  -m, --mode MODE        read (default) | write | full
                           read  = read-only sandbox, cannot modify anything
                           write = may edit files in --cd dir (+ /tmp), no network
                           full  = NO sandbox (danger-full-access); explicit user request only
      --model MODEL      Model slug (default: Codex config default)
  -e, --effort LEVEL     low | medium | high | xhigh | max | ultra
  -C, --cd DIR           Working directory for the agent (default: current dir)
      --add-dir DIR      Extra writable dir (write mode; repeatable)
      --network          Allow outbound network in write mode
      --search           Enable live web search
      --schema FILE      JSON Schema the final message must conform to
      --context-file F   Append file contents to the prompt as <context> (repeatable)
  -i, --image FILE       Attach image (repeatable)
      --resume ID|last   Continue a previous session with a follow-up prompt
      --review TARGET    Code review: uncommitted | base:BRANCH | commit:SHA
                           (no prompt allowed), or custom (prompt = review instructions)
      --worktree         Run in a fresh Codex-managed git worktree (isolated edits)
      --timeout SECS     Kill the agent after SECS (default 1800, 0 = none)
      --out DIR          Run directory (default: $TMPDIR/codex-agent/<stamp>)
      --no-claude-md     Don't fall back to CLAUDE.md when no AGENTS.md exists
      --skip-git-check   Allow write/full mode outside a git repo
      --ephemeral        Don't persist the Codex session (cannot be resumed)
  -c KEY=VALUE           Raw Codex config override (repeatable)
      --dry-run          Print the codex command and exit
  -h, --help             Show this help
EOF
}

die() { printf 'codex-agent: %s\n' "$*" >&2; exit 2; }

mode=read model="" effort="" workdir="$PWD" network=0 search=0 schema=""
resume="" review="" worktree=0 timeout_secs=1800 out_dir="" claude_md=1
skip_git=0 ephemeral=0 dry_run=0 prompt_file="" read_stdin=0
add_dirs=() images=() context_files=() overrides=() prompt_parts=()

while [ $# -gt 0 ]; do
  case "$1" in
    -m|--mode) mode="$2"; shift 2 ;;
    --model) model="$2"; shift 2 ;;
    -e|--effort) effort="$2"; shift 2 ;;
    -C|--cd) workdir="$2"; shift 2 ;;
    --add-dir) add_dirs+=("$2"); shift 2 ;;
    --network) network=1; shift ;;
    --search) search=1; shift ;;
    --schema) schema="$2"; shift 2 ;;
    --context-file) context_files+=("$2"); shift 2 ;;
    -i|--image) images+=("$2"); shift 2 ;;
    --resume) resume="$2"; shift 2 ;;
    --review) review="$2"; shift 2 ;;
    --worktree) worktree=1; shift ;;
    --timeout) timeout_secs="$2"; shift 2 ;;
    --out) out_dir="$2"; shift 2 ;;
    --prompt-file) prompt_file="$2"; shift 2 ;;
    --no-claude-md) claude_md=0; shift ;;
    --skip-git-check) skip_git=1; shift ;;
    --ephemeral) ephemeral=1; shift ;;
    -c) overrides+=("$2"); shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -) read_stdin=1; shift ;;
    --) shift; while [ $# -gt 0 ]; do prompt_parts+=("$1"); shift; done ;;
    -*) die "unknown option: $1 (see --help)" ;;
    *) prompt_parts+=("$1"); shift ;;
  esac
done

# --- Preflight ---------------------------------------------------------------

codex_bin=$(command -v codex 2>/dev/null) || die "codex CLI not found on PATH.
Install: npm install -g @openai/codex   (or on macOS: brew install --cask codex)
Then authenticate: codex login   (or set CODEX_API_KEY for API-key billing)"

case "$codex_bin" in
  /mnt/[a-z]/*|*.exe)
    echo "codex-agent: warning: '$codex_bin' looks like the Windows build; inside WSL install the Linux build (npm install -g @openai/codex) so sandboxing works." >&2 ;;
esac

[ -d "$workdir" ] || die "working directory does not exist: $workdir"
workdir=$(cd "$workdir" && pwd -P)

case "$mode" in
  read) sandbox=read-only ;;
  write) sandbox=workspace-write ;;
  full) sandbox=danger-full-access ;;
  *) die "--mode must be read, write or full" ;;
esac

in_git=0
git -C "$workdir" rev-parse --is-inside-work-tree >/dev/null 2>&1 && in_git=1
if [ "$in_git" = 0 ]; then
  [ "$worktree" = 1 ] && die "--worktree requires a git repository"
  [ -n "$review" ] && die "--review requires a git repository"
  if [ "$mode" != read ] && [ "$skip_git" = 0 ]; then
    die "$workdir is not a git repository; edits there can't be reviewed or reverted with git. Pass --skip-git-check to proceed anyway."
  fi
fi

if [ -z "$out_dir" ]; then
  base="${TMPDIR:-/tmp}"; base="${base%/}/codex-agent"
  mkdir -p "$base" || die "cannot create $base"
  out_dir=$(mktemp -d "$base/$(date +%Y%m%d-%H%M%S)-XXXXXX") || die "mktemp failed"
else
  mkdir -p "$out_dir" || die "cannot create $out_dir"
fi
out_dir=$(cd "$out_dir" && pwd -P)
prompt_path="$out_dir/prompt.md"
events="$out_dir/events.jsonl"
last_msg="$out_dir/last-message.txt"
err_log="$out_dir/stderr.log"

# --- Assemble the prompt (always fed via stdin: no ARG_MAX limits, no stdin hang)

: > "$prompt_path"
if [ -n "$prompt_file" ]; then
  [ -f "$prompt_file" ] || die "prompt file not found: $prompt_file"
  cat "$prompt_file" >> "$prompt_path"
fi
[ ${#prompt_parts[@]} -gt 0 ] && printf '%s\n' "${prompt_parts[*]}" >> "$prompt_path"
[ "$read_stdin" = 1 ] && cat >> "$prompt_path"
for f in ${context_files[@]+"${context_files[@]}"}; do
  [ -f "$f" ] || die "context file not found: $f"
  { printf '\n<context file="%s">\n' "$f"; cat "$f"; printf '\n</context>\n'; } >> "$prompt_path"
done

have_prompt=0
[ -s "$prompt_path" ] && have_prompt=1
if [ -n "$review" ] && [ "$review" != custom ]; then
  [ "$have_prompt" = 1 ] && die "codex rejects extra instructions with --review $review; use --review custom with a prompt that names what to review (e.g. \"Review uncommitted changes, focusing on ...\")"
elif [ "$have_prompt" = 0 ]; then
  die "no prompt given (pass text, --prompt-file, or - for stdin)"
fi

# --- Build the codex command ---------------------------------------------------

common=(--json -o "$last_msg" -c "sandbox_mode=\"$sandbox\"")
[ -n "$model" ] && common+=(-m "$model")
[ -n "$effort" ] && common+=(-c "model_reasoning_effort=\"$effort\"")
[ "$search" = 1 ] && common+=(-c 'web_search="live"')
[ "$network" = 1 ] && common+=(-c 'sandbox_workspace_write.network_access=true')
[ "$claude_md" = 1 ] && common+=(-c 'project_doc_fallback_filenames=["CLAUDE.md"]')
[ -n "$schema" ] && { [ -f "$schema" ] || die "schema not found: $schema"; common+=(--output-schema "$schema"); }
[ "$ephemeral" = 1 ] && common+=(--ephemeral)
[ "$worktree" = 1 ] && common+=(--worktree)
{ [ "$in_git" = 0 ] || [ "$skip_git" = 1 ]; } && common+=(--skip-git-repo-check)
for o in ${overrides[@]+"${overrides[@]}"}; do common+=(-c "$o"); done

if [ -n "$review" ]; then
  cmd=(codex exec review "${common[@]}")
  case "$review" in
    uncommitted) cmd+=(--uncommitted) ;;
    base:*) cmd+=(--base "${review#base:}") ;;
    commit:*) cmd+=(--commit "${review#commit:}") ;;
    custom) ;;
    *) die "--review must be uncommitted, base:BRANCH, commit:SHA or custom" ;;
  esac
elif [ -n "$resume" ]; then
  cmd=(codex exec resume "${common[@]}")
  for img in ${images[@]+"${images[@]}"}; do cmd+=(-i "$img"); done
  if [ "$resume" = last ]; then cmd+=(--last); else cmd+=("$resume"); fi
else
  cmd=(codex exec "${common[@]}")
  for img in ${images[@]+"${images[@]}"}; do cmd+=(-i "$img"); done
  for d in ${add_dirs[@]+"${add_dirs[@]}"}; do cmd+=(--add-dir "$d"); done
fi
[ "$have_prompt" = 1 ] && cmd+=(-)

if [ "$dry_run" = 1 ]; then
  printf 'cd %q &&' "$workdir"; printf ' %q' "${cmd[@]}"
  [ "$have_prompt" = 1 ] && printf ' < %q' "$prompt_path"
  printf '\n'; exit 0
fi

# --- Run ------------------------------------------------------------------------

wt_before=""
[ "$worktree" = 1 ] && wt_before=$(git -C "$workdir" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p')

stdin_src=/dev/null
[ "$have_prompt" = 1 ] && stdin_src="$prompt_path"

start=$(date +%s)
(cd "$workdir" && exec "${cmd[@]}") < "$stdin_src" > "$events" 2> "$err_log" &
pid=$!

cleanup() { kill -TERM "$pid" 2>/dev/null; exit 130; }
trap cleanup INT TERM HUP

timed_out=0
if [ "$timeout_secs" -gt 0 ] 2>/dev/null; then
  # Poll rather than background a sleep, so nothing lingers after codex exits.
  while kill -0 "$pid" 2>/dev/null; do
    if [ $(( $(date +%s) - start )) -ge "$timeout_secs" ]; then
      timed_out=1
      kill -TERM "$pid" 2>/dev/null
      for _ in 1 2 3 4 5; do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
      kill -KILL "$pid" 2>/dev/null
      break
    fi
    sleep 1
  done
fi
wait "$pid" 2>/dev/null; rc=$?
trap - INT TERM HUP
elapsed=$(( $(date +%s) - start ))

# --- Report -----------------------------------------------------------------------

json_str() { sed -n "s/.*\"$1\":\"\\([^\"]*\\)\".*/\\1/p" | head -n 1; }
json_num() { sed -n "s/.*\"$1\":\\([0-9][0-9]*\\).*/\\1/p" | head -n 1; }

session=$(json_str thread_id < "$events")
usage_line=$(grep '"type":"turn.completed"' "$events" | tail -n 1)
fail_line=$(grep -E '"type":"(turn\.failed|error)"' "$events" | tail -n 1)
n_cmds=$(grep '"type":"item.completed"' "$events" | grep -c '"type":"command_execution"')
changed=$(grep '"type":"item.completed"' "$events" | grep '"type":"file_change"' \
  | grep -o '"path":"[^"]*","kind":"[a-z]*"' \
  | sed 's/"path":"\([^"]*\)","kind":"\([a-z]*\)"/\2 \1/' | sort -u)

status=ok
if [ "$timed_out" = 1 ]; then status="timeout after ${timeout_secs}s"
elif [ "$rc" -ne 0 ] || [ -n "$(printf '%s' "$fail_line" | grep turn.failed)" ]; then status="failed"
fi

if [ -s "$last_msg" ]; then
  cat "$last_msg"; printf '\n'
else
  printf '(no final message from codex)\n'
fi

printf '\n--- codex-agent ---\n'
printf 'status:   %s (exit %s)\n' "$status" "$rc"
if [ -n "$session" ]; then
  if [ "$ephemeral" = 1 ]; then printf 'session:  %s (ephemeral, not resumable)\n' "$session"
  else printf 'session:  %s  (follow up: --resume %s)\n' "$session" "$session"; fi
fi
printf 'mode:     %s (sandbox %s)%s%s\n' "$mode" "$sandbox" \
  "${model:+, model $model}" "${effort:+, effort $effort}"
printf 'cwd:      %s\n' "$workdir"
printf 'duration: %ss, commands run: %s\n' "$elapsed" "$n_cmds"
# Review runs happen in a child thread and report zero usage here; skip that noise.
if [ -n "$usage_line" ] && [ "$(printf '%s' "$usage_line" | json_num input_tokens)" != 0 ]; then
  printf 'tokens:   in %s (cached %s), out %s, reasoning %s\n' \
    "$(printf '%s' "$usage_line" | json_num input_tokens)" \
    "$(printf '%s' "$usage_line" | json_num cached_input_tokens)" \
    "$(printf '%s' "$usage_line" | json_num output_tokens)" \
    "$(printf '%s' "$usage_line" | json_num reasoning_output_tokens)"
fi
if [ -n "$changed" ]; then
  printf 'files changed:\n'; printf '%s\n' "$changed" | sed 's/^/  /'
fi
if [ "$worktree" = 1 ]; then
  wt_after=$(git -C "$workdir" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p')
  new_wt=$(printf '%s\n' "$wt_after" | grep -vxF -f <(printf '%s\n' "$wt_before") | head -n 1)
  [ -n "$new_wt" ] && printf 'worktree: %s (detached HEAD; inspect with git -C <path> diff)\n' "$new_wt"
fi
if [ "$status" != ok ]; then
  [ -n "$fail_line" ] && printf 'error:    %s\n' "$(printf '%s' "$fail_line" | sed 's/^.*"message":"//; s/"}*$//; s/\\"/"/g')"
  if grep -qiE 'unauthori[sz]ed|401|not logged in|login' "$err_log" "$events" 2>/dev/null; then
    printf 'hint:     authentication problem; run `codex login` (or set CODEX_API_KEY)\n'
  fi
  tail_err=$(grep -v '^Reading additional input from stdin' "$err_log" | tail -n 15)
  [ -n "$tail_err" ] && { printf 'stderr (tail):\n'; printf '%s\n' "$tail_err" | sed 's/^/  /'; }
fi
printf 'run dir:  %s (prompt.md, events.jsonl, last-message.txt, stderr.log)\n' "$out_dir"

[ "$status" = ok ] && exit 0
[ "$timed_out" = 1 ] && exit 124
[ "$rc" -ne 0 ] && exit "$rc"
exit 1

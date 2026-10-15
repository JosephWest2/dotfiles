#!/usr/bin/env bash
# gh-watch.sh — wait for one GitHub event, for Claude Code background Bash tasks.
#
# Polls the GitHub REST API through `gh api` (no GraphQL, so it also works where only
# REST is proxied). Prints EVENT lines and exits 0 when the event happens. gh errors go
# to stderr and are retried with backoff; after --max-failures consecutive failed polls
# the watcher exits 3 instead of spinning. An empty answer never counts as "done".
# Dedup keys, the pid, the last status and an event log live under
# ${XDG_STATE_HOME:-~/.local/state}/gh-watch, outside any session scratchpad.
# Portable: bash 3.2+ and gh; no jq.

usage() {
  cat <<'EOF'
Usage: gh-watch.sh MODE --repo OWNER/REPO [options]
       gh-watch.sh status | log [N] | forget NAME

Modes (each exits 0 after printing EVENT lines):
  branch-marker  A commit on a branch, compared with its base, whose subject matches --marker.
                   --branch B[@BASE]   repeatable; BASE defaults to the repo's default branch
                   --marker REGEX      repeatable; extended regex, case-insensitive, unanchored
                   --full-message      match the whole commit message, not just the subject
                   --allow-missing     a missing branch means "not yet" instead of an error
  pr-marker      A PR body line (or comment) matching --marker. Also fires when the PR closes.
                   --pr N | --head BRANCH   repeatable
                   --marker REGEX      repeatable
                   --comments          also match the PR's conversation comments
  pr-open        An open PR exists for --head BRANCH (repeatable).
  checks         Every check run on a commit has completed: at least --min runs, every
                 --require name present, and the same set again after --settle seconds.
                   --sha SHA | --ref BRANCH   --ref follows new pushes to the branch
                   --require REGEX     repeatable; a check name that must exist
                   --ignore REGEX      check names to leave out (e.g. optional jobs)
                   --min N (1)   --settle SECS (90)
  run            One workflow run has completed.
                   --run-id ID   [--min-attempt N]   (use N=2 after `gh run rerun`)
  runs           Every run of a workflow on a branch created since --since has completed.
                   --workflow FILE --ref BRANCH   [--since ISO8601] (default: 10 min before start)
                   [--event EVENT]   [--min N (1)]   [--settle SECS (60)]

Common options:
  --repo OWNER/REPO   default $GH_REPO
  --name NAME         state key; reuse it when re-arming so handled markers stay handled
                      (default: derived from the mode and targets)
  --interval SECS     poll interval (marker modes 240, CI modes 90)
  --since-now         marker modes: treat matches that already exist as handled
  --replace           stop a running watcher with the same name first
  --heartbeat SECS    HEARTBEAT line interval (1800)
  --max-failures N    consecutive failed polls before giving up (8, about 35 min of backoff)
  --timeout SECS      give up after this long (86400; 0 = never)

Output: WATCH at start, HEARTBEAT lines, EVENT lines and DONE on success; ERROR, GIVEUP
or TIMEOUT before a failure exit. gh errors are logged to stderr.
Exit codes: 0 event   2 usage, auth or not-found error   3 gave up after repeated gh
failures   4 timeout   5 a watcher with this name is already running
EOF
}

STATE_ROOT=${GH_WATCH_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/gh-watch}
export GH_PROMPT_DISABLED=1 GH_NO_UPDATE_NOTIFIER=1 GH_PAGER=cat NO_COLOR=1

die() { printf 'gh-watch: %s\n' "$*" >&2; exit 2; }
now() { date +%s; }
iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }
iso_at() { date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -r "$1" +%Y-%m-%dT%H:%M:%SZ; }
log_err() { printf 'gh-watch: %s %s: %s\n' "$(iso)" "$NAME" "$*" >&2; }
is_num() { case $1 in ''|*[!0-9]*) return 1 ;; esac; }
alive() { [ -n "$1" ] && kill -0 "$1" 2>/dev/null && ps -p "$1" -o args= 2>/dev/null | grep -q 'gh-watch'; }
lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

if command -v timeout >/dev/null 2>&1; then TO=timeout
elif command -v gtimeout >/dev/null 2>&1; then TO=gtimeout
else TO=""; fi

# ---- subcommands ------------------------------------------------------------
MODE=$1; [ $# -gt 0 ] && shift
case $MODE in
  ''|-h|--help|help) usage; exit 0 ;;
  status)
    found=0
    for d in "$STATE_ROOT"/w/*/; do
      [ -d "$d" ] || continue; found=1
      n=$(basename "$d"); pid=$(cat "$d/pid" 2>/dev/null); st=stopped
      alive "$pid" && st="running:$pid"
      printf '%-44s %-14s %s\n' "$n" "$st" "$(tail -n 1 "$d/status" 2>/dev/null)"
    done
    [ $found = 1 ] || echo "no watchers in $STATE_ROOT"
    exit 0 ;;
  log) tail -n "${1:-30}" "$STATE_ROOT/events.log" 2>/dev/null || echo "no events in $STATE_ROOT"; exit 0 ;;
  forget)
    case $1 in ''|*/*|.*) die "forget needs a watcher NAME from 'status'" ;; esac
    rm -rf "${STATE_ROOT:?}/w/$1"; exit 0 ;;
  branch-marker|pr-marker|pr-open|checks|run|runs) ;;
  *) usage >&2; die "unknown mode: $MODE" ;;
esac

# ---- options ----------------------------------------------------------------
REPO=${GH_REPO:-} NAME="" INTERVAL="" SINCE_NOW=0 REPLACE=0 HEARTBEAT=1800 MAX_FAIL=8
TIMEOUT=86400 FULL_MSG=0 ALLOW_MISSING=0 COMMENTS=0 SHA="" REF="" MIN=1 SETTLE=""
RUN_ID="" MIN_ATTEMPT=1 WORKFLOW="" SINCE="" EVENT_FILTER="" IGNORE=""
BRANCHES=() MARKERS=() TARGETS=() REQUIRES=()

need() { [ $# -ge 2 ] && [ -n "$2" ] || die "$1 needs a value"; }
while [ $# -gt 0 ]; do
  case $1 in
    --repo) need "$@"; REPO=$2; shift 2 ;;
    --name) need "$@"; NAME=$2; shift 2 ;;
    --interval) need "$@"; INTERVAL=$2; shift 2 ;;
    --since-now) SINCE_NOW=1; shift ;;
    --replace) REPLACE=1; shift ;;
    --heartbeat) need "$@"; HEARTBEAT=$2; shift 2 ;;
    --max-failures) need "$@"; MAX_FAIL=$2; shift 2 ;;
    --timeout) need "$@"; TIMEOUT=$2; shift 2 ;;
    --branch) need "$@"; BRANCHES+=("$2"); shift 2 ;;
    --marker) need "$@"; MARKERS+=("$2"); shift 2 ;;
    --full-message) FULL_MSG=1; shift ;;
    --allow-missing) ALLOW_MISSING=1; shift ;;
    --pr) need "$@"; is_num "$2" || die "--pr needs a number"; TARGETS+=("pr:$2"); shift 2 ;;
    --head) need "$@"; TARGETS+=("head:$2"); shift 2 ;;
    --comments) COMMENTS=1; shift ;;
    --sha) need "$@"; SHA=$2; shift 2 ;;
    --ref) need "$@"; REF=$2; shift 2 ;;
    --require) need "$@"; REQUIRES+=("$2"); shift 2 ;;
    --ignore) need "$@"; IGNORE=$2; shift 2 ;;
    --min) need "$@"; MIN=$2; shift 2 ;;
    --settle) need "$@"; SETTLE=$2; shift 2 ;;
    --run-id) need "$@"; RUN_ID=$2; shift 2 ;;
    --min-attempt) need "$@"; MIN_ATTEMPT=$2; shift 2 ;;
    --workflow) need "$@"; WORKFLOW=$2; shift 2 ;;
    --since) need "$@"; SINCE=$2; shift 2 ;;
    --event) need "$@"; EVENT_FILTER=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1 (see --help)" ;;
  esac
done

case $REPO in */*) ;; *) die "--repo OWNER/REPO is required (or set GH_REPO)" ;; esac
OWNER=${REPO%%/*}
for v in HEARTBEAT MAX_FAIL TIMEOUT MIN MIN_ATTEMPT; do
  eval "is_num \"\$$v\"" || die "$v must be a whole number"
done
case $MODE in
  branch-marker)
    [ ${#BRANCHES[@]} -gt 0 ] || die "branch-marker needs --branch"
    [ ${#MARKERS[@]} -gt 0 ] || die "branch-marker needs --marker" ;;
  pr-marker)
    [ ${#TARGETS[@]} -gt 0 ] || die "pr-marker needs --pr or --head"
    [ ${#MARKERS[@]} -gt 0 ] || die "pr-marker needs --marker" ;;
  pr-open)
    [ ${#TARGETS[@]} -gt 0 ] || die "pr-open needs --head"
    for t in "${TARGETS[@]}"; do case $t in head:*) ;; *) die "pr-open takes --head only" ;; esac; done ;;
  checks)
    [ -n "$SHA$REF" ] || die "checks needs --sha or --ref"
    [ -n "$SHA" ] && [ -n "$REF" ] && die "checks takes --sha or --ref, not both" ;;
  run) is_num "$RUN_ID" || die "run needs --run-id" ;;
  runs)
    [ -n "$WORKFLOW" ] && [ -n "$REF" ] || die "runs needs --workflow and --ref" ;;
esac
case $MODE in
  branch-marker|pr-marker|pr-open) : "${INTERVAL:=240}" ;;
  *) : "${INTERVAL:=90}" ;;
esac
case $MODE in runs) : "${SETTLE:=60}" ;; *) : "${SETTLE:=90}" ;; esac
is_num "$INTERVAL" && [ "$INTERVAL" -gt 0 ] || die "--interval must be a positive number"
is_num "$SETTLE" || die "--settle must be a whole number"

MARK_RE=""
for m in "${MARKERS[@]}"; do MARK_RE="${MARK_RE:+$MARK_RE|}($m)"; done
if [ -n "$MARK_RE" ]; then
  printf 'x\n' | grep -iEq -- "$MARK_RE" 2>/dev/null; [ $? -eq 2 ] && die "invalid --marker regex: $MARK_RE"
fi
for r in "${REQUIRES[@]}" "$IGNORE"; do
  [ -n "$r" ] || continue
  printf 'x\n' | grep -iEq -- "$r" 2>/dev/null; [ $? -eq 2 ] && die "invalid regex: $r"
done

START=$(now)
if [ "$MODE" = runs ] && [ -z "$SINCE" ]; then SINCE=$(iso_at $((START - 600))); fi

TARGET_DESC="${BRANCHES[*]} ${TARGETS[*]} ${MARK_RE} ${SHA}${REF}${RUN_ID} ${WORKFLOW} ${REQUIRES[*]}"
if [ -z "$NAME" ]; then
  NAME="$MODE-$(printf '%s %s' "$REPO" "$TARGET_DESC" | cksum | cut -d' ' -f1)"
fi
case $NAME in *[!A-Za-z0-9._-]*|.*|'') die "--name may use only letters, digits, '.', '_' and '-'" ;; esac

W="$STATE_ROOT/w/$NAME"
mkdir -p "$W" || die "cannot create state directory $W"
SEEN="$W/seen"; touch "$SEEN"

# ---- single instance ---------------------------------------------------------
old=$(cat "$W/pid" 2>/dev/null)
if [ "$old" != "$$" ] && alive "$old"; then
  if [ $REPLACE = 1 ]; then
    kill "$old" 2>/dev/null
    for _ in 1 2 3 4 5 6 7 8 9 10; do alive "$old" || break; sleep 0.5; done
    alive "$old" && die "could not stop the running watcher $NAME (pid $old)"
  else
    printf 'gh-watch: watcher %s is already running (pid %s); use --replace or another --name\n' "$NAME" "$old" >&2
    exit 5
  fi
fi
echo $$ > "$W/pid"
SLEEP_PID=""
cleanup() {
  [ -n "$SLEEP_PID" ] && kill "$SLEEP_PID" 2>/dev/null
  [ "$(cat "$W/pid" 2>/dev/null)" = "$$" ] && rm -f "$W/pid"
}
trap cleanup EXIT
trap 'echo "STOPPED $(iso) name=$NAME by signal"; exit 143' TERM INT HUP
nap() { sleep "$1" & SLEEP_PID=$!; wait "$SLEEP_PID" 2>/dev/null; SLEEP_PID=""; }

# ---- gh api wrapper ------------------------------------------------------------
# api PATH [JQ] [paginate] -> sets API_OUT, API_ERR.
# Returns 0 ok, 1 transient (network, 5xx, rate limit, timeout), 2 not found, 3 fatal.
API_OUT="" API_ERR="" API_RATE=0
api() {
  local cmd rc errf="$W/last-gh-error"
  cmd=(gh api)
  [ -n "$3" ] && cmd+=(--paginate)
  cmd+=("$1")
  [ -n "$2" ] && cmd+=(--jq "$2")
  [ -n "$TO" ] && cmd=("$TO" 60 "${cmd[@]}")
  API_OUT=$("${cmd[@]}" 2>"$errf"); rc=$?
  [ $rc -eq 0 ] && { API_ERR=""; return 0; }
  API_ERR=$(head -c 400 "$errf" | tr '\n' ' ')
  if [ $rc -eq 124 ] && [ -n "$TO" ]; then API_ERR="gh api $1 timed out after 60s"; return 1; fi
  [ -n "$API_ERR" ] || API_ERR="gh api $1 failed with exit $rc and no message"
  case $API_ERR in
    *"HTTP 404"*) return 2 ;;
    *"rate limit"*|*"HTTP 429"*) API_RATE=1; return 1 ;;
    *"HTTP 401"*|*"Bad credentials"*|*"gh auth login"*|*"HTTP 403"*|*"HTTP 4"[0-9][0-9]*) return 3 ;;
  esac
  return 1
}

# ---- event buffer ----------------------------------------------------------------
NL='
'
TAB=$(printf '\t')
EV_LINES="" EV_KEYS="" FATAL_MSG="" STATUS="" NEXT_SLEEP=$INTERVAL
seen() { grep -qxF -- "$1" "$SEEN" || printf '%s' "$EV_KEYS" | grep -qxF -- "$1"; }
add_event() { # add_event KEY LINE
  seen "$1" && return 0
  EV_KEYS="$EV_KEYS$1$NL"; EV_LINES="$EV_LINES$2$NL"
}
fatal_from_api() { # map api rc 2/3 to a fatal message; return 2
  FATAL_MSG="$1: $API_ERR"; return 2
}

DEFAULT_BRANCH=""
ensure_repo() {
  [ -n "$DEFAULT_BRANCH" ] && return 0
  api "repos/$REPO" '.default_branch'
  case $? in
    0) DEFAULT_BRANCH=$API_OUT; [ -n "$DEFAULT_BRANCH" ] || { API_ERR="empty default branch for $REPO"; return 1; } ;;
    2) FATAL_MSG="repository $REPO not found, or the gh account cannot see it"; return 2 ;;
    3) fatal_from_api "cannot read $REPO (check 'gh auth status')"; return 2 ;;
    *) return 1 ;;
  esac
}

# ---- polls: return 0 (ok; events in EV_LINES), 1 transient, 2 fatal ------------------
poll_branch_marker() {
  local spec b base sha subj jq n=0 missing=0
  for spec in "${BRANCHES[@]}"; do
    b=${spec%%@*}; base=$DEFAULT_BRANCH; [ "$spec" != "$b" ] && base=${spec#*@}
    jq='.commits[] | [.sha, (.commit.message | split("\n")[0])] | @tsv'
    [ $FULL_MSG = 1 ] && jq='.commits[] | [.sha, (.commit.message | gsub("[\r\n]+"; " "))] | @tsv'
    api "repos/$REPO/compare/$base...$b" "$jq"
    case $? in
      0) ;;
      2) if [ $ALLOW_MISSING = 1 ]; then missing=$((missing + 1)); continue; fi
         FATAL_MSG="cannot compare $base...$b in $REPO: branch or base not found (use --allow-missing to wait for a new branch)"
         return 2 ;;
      3) fatal_from_api "cannot compare $base...$b"; return ;;
      *) return 1 ;;
    esac
    while IFS=$'\t' read -r sha subj; do
      [ -n "$sha" ] || continue
      n=$((n + 1))
      printf '%s\n' "$subj" | grep -iEq -- "$MARK_RE" || continue
      add_event "c:$sha" "EVENT branch-marker repo=$REPO branch=$b sha=${sha:0:12} subject=$(printf '%s' "$subj" | cut -c1-300)"
    done <<EOF
$API_OUT
EOF
  done
  STATUS="branches=${#BRANCHES[@]} commits=$n missing=$missing"
  return 0
}

resolve_pr() { # resolve_pr TARGET -> PR_NUM ("" if no PR yet); returns like api
  local t=$1
  case $t in pr:*) PR_NUM=${t#pr:}; return 0 ;; esac
  local st rc
  for st in open all; do # prefer the open PR; fall back to the newest closed one
    api "repos/$REPO/pulls?head=$OWNER:${t#head:}&state=$st&per_page=1" '.[0].number // empty'
    rc=$?; [ $rc -eq 0 ] || return $rc
    PR_NUM=$API_OUT; [ -n "$PR_NUM" ] && return 0
  done
  return 0
}

poll_pr_marker() {
  local t num head body line norm cid who text waiting=0 checked=0
  for t in "${TARGETS[@]}"; do
    resolve_pr "$t"
    case $? in 0) ;; 2|3) fatal_from_api "cannot list PRs for $t"; return ;; *) return 1 ;; esac
    [ -n "$PR_NUM" ] || { waiting=$((waiting + 1)); continue; }
    num=$PR_NUM
    api "repos/$REPO/pulls/$num" '"\(.state)\t\(.merged)", (.body // "" | gsub("\r"; ""))'
    case $? in 0) ;; 2|3) fatal_from_api "cannot read PR #$num"; return ;; *) return 1 ;; esac
    checked=$((checked + 1))
    head=${API_OUT%%"$NL"*}
    case $API_OUT in *"$NL"*) body=${API_OUT#*"$NL"} ;; *) body="" ;; esac
    while IFS= read -r line; do
      printf '%s\n' "$line" | grep -iEq -- "$MARK_RE" || continue
      norm=$(lower "$line" | tr -s ' \t' '  ' | sed 's/^ *//; s/ *$//')
      add_event "b:$num:$(printf '%s' "$norm" | cksum | cut -d' ' -f1)" \
        "EVENT pr-marker repo=$REPO pr=$num line=$(printf '%s' "$line" | cut -c1-200)"
    done <<EOF
$body
EOF
    if [ $COMMENTS = 1 ]; then
      api "repos/$REPO/issues/$num/comments?per_page=100" \
        '.[] | [(.id | tostring), (.user.login // "-"), (.body // "" | gsub("[\r\n\t]+"; " "))] | @tsv' paginate
      case $? in 0) ;; 2|3) fatal_from_api "cannot read comments on #$num"; return ;; *) return 1 ;; esac
      while IFS=$'\t' read -r cid who text; do
        [ -n "$cid" ] || continue
        printf '%s\n' "$text" | grep -iEq -- "$MARK_RE" || continue
        add_event "m:$cid" "EVENT pr-comment-marker repo=$REPO pr=$num comment=$cid author=$who text=$(printf '%s' "$text" | cut -c1-200)"
      done <<EOF
$API_OUT
EOF
    fi
    case $head in
      closed*) add_event "x:$num" "EVENT pr-closed repo=$REPO pr=$num merged=${head#*"$TAB"}" ;;
    esac
  done
  STATUS="prs=$checked no-pr-yet=$waiting"
  return 0
}

poll_pr_open() {
  local t num url waiting=0
  for t in "${TARGETS[@]}"; do
    api "repos/$REPO/pulls?head=$OWNER:${t#head:}&state=open&per_page=1" '.[0] | select(. != null) | [(.number | tostring), .html_url] | @tsv'
    case $? in 0) ;; 2|3) fatal_from_api "cannot list PRs for ${t#head:}"; return ;; *) return 1 ;; esac
    if [ -z "$API_OUT" ]; then waiting=$((waiting + 1)); continue; fi
    IFS=$'\t' read -r num url <<EOF
$API_OUT
EOF
    add_event "o:$num" "EVENT pr-open repo=$REPO head=${t#head:} pr=$num url=$url"
  done
  STATUS="heads=${#TARGETS[@]} without-pr=$waiting"
  return 0
}

SETTLE_SIG="" SETTLE_T=0 CUR_SHA=""
# settling SIG: true while the finished set SIG has not stayed unchanged for --settle
# seconds, so checks or runs that register late are not missed.
settling() {
  local t
  [ "$SETTLE" -gt 0 ] || return 1
  t=$(now)
  if [ "$SETTLE_SIG" != "$1" ]; then SETTLE_SIG=$1; SETTLE_T=$t; fi
  [ $((t - SETTLE_T)) -ge "$SETTLE" ] && return 1
  NEXT_SLEEP=$((SETTLE - (t - SETTLE_T))); STATUS="$STATUS settling-${NEXT_SLEEP}s"
  return 0
}
classify() { # classify CONCLUSION -> ok | bad | cancelled
  case $1 in
    success|neutral|skipped) echo ok ;;
    cancelled) echo cancelled ;;
    *) echo bad ;;
  esac
}

poll_checks() {
  local sha=$SHA id st concl name n=0 pending=0 rows="" r sig missing="" result bad="" ncanc=0
  if [ -n "$REF" ]; then
    api "repos/$REPO/commits/$REF" '.sha'
    case $? in
      0) sha=$API_OUT ;;
      2) FATAL_MSG="ref $REF not found in $REPO"; return 2 ;;
      3) fatal_from_api "cannot resolve $REF"; return ;;
      *) return 1 ;;
    esac
    if [ -n "$CUR_SHA" ] && [ "$sha" != "$CUR_SHA" ]; then
      echo "NOTE $(iso) name=$NAME $REF moved ${CUR_SHA:0:12} -> ${sha:0:12}; following the new head"
      SETTLE_SIG=""
    fi
    CUR_SHA=$sha
  fi
  api "repos/$REPO/commits/$sha/check-runs?per_page=100" \
    '.check_runs[] | [(.id | tostring), .status, (.conclusion // "-"), .name] | @tsv' paginate
  case $? in
    0) ;;
    2) FATAL_MSG="commit $sha not found in $REPO"; return 2 ;;
    3) fatal_from_api "cannot read check runs for $sha"; return ;;
    *) return 1 ;;
  esac
  while IFS=$'\t' read -r id st concl name; do
    [ -n "$id" ] || continue
    if [ -n "$IGNORE" ] && printf '%s\n' "$name" | grep -iEq -- "$IGNORE"; then continue; fi
    n=$((n + 1)); [ "$st" = completed ] || pending=$((pending + 1))
    rows="$rows$id$TAB$concl$TAB$name$NL"
  done <<EOF
$API_OUT
EOF
  for r in "${REQUIRES[@]}"; do
    printf '%s' "$rows" | cut -f3 | grep -iEq -- "$r" || missing="$missing [$r]"
  done
  STATUS="sha=${sha:0:12} checks=$n pending=$pending"
  if [ $n -lt "$MIN" ] || [ -n "$missing" ] || [ $pending -gt 0 ]; then
    [ $n -lt "$MIN" ] && STATUS="$STATUS waiting-for-at-least=$MIN"
    [ -n "$missing" ] && STATUS="$STATUS not-registered-yet:$missing"
    SETTLE_SIG=""; return 0
  fi
  sig=$(printf '%s' "$rows" | cut -f1,2 | sort | tr '\n' ' ')
  settling "$sig" && return 0
  result=success
  while IFS=$'\t' read -r id concl name; do
    [ -n "$id" ] || continue
    EV_LINES="${EV_LINES}CHECK $concl $name$NL"
    case $(classify "$concl") in
      bad) result=failure; bad="$bad${bad:+,}$name" ;;
      cancelled) ncanc=$((ncanc + 1)); bad="$bad${bad:+,}$name" ;;
    esac
  done <<EOF
$rows
EOF
  [ $result = success ] && [ $ncanc -gt 0 ] && result=cancelled
  EV_LINES="${EV_LINES}EVENT checks repo=$REPO sha=${sha:0:12} result=$result checks=$n${bad:+ not-ok=$bad}$NL"
  [ $ncanc -gt 0 ] && EV_LINES="${EV_LINES}NOTE cancelled checks usually mean a newer push or dispatch replaced this run (concurrency group); re-check the newer commit$NL"
  return 0
}

poll_run() {
  local st concl attempt hsha ev name
  api "repos/$REPO/actions/runs/$RUN_ID" \
    '[.status, (.conclusion // "-"), (.run_attempt | tostring), .head_sha[0:12], .event, .name] | @tsv'
  case $? in
    0) ;;
    2) FATAL_MSG="workflow run $RUN_ID not found in $REPO"; return 2 ;;
    3) fatal_from_api "cannot read run $RUN_ID"; return ;;
    *) return 1 ;;
  esac
  IFS=$'\t' read -r st concl attempt hsha ev name <<EOF
$API_OUT
EOF
  [ -n "$st" ] || { API_ERR="empty response for run $RUN_ID"; return 1; }
  STATUS="run=$RUN_ID status=$st attempt=$attempt"
  [ "$st" = completed ] || return 0
  if is_num "$attempt" && [ "$attempt" -lt "$MIN_ATTEMPT" ]; then STATUS="$STATUS waiting-for-attempt=$MIN_ATTEMPT"; return 0; fi
  EV_LINES="EVENT run repo=$REPO id=$RUN_ID result=$concl attempt=$attempt sha=$hsha event=$ev name=$name$NL"
  [ "$concl" = cancelled ] && EV_LINES="${EV_LINES}NOTE run $RUN_ID was cancelled: a newer run in its concurrency group, a push with cancel-in-progress, or a manual cancel$NL"
  return 0
}

poll_runs() {
  local q id st concl ev created attempt n=0 pending=0 rows="" sig ok=0 bad=0 canc=0
  q="repos/$REPO/actions/workflows/$WORKFLOW/runs?branch=$REF&per_page=100&created=%3E%3D$SINCE"
  [ -n "$EVENT_FILTER" ] && q="$q&event=$EVENT_FILTER"
  api "$q" '.workflow_runs[] | [(.id | tostring), .status, (.conclusion // "-"), .event, .created_at, (.run_attempt | tostring)] | @tsv'
  case $? in
    0) ;;
    2) FATAL_MSG="workflow $WORKFLOW not found in $REPO"; return 2 ;;
    3) fatal_from_api "cannot list runs of $WORKFLOW"; return ;;
    *) return 1 ;;
  esac
  while IFS=$'\t' read -r id st concl ev created attempt; do
    [ -n "$id" ] || continue
    n=$((n + 1)); [ "$st" = completed ] || pending=$((pending + 1))
    rows="$rows$id$TAB$st$TAB$concl$TAB$ev$TAB$created$TAB$attempt$NL"
  done <<EOF
$API_OUT
EOF
  STATUS="workflow=$WORKFLOW ref=$REF since=$SINCE runs=$n pending=$pending"
  if [ $n -lt "$MIN" ] || [ $pending -gt 0 ]; then
    [ $n -lt "$MIN" ] && STATUS="$STATUS waiting-for-at-least=$MIN"
    SETTLE_SIG=""; return 0
  fi
  sig=$(printf '%s' "$rows" | cut -f1,3,6 | sort | tr '\n' ' ')
  settling "$sig" && return 0
  while IFS=$'\t' read -r id st concl ev created attempt; do
    [ -n "$id" ] || continue
    EV_LINES="${EV_LINES}RUN $id $concl event=$ev created=$created attempt=$attempt$NL"
    case $(classify "$concl") in ok) ok=$((ok + 1)) ;; cancelled) canc=$((canc + 1)) ;; *) bad=$((bad + 1)) ;; esac
  done <<EOF
$rows
EOF
  EV_LINES="${EV_LINES}EVENT runs repo=$REPO workflow=$WORKFLOW ref=$REF runs=$n ok=$ok failed=$bad cancelled=$canc$NL"
  [ $canc -gt 0 ] && EV_LINES="${EV_LINES}NOTE cancelled runs: a concurrency group keeps one pending run, so a newer dispatch cancels the older pending one; dispatch one at a time$NL"
  return 0
}

# ---- main loop ----------------------------------------------------------------------
fn=poll_$(printf '%s' "$MODE" | tr '-' '_')
echo "WATCH $(iso) name=$NAME mode=$MODE repo=$REPO interval=${INTERVAL}s pid=$$ state=$W"
BASELINE=$SINCE_NOW fails=0 polls=0 last_hb=0
while :; do
  EV_LINES="" EV_KEYS="" FATAL_MSG="" NEXT_SLEEP=$INTERVAL API_RATE=0
  ensure_repo && $fn
  rc=$?
  polls=$((polls + 1))
  case $rc in
    0) fails=0 ;;
    2) echo "ERROR $(iso) name=$NAME $FATAL_MSG"; log_err "$FATAL_MSG"; exit 2 ;;
    *)
      fails=$((fails + 1))
      [ -n "$API_ERR" ] || API_ERR="poll failed without a gh error (rc=$rc)"
      log_err "poll failed ($fails/$MAX_FAIL): $API_ERR"
      if [ $fails -ge "$MAX_FAIL" ]; then
        echo "GIVEUP $(iso) name=$NAME after $fails consecutive failed polls: $API_ERR"
        exit 3
      fi
      NEXT_SLEEP=$((30 * (1 << (fails - 1))))
      [ $NEXT_SLEEP -gt 600 ] && NEXT_SLEEP=600
      [ $API_RATE = 1 ] && [ $NEXT_SLEEP -lt 300 ] && NEXT_SLEEP=300
      ;;
  esac
  if [ $rc = 0 ] && [ $BASELINE = 1 ]; then
    printf '%s' "$EV_KEYS" >> "$SEEN"
    echo "BASELINE $(iso) name=$NAME marked $(printf '%s' "$EV_KEYS" | grep -c .) existing matches as handled"
    BASELINE=0; EV_LINES=""
  fi
  if [ $rc = 0 ] && [ -n "$EV_LINES" ]; then
    printf '%s' "$EV_KEYS" >> "$SEEN"
    printf '%s' "$EV_LINES"
    printf '%s' "$EV_LINES" | grep '^EVENT' | while IFS= read -r l; do
      printf '%s %s %s\n' "$(iso)" "$NAME" "$l"
    done >> "$STATE_ROOT/events.log"
    echo "DONE $(iso) name=$NAME"
    echo "$(iso) polls=$polls event fired" > "$W/status"
    exit 0
  fi
  t=$(now)
  echo "$(iso) polls=$polls fails=$fails $STATUS" > "$W/status"
  if [ $((t - last_hb)) -ge "$HEARTBEAT" ]; then
    echo "HEARTBEAT $(iso) name=$NAME polls=$polls fails=$fails $STATUS"
    last_hb=$t
  fi
  if [ "$TIMEOUT" -gt 0 ]; then
    left=$((TIMEOUT - (t - START)))
    if [ $left -le 0 ]; then
      echo "TIMEOUT $(iso) name=$NAME no event after ${TIMEOUT}s; last status: $STATUS"
      exit 4
    fi
    [ "$NEXT_SLEEP" -gt $left ] && NEXT_SLEEP=$left
  fi
  nap "$NEXT_SLEEP"
done

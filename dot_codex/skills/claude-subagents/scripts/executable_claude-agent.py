#!/usr/bin/env python3
"""Run and supervise a headless Claude worker (Python 3.9+, Linux/macOS)."""

import argparse
import fcntl
import json
import math
import os
from pathlib import Path
import shlex
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import uuid


# Only the child environment changes; never edit shell or credential files.
SUBSCRIPTION_ENV_OVERRIDES = (
    "ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_BASE_URL",
    "ANTHROPIC_CUSTOM_HEADERS", "ANTHROPIC_PROFILE",
    "CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX", "CLAUDE_CODE_USE_FOUNDRY",
    "CLAUDE_CODE_BARE", "CLAUDE_CODE_SIMPLE",
)
SUBSCRIPTION_SETTINGS = '{"forceLoginMethod":"claudeai"}'


def subscription_environment():
    environment = os.environ.copy()
    for name in SUBSCRIPTION_ENV_OVERRIDES:
        environment.pop(name, None)
    return environment


def check_subscription(binary, environment, workspace):
    check = subprocess.run(
        [binary, "--safe-mode", "--settings", SUBSCRIPTION_SETTINGS,
         "auth", "status", "--json"],
        env=environment, cwd=workspace, text=True, capture_output=True, timeout=15)
    try:
        auth = json.loads(check.stdout)
    except json.JSONDecodeError:
        raise ValueError("could not verify Claude subscription login with claude auth status") from None
    if (check.returncode != 0 or not isinstance(auth, dict)
            or auth.get("loggedIn") is not True
            or auth.get("authMethod") != "claude.ai"
            or auth.get("apiProvider") != "firstParty"
            or not auth.get("subscriptionType")):
        raise ValueError("Claude subscription login could not be confirmed; run "
                         "env -u ANTHROPIC_API_KEY -u ANTHROPIC_AUTH_TOKEN claude auth login "
                         "with your subscribed account. No API billing fallback was attempted.")
    # Retain only non-identifying status, never credentials or account details.
    return {key: auth[key] for key in ("authMethod", "apiProvider", "subscriptionType")}


def positive_seconds(value):
    value = float(value)
    if not math.isfinite(value) or value <= 0:
        raise argparse.ArgumentTypeError("must be a finite number greater than zero")
    return value


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("prompt", nargs="*", help="prompt text, or - for stdin")
    parser.add_argument("--prompt-file", type=Path)
    parser.add_argument("--context-file", type=Path, action="append", default=[])
    parser.add_argument("--cd", type=Path, help="workspace (default: current directory)")
    parser.add_argument("--mode", choices=["read", "write"])
    parser.add_argument("--model", help="omit to retain Claude's default")
    parser.add_argument("--effort", choices=["low", "medium", "high", "xhigh", "max"])
    parser.add_argument("--allow-command", action="append", help="pre-approve a Bash pattern in write mode; existing Claude grants still apply")
    parser.add_argument("--worktree", action="store_true", help="create a detached worktree from clean committed HEAD; keep it after exit")
    parser.add_argument("--resume", type=Path, help="previous run directory; restores workspace and invocation settings")
    parser.add_argument("--schema", type=Path, help="JSON Schema file for structured output")
    parser.add_argument("--timeout", type=positive_seconds, default=1800)
    parser.add_argument("--out", type=Path, help="new run directory (must not already exist)")
    parser.add_argument("--dry-run", action="store_true", help="show command and settings without running Claude or creating files")
    args = parser.parse_args()
    if args.resume and any([args.cd, args.mode, args.model, args.effort,
                            args.allow_command, args.worktree, args.schema]):
        parser.error("--resume restores settings; do not combine it with workspace/model/tool/schema overrides")
    if not args.resume and args.allow_command and args.mode != "write":
        parser.error("--allow-command requires --mode write")
    if args.worktree and args.mode != "write":
        parser.error("--worktree requires --mode write")
    return args


def git(workspace, *args):
    return subprocess.check_output(["git", "-C", str(workspace), *args],
                                   stderr=subprocess.PIPE, text=True).strip()


def write_record(directory, record):
    temporary = directory / "run.json.tmp"
    temporary.write_text(json.dumps(record, indent=2) + "\n")
    temporary.replace(directory / "run.json")


def stop_group(process, sig):
    """Signal the group even if its leader has already exited."""
    try:
        os.killpg(process.pid, sig)
    except ProcessLookupError:
        return
    deadline = time.monotonic() + 3
    while time.monotonic() < deadline:
        process.poll()  # reap the leader while waiting for the rest of the group
        try:
            os.killpg(process.pid, 0)
        except ProcessLookupError:
            return
        time.sleep(0.05)
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    process.wait()


def read_result(path):
    result = None
    malformed = False
    with path.open() as events:
        for line in events:
            if not line.strip():
                continue
            try:
                event = json.loads(line)
                if not isinstance(event, dict):
                    malformed = True
                elif event.get("type") == "result":
                    result = event
            except json.JSONDecodeError:
                malformed = True
    return result, malformed


def main():
    args = parse_args()
    parts = []
    if args.prompt_file:
        parts.append(args.prompt_file.read_text())
    if args.prompt == ["-"]:
        parts.append(sys.stdin.read())
    elif args.prompt:
        parts.append(" ".join(args.prompt))
    if not any(part.strip() for part in parts):
        raise ValueError("provide a prompt, --prompt-file, or - for stdin")
    for path in args.context_file:
        parts.append("\n<context file=" + json.dumps(str(path.resolve())) + ">\n"
                     + path.read_text() + "\n</context>")
    prompt = "\n\n".join(parts) + "\n"
    if len(prompt.encode()) > 10_000_000:
        raise ValueError("prompt exceeds Claude's stdin limit; reference large files instead")

    session = str(uuid.uuid4())
    session_root = None
    if args.resume:
        previous = json.loads((args.resume / "run.json").read_text())
        if previous.get("status") in ("starting", "running"):
            raise ValueError("previous run has not stopped; inspect its process before resuming")
        session = str(uuid.UUID(previous["session_id"]))
        session_root = Path(previous["session_root"])
        config = previous["config"]
    else:
        config = dict(workspace=str((args.cd or Path.cwd()).resolve()),
                      mode=args.mode or "read", model=args.model, effort=args.effort,
                      allow_commands=args.allow_command or [], schema=None)
        if args.schema:
            schema = json.loads(args.schema.read_text())
            if not isinstance(schema, (dict, bool)):
                raise ValueError("schema must be a JSON object or boolean")
            config["schema"] = schema
    workspace = Path(config["workspace"])
    if not workspace.is_dir():
        raise ValueError("workspace does not exist: " + str(workspace))
    if args.worktree:
        git(workspace, "rev-parse", "--verify", "HEAD")
        if git(workspace, "status", "--porcelain"):
            raise ValueError("--worktree starts from committed HEAD; source tree must be clean")

    binary = shutil.which("claude")
    if not binary:
        raise ValueError("claude CLI not found on PATH; install Claude Code and run claude auth login")
    environment = subscription_environment()
    help_text = subprocess.check_output([binary, "--help"], env=environment, text=True, timeout=15)
    for flag in ["--safe-mode", "--permission-prompts", "--tools", "--strict-mcp-config"]:
        if flag not in help_text:
            raise ValueError("Claude CLI is missing " + flag + "; update Claude Code")
    version = subprocess.check_output([binary, "--version"], env=environment, text=True, timeout=15).strip()
    auth = check_subscription(binary, environment, workspace)

    selected_tools = ["Read", "Glob", "Grep"]
    if config["mode"] == "write":
        selected_tools += ["Edit", "Write"]
    allowed = list(selected_tools)
    if config["allow_commands"]:
        selected_tools.append("Bash")
        allowed += ["Bash(" + pattern + ")" for pattern in config["allow_commands"]]
    command = [binary, "-p", "--output-format", "stream-json", "--verbose",
               "--settings", SUBSCRIPTION_SETTINGS,
               "--safe-mode", "--strict-mcp-config", "--mcp-config", '{"mcpServers":{}}',
               "--no-chrome", "--disable-slash-commands", "--disallowedTools", "mcp__*",
               "--permission-mode", "dontAsk", "--permission-prompts", "none",
               "--tools", ",".join(selected_tools), "--allowedTools", *allowed,
               "--resume" if args.resume else "--session-id", session]
    for key in ("model", "effort"):
        if config[key]:
            command += ["--" + key, config[key]]
    if config["schema"] is not None:
        command += ["--json-schema", json.dumps(config["schema"])]

    if args.dry_run:
        print(json.dumps(dict(workspace=str(workspace), create_worktree=args.worktree,
                              command=command, config=config, authentication=auth), indent=2))
        return 0

    # Keep prompts and transcripts private, independent of the caller's umask.
    os.umask(0o077)
    if args.out:
        directory = args.out.resolve()
        directory.mkdir(parents=True, exist_ok=False)
    else:
        directory = Path(tempfile.mkdtemp(prefix="claude-agent-"))
    print("run dir: " + str(directory), flush=True)
    session_root = session_root or directory
    # All turns descended from this run share an advisory lock.
    with (session_root / "session.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise ValueError("another worker is already using this Claude session")
        if args.worktree:
            target = directory / "worktree"
            git(workspace, "worktree", "add", "--detach", str(target), "HEAD")
            workspace = target
            config["workspace"] = str(workspace)
        record = dict(session_id=session, session_root=str(session_root), config=config,
                      authentication=auth,
                      command=command, cli_version=version, status="starting",
                      runner_pid=os.getpid(), claude_pid=None)
        write_record(directory, record)
        (directory / "prompt.md").write_text(prompt)
        interrupted = []

        def on_signal(sig, _frame):
            interrupted.append(sig)

        old_handlers = {sig: signal.signal(sig, on_signal)
                        for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP)}
        process = None
        started = time.monotonic()
        status = "failed"
        rc = 1
        try:
            with (directory / "prompt.md").open("rb") as stdin, \
                    (directory / "events.jsonl").open("wb") as stdout, \
                    (directory / "stderr.log").open("wb") as stderr:
                process = subprocess.Popen(command, cwd=workspace, stdin=stdin,
                                           stdout=stdout, stderr=stderr, env=environment,
                                           start_new_session=True)
                record.update(status="running", claude_pid=process.pid)
                write_record(directory, record)
                while process.poll() is None:
                    if interrupted:
                        status, rc = "interrupted", 128 + interrupted[0]
                        stop_group(process, interrupted[0])
                        break
                    if time.monotonic() - started >= args.timeout:
                        status, rc = "timeout", 124
                        stop_group(process, signal.SIGTERM)
                        break
                    time.sleep(0.1)
                else:
                    rc = process.returncode
                    if rc < 0:
                        rc = 128 - rc
                record["process_exit_code"] = process.wait()
            result, malformed = read_result(directory / "events.jsonl")
            success = (result is not None and result.get("subtype") == "success"
                       and result.get("is_error") is False and not malformed)
            if status not in ("timeout", "interrupted"):
                if rc == 0 and success:
                    status = "blocked" if result.get("permission_denials") else "ok"
                else:
                    status = "failed"
                rc = 0 if status == "ok" else (rc or 1)
            if result:
                record["result"] = result
                if "structured_output" in result:
                    final = json.dumps(result["structured_output"], indent=2)
                else:
                    final = result.get("result") or json.dumps(result.get("errors", []))
            else:
                final = "(no final result from Claude; inspect events.jsonl and stderr.log)"
            (directory / "last-message.txt").write_text(final + "\n")
            print(final)
        except BaseException as error:
            if process is not None:
                stop_group(process, signal.SIGTERM)
            record["error"] = str(error)
            raise
        finally:
            record.update(status=status, exit_code=rc,
                          duration_seconds=round(time.monotonic() - started, 2))
            write_record(directory, record)
            for sig, handler in old_handlers.items():
                signal.signal(sig, handler)
            print("\n--- claude-agent ---")
            print("status: {} (exit {})".format(status, rc))
            print("session: " + session)
            print("workspace: " + str(workspace))
            print("run dir: " + str(directory))
            print("follow up: --resume " + shlex.quote(str(directory)))
        return rc


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print("claude-agent: " + str(error), file=sys.stderr)
        sys.exit(2)

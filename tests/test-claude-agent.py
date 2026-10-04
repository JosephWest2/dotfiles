#!/usr/bin/env python3
"""Offline behavior tests; a fake CLI never contacts a model or reads credentials."""

import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest


RUNNER = Path(__file__).resolve().parents[1] / "dot_codex/skills/claude-subagents/scripts/executable_claude-agent.py"
FAKE = r'''#!/usr/bin/env python3
import json, os, signal, subprocess, sys, time
from pathlib import Path
if "--help" in sys.argv:
    print("--safe-mode --permission-prompts --tools --strict-mcp-config")
    sys.exit(0)
if "--version" in sys.argv:
    print("fake-claude")
    sys.exit(0)
if "auth" in sys.argv and "status" in sys.argv:
    print(json.dumps({"loggedIn": True, "authMethod": os.environ.get("FAKE_AUTH", "claude.ai"),
                      "apiProvider": "firstParty", "subscriptionType": "pro"}))
    sys.exit(0)
args = sys.argv[1:]
prompt = sys.stdin.read()
kind = os.environ.get("FAKE_KIND", "success")
session_flag = "--resume" if "--resume" in args else "--session-id"
session = args[args.index(session_flag) + 1]
print(json.dumps({"type": "system", "session_id": session}), flush=True)
if kind == "wait":
    child = subprocess.Popen([sys.executable, "-c", "import signal,time; signal.signal(signal.SIGTERM, signal.SIG_IGN); time.sleep(60)"])
    Path("child.pid").write_text(str(child.pid))
    time.sleep(60)
if kind == "missing":
    sys.exit(0)
if kind == "malformed":
    print("broken JSON")
result = {"type": "result", "subtype": "success", "is_error": False,
          "session_id": session, "result": json.dumps({"args": args, "prompt": prompt, "cwd": os.getcwd(),
              "api_key_present": "ANTHROPIC_API_KEY" in os.environ,
              "auth_token_present": "ANTHROPIC_AUTH_TOKEN" in os.environ,
              "base_url_present": "ANTHROPIC_BASE_URL" in os.environ}),
          "permission_denials": []}
if kind == "error":
    result.update(subtype="error_during_execution", is_error=True, errors=["fake failure"])
if kind == "api_error":
    # Observed from real Claude 2.1.289: subtype alone does not imply success.
    result.update(is_error=True, result="Credit balance is too low", terminal_reason="api_error")
if kind == "denied":
    result["permission_denials"] = [{"tool_name": "Write"}]
if "--json-schema" in args:
    result["structured_output"] = {"answer": "structured"}
print(json.dumps(result), flush=True)
sys.exit(7 if kind == "exit" else 0)
'''


class RunnerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="test-claude-agent-")
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        fake = self.bin / "claude"
        fake.write_text(FAKE)
        fake.chmod(0o755)
        self.workspace = self.root / "workspace with spaces"
        self.workspace.mkdir()
        self.env = dict(os.environ, PATH=str(self.bin) + os.pathsep + os.environ["PATH"])
        self.count = 0

    def tearDown(self):
        self.temp.cleanup()

    def run_worker(self, *args, kind="success", stdin=None):
        self.count += 1
        out = self.root / ("run-" + str(self.count))
        result = subprocess.run([sys.executable, str(RUNNER), "--out", str(out), *args],
                                cwd=self.workspace, env=dict(self.env, FAKE_KIND=kind),
                                input=stdin, text=True, capture_output=True, timeout=15)
        return result, out

    def record(self, out):
        return json.loads((out / "run.json").read_text())

    def test_prompt_quoting_and_read_tools(self):
        brief = self.root / "brief.md"
        brief.write_text('A multiline prompt\nwith `ticks` and $(do-not-run)\n')
        context = self.root / "context.md"
        context.write_text("repository rules")
        result, out = self.run_worker("--prompt-file", str(brief), "--context-file", str(context))
        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads((out / "last-message.txt").read_text())
        self.assertIn(brief.read_text(), report["prompt"])
        self.assertIn(context.read_text(), report["prompt"])
        self.assertEqual(report["args"][report["args"].index("--tools") + 1], "Read,Glob,Grep")
        self.assertIn("--safe-mode", report["args"])
        self.assertNotIn("--bare", report["args"])
        self.assertEqual(out.stat().st_mode & 0o777, 0o700)
        self.assertEqual((out / "prompt.md").stat().st_mode & 0o777, 0o600)

    def test_stdin_and_structured_result(self):
        schema = self.root / "schema.json"
        schema.write_text('{"type":"object"}')
        result, out = self.run_worker("--schema", str(schema), "-", stdin="hello stdin")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads((out / "last-message.txt").read_text()), {"answer": "structured"})

    def test_subscription_removes_overrides_on_launch_and_resume(self):
        self.env.update(ANTHROPIC_API_KEY="test-api-key", ANTHROPIC_AUTH_TOKEN="test-token",
                        ANTHROPIC_BASE_URL="https://example.invalid")
        result, first = self.run_worker("hello")
        self.assertEqual(result.returncode, 0, result.stderr)
        result, resumed = self.run_worker("--resume", str(first), "follow-up")
        self.assertEqual(result.returncode, 0, result.stderr)
        for out in [first, resumed]:
            report = json.loads((out / "last-message.txt").read_text())
            self.assertFalse(report["api_key_present"])
            self.assertFalse(report["auth_token_present"])
            self.assertFalse(report["base_url_present"])
            self.assertEqual(self.record(out)["authentication"]["authMethod"], "claude.ai")
        self.assertEqual(self.env["ANTHROPIC_API_KEY"], "test-api-key")

    def test_refuses_api_authentication_before_starting_worker(self):
        self.env["FAKE_AUTH"] = "api_key"
        result, out = self.run_worker("hello")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("No API billing fallback", result.stderr)
        self.assertFalse(out.exists())

    def test_resume_preserves_workspace_and_permissions(self):
        result, first = self.run_worker("--mode", "write", "--allow-command", "python3 -m unittest",
                                        "--model", "sonnet", "--effort", "low", "first")
        self.assertEqual(result.returncode, 0, result.stderr)
        result, second = self.run_worker("--resume", str(first), "follow-up")
        self.assertEqual(result.returncode, 0, result.stderr)
        a, b = self.record(first), self.record(second)
        self.assertEqual(a["session_id"], b["session_id"])
        self.assertEqual(a["config"], b["config"])
        self.assertIn("--resume", b["command"])
        self.assertNotIn("--session-id", b["command"])
        result, _ = self.run_worker("--resume", str(first), "--mode", "read", "override")
        self.assertNotEqual(result.returncode, 0)

    def test_failure_and_incomplete_results(self):
        for kind in ["error", "api_error", "missing", "malformed", "exit", "denied"]:
            with self.subTest(kind=kind):
                result, out = self.run_worker("hello", kind=kind)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.record(out)["status"], "blocked" if kind == "denied" else "failed")

    def test_dry_run_and_invalid_options_do_not_create_output(self):
        result, out = self.run_worker("--dry-run", "hello")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(out.exists())
        for flags in [("--timeout", "nan"), ("--timeout", "0"), ("--mode",),
                      ("--allow-command", "pwd"), ("--worktree",)]:
            with self.subTest(flags=flags):
                result, out = self.run_worker(*flags, "hello")
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(out.exists())

    def test_worktree_and_resume(self):
        def git(*args):
            return subprocess.run(["git", "-C", str(self.workspace), *args],
                                  text=True, capture_output=True, check=True)
        git("init")
        (self.workspace / "tracked.txt").write_text("initial")
        git("add", "tracked.txt")
        git("-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "-m", "initial")
        result, out = self.run_worker("--mode", "write", "--worktree", "hello")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((out / "worktree/tracked.txt").read_text(), "initial")
        result, resumed = self.run_worker("--resume", str(out), "follow-up")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.record(resumed)["config"]["workspace"], str(out / "worktree"))
        (self.workspace / "tracked.txt").write_text("dirty")
        result, _ = self.run_worker("--mode", "write", "--worktree", "hello")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("must be clean", result.stderr)

    def test_timeout_kills_process_group(self):
        result, out = self.run_worker("--timeout", "0.5", "hello", kind="wait")
        self.assertEqual(result.returncode, 124, result.stderr)
        self.assertEqual(self.record(out)["status"], "timeout")
        child = int((self.workspace / "child.pid").read_text())
        # A terminated orphan may briefly remain a zombie until PID 1 reaps it.
        state = subprocess.run(["ps", "-o", "stat=", "-p", str(child)], capture_output=True, text=True)
        self.assertTrue(not state.stdout.strip() or state.stdout.strip().startswith("Z"), state.stdout)

    def test_interrupt_and_session_lock(self):
        result, first = self.run_worker("initial")
        self.assertEqual(result.returncode, 0, result.stderr)
        out = self.root / "long-run"
        process = subprocess.Popen([sys.executable, str(RUNNER), "--resume", str(first),
                                    "--out", str(out), "continue"], cwd=self.workspace,
                                   env=dict(self.env, FAKE_KIND="wait"),
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            deadline = time.monotonic() + 5
            while not (self.workspace / "child.pid").exists() and time.monotonic() < deadline:
                time.sleep(0.05)
            self.assertTrue((self.workspace / "child.pid").exists())
            result, _ = self.run_worker("--resume", str(first), "concurrent")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("already using", result.stderr)
            process.send_signal(signal.SIGINT)
            process.communicate(timeout=10)
            self.assertEqual(process.returncode, 130)
            self.assertEqual(self.record(out)["status"], "interrupted")
        finally:
            if process.poll() is None:
                process.terminate()
                process.communicate(timeout=10)


if __name__ == "__main__":
    unittest.main()

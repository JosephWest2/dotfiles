#!/usr/bin/env python3
"""Offline lifecycle tests: fake cloud CLI, local Git origin, no model calls."""

import importlib.util
from contextlib import redirect_stdout
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock


sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / "dot_codex/skills/cloud-subagents/scripts/executable_cloud-agent.py"
THREAD = "11111111-1111-4111-8111-111111111111"
FAKE = r'''#!/usr/bin/env python3
import json, os, re, sys
from pathlib import Path
root = Path(os.environ["FAKE_CLOUD_DIR"])
config = json.loads((root / "config.json").read_text())
args = sys.argv[1:]
with (root / "calls.jsonl").open("a") as out:
    out.write(json.dumps({"args": args, "api_key": "OPENAI_API_KEY" in os.environ,
                          "codex_key": "CODEX_API_KEY" in os.environ,
                          "endpoint": "OPENAI_BASE_URL" in os.environ}) + "\n")
if args == ["queue", "--help"]:
    print("--thread --message --remote")
elif args == ["login", "status"]:
    print("Logged in using " + config.get("auth", "ChatGPT"), file=sys.stderr)
elif args[:2] == ["cloud", "exec"]:
    prompt = sys.stdin.read()
    (root / "prompt.txt").write_text(prompt)
    if config.get("submit") == "garbage":
        print("unexpected output")
    else:
        print("https://chatgpt.com/codex/tasks/task_fake")
    if config.get("submit") == "failed":
        print("transport failed after sending", file=sys.stderr)
        sys.exit(7)
elif args[:2] == ["cloud", "status"]:
    path = root / "poll-count"
    count = int(path.read_text()) if path.exists() else 0
    path.write_text(str(count + 1))
    stages = config.get("stages", ["READY"])
    stage = stages[min(count, len(stages) - 1)]
    if stage == "transport":
        print("network unavailable", file=sys.stderr)
        sys.exit(7)
    if stage == "unknown":
        print("[UNKNOWN] fake worker")
        sys.exit(1)
    print("[" + stage + "] fake worker")
    print("test environment • now")
    print("+3/-0 • 1 file")
    sys.exit(0 if stage == "READY" else 1)
elif args[:2] == ["cloud", "diff"]:
    if config.get("diff_error"):
        print("no attempts available", file=sys.stderr)
        sys.exit(1)
    prompt = (root / "prompt.txt").read_text()
    name = re.search(r"\.cloud-agent-reports/[A-Za-z0-9-]+\.md", prompt).group(0)
    if config.get("missing_report"):
        print("diff --git a/app.txt b/app.txt\n--- a/app.txt\n+++ b/app.txt\n@@ -1 +1 @@\n-old\n+new")
    else:
        print("diff --git a/" + name + " b/" + name)
        print("new file mode 100644\nindex 0000000..1234567\n--- /dev/null\n+++ b/" + name)
        print("@@ -0,0 +1,3 @@\n+Outcome: completed\n+Checks: fake test passed\n+Questions: none")
elif args[:1] == ["queue"]:
    with (root / "notifications.jsonl").open("a") as out:
        out.write(json.dumps(args) + "\n")
    if config.get("notify_fail"):
        print("parent daemon unavailable", file=sys.stderr)
        sys.exit(1)
    print("Queued message fake for thread " + args[args.index("--thread") + 1])
else:
    print("unexpected command: " + repr(args), file=sys.stderr)
    sys.exit(9)
'''


def runner_module():
    spec = importlib.util.spec_from_file_location("cloud_agent", RUNNER)
    runner = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(runner)
    return runner


class CloudRunnerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="test-cloud-agent-")
        self.root = Path(self.temp.name)
        self.workspace = self.root / "project with spaces"
        self.workspace.mkdir()
        self.origin = self.root / "origin.git"
        self.git("-c", "init.templateDir=", "init", "--bare", str(self.origin))
        self.git("-c", "init.templateDir=", "init", "-b", "main")
        (self.workspace / "README.md").write_text("test source\n")
        self.git("add", "README.md")
        self.git("-c", "user.name=Test", "-c", "user.email=test@example.invalid",
                 "-c", "commit.gpgsign=false", "commit", "-m", "Initial source")
        self.git("remote", "add", "origin", str(self.origin))
        self.git("push", "origin", "main")
        self.bin = self.root / "bin"
        self.bin.mkdir()
        fake = self.bin / "codex"
        fake.write_text(FAKE)
        fake.chmod(0o755)
        self.config = {}
        self.configure()
        self.env = dict(os.environ, PATH=str(self.bin) + os.pathsep + os.environ["PATH"],
                        FAKE_CLOUD_DIR=str(self.root), CODEX_THREAD_ID=THREAD,
                        OPENAI_API_KEY="test-secret", CODEX_API_KEY="another-test-secret",
                        OPENAI_BASE_URL="https://example.invalid")
        self.run_dir = self.root / "saved run"
        self.prompt = self.root / "task.md"
        self.prompt.write_text("Implement the bounded task.\nLiteral `ticks` and $(do-not-execute).\n")

    def tearDown(self):
        # Detached watchers in the test suite are explicitly stopped and observed.
        if (self.run_dir / "run.json").exists():
            (self.run_dir / "stop-watcher").touch()
            deadline = time.monotonic() + 5
            while self.record().get("watcher_pid") and time.monotonic() < deadline:
                time.sleep(0.02)
        self.temp.cleanup()

    def git(self, *args):
        return subprocess.run(["git", *args], cwd=self.workspace, text=True,
                              capture_output=True, check=True).stdout.strip()

    def configure(self, **changes):
        self.config.update(changes)
        (self.root / "config.json").write_text(json.dumps(self.config))

    def invoke(self, *args, **kwargs):
        return subprocess.run([sys.executable, str(RUNNER), *map(str, args)],
                              cwd=self.root, env=self.env, text=True,
                              capture_output=True, timeout=10, **kwargs)

    def start(self, *extra):
        return self.invoke("start", "--cd", self.workspace, "--env", "env_test",
                           "--prompt-file", self.prompt, "--out", self.run_dir, *extra)

    def record(self):
        return json.loads((self.run_dir / "run.json").read_text())

    def calls(self, name="calls.jsonl"):
        path = self.root / name
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def wait(self, *extra):
        return self.invoke("wait", self.run_dir, "--interval", "0.01", "--timeout", "5", *extra)

    def test_completion_report_parent_queue_and_deduplication(self):
        self.configure(stages=["PENDING", "READY"])
        result = self.start()
        self.assertEqual(result.returncode, 0, result.stderr)
        result = self.wait()
        self.assertEqual(result.returncode, 0, result.stderr)
        record = self.record()
        self.assertEqual(record["cloud_status"], "ready")
        self.assertEqual(record["notification"]["status"], "sent")
        self.assertEqual(record["source_sha"], self.git("rev-parse", "HEAD"))
        self.assertEqual(record["watcher"], "finished")
        self.assertIsNone(record["watcher_pid"])
        self.assertTrue((self.run_dir / "changes.patch").exists())
        self.assertIn("Outcome: completed", (self.run_dir / "report.md").read_text())
        notices = self.calls("notifications.jsonl")
        self.assertEqual(len(notices), 1)
        self.assertIn(THREAD, notices[0])
        message = notices[0][notices[0].index("--message") + 1]
        self.assertIn(str(self.run_dir), message)
        self.assertNotIn("Outcome: completed", message)
        self.assertEqual(self.wait().returncode, 0)
        self.assertEqual(len(self.calls("notifications.jsonl")), 1)
        self.assertEqual(self.run_dir.stat().st_mode & 0o777, 0o700)
        self.assertEqual((self.run_dir / "prompt.md").stat().st_mode & 0o777, 0o600)
        prompt = (self.root / "prompt.txt").read_text()
        self.assertIn(self.prompt.read_text(), prompt)
        for call in self.calls():
            self.assertFalse(call["api_key"] or call["codex_key"] or call["endpoint"])
            self.assertNotIn(self.prompt.read_text(), call["args"])

    def test_applied_exit_one_is_terminal_not_transport_failure(self):
        self.configure(stages=["APPLIED"])
        self.assertEqual(self.start().returncode, 0)
        self.assertEqual(self.wait().returncode, 0)
        self.assertEqual(self.record()["cloud_status"], "applied")

    def test_cloud_error_is_not_success(self):
        self.configure(stages=["ERROR"])
        self.assertEqual(self.start().returncode, 0)
        result = self.wait()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(self.record()["cloud_status"], "error")
        self.assertEqual(len(self.calls("notifications.jsonl")), 1)

    def test_poll_errors_retry_then_notify_unknown_outcome(self):
        self.configure(stages=["transport"])
        self.assertEqual(self.start().returncode, 0)
        result = self.wait()
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertEqual((self.root / "poll-count").read_text(), "3")
        self.assertEqual(self.record()["watcher"], "poll_failed")
        self.assertIsNone(self.record()["cloud_status"])
        self.assertIn("outcome unknown", self.calls("notifications.jsonl")[0][-1])
        self.configure(stages=["READY"])
        self.assertEqual(self.wait().returncode, 0)
        self.assertEqual(len(self.calls("notifications.jsonl")), 2)

    def test_pending_status_and_temporary_transport_failure(self):
        self.configure(stages=["PENDING", "transport", "READY"])
        self.assertEqual(self.start().returncode, 0)
        result = self.invoke("status", self.run_dir)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.record()["cloud_status"], "pending")
        self.assertEqual(self.wait().returncode, 0)
        self.assertEqual(self.record()["cloud_status"], "ready")

    def test_uncertain_submission_is_saved_and_not_retried(self):
        for mode in ("failed", "garbage"):
            with self.subTest(mode=mode):
                self.run_dir = self.root / mode
                self.configure(submit=mode)
                result = self.start()
                self.assertEqual(result.returncode, 2)
                self.assertEqual(self.record()["submission"], "uncertain")
                self.assertTrue((self.run_dir / "submit.stdout").exists())
                self.assertEqual(self.invoke("watch", self.run_dir).returncode, 2)
        submissions = [call for call in self.calls() if call["args"][:2] == ["cloud", "exec"]]
        self.assertEqual(len(submissions), 2)

    def test_submission_timeout_retains_partial_output_for_reconciliation(self):
        runner = runner_module()
        original_command = runner.command

        def timed_out(argv, *args, **kwargs):
            if argv[1:3] == ["cloud", "exec"]:
                raise subprocess.TimeoutExpired(argv, 120,
                    output=b"https://chatgpt.com/codex/tasks/task_fake\n", stderr=b"late response\n")
            return original_command(argv, *args, **kwargs)

        argv = [str(RUNNER), "start", "--cd", str(self.workspace), "--env", "env_test",
                "--prompt-file", str(self.prompt), "--out", str(self.run_dir)]
        with mock.patch.dict(os.environ, self.env), mock.patch.object(sys, "argv", argv):
            args = runner.parse_args()
            with mock.patch.object(runner, "command", side_effect=timed_out), redirect_stdout(io.StringIO()):
                with self.assertRaises(subprocess.TimeoutExpired):
                    runner.start(args)
        self.assertEqual(self.record()["submission"], "uncertain")
        self.assertIn("task_fake", (self.run_dir / "submit.stdout").read_text())
        self.assertEqual((self.run_dir / "submit.stderr").read_text(), "late response\n")

    def test_missing_report_and_failed_artifact_collection_are_explicit(self):
        self.configure(missing_report=True)
        self.assertEqual(self.start().returncode, 0)
        self.assertEqual(self.wait().returncode, 0)
        self.assertFalse(self.record()["report_available"])
        self.assertFalse((self.run_dir / "report.md").exists())
        self.configure(diff_error=True)
        result = self.wait()
        self.assertEqual(result.returncode, 2)
        self.assertEqual(self.record()["collection"], "failed")
        self.assertEqual(self.record()["cloud_status"], "ready")

    def test_notification_failure_requires_explicit_retry(self):
        self.configure(notify_fail=True)
        self.assertEqual(self.start().returncode, 0)
        self.assertEqual(self.wait().returncode, 3)
        self.assertEqual(self.record()["notification"]["status"], "failed")
        self.assertEqual(self.wait().returncode, 3)
        self.assertEqual(len(self.calls("notifications.jsonl")), 1)
        self.configure(notify_fail=False)
        result = self.invoke("notify", self.run_dir, "--retry")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(self.calls("notifications.jsonl")), 2)
        self.assertEqual(self.record()["notification"]["status"], "sent")

    def test_current_branch_local_changes_require_explicit_remote_only(self):
        (self.workspace / "README.md").write_text("unpublished\n")
        result = self.start()
        self.assertEqual(result.returncode, 2)
        self.assertFalse(self.run_dir.exists())
        self.assertFalse(self.calls())
        self.assertEqual(self.start("--remote-only").returncode, 0)
        self.assertEqual((self.workspace / "README.md").read_text(), "unpublished\n")

    def test_local_environment_setting_context_and_no_notifications(self):
        self.git("config", "--local", "cloud-agent.environment", "env_local")
        context = self.root / "context.md"
        context.write_text("important decision")
        result = self.invoke("start", "--cd", self.workspace, "--prompt-file", self.prompt,
                             "--out", self.run_dir, "--no-notify", "--context-file", context)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.record()["environment"], "env_local")
        self.assertIn("important decision", (self.root / "prompt.txt").read_text())
        self.assertEqual(self.wait().returncode, 0)
        self.assertFalse(self.calls("notifications.jsonl"))
        self.assertEqual(self.invoke("watch", self.run_dir).returncode, 2)

    def test_api_login_is_rejected_before_submission(self):
        self.configure(auth="an API key")
        result = self.start()
        self.assertEqual(result.returncode, 2)
        self.assertIn("ChatGPT login required", result.stderr)
        self.assertFalse(self.run_dir.exists())
        self.assertFalse(any(call["args"][:2] == ["cloud", "exec"] for call in self.calls()))

    def test_detached_watcher_lock_stop_and_restart(self):
        self.configure(stages=["PENDING"])
        result = self.start("--watch", "--interval", "0.02", "--timeout", "5")
        self.assertEqual(result.returncode, 0, result.stderr)
        deadline = time.monotonic() + 5
        while self.record().get("watcher") != "running" and time.monotonic() < deadline:
            time.sleep(0.02)
        self.assertEqual(self.record()["watcher"], "running")
        self.assertEqual(self.invoke("watch", self.run_dir).returncode, 2)
        self.assertEqual(self.invoke("stop-watcher", self.run_dir).returncode, 0)
        deadline = time.monotonic() + 5
        while self.record().get("watcher_pid") and time.monotonic() < deadline:
            time.sleep(0.02)
        self.assertEqual(self.record()["watcher"], "stopped")
        self.assertFalse(self.calls("notifications.jsonl"))
        self.assertTrue((self.run_dir / "watcher.log").exists())
        self.configure(stages=["READY"])
        self.assertEqual(self.wait().returncode, 0)
        self.assertEqual(len(self.calls("notifications.jsonl")), 1)
        self.assertFalse(any(call["args"][:2] == ["cloud", "apply"] for call in self.calls()))

    def test_monitor_timeout_does_not_cancel_cloud_and_later_completion_notifies(self):
        self.configure(stages=["PENDING"])
        self.assertEqual(self.start().returncode, 0)
        result = self.wait("--timeout", "0.3")
        self.assertEqual(result.returncode, 124, result.stderr)
        self.assertEqual(self.record()["watcher"], "timed_out")
        self.assertEqual(self.record()["cloud_status"], "pending")
        self.assertEqual(len(self.calls("notifications.jsonl")), 1)
        self.configure(stages=["READY"])
        self.assertEqual(self.wait().returncode, 0)
        self.assertEqual(len(self.calls("notifications.jsonl")), 2)
        self.assertFalse(any("cancel" in call["args"] for call in self.calls()))

    def test_ambiguous_notification_does_not_auto_resend(self):
        self.assertEqual(self.start().returncode, 0)
        record = self.record()
        record["notification"] = {"status": "sending", "reason": "ready"}
        (self.run_dir / "run.json").write_text(json.dumps(record))
        self.assertEqual(self.wait().returncode, 3)
        self.assertFalse(self.calls("notifications.jsonl"))
        self.assertEqual(self.invoke("notify", self.run_dir, "--retry").returncode, 0)

    def test_queue_timeout_is_uncertain_and_not_automatically_retried(self):
        self.assertEqual(self.start().returncode, 0)
        runner = runner_module()
        with mock.patch.object(runner, "command", side_effect=subprocess.TimeoutExpired(["codex", "queue"], 30)) as call:
            with redirect_stdout(io.StringIO()):
                self.assertFalse(runner.notify(self.run_dir, "codex", "ready"))
                self.assertFalse(runner.notify(self.run_dir, "codex", "ready"))
            self.assertEqual(call.call_count, 1)
        self.assertEqual(self.record()["notification"]["status"], "uncertain")

    def test_invalid_poll_settings_rejected(self):
        for setting in ("nan", "inf", "0", "-1"):
            result = self.invoke("wait", self.run_dir, "--interval", setting)
            self.assertEqual(result.returncode, 2)


class ReportTests(unittest.TestCase):
    def test_extracts_real_git_patch_without_applying_it(self):
        runner = runner_module()
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            subprocess.run(["git", "-c", "init.templateDir=", "init", str(root)],
                           capture_output=True, check=True)
            path = ".cloud-agent-reports/test.md"
            (root / ".cloud-agent-reports").mkdir()
            expected = "Outcome: blocked\nQuestion: what is the desired behavior?"
            (root / path).write_text(expected)
            subprocess.run(["git", "-C", str(root), "add", "-N", path], check=True)
            diff = subprocess.check_output(["git", "-C", str(root), "diff"], text=True)
            self.assertEqual(runner.extract_report(diff, path), expected)
            self.assertIsNone(runner.extract_report(diff.replace("+1,2", "+1,9"), path))
            self.assertIsNone(runner.extract_report(diff.replace("--- /dev/null", "--- a/old.md"), path))
            self.assertIsNone(runner.extract_report(diff, "other.md"))


if __name__ == "__main__":
    unittest.main()

"""Behavioral checks for the explicit local-config migration helper."""

import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class LocalConfigsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.setup = self.root / "setup"
        shutil.copytree(Path(__file__).resolve().parents[1] / "setup", self.setup)
        for name, contents in {
            ".config/zsh/shared.zsh": "# shared\n",
            ".config/kitty/shared.conf": "font_size 12\n",
            ".config/kitty/default-theme.conf": "background #282c34\n",
        }.items():
            path = self.home / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(contents)

    def run_setup(self):
        return subprocess.run(
            ["python3", str(self.setup / "local-configs.py"), "--home", str(self.home)],
            capture_output=True, text=True,
        )

    def test_fresh_setup_and_repeat_preserve_local_edits(self):
        self.assertEqual(self.run_setup().returncode, 0)
        zsh = self.home / ".zshrc"
        zsh.write_text(zsh.read_text() + "# installer addition\n")
        theme = self.home / ".config/kitty/current-theme.conf"
        theme.write_text("background #123456\n")
        before = zsh.read_bytes()
        self.assertEqual(self.run_setup().returncode, 0)
        self.assertEqual(zsh.read_bytes(), before)
        self.assertEqual(theme.read_text(), "background #123456\n")
        self.assertFalse(list(self.home.rglob("*.before-shared-*")))

    def test_recognized_legacy_config_is_backed_up(self):
        old = "# former shared config\n"
        (self.home / ".zshrc").write_text(old)
        hashes = self.setup / "legacy-config-hashes.json"
        data = json.loads(hashes.read_text())
        data["zsh"] = [hashlib.sha256(old.encode()).hexdigest()]
        hashes.write_text(json.dumps(data))
        self.assertEqual(self.run_setup().returncode, 0)
        backups = list(self.home.glob(".zshrc.before-shared-*"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), old)
        self.assertIn("shared.zsh", (self.home / ".zshrc").read_text())

    def test_unknown_config_is_preserved(self):
        target = self.home / ".zshrc"
        target.write_text("# custom installer configuration\n")
        before = target.read_bytes()
        result = self.run_setup()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(target.read_bytes(), before)
        self.assertIn("Preserved customized config", result.stderr)

    def test_missing_shared_config_does_not_create_entry_point(self):
        (self.home / ".config/zsh/shared.zsh").unlink()
        self.assertEqual(self.run_setup().returncode, 1)
        self.assertFalse((self.home / ".zshrc").exists())


if __name__ == "__main__":
    unittest.main()

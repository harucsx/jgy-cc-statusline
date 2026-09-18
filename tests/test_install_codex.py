import importlib.util
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import tomllib
import unittest
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[1] / "install-codex.py"
SPEC = importlib.util.spec_from_file_location("install_codex", SCRIPT)
installer = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(installer)


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.config = self.root / "codex home" / "config.toml"

    def write(self, content):
        self.config.parent.mkdir(parents=True, exist_ok=True)
        self.config.write_bytes(content.encode("utf-8"))

    def run_cli(self, *args, **kwargs):
        return subprocess.run(
            [sys.executable, str(SCRIPT), "--config", str(self.config), *args],
            capture_output=True, text=True, **kwargs,
        )

    def assert_preset(self):
        data = tomllib.loads(self.config.read_text())
        for key, value in installer.PRESET.items():
            self.assertEqual(data["tui"][key], value)
        return data

    def test_new_install_and_repeat_are_idempotent(self):
        self.assertEqual(self.run_cli().returncode, 0)
        self.assert_preset()
        self.assertEqual(stat.S_IMODE(self.config.stat().st_mode), 0o600)
        timestamp = self.config.stat().st_mtime_ns
        self.assertIn("Already configured", self.run_cli().stdout)
        self.assertEqual(self.config.stat().st_mtime_ns, timestamp)
        self.assertEqual(list(self.config.parent.glob("config.toml.bak.*")), [])

    def test_preserves_other_settings_comments_and_exact_backup(self):
        original = '''# 설정 보존
model = "example-model"
[tui] # footer
notifications = false
status_line = [
  "model", # previous selection
  "current-dir",
]
status_line_use_colors = false
[tui.model_availability_nux]
example = 3
[mcp_servers.example]
command = "example"
args = ["--local"]
[projects."/tmp/my project"]
trust_level = "trusted"
'''
        self.write(original)
        self.config.chmod(0o640)
        result = self.run_cli("--apply")
        self.assertEqual(result.returncode, 0, result.stderr)
        data = self.assert_preset()
        before = tomllib.loads(original)
        before["tui"].update(installer.PRESET)
        self.assertEqual(data, before)
        self.assertIn('# 설정 보존\nmodel = "example-model"', self.config.read_text())
        self.assertIn('[tui] # footer\nnotifications = false\n', self.config.read_text())
        backups = list(self.config.parent.glob("config.toml.bak.*"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_bytes(), original.encode())
        self.assertEqual(stat.S_IMODE(backups[0].stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(self.config.stat().st_mode), 0o640)

    def test_toml_statement_boundaries(self):
        cases = [
            '["tui"] # quoted\n"status_line" = ["model"]\n',
            "['tui']\n'status_line_use_colors' = false",
            'model = "example"',
            '[tui]',
            '[tui]\r\nnotifications = false\r\n',
            '[tui.model_availability_nux]\nexample = 1\n',
            'instructions = """\n[tui]\nstatus_line = []\n"""\n',
            "[tui]\nnote = '''\n[not_a_table]\nstatus_line = []\n'''\n",
            '[tui]\nmatrix = [\n[1, 2],\n[3, 4],\n]\nstatus_line = []\n',
        ]
        for original in cases:
            with self.subTest(original=original):
                updated = installer.configure(original)
                expected = tomllib.loads(original)
                expected.setdefault("tui", {}).update(installer.PRESET)
                self.assertEqual(tomllib.loads(updated), expected)
                self.assertEqual(installer.configure(updated), updated)
                if "\r\n" in original:
                    self.assertNotIn("\n", updated.replace("\r\n", ""))

    def test_dry_run_and_show_do_not_write_or_expose_other_values(self):
        for action in ("--dry-run", "--show"):
            with self.subTest(action=action):
                result = self.run_cli(action)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertFalse(self.config.parent.exists())
        self.write('model = "private-value"\n[tui]\nnotifications = false\n')
        original = self.config.read_bytes()
        for action in ("--dry-run", "--show"):
            result = self.run_cli(action)
            self.assertNotIn("private-value", result.stdout + result.stderr)
            self.assertNotIn("notifications", result.stdout)
        self.assertEqual(self.config.read_bytes(), original)
        self.assertEqual(list(self.config.parent.iterdir()), [self.config])

    def test_invalid_or_unsupported_layout_fails_without_writing(self):
        for text in ('[tui\n', 'tui = false\n', 'tui = { status_line = [] }\n',
                     'tui.status_line = []\n', '[tui]\nstatus_line = []\nstatus_line = []\n'):
            with self.subTest(text=text):
                self.write(text)
                result = self.run_cli()
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.config.read_bytes(), text.encode())
                self.assertEqual(list(self.config.parent.iterdir()), [self.config])

    def test_codex_home_and_home_fallback(self):
        for custom in (True, False):
            with self.subTest(custom=custom):
                env = os.environ.copy()
                env["HOME"] = str(self.root / "user")
                env.pop("CODEX_HOME", None)
                expected = Path(env["HOME"]) / ".codex" / "config.toml"
                if custom:
                    env["CODEX_HOME"] = str(self.root / "custom home")
                    expected = Path(env["CODEX_HOME"]) / "config.toml"
                result = subprocess.run([sys.executable, str(SCRIPT)], env=env,
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(tomllib.loads(expected.read_text())["tui"], installer.PRESET)
                self.assertFalse((Path(env["HOME"]) / ".claude").exists())

    def test_symlink_is_preserved_and_target_backed_up(self):
        target = self.root / "shared.toml"
        target.write_text('model = "example"\n')
        self.config.parent.mkdir()
        self.config.symlink_to(target)
        result = self.run_cli()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.config.is_symlink())
        self.assert_preset()
        self.assertEqual(len(list(self.root.glob("shared.toml.bak.*"))), 1)

    def test_dangling_symlink_is_not_replaced(self):
        self.config.parent.mkdir()
        self.config.symlink_to(self.root / "missing.toml")
        self.assertNotEqual(self.run_cli().returncode, 0)
        self.assertTrue(self.config.is_symlink())
        self.assertFalse(self.config.exists())

    def test_write_failure_keeps_original_and_backup(self):
        self.write('model = "example"\n')
        original = self.config.read_bytes()
        with mock.patch.object(installer.os, "replace", side_effect=OSError("write failed")):
            with self.assertRaises(OSError):
                installer.save_config(self.config, original, b"new content")
        self.assertEqual(self.config.read_bytes(), original)
        self.assertEqual(len(list(self.config.parent.glob("config.toml.bak.*"))), 1)
        self.assertEqual(list(self.config.parent.glob(".codex-statusline-*")), [])

    def test_concurrent_edit_is_not_overwritten(self):
        self.write('model = "original"\n')
        original = self.config.read_bytes()
        self.write('model = "changed"\n')
        with self.assertRaisesRegex(ValueError, "changed during"):
            installer.save_config(self.config, original, b"new content")
        self.assertEqual(self.config.read_text(), 'model = "changed"\n')


if __name__ == "__main__":
    unittest.main()

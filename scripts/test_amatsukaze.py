"""Exercise the packaged launcher with small executable fixtures."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import unittest

PROJECT = Path(__file__).resolve().parents[1]
RUNNER = PROJECT / "pkgs/amatsukaze/run.py"
ROOT = Path("/private/tmp/jodtv-amatsukaze-tests")
if __name__ == "__main__" and len(sys.argv) == 3:
    RUNNER, ROOT = map(Path, sys.argv[1:])
    sys.argv[1:] = []


class AmatsukazeTests(unittest.TestCase):
    def setUp(self):
        # Exact owned fixture path, below 1 MiB; clean on success or failure.
        shutil.rmtree(ROOT, ignore_errors=True)
        self.addCleanup(shutil.rmtree, ROOT, ignore_errors=True)
        self.bundle = ROOT / "bundle"
        self.state = ROOT / "state with spaces"
        self.log = ROOT / "calls.jsonl"
        (self.bundle / "exe_files/lib").mkdir(parents=True)
        for directory in ("profile", "JL", "avs", "bat", "drcs"):
            (self.bundle / directory).mkdir()
            (self.bundle / directory / "sample.txt").write_text("original")
        (self.bundle / "exe_files/ch_sid.txt").write_text("channels")
        library = self.bundle / "exe_files/lib/libexample.so.1"
        library.write_text("library-v1")
        (library.parent / "libexample.so").symlink_to(library.name)
        for name in ("AmatsukazeServerCLI", "AmatsukazeCLI", "AmatsukazeAddTask", "AmatsukazeGenLogo"):
            program = self.bundle / "exe_files" / name
            program.write_text(f"#!{sys.executable}\n" + '''import json, os, signal, sys
from pathlib import Path
with open(os.environ["MOCK_LOG"], "a") as log:
    log.write(json.dumps({"name": Path(sys.argv[0]).name, "cwd": os.getcwd(), "args": sys.argv[1:], "update": os.environ.get("AMT_ENABLE_SELF_UPDATE")}) + "\\n")
if os.environ.get("MOCK_HOLD") and Path(sys.argv[0]).name == "AmatsukazeServerCLI":
    while True:
        signal.pause()
sys.exit(int(os.environ.get("MOCK_EXIT", 0)))
''')
            program.chmod(0o555)
        self.env = os.environ | {"MOCK_LOG": str(self.log), "PYTHONDONTWRITEBYTECODE": "1"}
        self.base = [sys.executable, str(RUNNER), "--bundle", str(self.bundle), "--state-dir", str(self.state)]

    def run_cli(self, *args, env=None):
        return subprocess.run([*self.base, *args], env=env or self.env, cwd=ROOT,
                              text=True, capture_output=True, timeout=10)

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def test_help_cli_and_arguments(self):
        result = self.run_cli("--help")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.state.exists())
        result = self.run_cli("cli", "-i", "relative.ts", "--output", "output with spaces.mp4", env=self.env | {"MOCK_EXIT": "23"})
        self.assertEqual(result.returncode, 23, result.stderr)
        self.assertFalse(self.state.exists())
        call = self.calls()[-1]
        self.assertEqual(call["cwd"], str(ROOT))
        self.assertEqual(call["args"], ["-i", "relative.ts", "--output", "output with spaces.mp4"])
        self.assertEqual(call["update"], "0")

    def test_initialization_and_upgrade_preserve_existing_data(self):
        result = self.run_cli("server", "-p", "32770")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls()[-1]["cwd"], str(self.state))
        self.assertEqual(self.calls()[-1]["args"], ["-p", "32770"])
        for name in ("profile/sample.txt", "JL/sample.txt", "avs/sample.txt", "bat/sample.txt", "drcs/sample.txt", "exe_files/ch_sid.txt"):
            (self.state / name).write_text("user")
        (self.state / "config/queue.xml").write_text("queued-recording")
        (self.state / "exe_files/custom-tool").write_text("user-tool")
        newer = ROOT / "new-bundle"
        shutil.copytree(self.bundle, newer, symlinks=True)
        (newer / "exe_files/lib/libexample.so.1").write_text("library-v2")
        (newer / "exe_files/obsolete").write_text("obsolete")
        self.base[self.base.index("--bundle") + 1] = str(newer)
        self.assertEqual(self.run_cli("add-task", "-f", "/record/input.ts").returncode, 0)
        self.assertEqual(self.calls()[-1]["name"], "AmatsukazeAddTask")
        self.assertEqual((self.state / "exe_files/lib/libexample.so").read_text(), "library-v2")
        for name in ("profile/sample.txt", "JL/sample.txt", "avs/sample.txt", "bat/sample.txt", "drcs/sample.txt", "exe_files/ch_sid.txt"):
            self.assertEqual((self.state / name).read_text(), "user")
        self.assertEqual((self.state / "config/queue.xml").read_text(), "queued-recording")
        self.base[self.base.index("--bundle") + 1] = str(self.bundle)
        self.assertEqual(self.run_cli().returncode, 0)
        self.assertFalse((self.state / "exe_files/obsolete").exists())
        self.assertEqual((self.state / "exe_files/custom-tool").read_text(), "user-tool")

    def test_running_server_allows_tasks_and_fences_upgrades(self):
        process = subprocess.Popen(self.base, env=self.env | {"MOCK_HOLD": "1"}, cwd=ROOT,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            deadline = time.monotonic() + 5
            while not self.log.exists() and time.monotonic() < deadline:
                time.sleep(0.02)
            self.assertTrue(self.log.exists())
            duplicate = self.run_cli()
            self.assertEqual(duplicate.returncode, 1)
            self.assertIn("already running", duplicate.stderr)
            self.assertEqual(self.run_cli("add-task", "-f", "/record/input.ts").returncode, 0)
            newer = ROOT / "new-bundle"
            shutil.copytree(self.bundle, newer, symlinks=True)
            self.base[self.base.index("--bundle") + 1] = str(newer)
            upgrade = self.run_cli("add-task")
            self.assertEqual(upgrade.returncode, 1)
            self.assertIn("before upgrading", upgrade.stderr)
            process.terminate()
            output = process.communicate(timeout=5)
            self.assertEqual(process.returncode, 143, output)
        finally:
            if process.poll() is None:
                process.kill()
                process.communicate(timeout=5)
        self.assertEqual(self.run_cli().returncode, 0)


if __name__ == "__main__":
    unittest.main()

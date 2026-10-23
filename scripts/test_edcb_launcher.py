"""Exercise the desktop entry point with a process-level Wine substitute."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import unittest

PROJECT = Path(__file__).resolve().parents[1]
RUNNER = PROJECT / "pkgs/edcb-wine/run.py"
INITIALIZER = PROJECT / "modules/edcb-wine/init-runtime.py"
ROOT = Path("/private/tmp/jodtv-edcb-wine-launcher-tests")
if __name__ == "__main__" and len(sys.argv) == 4:
    RUNNER, INITIALIZER, ROOT = map(Path, sys.argv[1:])
    sys.argv[1:] = []


class LauncherTests(unittest.TestCase):
    def setUp(self):
        # Exact owned path; fixtures/logs remain below 1 MiB. Cleanup is
        # registered before writing, including for failures and interruption.
        shutil.rmtree(ROOT, ignore_errors=True)
        self.addCleanup(shutil.rmtree, ROOT, ignore_errors=True)
        self.bundle = ROOT / "bundle"
        self.state = ROOT / "data/edcb-wine"
        self.wine = ROOT / "wine"
        self.log = ROOT / "wine-log.jsonl"
        (self.bundle / "BonDriver").mkdir(parents=True)
        self.wine.mkdir()
        for name in ("Common", "EpgDataCap_Bon", "EpgTimerSrv"):
            (self.bundle / f"{name}.example.ini").write_bytes(b"[SET]\r\nKeep=1\r\n")
        (self.bundle / "BonDriver/BonDriver_mirakc_T.ini").write_text('[GLOBAL]\nSERVER_HOST="localhost"\nSERVER_PORT=40772\n')
        for name in ("EpgTimerSrv.exe", "EpgDataCap_Bon.exe"):
            (self.bundle / name).write_bytes(b"program-v1")
        mock = self.wine / "mock-wine"
        mock.write_text(f"#!{sys.executable}\n" + '''import json, os
from pathlib import Path
import signal, sys
name = Path(sys.argv[0]).name
prefix = Path(os.environ["WINEPREFIX"])
if name == "wineboot":
    prefix.mkdir(parents=True, exist_ok=True)
    (prefix / "system.reg").touch()
with open(os.environ["MOCK_WINE_LOG"], "a") as log:
    log.write(json.dumps({"name": name, "args": sys.argv[1:], "cwd": os.getcwd(), "prefix": str(prefix), "display": os.environ["DISPLAY"], "tz": os.environ["TZ"]}) + "\\n")
if name == "wine" and os.environ.get("MOCK_HOLD_SERVER") and sys.argv[1] == "EpgTimerSrv.exe":
    while True:
        signal.pause()
sys.exit(int(os.environ.get("MOCK_WINE_EXIT", "0")) if name == "wine" else 0)
''')
        mock.chmod(0o755)
        for name in ("wine", "wineboot", "wineserver", "regedit"):
            (self.wine / name).symlink_to(mock)
        self.font = ROOT / "font.ttc"
        self.font.write_bytes(b"font")
        self.fontconfig = ROOT / "fonts.conf"
        self.fontconfig.write_text("<fontconfig/>")
        self.env = os.environ.copy()
        self.env.update(DISPLAY=":42", XDG_DATA_HOME=str(ROOT / "data"), MOCK_WINE_LOG=str(self.log), PYTHONDONTWRITEBYTECODE="1")
        self.env.pop("WINEPREFIX", None)
        self.base = [sys.executable, str(RUNNER), "--bundle", str(self.bundle), "--wine-bin", str(self.wine),
                     "--font", str(self.font), "--fontconfig", str(self.fontconfig), "--initializer", str(INITIALIZER)]

    def run_cli(self, *args, env=None):
        return subprocess.run([*self.base, *args], env=env or self.env, capture_output=True, text=True, timeout=10)

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def test_help_and_missing_desktop_have_no_side_effects(self):
        env = {key: value for key, value in self.env.items() if key != "DISPLAY"}
        result = self.run_cli("--help", env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("scan-gr", result.stdout)
        self.assertNotIn("--wine-bin", result.stdout)
        self.assertFalse(self.state.exists())
        result = self.run_cli(env=env)
        self.assertEqual(result.returncode, 1)
        self.assertIn("X11 desktop", result.stderr)
        self.assertFalse(self.state.exists())

    def test_first_run_saved_backend_and_scan_share_prefix(self):
        result = self.run_cli("--backend-host", "tuner.example", "--backend-port", "40773")
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls()
        self.assertEqual([call["name"] for call in calls], ["wineboot", "wineserver", "regedit", "wine"])
        self.assertEqual(calls[-1]["args"], ["EpgTimerSrv.exe"])
        self.assertEqual(calls[-1]["display"], ":42")
        self.assertEqual(calls[-1]["tz"], "Asia/Tokyo")
        config = self.state / "EDCB/Common.ini"
        config.write_bytes(b"[SET]\r\nKeep=user-config\r\n")
        for action, driver in (("scan-gr", "T"), ("scan-bs", "S")):
            result = self.run_cli(action)
            self.assertEqual(result.returncode, 0, result.stderr)
            call = self.calls()[-1]
            self.assertEqual(call["args"], ["EpgDataCap_Bon.exe", "-d", f"BonDriver_mirakc_{driver}.dll", "-chscan"])
            self.assertEqual(call["prefix"], str(self.state / "wineprefix"))
        self.assertEqual(sum(call["name"] == "wineboot" for call in self.calls()), 1)
        self.assertEqual(config.read_bytes(), b"[SET]\r\nKeep=user-config\r\n")
        self.assertIn('SERVER_HOST="tuner.example"', (self.state / "EDCB/BonDriver/BonDriver_mirakc_T.ini").read_text())

    def test_capture_custom_directory_and_exit_status(self):
        env = self.env | {"MOCK_WINE_EXIT": "23"}
        state = ROOT / "state with spaces"
        result = self.run_cli("--state-dir", str(state), "capture", env=env)
        self.assertEqual(result.returncode, 23, result.stderr)
        self.assertEqual(self.calls()[-1]["cwd"], str(state / "EDCB"))
        self.assertEqual(self.calls()[-1]["args"], ["EpgDataCap_Bon.exe"])

    def test_running_server_allows_capture_but_fences_updates_and_duplicates(self):
        process = subprocess.Popen(self.base, env=self.env | {"MOCK_HOLD_SERVER": "1"}, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline:
                if self.log.exists() and any(call["name"] == "wine" for call in self.calls()):
                    break
                time.sleep(0.02)
            else:
                self.fail("server did not reach the Wine entry point")
            result = self.run_cli()
            self.assertEqual(result.returncode, 1)
            self.assertIn("server is running", result.stderr)
            result = self.run_cli("capture")
            self.assertEqual(result.returncode, 0, result.stderr)
            result = self.run_cli("--backend-host", "new.example", "capture")
            self.assertEqual(result.returncode, 1)
            self.assertIn("Close EDCB", result.stderr)
            self.assertEqual(json.loads((self.state / ".desktop-launch.json").read_text())["host"], "localhost")
            process.terminate()
            output = process.communicate(timeout=5)
            self.assertEqual(process.returncode, 143, output)
        finally:
            if process.poll() is None:
                process.kill()
                process.communicate(timeout=5)
        result = self.run_cli("--backend-host", "new.example")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_package_update_preserves_populated_configuration(self):
        self.assertEqual(self.run_cli().returncode, 0)
        config = self.state / "EDCB/EpgTimerSrv.ini"
        config.write_bytes(b"[SET]\r\nKeep=reservation-settings\r\n")
        newer = ROOT / "new-bundle"
        shutil.copytree(self.bundle, newer)
        (newer / "EpgTimerSrv.exe").write_bytes(b"program-v2")
        self.base[self.base.index("--bundle") + 1] = str(newer)
        result = self.run_cli()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.state / "EDCB/EpgTimerSrv.exe").read_bytes(), b"program-v2")
        self.assertEqual(config.read_bytes(), b"[SET]\r\nKeep=reservation-settings\r\n")


if __name__ == "__main__":
    unittest.main()

"""Exercise the actual first-start and package-update helper with populated state."""
import importlib.util
from pathlib import Path
import shutil
import sys
import unittest

HELPER = Path(__file__).resolve().parents[1] / "modules/edcb-wine/init-runtime.py"
ROOT = Path("/private/tmp/jodtv-edcb-wine-state-tests")
if __name__ == "__main__" and len(sys.argv) > 2 and sys.argv[1].endswith("init-runtime.py"):
    HELPER = Path(sys.argv.pop(1))
    ROOT = Path(sys.argv.pop(1))
spec = importlib.util.spec_from_file_location("edcb_runtime", HELPER)
runtime = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runtime)


class StateTests(unittest.TestCase):
    def setUp(self):
        # Owned deterministic path; fixtures are below 1 MiB. Cleanup on failure
        # is registered before any files are created.
        shutil.rmtree(ROOT, ignore_errors=True)
        self.addCleanup(shutil.rmtree, ROOT, ignore_errors=True)
        self.source = ROOT / "package-v1"
        self.state = ROOT / "state"
        (self.source / "BonDriver").mkdir(parents=True)
        (self.source / "Setting").mkdir()
        (self.source / "HttpPublic").mkdir()
        for name in ("Common", "EpgDataCap_Bon", "EpgTimerSrv"):
            (self.source / f"{name}.example.ini").write_bytes(b"[SET]\r\nKeep=1\r\n")
        (self.source / "BonDriver/BonDriver_mirakc_T.ini").write_bytes(b'SERVER_HOST="localhost"\r\nSERVER_PORT=40772\r\nTUNER=terrestrial\r\n')
        (self.source / "EpgTimerSrv.exe").write_bytes(b"version-1")
        (self.source / "old.dll").write_bytes(b"old")
        (self.source / "HttpPublic/index.html").write_text("web-v1")
        (self.source / "Setting/Reserve.txt").write_text("initial")
        (self.source / "bin").mkdir()
        (self.source / "bin/edcb-wine").write_text("desktop launcher")

    def initialize(self, source=None, host="tuner.example", port=40773):
        runtime.initialize(source or self.source, self.state, ROOT / "recordings", ROOT / "info", host, port)

    def test_seed_and_idempotent_restart(self):
        self.initialize()
        target = self.state / "EDCB"
        self.assertFalse((target / "bin").exists())
        common, _ = runtime.read_ini(target / "Common.ini")
        self.assertIn(runtime.windows_path(ROOT / "recordings"), common)
        self.assertIn(runtime.windows_path(ROOT / "info"), common)
        ini, _ = runtime.read_ini(target / "EpgTimerSrv.ini")
        self.assertIn("[TVTEST]", ini)
        self.assertIn("[BonDriver_mirakc_T.dll]", ini)
        self.assertIn("Count=2", ini)
        self.initialize()
        self.assertEqual(runtime.read_ini(target / "EpgTimerSrv.ini")[0], ini)
        self.assertIn('SERVER_HOST="tuner.example"', (target / "BonDriver/BonDriver_mirakc_T.ini").read_text())

    def test_upgrade_populated_state_and_remove_only_owned_programs(self):
        self.initialize()
        target = self.state / "EDCB"
        config = "[SET]\r\nRecFolderPath0=D:\\Custom\r\nKeep=日本語\r\n".encode("utf-16")
        (target / "Common.ini").write_bytes(config)
        (target / "Setting/Reserve.txt").write_text("reservation and history")
        (target / "BonDriver/channels.ch2").write_text("scanned channels")
        (target / "user.dll").write_bytes(b"user plugin")
        newer = ROOT / "package-v2"
        shutil.copytree(self.source, newer)
        (newer / "EpgTimerSrv.exe").write_bytes(b"version-2")
        (newer / "HttpPublic/index.html").write_text("web-v2")
        (newer / "old.dll").unlink()
        self.initialize(newer, host="new.example", port=40774)
        self.assertEqual((target / "EpgTimerSrv.exe").read_bytes(), b"version-2")
        self.assertEqual((target / "HttpPublic/index.html").read_text(), "web-v2")
        self.assertEqual((target / "Common.ini").read_bytes(), config)
        self.assertEqual((target / "Setting/Reserve.txt").read_text(), "reservation and history")
        self.assertEqual((target / "BonDriver/channels.ch2").read_text(), "scanned channels")
        self.assertEqual((target / "user.dll").read_bytes(), b"user plugin")
        self.assertFalse((target / "old.dll").exists())
        driver = (target / "BonDriver/BonDriver_mirakc_T.ini").read_text()
        self.assertIn('SERVER_HOST="new.example"', driver)
        self.assertIn("SERVER_PORT=40774", driver)
        self.assertIn("TUNER=terrestrial", driver)

    def test_import_existing_instance_without_marker(self):
        target = self.state / "EDCB"
        target.mkdir(parents=True)
        (target / "Common.ini").write_bytes(b"[SET]\r\nRecFolderPath0=D:\\Existing\r\n")
        (target / "EpgTimerSrv.exe").write_bytes(b"old-host-version")
        self.initialize()
        self.assertEqual((target / "EpgTimerSrv.exe").read_bytes(), b"version-1")
        self.assertEqual((target / "Common.ini").read_bytes(), b"[SET]\r\nRecFolderPath0=D:\\Existing\r\n")

    def test_ini_encodings(self):
        for encoding in ("utf-8", "utf-16", "utf-16-le", "cp932"):
            with self.subTest(encoding=encoding):
                path = ROOT / "encoding.ini"
                path.write_bytes("[SET]\r\nName=日本語\r\n".encode(encoding))
                runtime.set_keys(path, "SET", {"Port": 5510})
                text, _ = runtime.read_ini(path)
                self.assertIn("Name=日本語", text)
                self.assertIn("Port=5510", text)


if __name__ == "__main__":
    unittest.main()

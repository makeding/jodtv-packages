import argparse
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("bump", Path(__file__).with_name("bump-deps.py"))
bump = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bump)


class BumpTests(unittest.TestCase):
    def test_native_apple_silicon_system(self):
        with patch.object(bump.platform, "machine", return_value="arm64"), patch.object(bump.platform, "system", return_value="Darwin"):
            self.assertEqual(bump.native_system(), "aarch64-darwin")

    def test_epgstation_version_comes_from_fetched_source(self):
        with patch.object(bump.subprocess, "run") as run, patch.object(Path, "read_text", side_effect=[
            '{"version":"3.0.0-beta2"}',
            'version = "0-unstable-2026-10-22";',
        ]), patch.object(Path, "write_text") as write:
            run.return_value.stdout = "/nix/store/source\n"
            bump.refresh_epgstation_version("aarch64-darwin")
            write.assert_called_once_with('version = "3.0.0-beta2-unstable-2026-10-22";')
            self.assertIn(".#packages.aarch64-darwin.epgstation-h.src", run.call_args.args[0])

    def test_dependency_caches_and_release_policy(self):
        args = argparse.Namespace(version=None, system="x86_64-linux", build=False)
        cmds = list(bump.commands(["honomitv", "epgstation-h", "recisdb", "qsvencc"], args))
        self.assertEqual(cmds[0][-2:], ["--subpackage", "frontend"])
        self.assertEqual(cmds[1][-2:], ["--subpackage", "clientDir"])
        self.assertEqual(cmds[2][cmds[2].index("--version") + 1], "branch")
        self.assertEqual(cmds[3][cmds[3].index("--version") + 1], "stable")

    def test_dry_run_does_not_execute_and_deduplicates_alias(self):
        with patch.object(bump.subprocess, "run") as run, patch.object(bump.os, "execvp") as execute, patch("builtins.print") as output:
            self.assertEqual(bump.main(["konomitv", "honomitv", "--dry-run"]), 0)
            run.assert_not_called()
            execute.assert_not_called()
            self.assertEqual(output.call_count, 1)

    def test_fail_fast_preserves_failure(self):
        with patch.object(bump.shutil, "which", return_value="nix-update"), patch.object(bump.subprocess, "run") as run:
            run.return_value.returncode = 7
            self.assertEqual(bump.main(["hiraku", "libaribtlv"]), 7)
            self.assertEqual(run.call_count, 1)

    def test_explicit_branch_and_build(self):
        args = argparse.Namespace(version="branch=dev", system="aarch64-linux", build=True)
        cmd = next(bump.commands(["recisdb"], args))
        self.assertIn("branch=dev", cmd)
        self.assertIn("aarch64-linux", cmd)
        self.assertEqual(cmd[-1], "--build")


if __name__ == "__main__":
    unittest.main()

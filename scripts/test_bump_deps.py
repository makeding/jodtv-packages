import argparse
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("bump", Path(__file__).with_name("bump-deps.py"))
bump = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bump)


class BumpTests(unittest.TestCase):
    def test_all_excludes_manually_pinned_sources(self):
        available = bump.packages()
        self.assertTrue(available)
        self.assertTrue({"a865r-firmware", "edcb-wine", "ffmpeg-libaribtlv"}.isdisjoint(available))
        with patch.object(bump.subprocess, "run") as run, patch("builtins.print") as output:
            self.assertEqual(bump.main(["--all", "--dry-run"]), 0)
            run.assert_not_called()
            commands = [call.args[0] for call in output.call_args_list
                        if call.args[0].startswith("+ nix-update ")]
            self.assertEqual(len(commands), len(available))

    def test_native_apple_silicon_system(self):
        with patch.object(bump.platform, "machine", return_value="arm64"), patch.object(bump.platform, "system", return_value="Darwin"):
            self.assertEqual(bump.native_system(), "aarch64-darwin")

    def test_daily_updates_skip_maintained_software(self):
        maintained = {"epgstation-h", "hiraku", "honomitv", "libaribb61", "libaribtlv",
                      "librw5100", "mirakurun", "pcsc-rw5100", "recdvb", "recisdb", "tsreplace"}
        upstream = set(bump.packages(upstream_only=True))
        self.assertTrue(maintained.isdisjoint(upstream))
        self.assertTrue(maintained.issubset(bump.packages()))
        self.assertTrue({"konomitv", "epgstation-upstream", "amatsukaze", "nvencc"}.issubset(upstream))
        with patch.object(bump.subprocess, "run") as run, patch("builtins.print") as output:
            self.assertEqual(bump.main(["--all", "--upstream-only", "--dry-run"]), 0)
            run.assert_not_called()
            commands = [call.args[0] for call in output.call_args_list
                        if call.args[0].startswith("+ nix-update ")]
            self.assertEqual(len(commands), len(upstream))
            for name in maintained:
                self.assertFalse(any(f".{name} " in cmd for cmd in commands))

    def test_branch_version_uses_exact_commit_manifest_not_old_fork_tag(self):
        revision = "b" * 40
        contents = ('version = "0.12.0-old-fork-tag";\n'
                    'owner = "makeding";\nrepo = "HonomiTV";\n'
                    f'rev = "{"a" * 40}";\n')
        with patch.object(bump, "fetch", side_effect=[
            '{"sha":"' + revision + '","commit":{"committer":{"date":"2026-10-22T00:00:00Z"}}}',
            '[project]\nversion = "0.14.1"\n',
        ]) as fetch, patch.object(Path, "read_text", return_value=contents), patch.object(Path, "write_text") as write:
            bump.prepare_branch("honomitv", "branch")
            result = write.call_args.args[0]
            self.assertIn('version = "0.14.1-unstable-2026-10-22";', result)
            self.assertIn(f'rev = "{revision}";', result)
            self.assertEqual(fetch.call_args.args[0],
                             f"https://raw.githubusercontent.com/makeding/HonomiTV/{revision}/server/pyproject.toml")

    def test_source_version_formats(self):
        samples = [
            ('{"version":"3.0.0-beta2"}', "json", "3.0.0-beta2"),
            ('[package]\nversion = "1.3.0"', "package", "1.3.0"),
            ('cmake_minimum_required(VERSION 3.16)\nproject(aribtlv VERSION 0.6.1 LANGUAGES C)', "cmake", "0.6.1"),
            ('AC_INIT([recpt1], [1.2.1.1], email)', "autoconf", "1.2.1.1"),
            ('#define VER_STR_FILEVERSION "0.20"\r\n', "header", "0.20"),
        ]
        for contents, kind, expected in samples:
            with self.subTest(kind=kind):
                self.assertEqual(bump.manifest_version(contents, kind), expected)
        with self.assertRaises(ValueError):
            bump.manifest_version('project(aribtlv LANGUAGES C)', "cmake")

    def test_version_equal_to_old_commit_does_not_corrupt_new_revision(self):
        contents = f'version = "{"a" * 40}";\nowner = "owner";\nrepo = "repo";\nrev = "{"a" * 40}";\n'
        with patch.object(bump, "fetch", return_value='{"sha":"' + "b" * 40 + '","commit":{"committer":{"date":"2026-10-22T00:00:00Z"}}}'), patch.object(Path, "read_text", return_value=contents), patch.object(Path, "write_text") as write:
            bump.prepare_branch("hiraku", "branch=main")
            self.assertIn('version = "unstable-2026-10-22";', write.call_args.args[0])
            self.assertIn(f'rev = "{"b" * 40}";', write.call_args.args[0])

    def test_gitea_archive_uses_commit_and_cmake_version(self):
        contents = ('version = "1.0";\nurl = "https://git.huggy.moe/rw5100/pcsc-rw5100/'
                    f'archive/{"a" * 40}.tar.gz";\n')
        with patch.object(bump, "fetch", side_effect=[
            '[{"sha":"' + "b" * 40 + '","commit":{"committer":{"date":"2026-09-14T00:15:57+09:00"}}}]',
            'project(pcsc-rw5100 VERSION 0.1.0 LANGUAGES C)',
        ]), patch.object(Path, "read_text", return_value=contents), patch.object(Path, "write_text") as write:
            bump.prepare_branch("pcsc-rw5100", "branch")
            self.assertIn('version = "0.1.0-unstable-2026-09-14";', write.call_args.args[0])
            self.assertIn(f'/archive/{"b" * 40}.tar.gz', write.call_args.args[0])

    def test_repo_can_reference_pname(self):
        contents = 'pname = "tsreplace";\nversion = "0.19";\nowner = "makeding";\nrepo = pname;\nrev = "old";\n'
        with patch.object(bump, "fetch", side_effect=[
            '{"sha":"' + "b" * 40 + '","commit":{"committer":{"date":"2026-10-22T00:00:00Z"}}}',
            '#define VER_STR_FILEVERSION "0.20"',
        ]) as fetch, patch.object(Path, "read_text", return_value=contents), patch.object(Path, "write_text") as write:
            bump.prepare_branch("tsreplace", "branch")
            self.assertEqual(fetch.call_args_list[0].args[0], "https://api.github.com/repos/makeding/tsreplace/commits/HEAD")
            self.assertIn('version = "0.20-unstable-2026-10-22";', write.call_args.args[0])

    def test_dependency_caches_and_release_policy(self):
        args = argparse.Namespace(version=None, system="x86_64-linux", build=False)
        cmds = list(bump.commands(["honomitv", "epgstation-h", "recisdb", "qsvencc", "amatsukaze", "nvencc"], args))
        self.assertEqual(cmds[0][-2:], ["--subpackage", "frontend"])
        self.assertEqual(cmds[1][-2:], ["--subpackage", "clientDir"])
        self.assertEqual(cmds[2][cmds[2].index("--version") + 1], "skip")
        self.assertEqual(cmds[3][cmds[3].index("--version") + 1], "stable")
        for command in cmds[4:]:
            self.assertEqual(command[command.index("--version") + 1], "stable")

    def test_linux_package_updates_use_native_full_inventory(self):
        args = argparse.Namespace(version=None, system="aarch64-darwin", build=False)
        cmd = next(bump.commands(["casproxyserver"], args))
        self.assertEqual(cmd[1], "legacyPackages.aarch64-darwin.casproxyserver")
        self.assertEqual(cmd[cmd.index("--system") + 1], "aarch64-darwin")
        self.assertEqual(cmd[-1], "pkgs/casproxyserver/package.nix")

    def test_dry_run_does_not_execute_and_deduplicates_alias(self):
        with patch.object(bump.subprocess, "run") as run, patch.object(bump.os, "execvp") as execute, patch("builtins.print") as output:
            self.assertEqual(bump.main(["epgstation", "epgstation-h", "--dry-run"]), 0)
            run.assert_not_called()
            execute.assert_not_called()
            self.assertEqual(output.call_count, 2)

    def test_upstream_variants_update_independently(self):
        args = argparse.Namespace(version=None, system="x86_64-linux", build=False)
        names = ["konomitv", "honomitv", "epgstation-upstream", "epgstation-h"]
        self.assertTrue(set(names).issubset(bump.packages()))
        cmds = list(bump.commands(names, args))
        self.assertEqual([cmd[1] for cmd in cmds],
                         [f"legacyPackages.x86_64-linux.{name}" for name in names])
        self.assertEqual([cmd[-1] for cmd in cmds],
                         ["frontend", "frontend", "clientDir", "clientDir"])
        with patch.object(bump.subprocess, "run") as run, patch("builtins.print") as output:
            self.assertEqual(bump.main([*names, "--dry-run"]), 0)
            run.assert_not_called()
            self.assertEqual(output.call_count, 8)

    def test_fail_fast_preserves_failure(self):
        with patch.object(bump, "prepare_branch"), patch.object(bump.shutil, "which", return_value="nix-update"), patch.object(bump.subprocess, "run") as run:
            run.return_value.returncode = 7
            self.assertEqual(bump.main(["hiraku", "libaribtlv"]), 7)
            self.assertEqual(run.call_count, 1)

    def test_explicit_branch_and_build(self):
        args = argparse.Namespace(version="branch=dev", system="aarch64-linux", build=True)
        cmd = next(bump.commands(["recisdb"], args))
        self.assertEqual(cmd[1], "recisdb")
        self.assertEqual(cmd[cmd.index("--version") + 1], "skip")
        self.assertIn("aarch64-linux", cmd)
        self.assertEqual(cmd[-1], "--build")


if __name__ == "__main__":
    unittest.main()

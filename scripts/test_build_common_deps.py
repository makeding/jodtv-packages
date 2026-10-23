import importlib.util
from pathlib import Path
import unittest
from unittest.mock import mock_open, patch

spec = importlib.util.spec_from_file_location("common", Path(__file__).with_name("build-common-deps.py"))
common = importlib.util.module_from_spec(spec)
spec.loader.exec_module(common)


def root(drv, outputs=("out",)):
    return {"drvPath": drv, "outputs": outputs}


class DependencyPlanTests(unittest.TestCase):
    def test_repository_dependencies_build_before_consumers(self):
        graph = {
            "epgstation": {"tsreplace": {"out"}},
            "tsreplace": {"hiraku": {"out"}, "ffmpeg": {"bin", "dev"}},
            "hiraku": {}, "ffmpeg": {},
        }
        roots = {name: root(name) for name in ("epgstation", "tsreplace", "hiraku")}
        targets, remaining, _ = common.plan_build(roots, graph)
        self.assertEqual(set(targets), {"tsreplace", "hiraku"})
        self.assertEqual(remaining, ["epgstation"])

    def test_shared_transitive_dependency_and_distinct_ffmpeg_variants(self):
        graph = {
            "epgstation": {"tsreplace": {"out"}, "ffmpeg-headless": {"bin"}},
            "tsreplace": {"ffmpeg": {"bin", "dev"}},
            "qsvencc": {"ffmpeg": {"dev", "lib"}},
            "konomitv": {"ffmpeg-headless": {"bin"}},
            "ffmpeg": {}, "ffmpeg-headless": {},
        }
        roots = {name: root(name) for name in ("epgstation", "qsvencc", "konomitv")}
        targets, remaining, _ = common.plan_build(roots, graph)
        self.assertEqual(targets, {"ffmpeg": ["bin", "dev", "lib"], "ffmpeg-headless": ["bin"]})
        self.assertEqual(list(roots), remaining)

    def test_shared_subgraph_stays_in_one_build_without_expanding_toolchain(self):
        graph = {
            "a": {"shared": {"out"}}, "b": {"shared": {"out"}},
            "shared": {"compiler": {"out"}}, "compiler": {},
        }
        targets, _, _ = common.plan_build({name: root(name) for name in ("a", "b")}, graph)
        self.assertEqual(targets, {"shared": ["out"]})

    def test_dependency_also_used_outside_shared_parent_is_built_explicitly(self):
        graph = {
            "a": {"shared": {"out"}, "compiler": {"dev"}},
            "b": {"shared": {"out"}, "compiler": {"dev"}},
            "shared": {"compiler": {"out"}}, "compiler": {},
        }
        targets, _, _ = common.plan_build({name: root(name) for name in ("a", "b")}, graph)
        # Even when shared is substituted, compiler.dev is ready for a and b.
        self.assertEqual(targets, {"compiler": ["dev", "out"], "shared": ["out"]})

    def test_single_package_and_diamond_do_not_count_as_multiple_consumers(self):
        graph = {"a": {"b": {"out"}, "c": {"out"}},
                 "b": {"d": {"out"}}, "c": {"d": {"out"}}, "d": {}}
        targets, remaining, _ = common.plan_build({"a": root("a")}, graph)
        self.assertEqual(targets, {})
        self.assertEqual(remaining, ["a"])

    def test_aliases_can_leave_empty_matrix(self):
        targets, remaining, _ = common.plan_build({"a": root("same"), "alias": root("same")}, {"same": {}})
        self.assertEqual(targets, {"same": ["out"]})
        self.assertEqual(remaining, [])

    def test_nix_json_formats(self):
        legacy = {"/nix/store/a.drv": {"inputDrvs": {"/nix/store/b.drv": ["dev"]}},
                  "/nix/store/b.drv": {"inputDrvs": {}}}
        versioned = {"version": 4, "derivations": {
            "a.drv": {"inputs": {"drvs": {"b.drv": {"outputs": ["dev"], "dynamicOutputs": {}}}}},
            "b.drv": {"inputs": {"drvs": {}}},
        }}
        expected = {"/nix/store/a.drv": {"/nix/store/b.drv": {"dev"}}, "/nix/store/b.drv": {}}
        self.assertEqual(common.normalize_graph(legacy, "/nix/store"), expected)
        self.assertEqual(common.normalize_graph(versioned, "/nix/store"), expected)

    def test_build_passes_consumed_outputs_and_emits_remaining_matrix_after_success(self):
        roots = {"a": root("/nix/store/a.drv"), "b": root("/nix/store/b.drv")}
        document = {
            "/nix/store/a.drv": {"inputDrvs": {"/nix/store/shared.drv": ["bin"]}},
            "/nix/store/b.drv": {"inputDrvs": {"/nix/store/shared.drv": ["dev"]}},
            "/nix/store/shared.drv": {"inputDrvs": {}},
        }
        with patch("sys.argv", ["build-common-deps.py", "--build", "--packages", "a,b"]), \
             patch.object(common, "nix_json", side_effect=[["a", "b"], roots, document]), \
             patch.object(common.subprocess, "run") as run, \
             patch.dict(common.os.environ, {"GITHUB_OUTPUT": "mock-output"}), \
             patch("builtins.open", mock_open()) as output, patch("builtins.print"):
            common.main()
            self.assertEqual(run.call_args.kwargs["input"], "/nix/store/shared.drv^bin,dev\n")
            self.assertTrue(run.call_args.kwargs["check"])
            output().write.assert_called_once_with('packages=["a", "b"]\n')


if __name__ == "__main__":
    unittest.main()

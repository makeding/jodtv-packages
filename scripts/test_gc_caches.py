import importlib.util
from pathlib import Path
import unittest
from unittest.mock import Mock, patch


spec = importlib.util.spec_from_file_location("gc_caches", Path(__file__).with_name("gc-caches.py"))
gc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gc)

A, B, C, D = (letter * 32 for letter in "abcd")
NAR_A, NAR_B, NAR_C = (letter * 52 for letter in "abc")
REF = "refs/heads/master"


def info(nar, references=()):
    return {"narHash": "sha256:" + nar, "references": list(references)}


def entry(number, key, ref=REF):
    return {"id": number, "key": key, "ref": ref}


class CacheRetentionTests(unittest.TestCase):
    def test_nix_formats_keep_build_outputs_sources_and_derivations(self):
        root = {"pkg": {"drvPath": f"/nix/store/{A}-pkg.drv", "outPath": f"/nix/store/{B}-pkg"}}
        for document in [
            {f"/nix/store/{A}-pkg.drv": {"outputs": {"out": {"path": f"/nix/store/{B}-pkg"}},
                                        "inputSrcs": [f"/nix/store/{C}-source"]}},
            {"version": 4, "derivations": {f"{A}-pkg.drv": {
                "outputs": {"out": {"path": f"{B}-pkg"}}, "inputs": {"srcs": [f"{C}-source"]}}}},
        ]:
            with self.subTest(document=document), patch.object(gc, "nix_json", side_effect=[root, document]):
                roots, protected = gc.current_paths("x86_64-linux")
                self.assertEqual(roots, root)
                self.assertEqual(protected, {A, B, C})

    def test_empty_package_inventory_and_unknown_output_abort(self):
        with patch.object(gc, "nix_json", return_value={}):
            with self.assertRaisesRegex(ValueError, "empty"):
                gc.current_paths("x86_64-linux")
        root = {"pkg": {"drvPath": f"{A}-pkg.drv", "outPath": f"{B}-pkg"}}
        with patch.object(gc, "nix_json", side_effect=[root, {f"{A}-pkg.drv": {"outputs": {"out": {}}}}]):
            with self.assertRaisesRegex(ValueError, "output path"):
                gc.current_paths("x86_64-linux")

    def test_runtime_closure_follows_upstream_and_cachix_reference_encodings(self):
        lookup = Mock(side_effect=lambda value: {
            A: info(NAR_A, [f"{A}-self {B}-upstream"]),
            B: info(NAR_B, [f"{C}-runtime"]),
            C: info(NAR_C),
        }[value])
        paths, nars = gc.cached_closure({A}, {A, C, D}, lookup)
        self.assertEqual(paths, {A, C})
        self.assertEqual(nars, {NAR_A, NAR_B, NAR_C})
        self.assertEqual(lookup.call_count, 3)

    def test_missing_closure_and_unknown_nar_hash_abort(self):
        with self.assertRaisesRegex(ValueError, "missing"):
            gc.cached_closure({A}, set(), lambda _: None)
        with self.assertRaisesRegex(ValueError, "NAR hash"):
            gc.cached_closure({A}, {A}, lambda _: {"narHash": "bad"})

    def test_plan_keeps_cached_build_dependency_closure_and_verifies_roots(self):
        api, upstream = Mock(), Mock()
        api.request.side_effect = lambda path: {
            "/api/v1/cache/jodtv/contents": [A, B, C, D],
            "/api/v1/cache/jodtv/pin": [],
            f"/api/v1/cache/jodtv/{A}.narinfo": info(NAR_A),
            f"/api/v1/cache/jodtv/{B}.narinfo": info(NAR_B, [f"{C}-runtime"]),
            f"/api/v1/cache/jodtv/{C}.narinfo": info(NAR_C),
        }[path]
        obsolete, protected, nars = gc.cachix_plan(
            api, upstream, "jodtv", {"pkg": {"outPath": f"/nix/store/{A}-pkg"}}, {A, B}, [],
        )
        self.assertEqual(obsolete, {D})
        self.assertEqual(protected, {A, B, C})
        self.assertEqual(nars, {NAR_A, NAR_B, NAR_C})
        upstream.request.assert_not_called()

    def test_official_default_output_need_not_be_uploaded_to_cachix(self):
        api, upstream = Mock(), Mock()
        api.request.side_effect = [[D], []]
        upstream.request.return_value = f"NarHash: sha256:{NAR_A}\nReferences: \n"
        obsolete, protected, _ = gc.cachix_plan(
            api, upstream, "jodtv", {"pkg": {"outPath": f"{A}-pkg"}}, {A}, [],
        )
        self.assertEqual(obsolete, {D})
        self.assertIn(A, protected)
        upstream.request.assert_called_once_with(f"/{A}.narinfo", missing_ok=True, text=True)

    def test_cachix_pins_preserve_unenumerable_history_and_github_nars(self):
        api = Mock()
        api.request.side_effect = lambda path: {
            "/api/v1/cache/jodtv/contents": [A, B],
            "/api/v1/cache/jodtv/pin": [{"name": "release", "keep": {"Forever": []}}],
            f"/api/v1/cache/jodtv/{A}.narinfo": info(NAR_A),
        }[path]
        with patch("builtins.print"):
            obsolete, protected, nars = gc.cachix_plan(
                api, Mock(), "jodtv", {}, {C}, [entry(1, A + ".narinfo-aB12")]
            )
        self.assertFalse(obsolete)
        self.assertEqual(protected, {A, B, C})
        self.assertEqual(nars, {NAR_A})
        self.assertFalse(gc.github_plan([entry(1, NAR_A + ".nar.zstd-aB12")], protected, nars, REF))
        self.assertEqual(
            [item["id"] for item in gc.github_plan([entry(1, NAR_C + ".nar.zstd-aB12")], protected, nars, REF)],
            [1],
        )

    def test_pins_do_not_skip_current_root_availability_validation(self):
        api, upstream = Mock(), Mock()
        api.request.side_effect = [[A], [{"name": "release", "keep": {"Forever": []}}]]
        upstream.request.return_value = None
        with self.assertRaisesRegex(ValueError, "missing from both caches"):
            gc.cachix_plan(
                api, upstream, "jodtv", {"pkg": {"outPath": f"{B}-pkg"}}, {B}, []
            )
        self.assertEqual(api.request.call_count, 1)
        upstream.request.assert_called_once_with(f"/{B}.narinfo", missing_ok=True, text=True)

    def test_protected_github_narinfo_keeps_upstream_nar(self):
        api, upstream = Mock(), Mock()
        api.request.side_effect = [[D], []]
        upstream.request.return_value = f"NarHash: sha256:{NAR_C}\nReferences: \n"
        obsolete, protected, nars = gc.cachix_plan(
            api,
            upstream,
            "jodtv",
            {"pkg": {"outPath": f"{C}-pkg"}},
            {C},
            [entry(1, C + ".narinfo-aB12"), entry(2, NAR_C + ".nar.zstd-aB12")],
        )
        self.assertEqual(obsolete, {D})
        self.assertIn(C, protected)
        self.assertEqual(nars, {NAR_C})
        self.assertFalse(gc.github_plan([entry(2, NAR_C + ".nar.zstd-aB12")], protected, nars, REF))

    def test_missing_metadata_for_protected_github_narinfo_aborts(self):
        api, upstream = Mock(), Mock()
        api.request.side_effect = [[D]]
        upstream.request.return_value = None
        with self.assertRaisesRegex(ValueError, "Cannot determine NAR hash"):
            gc.cachix_plan(
                api,
                upstream,
                "jodtv",
                {},
                {C},
                [entry(1, C + ".narinfo-aB12")],
            )

    def test_github_only_prunes_obsolete_magic_keys_on_default_branch(self):
        entries = [
            entry(1, A + ".narinfo-aB12"),
            entry(2, B + ".narinfo-aB12"),
            entry(3, NAR_A + ".nar.zstd-aB12"),
            entry(4, NAR_B + ".nar.zstd-aB12"),
            entry(5, B + ".narinfo-aB12", "refs/heads/feature"),
            entry(6, "unrelated-build-cache"),
            entry(7, B + ".narinfo-unknown-format"),
        ]
        self.assertEqual([item["id"] for item in gc.github_plan(entries, {A}, {NAR_A}, REF)], [2, 4])

    def test_github_inventory_is_paginated_before_deletion(self):
        api = Mock()
        api.request.side_effect = [{"actions_caches": list(range(100))}, {"actions_caches": [100]}]
        self.assertEqual(gc.github_caches(api, "owner/repo"), list(range(101)))
        self.assertIn("page=2", api.request.call_args.args[0])

    def run_gc(self, *, apply, revisions=(True, True), plan=None):
        github, cachix = Mock(), Mock()
        if plan is None:
            plan = ({B}, {A}, {NAR_A})
        with patch.object(gc, "at_revision", side_effect=revisions), \
             patch.object(gc, "current_paths", return_value=({"pkg": {"outPath": f"{A}-pkg"}}, {A})), \
             patch.object(gc, "cachix_plan", return_value=plan), \
             patch.object(gc, "github_caches", return_value=[entry(1, B + ".narinfo-aB12")]), \
             patch("builtins.print"):
            gc.run_gc(github, cachix, Mock(), "owner/repo", "master", "revision", "jodtv", "x86_64-linux", apply)
        return github, cachix

    def test_dry_run_never_deletes(self):
        github, cachix = self.run_gc(apply=False)
        github.request.assert_not_called()
        cachix.request.assert_not_called()

    def test_apply_deletes_exact_hash_and_cache_id_after_validation(self):
        github, cachix = self.run_gc(apply=True)
        cachix.request.assert_called_once_with(f"/api/v1/cache/jodtv/{B}.narinfo", method="DELETE", missing_ok=True)
        github.request.assert_called_once_with("/repos/owner/repo/actions/caches/1", method="DELETE", missing_ok=True)

    def test_stale_build_and_branch_change_never_delete(self):
        for revisions in [(False,), (True, False)]:
            with self.subTest(revisions=revisions):
                github, cachix = self.run_gc(apply=True, revisions=revisions)
                github.request.assert_not_called()
                cachix.request.assert_not_called()

    def test_failed_preflight_leaves_both_caches_untouched(self):
        github, cachix = Mock(), Mock()
        with patch.object(gc, "at_revision", return_value=True), \
             patch.object(gc, "current_paths", return_value=({}, set())), \
             patch.object(gc, "github_caches", return_value=[]), \
             patch.object(gc, "cachix_plan", side_effect=ValueError("missing required output")):
            with self.assertRaisesRegex(ValueError, "missing required output"):
                gc.run_gc(github, cachix, Mock(), "owner/repo", "master", "revision", "jodtv", "x86_64-linux", True)
        github.request.assert_not_called()
        cachix.request.assert_not_called()


if __name__ == "__main__":
    unittest.main()

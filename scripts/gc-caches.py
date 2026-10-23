#!/usr/bin/env python3
"""Prune obsolete CI cache objects after a complete successful package build.

Default is read-only. The workflow owns the build-success gate; this script
also checks that the built revision is still the default branch's head.
"""

import argparse
import json
import os
from pathlib import PurePosixPath
import re
import subprocess
import urllib.error
import urllib.parse
import urllib.request


STORE_HASH = re.compile(r"[0-9abcdfghijklmnpqrsvwxyz]{32}")
NAR_HASH = re.compile(r"sha256:([0-9abcdfghijklmnpqrsvwxyz]{52})")
MAGIC_KEY = re.compile(
    r"(?:([0-9abcdfghijklmnpqrsvwxyz]{32})\.narinfo|"
    r"([0-9abcdfghijklmnpqrsvwxyz]{52})\.nar\.zstd)-[A-Za-z0-9]{4}"
)


def store_hash(path):
    name = PurePosixPath(path).name.removesuffix(".narinfo")
    value = name.split("-", 1)[0]
    if not STORE_HASH.fullmatch(value):
        raise ValueError(f"Invalid store path/hash: {path!r}")
    return value


class API:
    def __init__(self, base, token=None):
        self.base = base.rstrip("/")
        self.token = token

    def request(self, path, method="GET", missing_ok=False, text=False):
        headers = {"Accept": "application/json", "User-Agent": "jodtv-cache-gc"}
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"
        request = urllib.request.Request(self.base + path, headers=headers, method=method)
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                body = response.read().decode()
        except urllib.error.HTTPError as error:
            if missing_ok and error.code == 404:
                return None
            raise RuntimeError(f"{method} {self.base}{path}: HTTP {error.code}") from None
        if text:
            return body
        return json.loads(body) if body else None


def nix_json(*args):
    return json.loads(subprocess.check_output(["nix", *args], text=True))


def current_paths(system):
    roots = nix_json(
        "eval", "--impure", "--json", f".#packages.{system}", "--apply",
        "ps: builtins.mapAttrs (_: p: { drvPath = p.drvPath; outputPath = p.outPath; }) ps",
    )
    if not roots:
        raise ValueError("Refusing GC with an empty package set")
    document = nix_json("derivation", "show", "--recursive", *sorted({
        root["drvPath"] for root in roots.values()
    }))
    paths = {root["outputPath"] for root in roots.values()}
    for drv, data in document.get("derivations", document).items():
        paths.add(drv)
        queried_outputs = False
        for output in data["outputs"].values():
            if not output.get("path"):
                # JSON v4 omits paths for fixed content-addressed outputs.
                # Let Nix compute them rather than trusting builder env values
                # or reimplementing its store-path hashing algorithm.
                if not output.get("hash") or not output.get("method"):
                    raise ValueError(f"Cannot determine output path for {drv}")
                if not queried_outputs:
                    drv_path = str(PurePosixPath("/nix/store") / drv)
                    outputs = subprocess.check_output(
                        ["nix-store", "--query", "--outputs", drv_path], text=True,
                    ).splitlines()
                    if len(outputs) != len(data["outputs"]) or not all(outputs):
                        raise ValueError(f"Cannot determine output paths for {drv}")
                    paths.update(outputs)
                    queried_outputs = True
            else:
                paths.add(output["path"])
        paths.update(data["inputSrcs"] if "inputSrcs" in data else data["inputs"]["srcs"])
    return roots, {store_hash(path) for path in paths}


def cachix_contents(api, cache):
    entries = api.request(f"/api/v1/cache/{cache}/contents")
    if not isinstance(entries, list):
        raise ValueError("Unexpected Cachix contents response")
    return {store_hash(path) for path in entries}


def cached_closure(roots, narinfo):
    """Follow references even through upstream paths to protect cached children."""
    pending = list(roots)
    seen = set()
    nars = set()
    while pending:
        value = pending.pop()
        if value in seen:
            continue
        info = narinfo(value)
        if info is None:
            raise ValueError(f"Required store path is missing from both caches: {value}")
        nar = NAR_HASH.fullmatch(info["narHash"])
        if not nar:
            raise ValueError(f"Unexpected NAR hash for {value}")
        nars.add(nar[1])
        seen.add(value)
        # Cachix can encode the complete References line as one array item.
        pending.extend(store_hash(path) for group in info["references"] for path in group.split())
    return seen, nars


def cachix_plan(api, upstream, cache, roots, protected, github_entries, ref):
    available = cachix_contents(api, cache)
    metadata = {}

    def narinfo(value):
        if value in metadata:
            return metadata[value]
        if value in available:
            metadata[value] = api.request(f"/api/v1/cache/{cache}/{value}.narinfo")
        else:
            body = upstream.request(f"/{value}.narinfo", missing_ok=True, text=True)
            if body is None:
                return None
            fields = dict(line.split(": ", 1) for line in body.splitlines() if ": " in line)
            metadata[value] = {"references": fields.get("References", "").split(), "narHash": fields["NarHash"]}
        return metadata[value]

    # Include every cached build input/output, not just package runtime roots.
    starts = (protected & available) | {store_hash(root["outputPath"]) for root in roots.values()}
    closure, nars = cached_closure(starts, narinfo)
    protected = protected | closure
    # A protected store path can be served by cache.nixos.org while only its
    # Magic Nix Cache narinfo/NAR pair remains on GitHub.  Keep that NAR too.
    # Metadata is mandatory: deleting its NAR without knowing the digest would
    # leave the protected narinfo incomplete.
    def protect_github_closure(paths):
        starts = {
            match[1]
            for entry in github_entries
            if entry["ref"] == ref
            and (match := MAGIC_KEY.fullmatch(entry["key"]))
            and match[1] in paths
        }
        if starts:
            closure, closure_nars = cached_closure(starts, narinfo)
            protected.update(closure)
            nars.update(closure_nars)

    protect_github_closure(protected)

    pins = api.request(f"/api/v1/cache/{cache}/pin")
    if not isinstance(pins, list):
        raise ValueError("Unexpected Cachix pins response")
    # GET pin exposes only lastRevision, not the retained revision histories.
    # Preserve the entire cache when those histories cannot be proven safe, but
    # only after current roots and GitHub NAR protection have been validated.
    if pins:
        protected.update(available)
        print("Cachix GC skipped: existing pins may retain historical closures.", flush=True)
        # Historical pin revisions are not enumerable. Retain every GitHub NAR
        # rather than guessing which ones those old Cachix closures require.
        return set(), protected, None
    return available - protected, protected, nars


def github_caches(api, repository):
    entries = []
    page = 1
    while True:
        data = api.request(f"/repos/{repository}/actions/caches?per_page=100&page={page}")
        batch = data["actions_caches"]
        entries.extend(batch)
        if len(batch) < 100:
            return entries
        page += 1


def github_plan(entries, protected, nars, ref):
    obsolete = []
    for entry in entries:
        match = MAGIC_KEY.fullmatch(entry["key"])
        if entry["ref"] != ref or not match:
            continue
        if match[1] and match[1] not in protected:
            obsolete.append(entry)
        elif match[2] and nars is not None and match[2] not in nars:
            obsolete.append(entry)
    return obsolete


def at_revision(api, repository, branch, revision):
    ref = urllib.parse.quote(branch, safe="")
    return api.request(f"/repos/{repository}/git/ref/heads/{ref}")["object"]["sha"] == revision


def run_gc(github, cachix, upstream, repository, branch, revision, cache, system, apply):
    if not at_revision(github, repository, branch, revision):
        print("GC skipped: a newer default-branch revision has not passed this build.", flush=True)
        return
    roots, protected = current_paths(system)
    github_entries = github_caches(github, repository)
    obsolete, protected, nars = cachix_plan(
        cachix, upstream, cache, roots, protected, github_entries, f"refs/heads/{branch}"
    )
    entries = github_plan(github_entries, protected, nars, f"refs/heads/{branch}")
    # Finish all reads and validate the complete plan before either deletion API.
    if not at_revision(github, repository, branch, revision):
        print("GC skipped: the default branch changed while planning.", flush=True)
        return
    print(f"GC plan: {len(obsolete)} Cachix paths, {len(entries)} GitHub cache entries", flush=True)
    for value in sorted(obsolete):
        print(f"{'Delete' if apply else 'Would delete'} Cachix {cache}/{value}", flush=True)
        if apply:
            cachix.request(f"/api/v1/cache/{cache}/{value}.narinfo", method="DELETE", missing_ok=True)
    for entry in entries:
        print(f"{'Delete' if apply else 'Would delete'} GitHub cache {entry['id']} ({entry['key']})", flush=True)
        if apply:
            github.request(f"/repos/{repository}/actions/caches/{entry['id']}", method="DELETE", missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--revision", required=True)
    parser.add_argument("--branch", required=True)
    parser.add_argument("--repository", default=os.environ.get("GITHUB_REPOSITORY"), required=not os.environ.get("GITHUB_REPOSITORY"))
    parser.add_argument("--cache", default="jodtv")
    parser.add_argument("--system", default="x86_64-linux")
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    if not re.fullmatch(r"[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+", args.repository):
        parser.error("invalid repository")
    if not re.fullmatch(r"[a-z0-9-]+", args.cache):
        parser.error("invalid cache name")
    github = API("https://api.github.com", os.environ.get("GITHUB_TOKEN"))
    cachix = API(
        "https://app.cachix.org",
        os.environ.get("CACHIX_GC_AUTH_TOKEN") or os.environ.get("CACHIX_AUTH_TOKEN"),
    )
    run_gc(github, cachix, API("https://cache.nixos.org"), args.repository,
           args.branch, args.revision, args.cache, args.system, args.apply)


if __name__ == "__main__":
    main()

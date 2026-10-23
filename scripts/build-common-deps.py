#!/usr/bin/env python3
"""Build shared Nix derivations before the independent package matrix.

Compare exact derivation paths, including transitive dependencies. Build the
shared nodes at the boundary of each independent package's dependency graph;
Nix orders and deduplicates their own dependencies within the same store.
The workflow waits for this job's Cachix uploads before starting the matrix.
"""

import argparse
from collections import defaultdict
import json
import os
from pathlib import Path
import subprocess


def nix_json(*args):
    return json.loads(subprocess.check_output(["nix", *args], text=True))


def normalize_graph(document, store_dir):
    def path(value):
        return value if value.startswith("/") else f"{store_dir}/{value}"

    # Nix 2.34 uses a versioned envelope and store-relative paths.
    derivations = document.get("derivations", document)
    return {
        path(drv): {
            path(dep): set(info["outputs"] if isinstance(info, dict) else info)
            for dep, info in (data["inputDrvs"] if "inputDrvs" in data else data["inputs"]["drvs"]).items()
        }
        for drv, data in derivations.items()
    }


def plan_build(roots, graph):
    consumers = defaultdict(set)
    required_outputs = defaultdict(set)
    for name, root in roots.items():
        required_outputs[root["drvPath"]].update(root["outputs"])
        pending = [root["drvPath"]]
        seen = set()
        while pending:
            drv = pending.pop()
            if drv in seen:
                continue
            seen.add(drv)
            consumers[drv].add(name)
            for dep, outputs in graph[drv].items():
                required_outputs[dep].update(outputs)
                pending.append(dep)

    shared = {drv for drv, names in consumers.items() if len(names) > 1}
    # Every path from a remaining package into the shared graph crosses one of
    # these nodes. Keep all crossings, even when one shared node depends on
    # another: a substituted parent need not realize its build dependencies.
    boundary = {
        dep for parent in consumers if parent not in shared
        for dep in graph[parent] if dep in shared
    }
    boundary.update(root["drvPath"] for root in roots.values() if root["drvPath"] in shared)
    targets = {
        drv: sorted(required_outputs[drv]) for drv in sorted(boundary)
    }
    remaining = [name for name, root in roots.items() if root["drvPath"] not in shared]
    return targets, remaining, consumers


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--system", default="x86_64-linux")
    parser.add_argument("--packages", default="", help="Space/comma-separated names; empty selects all")
    parser.add_argument("--build", action="store_true", help="Build the plan; otherwise only display it")
    args = parser.parse_args()
    attr = f".#packages.{args.system}"
    available = nix_json("eval", "--impure", "--json", attr, "--apply", "builtins.attrNames")
    requested = list(dict.fromkeys(args.packages.replace(",", " ").split()))
    unknown = sorted(set(requested) - set(available))
    if unknown:
        parser.error("Unknown packages: " + ", ".join(unknown))
    selected = requested or available
    names = "[ " + " ".join(json.dumps(name) for name in selected) + " ]"
    roots = nix_json(
        "eval", "--impure", "--json", attr, "--apply",
        "ps: builtins.listToAttrs (map (name: { inherit name; "
        "value = { inherit (ps.${name}) drvPath outputs; }; }) " + names + ")",
    )
    document = nix_json("derivation", "show", "--recursive", *[r["drvPath"] for r in roots.values()])
    store_dir = str(Path(next(iter(roots.values()))["drvPath"]).parent)
    targets, remaining, consumers = plan_build(roots, normalize_graph(document, store_dir))
    print(f"Shared dependency targets: {len(targets)}", flush=True)
    for drv in targets:
        print(f"  {Path(drv).name}: {', '.join(sorted(consumers[drv]))}", flush=True)
    print("Package matrix: " + ", ".join(remaining), flush=True)
    if args.build:
        if targets:
            # --stdin avoids command-length limits. Request every consumed output
            # (e.g. FFmpeg bin/dev/lib), rather than only the default output.
            subprocess.run(
                ["nix", "build", "--no-link", "--print-build-logs", "--stdin"],
                input="".join(f"{drv}^{','.join(outputs)}\n" for drv, outputs in targets.items()),
                text=True, check=True,
            )
        if os.environ.get("GITHUB_OUTPUT"):
            with open(os.environ["GITHUB_OUTPUT"], "a") as output:
                output.write("packages=" + json.dumps(remaining) + "\n")


if __name__ == "__main__":
    main()

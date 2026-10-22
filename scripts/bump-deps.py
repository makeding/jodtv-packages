#!/usr/bin/env python3
"""Update this flake's packaged sources and dependency hashes with nix-update."""
import argparse
import json
import os
import platform
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
# These track release tags; other packages track their default branch.
RELEASES = {"mirakc", "mirakc-arib", "intel-media-sdk-h", "qsvencc", "psisimux", "tsreadex"}
SUBPACKAGES = {"honomitv": "frontend", "epgstation-h": "clientDir"}
ALIASES = {"konomitv": "honomitv", "epgstation": "epgstation-h"}
EXCLUDED = {"konomitv", "ffmpeg-libaribtlv"}


def native_system():
    machine = {"arm64": "aarch64", "AMD64": "x86_64"}.get(platform.machine(), platform.machine())
    return f"{machine}-{platform.system().lower()}"


def refresh_epgstation_version(system):
    # Forks without release tags are reported as version 0 by nix-update.
    # Read the actual application version from the freshly fetched source.
    result = subprocess.run(
        ["nix", "build", "--no-link", "--print-out-paths",
         f".#packages.{system}.epgstation-h.src"],
        cwd=ROOT, check=True, stdout=subprocess.PIPE, text=True,
    )
    source = Path(result.stdout.strip())
    version = json.loads((source / "package.json").read_text())["version"]
    if not re.fullmatch(r"[0-9A-Za-z.+-]+", version):
        raise ValueError("Invalid EPGStation package version")
    package = ROOT / "pkgs/epgstation-h/package.nix"
    text = package.read_text()
    text = re.sub(r'version = "[^"\n]+(-unstable-\d{4}-\d{2}-\d{2})";',
                  lambda match: f'version = "{version}{match[1]}";', text, count=1)
    package.write_text(text)


def packages():
    return sorted(p.parent.name for p in (ROOT / "pkgs").glob("*/package.nix")
                  if p.parent.name not in EXCLUDED)


def commands(names, args):
    for name in names:
        mode = args.version or ("stable" if name in RELEASES else "branch")
        cmd = ["nix-update", name, "--flake", "--system", args.system,
               "--version", mode, "--override-filename", f"pkgs/{name}/package.nix"]
        if name == "intel-media-sdk-h":
            cmd += ["--version-regex", "intel-mediasdk-(.*)"]
        if name in SUBPACKAGES:
            cmd += ["--subpackage", SUBPACKAGES[name]]
        if args.build:
            cmd += ["--build"]
        yield cmd


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("packages", nargs="*", help="package names (also accepts konomitv and epgstation aliases)")
    parser.add_argument("--all", action="store_true", help="update all supported packages serially")
    parser.add_argument("--list", action="store_true", help="list supported packages")
    parser.add_argument("--dry-run", action="store_true", help="print commands without network access or writes")
    parser.add_argument("--version", help="nix-update version: stable, branch, branch=NAME, skip, or explicit version")
    parser.add_argument("--system", default=native_system(), help="evaluation/build system (default: native host; foreign systems require a matching builder)")
    parser.add_argument("--build", action="store_true", help="also build updated packages; needs a matching builder")
    args = parser.parse_args(argv)
    available = packages()
    if args.list:
        print("\n".join(available))
        return 0
    if args.all and args.packages:
        parser.error("use either package names or --all")
    names = list(dict.fromkeys(ALIASES.get(p, p) for p in args.packages))
    if args.all:
        names = available
    if not names:
        parser.error("specify package names or --all (use --list to inspect)")
    unknown = set(names) - set(available)
    if unknown:
        parser.error("unsupported packages: " + ", ".join(sorted(unknown)))
    if not re.fullmatch(r"[a-z0-9_]+-(linux|darwin)", args.system):
        parser.error("invalid --system")
    if not args.dry_run and not shutil.which("nix-update"):
        # Use an ephemeral Nix environment, preserving arguments as individual words.
        command = shlex.join([sys.executable, str(Path(__file__).resolve()), *sys.argv[1:]])
        os.execvp("nix-shell", ["nix-shell", "-p", "nix-update", "--run", command])
    for name, command in zip(names, commands(names, args)):
        print("+ " + shlex.join(command), flush=True)
        if args.dry_run:
            continue
        result = subprocess.run(command, cwd=ROOT, check=False)
        if result.returncode:
            print("Update failed; inspect git diff before retrying. Partial edits are preserved.", file=sys.stderr)
            return result.returncode
        if name == "epgstation-h" and (args.version is None or args.version.startswith("branch")):
            refresh_epgstation_version(args.system)
    return 0


if __name__ == "__main__":
    sys.exit(main())

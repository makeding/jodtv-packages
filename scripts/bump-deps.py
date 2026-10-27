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
import tomllib
from urllib.parse import quote, urlencode

ROOT = Path(__file__).resolve().parent.parent
# These track release tags; other packages track their default branch.
RELEASES = {"mirakc", "mirakc-arib", "mmt2ts", "intel-media-sdk-h", "qsvencc", "psisimux", "tsreadex", "amatsukaze", "nvencc"}
SUBPACKAGES = {"honomitv": "frontend", "konomitv": "frontend",
               "epgstation-h": "clientDir", "epgstation-upstream": "clientDir",
               "amatsukaze": "sourceBuild", "nvencc": "sourceBuild"}
ALIASES = {"epgstation": "epgstation-h"}
# The firmware pin also has an independently verified extracted SYS checksum.
EXCLUDED = {"a865r-firmware", "ffmpeg-libaribtlv", "edcb-wine"}
MANIFESTS = {
    "epgstation-h": ("package.json", "json"),
    "epgstation-upstream": ("package.json", "json"),
    "konomitv": ("server/pyproject.toml", "project"),
    "honomitv": ("server/pyproject.toml", "project"),
    "mirakurun": ("package.json", "json"),
    "recisdb": ("recisdb-rs/Cargo.toml", "package"),
    **{name: ("CMakeLists.txt", "cmake") for name in
       ("libaribb25", "libaribb61", "libaribtlv", "librw5100", "pcsc-rw5100")},
    "recdvb": ("configure.ac", "autoconf"),
    "recpt1": ("recpt1/configure.ac", "autoconf"),
    "tsreplace": ("app/rgy_version.h", "header"),
}


def native_system():
    machine = {"arm64": "aarch64", "AMD64": "x86_64"}.get(platform.machine(), platform.machine())
    return f"{machine}-{platform.system().lower()}"


def fetch(url):
    # Use the host's TLS-verified curl, including its normal CA/keychain support.
    return subprocess.run(
        ["curl", "--fail", "--silent", "--show-error", "--location",
         "--max-time", "60", url], check=True, stdout=subprocess.PIPE, text=True,
    ).stdout


def manifest_version(contents, kind):
    if kind == "json":
        version = json.loads(contents)["version"]
    elif kind in ("project", "package"):
        version = tomllib.loads(contents)[kind]["version"]
    else:
        patterns = {
            "cmake": r'(?is)\bproject\s*\([^)]*?\bVERSION\s+"?([0-9][0-9A-Za-z.+-]*)',
            "autoconf": r'AC_INIT\s*\(\s*\[[^]]+\]\s*,\s*\[([^]]+)\]',
            "header": r'(?m)^\s*#define\s+VER_STR_FILEVERSION\s+"([^"]+)"',
        }
        match = re.search(patterns[kind], contents)
        if not match:
            raise ValueError(f"Missing {kind} source version")
        version = match[1]
    if not isinstance(version, str) or not re.fullmatch(r"[0-9][0-9A-Za-z.+-]*", version):
        raise ValueError(f"Invalid source version: {version!r}")
    return version


def prepare_branch(name, mode):
    """Resolve an exact commit and its own manifest before writing any edits."""
    package = ROOT / f"pkgs/{name}/package.nix"
    original = package.read_text()
    github = re.search(r'owner = "([^"]+)";\s*repo = ("[^"]+"|pname);', original)
    archive = re.search(r'https://([^/]+)/([^/]+/[^/]+)/archive/([0-9a-f]{40})\.tar\.gz', original)
    branch = mode.partition("=")[2] if "=" in mode else "HEAD"
    if github:
        repo = re.search(r'pname = "([^"]+)";', original)[1] if github[2] == "pname" else github[2].strip('"')
        repository = f"{github[1]}/{repo}"
        commit = json.loads(fetch(f"https://api.github.com/repos/{repository}/commits/{quote(branch, safe='')}"))
        raw_base = f"https://raw.githubusercontent.com/{repository}"
    elif archive:
        host, repository = archive[1], archive[2]
        query = urlencode({"sha": branch, "limit": 1})
        commit = json.loads(fetch(f"https://{host}/api/v1/repos/{repository}/commits?{query}"))[0]
        raw_base = f"https://{host}/{repository}/raw/commit"
    else:
        raise ValueError(f"No branch source configured for {name}")
    revision = commit["sha"]
    date = commit["commit"]["committer"]["date"][:10]
    if not re.fullmatch(r"[0-9a-f]{40}", revision) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", date):
        raise ValueError(f"Invalid commit metadata for {name}")
    version = f"unstable-{date}"
    if name in MANIFESTS:
        path, kind = MANIFESTS[name]
        declared = manifest_version(fetch(f"{raw_base}/{revision}/{path}"), kind)
        version = f"{declared}-{version}"
    updated, count = re.subn(r'(?m)^(\s*version = ")[^"\n]+(";)',
                             lambda m: m[1] + version + m[2], original, count=1)
    if count != 1:
        raise ValueError(f"Missing version declaration for {name}")
    if github:
        updated, count = re.subn(r'(?m)^(\s*rev = ")[^"\n]+(";)',
                                 lambda m: m[1] + revision + m[2], updated, count=1)
        if count != 1:
            raise ValueError(f"{name} must pin src.rev independently of version")
    else:
        updated = updated.replace(archive[0], archive[0].replace(archive[3], revision), 1)
    print(f"{name}: {version} (commit {revision})", flush=True)
    if updated != original:
        package.write_text(updated)


def version_mode(name, args):
    return args.version or ("stable" if name in RELEASES else "branch")


def packages():
    return sorted(p.parent.name for p in (ROOT / "pkgs").glob("*/package.nix")
                  if p.parent.name not in EXCLUDED)


def commands(names, args):
    for name in names:
        mode = version_mode(name, args)
        attribute = name if args.build else f"legacyPackages.{args.system}.{name}"
        cmd = ["nix-update", attribute, "--flake", "--system", args.system,
               "--version", "skip" if mode.startswith("branch") else mode,
               "--override-filename", f"pkgs/{name}/package.nix"]
        if name == "intel-media-sdk-h":
            cmd += ["--version-regex", "intel-mediasdk-(.*)"]
        if name in SUBPACKAGES:
            cmd += ["--subpackage", SUBPACKAGES[name]]
        if args.build:
            cmd += ["--build"]
        yield cmd


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("packages", nargs="*", help="package names (also accepts the epgstation alias)")
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
        mode = version_mode(name, args)
        if mode.startswith("branch"):
            if args.dry_run:
                print(f"+ resolve {name} {mode} commit and source manifest", flush=True)
            else:
                prepare_branch(name, mode)
        print("+ " + shlex.join(command), flush=True)
        if args.dry_run:
            continue
        result = subprocess.run(command, cwd=ROOT, check=False)
        if result.returncode:
            print("Update failed; inspect git diff before retrying. Partial edits are preserved.", file=sys.stderr)
            return result.returncode
    return 0


if __name__ == "__main__":
    sys.exit(main())

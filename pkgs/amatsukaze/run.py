"""Keep Amatsukaze's writable application layout outside the Nix store."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys


def managed(relative):
    return (relative.parts[0] in {"exe_files", "scripts"}
            and relative.suffix.lower() not in {".txt", ".xml", ".config"})


def initialize(bundle, state):
    marker = state / ".amatsukaze-package.json"
    old = json.loads(marker.read_text()) if marker.exists() else {}
    if old.get("package") == str(bundle):
        return
    current = []
    for source in sorted(bundle.rglob("*")):
        if source.is_dir():
            continue
        relative = source.relative_to(bundle)
        owned = managed(relative)
        if owned:
            current.append(relative.as_posix())
        destination = state / relative
        if owned or not destination.exists():
            destination.parent.mkdir(parents=True, exist_ok=True)
            if destination.is_symlink():
                destination.unlink()
            if source.is_symlink():
                destination.symlink_to(os.readlink(source))
            else:
                shutil.copyfile(source, destination)
                destination.chmod(source.stat().st_mode & 0o777 | 0o200)
    for name in set(old.get("files", [])) - set(current):
        relative = Path(name)
        if not relative.is_absolute() and ".." not in relative.parts and managed(relative):
            (state / relative).unlink(missing_ok=True)
    for directory in ("config", "log", "logo", "drcs", "avscache"):
        (state / directory).mkdir(parents=True, exist_ok=True)
    pending = marker.with_suffix(".new")
    pending.write_text(json.dumps({"package": str(bundle), "files": current}))
    pending.replace(marker)


def invoke(command, cwd, env):
    process = subprocess.Popen(command, cwd=cwd, env=env)
    previous = {}
    try:
        for sig in (signal.SIGINT, signal.SIGTERM):
            previous[sig] = signal.signal(sig, lambda number, _frame: process.send_signal(number))
        code = process.wait()
        return code if code >= 0 else 128 - code
    finally:
        for sig, handler in previous.items():
            signal.signal(sig, handler)


def main():
    parser = argparse.ArgumentParser(description="Run Amatsukaze with persistent user-owned configuration.")
    parser.add_argument("--bundle", type=Path, required=True, help=argparse.SUPPRESS)
    data = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share")
    parser.add_argument("--state-dir", type=Path,
                        default=Path(os.environ.get("AMATSUKAZE_STATE_DIR") or data / "amatsukaze"),
                        help="application data directory (default: %(default)s)")
    parser.add_argument("command", nargs="?", default="server", choices=("server", "cli", "add-task", "gen-logo"))
    parser.add_argument("arguments", nargs=argparse.REMAINDER, help="arguments passed to the selected program")
    args = parser.parse_args()
    programs = {"server": "AmatsukazeServerCLI", "cli": "AmatsukazeCLI",
                "add-task": "AmatsukazeAddTask", "gen-logo": "AmatsukazeGenLogo"}
    arguments = args.arguments[1:] if args.arguments[:1] == ["--"] else args.arguments
    env = os.environ.copy()
    env["AMT_ENABLE_SELF_UPDATE"] = "0"
    if args.command in {"cli", "gen-logo"}:
        return invoke([str(args.bundle / "exe_files" / programs[args.command]), *arguments], None, env)

    state = args.state_dir.expanduser().resolve()
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (state / ".session.lock").open("a") as session, (state / ".server.lock").open("a") as server:
        try:
            fcntl.flock(session, fcntl.LOCK_SH | fcntl.LOCK_NB)
            if args.command == "server":
                fcntl.flock(server, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            parser.exit(1, "Amatsukaze is starting or its server is already running in this directory. Use add-task or another --state-dir.\n")
        marker = state / ".amatsukaze-package.json"
        saved = json.loads(marker.read_text()) if marker.exists() else {}
        if saved.get("package") != str(args.bundle):
            try:
                fcntl.flock(session, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                parser.exit(1, "Stop Amatsukaze and AddTask before upgrading, then run this command again.\n")
            initialize(args.bundle, state)
            fcntl.flock(session, fcntl.LOCK_SH)
        env["PATH"] = str(state / "exe_files") + os.pathsep + env.get("PATH", "")
        print(f"Amatsukaze data: {state}", flush=True)
        return invoke([str(state / "exe_files" / programs[args.command]), *arguments], state, env)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError) as error:
        print(f"Amatsukaze could not start: {error}. Check the data directory and retry.", file=sys.stderr)
        sys.exit(1)

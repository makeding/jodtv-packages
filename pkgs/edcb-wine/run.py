"""Run EDCB in the caller's desktop with persistent, user-owned Wine state."""
import argparse
import fcntl
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys


def port(value):
    try:
        number = int(value)
        if 1 <= number <= 65535:
            return number
    except ValueError:
        pass
    raise argparse.ArgumentTypeError("port must be between 1 and 65535")


def invoke(command, env, cwd):
    process = subprocess.Popen(command, env=env, cwd=cwd)
    previous = {}
    try:
        for sig in (signal.SIGINT, signal.SIGTERM):
            previous[sig] = signal.signal(sig, lambda number, _frame: process.send_signal(number))
        code = process.wait()
        return code if code >= 0 else 128 - code
    finally:
        for sig, handler in previous.items():
            signal.signal(sig, handler)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Run EDCB in your current X11/XWayland desktop.")
    parser.add_argument("command", nargs="?", default="server", choices=("server", "capture", "scan-gr", "scan-bs"),
                        help="server (default), capture window, terrestrial scan, or satellite scan")
    data = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share")
    parser.add_argument("--state-dir", type=Path, default=data / "edcb-wine", help="persistent data directory (default: %(default)s)")
    parser.add_argument("--backend-host", help="Mirakurun/mirakc host; saved for later launches (initial default: localhost)")
    parser.add_argument("--backend-port", type=port, help="Mirakurun/mirakc port; saved for later launches (initial default: 40772)")
    for name in ("bundle", "wine-bin", "font", "fontconfig", "initializer"):
        parser.add_argument(f"--{name}", type=Path, required=True, help=argparse.SUPPRESS)
    args = parser.parse_args(argv)
    if not os.environ.get("DISPLAY"):
        parser.exit(1, "EDCB needs an X11 desktop. Run it in a desktop terminal; on Wayland, enable XWayland.\n")
    if args.backend_host is not None and (not args.backend_host or any(c in args.backend_host for c in '\r\n"')):
        parser.error("backend host must be a hostname or IP address")

    state = args.state_dir.expanduser().resolve()
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    prefix = state / "wineprefix"
    target = state / "EDCB"
    env = os.environ.copy()
    env.update(WINEPREFIX=str(prefix), WINEARCH="win64", TZ="Asia/Tokyo",
               WINEDLLOVERRIDES=env.get("WINEDLLOVERRIDES", "mscoree,mshtml="),
               FONTCONFIG_FILE=str(args.fontconfig))
    # Shared locks let capture/scan windows coexist with the server. Updates
    # require exclusive access so running programs never see replaced binaries.
    with (state / ".desktop-session.lock").open("a") as session, (state / ".desktop-server.lock").open("a") as server:
        try:
            fcntl.flock(session, fcntl.LOCK_SH | fcntl.LOCK_NB)
            if args.command == "server":
                fcntl.flock(server, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            parser.exit(1, "EDCB is already starting or its server is running in this directory. Use capture/scan, or choose another --state-dir.\n")
        marker = state / ".desktop-launch.json"
        saved = json.loads(marker.read_text()) if marker.exists() else {}
        desired = {
            "package": str(args.bundle), "wine": str(args.wine_bin),
            "host": args.backend_host if args.backend_host is not None else saved.get("host", "localhost"),
            "port": args.backend_port if args.backend_port is not None else saved.get("port", 40772),
        }
        if saved != desired or not (prefix / "system.reg").exists():
            try:
                fcntl.flock(session, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                parser.exit(1, "Close EDCB and its capture/scan windows before updating the program or backend, then run this command again.\n")
            spec = importlib.util.spec_from_file_location("edcb_initializer", args.initializer)
            initializer = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(initializer)
            initializer.initialize(args.bundle, state, state / "recordings", state / "recording-info", desired["host"], desired["port"])
            boot = "--init" if not (prefix / "system.reg").exists() else "-u"
            if saved.get("wine") != desired["wine"] or not (prefix / "system.reg").exists():
                for command in (("wineboot", boot), ("wineserver", "-w")):
                    code = invoke([str(args.wine_bin / command[0]), *command[1:]], env, target)
                    if code:
                        parser.exit(code, "Wine initialization failed; check the Wine output above and retry.\n")
            fonts = prefix / "drive_c/windows/Fonts"
            fonts.mkdir(parents=True, exist_ok=True)
            font_link = fonts / "NotoSansCJK-VF.ttc"
            if font_link.is_symlink():
                font_link.unlink()
            if not font_link.exists():
                font_link.symlink_to(args.font)
            registry = state / "desktop-fonts.reg"
            registry.write_text('REGEDIT4\n\n[HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts]\n'
                                '"Noto Sans CJK JP (TrueType)"="NotoSansCJK-VF.ttc"\n\n'
                                '[HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes]\n'
                                + ''.join(f'"{name}"="Noto Sans CJK JP"\n' for name in
                                          ("MS Shell Dlg", "MS Shell Dlg 2", "MS Gothic", "MS PGothic", "MS UI Gothic", "Tahoma")))
            code = invoke([str(args.wine_bin / "regedit"), "/S", str(registry)], env, target)
            if code:
                parser.exit(code, "Japanese font setup failed; check the Wine output above and retry.\n")
            pending = marker.with_suffix(".new")
            pending.write_text(json.dumps(desired))
            pending.replace(marker)
            fcntl.flock(session, fcntl.LOCK_SH)

        command = [str(args.wine_bin / "wine"), "EpgTimerSrv.exe" if args.command == "server" else "EpgDataCap_Bon.exe"]
        if args.command.startswith("scan-"):
            command += ["-d", "BonDriver_mirakc_T.dll" if args.command == "scan-gr" else "BonDriver_mirakc_S.dll", "-chscan"]
        print(f"EDCB data: {state}", flush=True)
        return invoke(command, env, target)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError) as error:
        print(f"EDCB could not start: {error}. Check directory permissions and the saved configuration, then retry.", file=sys.stderr)
        sys.exit(1)

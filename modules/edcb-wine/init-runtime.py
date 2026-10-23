"""Synchronize managed EDCB programs while preserving writable application state."""
import json
from pathlib import Path
import shutil
import sys


def read_ini(path):
    data = path.read_bytes()
    if data.startswith((b"\xff\xfe", b"\xfe\xff")):
        return data.decode("utf-16"), "utf-16"
    if b"\0" in data:
        return data.decode("utf-16-le"), "utf-16-le"
    # Bundled examples are ASCII; user INIs may also use Japanese Windows text.
    try:
        return data.decode("utf-8-sig"), "utf-8-sig" if data.startswith(b"\xef\xbb\xbf") else "utf-8"
    except UnicodeDecodeError:
        return data.decode("cp932"), "cp932"


def set_keys(path, section, values):
    text, encoding = read_ini(path)
    lines = text.splitlines()
    start = next((i for i, line in enumerate(lines) if line.strip().lower() == f"[{section}]".lower()), None)
    if start is None:
        lines.extend([f"[{section}]", *(f"{key}={value}" for key, value in values.items())])
    else:
        end = next((i for i in range(start + 1, len(lines)) if lines[i].strip().startswith("[")), len(lines))
        remaining = dict(values)
        for i in range(start + 1, end):
            key = lines[i].partition("=")[0].strip()
            if key in remaining:
                lines[i] = f"{key}={remaining.pop(key)}"
        lines[end:end] = [f"{key}={value}" for key, value in remaining.items()]
    path.write_bytes(("\r\n".join(lines) + "\r\n").encode(encoding))


def managed(path):
    return path.parts[0] != "Setting" and path.suffix.lower() not in {".ini", ".txt", ".ch2", ".chset"}


def windows_path(path):
    return "Z:" + str(path).replace("/", "\\")


def initialize(template, state, recording, info, host, port):
    target = state / "EDCB"
    for path in (target, state / "home", state / "wineprefix", state / "fontconfig-cache", recording, info):
        path.mkdir(parents=True, exist_ok=True)
    marker = state / ".edcb-package.json"
    old = json.loads(marker.read_text()) if marker.exists() else {}
    current = []
    for source in sorted(template.rglob("*")):
        if not source.is_file():
            continue
        relative = source.relative_to(template)
        if relative.parts[0] == "bin":
            continue
        destination = target / relative
        owned = managed(relative)
        if owned:
            current.append(relative.as_posix())
        if not destination.exists() or (owned and old.get("package") != str(template)):
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, destination)
            destination.chmod(0o600)
    for name in set(old.get("files", [])) - set(current):
        relative = Path(name)
        if not relative.is_absolute() and ".." not in relative.parts and managed(relative):
            (target / relative).unlink(missing_ok=True)
    for name in ("Common", "EpgDataCap_Bon", "EpgTimerSrv"):
        path = target / f"{name}.ini"
        if path.exists():
            continue
        shutil.copyfile(target / f"{name}.example.ini", path)
        if name == "Common":
            set_keys(path, "SET", {"RecFolderPath0": windows_path(recording), "RecInfoFolder": windows_path(info)})
        elif name == "EpgTimerSrv":
            set_keys(path, "TVTEST", {"Num": 3, "0": "BonDriver_mirakc.dll", "1": "BonDriver_mirakc_T.dll", "2": "BonDriver_mirakc_S.dll"})
            for driver, count, priority in (("", 0, 0), ("_T", 2, 1), ("_S", 2, 2)):
                set_keys(path, f"BonDriver_mirakc{driver}.dll", {"Count": count, "GetEpg": int(count > 0), "EPGCount": int(count > 0), "Priority": priority})
    for path in (target / "BonDriver").glob("BonDriver_mirakc*.ini"):
        # Preserve BonDriver sections and unrelated settings verbatim.
        text, encoding = read_ini(path)
        lines = text.splitlines()
        values = {"SERVER_HOST": f'"{host}"', "SERVER_PORT": str(port)}
        for i, line in enumerate(lines):
            key = line.partition("=")[0].strip()
            if key in values:
                lines[i] = f"{key}={values.pop(key)}"
        lines.extend(f"{key}={value}" for key, value in values.items())
        path.write_bytes(("\r\n".join(lines) + "\r\n").encode(encoding))
    batches = {
        "Open_EDCB_Folder.bat": f'explorer.exe /e,"{windows_path(target)}"',
        "Open_EpgDataCap_Bon.bat": 'start "" EpgDataCap_Bon.exe',
        "ChannelScan_mirakc_T.bat": 'start "" EpgDataCap_Bon.exe -d BonDriver_mirakc_T.dll -chscan',
        "ChannelScan_mirakc_S.bat": 'start "" EpgDataCap_Bon.exe -d BonDriver_mirakc_S.dll -chscan',
    }
    for name, command in batches.items():
        (target / name).write_bytes((f'@echo off\r\ncd /d "{windows_path(target)}"\r\n{command}\r\n').encode("utf-8"))
    pending = marker.with_suffix(".new")
    pending.write_text(json.dumps({"package": str(template), "files": current}))
    pending.replace(marker)


if __name__ == "__main__":
    initialize(*(Path(value) for value in sys.argv[1:5]), *sys.argv[5:7])

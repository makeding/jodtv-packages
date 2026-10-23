"""Verify loader wrapping preserves self-contained .NET hosts byte for byte."""
from pathlib import Path
import sys
import tarfile

programs = {"AmatsukazeServerCLI", "AmatsukazeAddTask", "ScriptCommand", "AmatsukazeDockerConfigFix"}
seen = set()
with tarfile.open(sys.argv[1], mode="r|xz") as archive:
    for member in archive:
        name = Path(member.name)
        if name.parent.as_posix() != "exe_files" or name.name not in programs:
            continue
        original = archive.extractfile(member).read()
        patched = (Path(sys.argv[2]) / name.parent / f".{name.name}-unwrapped").read_bytes()
        assert original == patched, name
        wrapper = (Path(sys.argv[2]) / name).read_text()
        assert '"$directory/.$program-unwrapped" "$@"' in wrapper, name
        seen.add(name.name)
assert seen == programs, seen

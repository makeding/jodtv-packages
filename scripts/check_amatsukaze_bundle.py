"""Verify loader wrapping preserves self-contained .NET hosts byte for byte."""
from pathlib import Path
import struct
import sys
import tarfile

SIGNATURE = bytes.fromhex("8b1202b96a612038604f927b930386774bae13f61e9ecec0945a5633a23c0239")
programs = {"AmatsukazeServerCLI", "AmatsukazeAddTask", "ScriptCommand"}
seen = set()
with tarfile.open(sys.argv[1], mode="r|xz") as archive:
    for member in archive:
        name = Path(member.name)
        if name.parent.as_posix() != "exe_files" or name.name not in programs:
            continue
        original = archive.extractfile(member).read()
        patched = (Path(sys.argv[2]) / name.parent / f".{name.name}-unwrapped").read_bytes()
        signature = original.index(SIGNATURE)
        original_offset = struct.unpack_from("<Q", original, signature - 8)[0]
        patched_offset = struct.unpack_from("<Q", patched, patched.index(SIGNATURE) - 8)[0]
        assert original_offset == patched_offset, name
        assert original[original_offset:] == patched[patched_offset:len(original)], name
        assert original == patched, name
        seen.add(name.name)
assert seen == programs, seen

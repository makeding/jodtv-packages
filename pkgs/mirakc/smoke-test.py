"""Exercise the installed server with no tuners or persistent state."""
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import time
from urllib.error import URLError
from urllib.request import build_opener, ProxyHandler

binary, version = sys.argv[1:]
# This file lives only in the Nix test build directory and is removed in finally.
config = Path("mirakc-smoke.yml").resolve()
assert not config.exists(), config
with socket.socket() as sock:
    sock.bind(("127.0.0.1", 0))
    port = sock.getsockname()[1]
process = None
try:
    config.write_text(f"server:\n  addrs:\n    - http: '127.0.0.1:{port}'\nchannels: []\ntuners: []\n")
    process = subprocess.Popen(
        [binary, "--config", str(config)],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        env={**os.environ, "RUST_LOG": "error"}, text=True,
    )
    opener = build_opener(ProxyHandler({}))
    deadline = time.monotonic() + 30
    while True:
        if process.poll() is not None:
            raise AssertionError(f"server exited with {process.returncode}")
        try:
            with opener.open(f"http://127.0.0.1:{port}/api/version", timeout=1) as response:
                assert response.status == 200
                actual = json.load(response)
            assert actual == {"current": version, "latest": version}, actual
            print("GET /api/version:", actual)
            break
        except URLError:
            if time.monotonic() >= deadline:
                raise
            time.sleep(0.1)
finally:
    if process is not None:
        process.terminate()
        try:
            output, _ = process.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            output, _ = process.communicate()
        if output:
            print(output, end="")
    config.unlink(missing_ok=True)

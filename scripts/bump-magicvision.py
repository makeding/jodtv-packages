#!/usr/bin/env python3
"""Update the mAgicVISION driver and firmware from one published release."""

import json
import os
from pathlib import Path
import re
import subprocess
from urllib.parse import quote


ROOT = Path(__file__).resolve().parent.parent
REPOSITORY = "makeding/mAgicVISION"
DRIVER = ROOT / "pkgs/magicvision/package.nix"
FIRMWARE = ROOT / "pkgs/magicvision-firmware/package.nix"


def output(*command):
    return subprocess.run(command, check=True, text=True, stdout=subprocess.PIPE).stdout.strip()


def github_json(path):
    command = ["curl", "--fail", "--silent", "--show-error", "--location", "--max-time", "60"]
    if token := os.environ.get("GITHUB_TOKEN"):
        command += ["--header", f"Authorization: Bearer {token}"]
    return json.loads(output(*command, f"https://api.github.com/repos/{REPOSITORY}/{path}"))


def field(contents, name):
    matches = re.findall(rf'(?m)^\s*{re.escape(name)} = "([^"\n]+)";', contents)
    if len(matches) != 1:
        raise ValueError(f"Expected exactly one {name} field")
    return matches[0]


def replace_field(contents, name, value):
    pattern = rf'(?m)^(\s*{re.escape(name)} = ")[^"\n]+(";)'
    updated, count = re.subn(pattern, lambda match: match[1] + value + match[2], contents)
    if count != 1:
        raise ValueError(f"Expected exactly one {name} field")
    return updated


def source_hash(revision):
    url = f"https://github.com/{REPOSITORY}/archive/{revision}.tar.gz"
    base32 = output("nix-prefetch-url", "--unpack", url).splitlines()[0]
    return output("nix", "hash", "convert", "--hash-algo", "sha256", "--to", "sri", base32)


def file_hash(url):
    base32 = output("nix-prefetch-url", url).splitlines()[0]
    return output("nix", "hash", "convert", "--hash-algo", "sha256", "--to", "sri", base32)


def update():
    release = github_json("releases/latest")
    tag = release["tag_name"]
    if not re.fullmatch(r"v[0-9][0-9A-Za-z._-]*", tag):
        raise ValueError(f"Unexpected release tag: {tag!r}")
    assets = [asset for asset in release["assets"]
              if re.fullmatch(r"magicvision-firmware_([0-9][0-9A-Za-z.+~-]*)_all\.deb", asset["name"])]
    if len(assets) != 1:
        raise ValueError(f"Expected one firmware asset for {tag}, found {len(assets)}")
    asset = assets[0]
    version = re.fullmatch(r"magicvision-firmware_([0-9][0-9A-Za-z.+~-]*)_all\.deb", asset["name"])[1]
    url = f"https://github.com/{REPOSITORY}/releases/download/{tag}/{quote(asset['name'], safe='')}"
    if asset["browser_download_url"] != url:
        raise ValueError("Unexpected firmware asset URL")
    commit = github_json(f"commits/{tag}")
    revision = commit["sha"]
    date = commit["commit"]["committer"]["date"][:10]
    if not re.fullmatch(r"[0-9a-f]{40}", revision) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", date):
        raise ValueError("Invalid release commit metadata")

    driver = DRIVER.read_text()
    firmware = FIRMWARE.read_text()
    driver_version = f"unstable-{date}-${{kernel.version}}"
    if (field(driver, "rev") == revision and field(driver, "version") == driver_version
            and field(firmware, "version") == version and field(firmware, "url") == url):
        print(f"mAgicVISION {tag} already pinned ({revision})")
        return False

    driver_hash = source_hash(revision)
    firmware_hash = file_hash(url)
    digest = asset.get("digest")
    if digest and digest != "sha256:" + output("nix", "hash", "convert", "--hash-algo", "sha256",
                                                "--to", "base16", firmware_hash):
        raise ValueError("Firmware download does not match the release asset digest")
    new_driver = replace_field(driver, "version", driver_version)
    new_driver = replace_field(new_driver, "rev", revision)
    new_driver = replace_field(new_driver, "hash", driver_hash)
    new_firmware = replace_field(firmware, "version", version)
    new_firmware = replace_field(new_firmware, "url", url)
    new_firmware = replace_field(new_firmware, "hash", firmware_hash)
    DRIVER.write_text(new_driver)
    FIRMWARE.write_text(new_firmware)
    print(f"mAgicVISION {tag}: {revision}, firmware {version}")
    return True


if __name__ == "__main__":
    update()

# Sample configurations

[日本語](README.md) | **English**

These modules extend an existing NixOS flake; they do not install an operating system.
Copy the whole `samples` directory into your configuration and import one sample
alongside your normal hardware configuration.

| File | Purpose |
| --- | --- |
| [all-in-one.nix](all-in-one.nix) | One PT3 with Mirakurun, EPGStation and HonomiTV on the same machine |
| [hirakud.nix](hirakud.nix) | Export all four PT3 inputs through Hiraku on a capture machine |
| [remote.nix](remote.nix) | Consume those four Hiraku inputs with Mirakurun on a frontend machine |
| [channels.json](channels.json) | Shared example channels; replace them for your reception area |

## Import the three-service setup

```nix
inputs.jodtv-packages = {
  url = "github:makeding/jodtv-packages";
  inputs.nixpkgs.follows = "nixpkgs";
};

# Inside nixpkgs.lib.nixosSystem:
modules = [
  inputs.jodtv-packages.nixosModules.default
  ./hardware-configuration.nix
  ./samples/all-in-one.nix
];
```

`all-in-one.nix` targets x86_64-linux. Mirakurun uses its standard port 40772,
EPGStation uses 20772 (20773 for Socket.IO), and HonomiTV uses 7000.
The sample opens the EPGStation and HonomiTV firewall ports; use it on a trusted network.
HonomiTV uses FFmpeg CPU encoding and reads live TV from Mirakurun plus recordings
from EPGStation. With the Mirakurun backend, schedule recordings in EPGStation.

HonomiTV settings are seeded only on the first start; later application changes
are preserved. See [HonomiTV configuration](../README.en.md#honomitv-configuration).

Before activation:

- Replace `channels.json` with the channels available in your reception area.
- Provision the database password at `/run/secrets/epgstation-db-password` at runtime,
  for example through sops-nix or agenix. Do not embed the password in Nix source.
  The NixOS module configures MariaDB and EPGStation's database.
- Provide enough space at `/var/lib/epgstation/recorded`. Configure a mount or bind
  mount at that path if recordings belong on a separate disk.

The sample enables a CCID card reader. For RW5100, uncomment
`card.rw5100Support = true` and permit the unfree package in your nixpkgs configuration.
Set `dtv.card.enable = false` if your configuration does not use a card reader.

## Split capture and frontend roles

On separate machines, import `hirakud.nix` and `remote.nix` instead of `all-in-one.nix`.
`hirakud.nix` opens port 40773 and exports four PT3 inputs without running Mirakurun.
`remote.nix` installs no local tuner drivers or card reader services.
Set the same shared token on both machines and replace `tuner.example:40773` with
the capture machine's address. The token is included in generated Nix configuration.

If one flake manages both machines, use `dtv.exports.hirakuTuners` with
`lib.mkHirakuTuners` to avoid repeating the tuner inventory on the frontend.
See [Unified configuration](../README.en.md#unified-configuration).

These examples are checked through NixOS configuration evaluation. Linux builds,
service startup and physical reception require separate verification.

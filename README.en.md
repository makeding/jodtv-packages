# jodtv-packages

[日本語](README.md) | **English**

Japanese digital TV packages and reusable NixOS modules.

## Use from a NixOS flake

```nix
inputs.jodtv-packages = {
  url = "github:makeding/jodtv-packages";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Import the modules you need:

```nix
imports = [
  inputs.jodtv-packages.nixosModules.packages
  inputs.jodtv-packages.nixosModules.dtv
];
dtv.tuners = [ { driver = "pt3"; } ];
dtv.hirakud.enable = true;
```

The `packages` module installs the package overlay. Individual service modules
leave the package set to the consumer, so an existing overlay stack and local
overrides keep their ordering. Importing a module does not enable a service.
To use packages without modules, add `inputs.jodtv-packages.overlays.default` to
`nixpkgs.overlays`. The default module includes the overlay and all service
modules with services off.
Mirakurun uses the upstream NixOS module; the EPGStation module extends the
upstream service with support for the external EPG updater.

The tuner module builds drivers against the consuming system's
`boot.kernelPackages`. It does not choose a kernel, channel map, networking,
storage or host-specific module parameters. Compact PT3 entries provide default
device numbering, and PX4 entries include the driver's bundled firmware.
Other required firmware and device-specific settings remain the consumer's responsibility.
PT3, upstream PX4, Siano and TBS6812 drivers are included. The experimental
PX4 PC/SC plugin is not packaged; external readers remain separate packages. Kernel-driver derivations
remain private to the module interface rather than exporting binaries tied to
a different kernel.

`packages.x86_64-linux` exposes the full package set. The aarch64-linux output
omits HonomiTV/KonomiTV and Intel encoding packages until their ARM packaging is
validated. The aarch64-darwin output contains Hiraku, libaribtlv, PSI/SI tools,
tsreadex, tsreplace and the FFmpeg patchset. Output lists are explicit to keep
source-dependent packages from forcing evaluation of unrelated tools.
An output's presence is not a claim that it was built on that platform. HonomiTV and the FFmpeg patchset require source-dependent evaluation;
`--option allow-import-from-derivation false` reports those requirements explicitly.

## Consumer overrides

Recorders accept normal `libaribb25` as a package argument. A consumer can
replace that dependency with its own package without changing this repository:

```nix
final: prev: {
  recpt1 = prev.recpt1.override { libaribb25 = final.myAribLibrary; };
  recdvb = prev.recdvb.override { libaribb25 = final.myAribLibrary; };
}
```

Apply consumer overlays after the jodtv-packages overlay. Other applications retain their
normal dependencies. Credentials, private variants and deployment configuration
belong to the consumer repository and must never be imported here.

## Validation

```sh
nix build --no-link .#checks.x86_64-linux.dependency-injection \
  .#checks.x86_64-linux.dtv
nix build --no-link .#recpt1 .#recdvb
```

Checks cover recorder dependency injection and NixOS
module composition, including the host kernel used for tuner builds. Real Linux
package builds and runtime/device acceptance are separate from evaluation.

Package versions and patches were extracted without importing deployment
repository history. Upstream package licenses continue to apply; do not infer
one license for the bundled upstream projects from this repository.

Some pinned projects do not provide a license grant and are marked unfree; consumers must explicitly permit them in their
own nixpkgs configuration. A public Git repository alone is not a license.

## Unified configuration

Import `nixosModules.default` (overlay and modules), or import
`nixosModules.packages` and `nixosModules.dtv` explicitly. Configure `dtv.tuners`
and `dtv.channels` once; the module generates the Mirakurun configuration and
installs the tools and local drivers selected by each tuner.

Local tuner drivers are `pt3`, `px4`, `siano`, `tbs6812` and generic `dvb`.
Use `mode = []` for a hardware-only declaration. Capturing entries specify a
name (optional), broadcast modes and device. `command` supports an explicit argument list.
`hiraku` connects to a remote Hiraku agent; `remote` connects to a remote
Mirakurun. Remote sources do not install local drivers or enable a local agent.
Each entry supports `enable`, additional `packages` and native tuner `settings`.
Local capture options include `b25`, `b61`, `strip`, `args` and `argsBS4K`.
`dtv.packages` supplies replaceable recorder, Hiraku and conversion tools and
respects consumer overlays. Enable `dtv.hirakud.enable` to serve local tuners
through Hiraku. Local entries are exported by default; `serve.enable = false`
excludes an entry, while `serve.mode` and `serve.modeBS4K` select its mode names.
Tuner declarations alone do not enable Hirakud or Mirakurun.

Mirakurun listen supports port, unixSocket and ipv6. EPGStation listen supports
its HTTP and Socket.IO ports. The module does not expose an arbitrary bind address for these applications. Hiraku listen is its native address:port string. Service-specific
settings, credentials, storage and database options remain available through
the underlying NixOS service modules.

Compact `{ driver = "pt3"; }` expands to `PT3-T1/T2/S1/S2` with
two GR and two BS/CS inputs. Further compact PT3 cards continue with T3/T4/S3/S4 and increment
the device offset automatically. Explicit `name` and `deviceOffset`
override those defaults. Supplying `mode` creates one entry without expansion;
`mode = []` registers only hardware. Other drivers require explicit `mode`.

For cross-machine reuse, pass `A.config.dtv.exports.hirakuTuners` to
`lib.mkHirakuTuners { tuners = ...; address = ...; secret = ...; }`, or pass
`A.config.dtv.exports.mirakurunTuners` to `lib.mkRemoteTuners` with `host`.
Copy `A.config.dtv.exports.channels` to the consumer's `dtv.channels`.
The exported descriptions contain no device paths or credentials.

Smart-card readers are optional and independent of recorder decoding flags.
`dtv.card.enable = true` enables PC/SC, CCID and pcsc-tools. Add
`dtv.card.rw5100Support = true` for the RW5100 plugin and USB permissions.
`dtv.card.plugins` accepts additional plugins; existing package overlays remain effective.

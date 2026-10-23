# jodtv-packages

## Shared CAS proxy and database management

Configure A once (the example network must be replaced with your own):

```nix
services.casproxyserver = {
  enable = true;
  openFirewall = true;
  settings = {
    listenIp = "192.0.2.10";
    port = 24000;
    allowedIps = [ "192.0.2.0/24" ];
  };
};
```

On B (Colmena), reference A directly:

```nix
{ nodes, ... }: {
  dtv.casProxy = nodes.A.config.dtv.exports.casProxy;
}
```

Local BS4K/B61 capture through Mirakurun or Hirakud automatically passes
`--cas-proxy` to recisdb/recdvb. Set a tuner's `casProxy = null` to use its local
reader. A wildcard listener needs `services.casproxyserver.advertiseAddress`
reachable from B. A retains control of its allowlist and firewall.

EPGStation's existing NixOS module already manages MariaDB startup, database
creation and password provisioning; hosts need not duplicate `initialDatabases`
or `ensureUsers`. Existing data and credentials are retained. See
[service ownership](docs/service-ownership.md) for the contract and validation.

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
PT3, upstream PX4, Siano, TBS6812 and A865R drivers are included. The experimental
PX4 PC/SC plugin is not packaged; external readers remain separate packages. Kernel-driver derivations
remain private to the module interface rather than exporting binaries tied to
a different kernel.

`packages.x86_64-linux` exposes the full package set. The aarch64-linux output
omits EDCB-Wine, HonomiTV/KonomiTV and Intel encoding packages until their ARM packaging is
validated. The aarch64-darwin output contains Hiraku, libaribb61, libaribtlv, PSI/SI tools,
tsreadex, tsreplace and the FFmpeg patchset. Output lists are explicit to keep
source-dependent packages from forcing evaluation of unrelated tools.
An output's presence is not a claim that it was built on that platform. HonomiTV and the FFmpeg patchset require source-dependent evaluation;
`--option allow-import-from-derivation false` reports those requirements explicitly.

## Binary cache

To use prebuilt packages from [jodtv.cachix.org](https://jodtv.cachix.org),
add this to your NixOS configuration:

```nix
nix.settings = {
  extra-substituters = [ "https://jodtv.cachix.org" ];
  extra-trusted-public-keys = [
    "jodtv.cachix.org-1:aYGvlIzrrtKlHUyKX+FP/hsgELT8SeaPnMeAn2tQDG4="
  ];
};
```

This preserves existing cache settings. Nix uses the cache when the same
derivation is available; different nixpkgs revisions or overrides may require a local build.

## BS4K media processing

`dtv.bs4k` is a sibling of `dtv.tuners`. An enabled tuner with `"BS4K"` in
its `mode` enables it automatically. For remote streams or recording-only hosts:

```nix
dtv.bs4k = true;
```

This selects `ffmpeg-libaribtlv` for FFmpeg/FFprobe, QSVEncC, NVEncC, tsreplace,
both TV server variants (including PyAV), both EPGStation variants and
Amatsukaze's native media components. NVEncC and the affected Amatsukaze tools
are rebuilt from source; binary bundles cannot gain MMTS support through PATH.
Without BS4K the normal packages remain selected. Explicitly disabling it while
an enabled tuner requires BS4K is an evaluation error.

Use the host's configured `pkgs` when selecting a package, for example
`services.honomitv.package = pkgs.konomitv`. Packages from a separate flake
evaluation, including plain `nix run .#...`, do not inherit NixOS options.
Source builds need a Linux builder; NVEncC additionally uses CUDA redistributables.

## Amatsukaze and NVEncC

On x86_64 Linux, permit the `amatsukaze` and `nvencc` bundles in your Nixpkgs
unfree policy, then run:

```sh
nix run .#amatsukaze
nix run .#amatsukaze -- add-task -f /recordings/input.ts
nix run .#amatsukaze -- cli --help
nix run .#nvencc -- --help
```

Amatsukaze's WebUI defaults to `http://localhost:32769/`. State lives in
`${XDG_DATA_HOME:-$HOME/.local/share}/amatsukaze`; `--state-dir` or
`AMATSUKAZE_STATE_DIR` changes it. Nix upgrades preserve configuration, profiles,
queue and history. The bundle includes AviSynth, filters and software encoders.
NVEncC is available independently and is included in Linux KonomiTV/HonomiTV;
software-only Amatsukaze does not require it. NVIDIA encoding requires the host's
working NVIDIA driver.

The default module includes the optional `services.amatsukaze` service:

```nix
services.amatsukaze = {
  enable = true;
  mediaDirectories = [ "/srv/recordings" "/srv/encoded" ];
  # openFirewall = true; # server port 32768 and WebUI port 32769
};
```

## EDCB under Wine

On an x86_64 Linux desktop, run EDCB directly with bundled Wine and Japanese fonts:

```sh
nix run .#edcb-wine
nix run .#edcb-wine -- scan-gr
nix run .#edcb-wine -- scan-bs
nix run .#edcb-wine -- capture
nix run .#edcb-wine -- --backend-host tuner.example --backend-port 40772
```

An X11 display (or XWayland) is required. State defaults to
`~/.local/share/edcb-wine` (respects `XDG_DATA_HOME`); use `--state-dir` to change
it. The first run initializes configuration, recordings and an isolated Wine
prefix. Explicit backend choices persist. EMWUI is at
`http://localhost:5510/EMWUI/`. Use `--help` for commands and options.
If your Nix configuration does not permit the unfree bundle, run
`NIXPKGS_ALLOW_UNFREE=1 nix run --impure .#edcb-wine`.

`nixosModules.edcb-wine` (also included in the default module) provides an
optional x86_64 Linux service with EDCB 260921, BonDriver_mirakc, EMWUI and an
Xvfb/Openbox desktop. Import the package overlay and module, then enable it:

```nix
services.edcb-wine = {
  enable = true;
  backend.host = "localhost"; # Mirakurun or mirakc
  backend.port = 40772;
};
```

VNC listens on `127.0.0.1:5900`; forward it with SSH. EMWUI is at
`http://HOST:5510/EMWUI/`. Set `openFirewall = true` to open EDCB's ports.
The mixed binary bundle is conservatively marked unfree; permit `edcb-wine`
in the consumer's Nixpkgs policy. Program upgrades preserve user configuration,
channel scans, reservations and history. See [packaging and validation](docs/edcb-wine-packaging.md)
for storage options and runtime acceptance limits.

## Consumer overrides

Recorders accept normal `libaribb25` as a package argument. A consumer can
replace that dependency with its own package without changing this repository:

```nix
final: prev: {
  recpt1 = prev.recpt1.override { libaribb25 = final.myAribLibrary; };
  recisdb = prev.recisdb.override { libaribb25 = final.myAribLibrary; };
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
nix build --no-link .#recisdb .#recpt1 .#recdvb
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

Local tuner drivers are `a865r`, `pt3`, `px4`, `siano`, `tbs6812` and generic `dvb`.
Use `mode = []` for a hardware-only declaration. Capturing entries specify a
name (optional), broadcast modes and device. `command` supports an explicit argument list.
`hiraku` connects to a remote Hiraku agent; `remote` connects to a remote
Mirakurun. Remote sources do not install local drivers or enable a local agent.
Each entry supports `enable`, additional `packages` and native tuner `settings`.
Local capture options include `b25`, `b61`, `lnb`, `strip`, `args` and `argsBS4K`.
`lnb = true` requests 15V LNB power for local BS/CS/BS4K capture (`--lnb 15v` for recisdb, `--lnb 15` for recdvb). It defaults to `false` (voltage unset); GR-only tuners and explicit command overrides are unaffected.
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

## A865R

The A865R driver creates a standard DVB frontend and is captured with recisdb.
Nix downloads the pinned Windows installer from the `makeding/a865r` initial
release, extracts only `AVer857BDA.sys`, and verifies its SHA-256. The installer
is never executed. Allow the unfree `a865r-firmware` package in your Nixpkgs
policy. Override `dtv.a865r.firmware` to supply another SYS or raw FW. Vendor
binaries are not committed to this source repository.

```nix
dtv.mirakurun.enable = true;
dtv.tuners = [{
  driver = "a865r";
  mode = [ "GR" ];
  device = "/dev/dvb/adapter0/frontend0";
}];
```

For cross-machine reuse, pass `A.config.dtv.exports.hirakuTuners` to
`lib.mkHirakuTuners { tuners = ...; address = ...; secret = ...; }`, or pass
`A.config.dtv.exports.mirakurunTuners` to `lib.mkRemoteTuners` with `host`.
Copy `A.config.dtv.exports.channels` to the consumer's `dtv.channels`.
The exported descriptions contain no device paths or credentials.

Smart-card readers are optional and independent of recorder decoding flags.
`dtv.card.enable = true` enables PC/SC, CCID and pcsc-tools. Add
`dtv.card.rw5100Support = true` for the RW5100 plugin and USB permissions.
`dtv.card.plugins` accepts additional plugins; existing package overlays remain effective.

## Samples

See [samples](samples/README.en.md) for the three-service setup and split capture/frontend configurations.

## Selecting upstream packages

HonomiTV and the EPGStation fork remain the defaults. Select
`pkgs.konomitv` (tsukumijima/KonomiTV) and `pkgs.epgstation-upstream`
(l3tnun/EPGStation) explicitly to use the original projects.
`pkgs.epgstation` continues to refer to `pkgs.epgstation-h`.

```nix
{ pkgs, ... }: {
  services.honomitv.package = pkgs.konomitv;
  dtv.epgstation.package = pkgs.epgstation-upstream;
  # Without dtv:
  # services.epgstation.package = pkgs.epgstation-upstream;
}
```

Use the existing service modules and settings. KonomiTV has an independent
upstream source pin and Python 3.13 / uv lock. Shared packaging adapts Nix tool
paths, writable state and direct HTTP serving; it does not import fork feature
patches. TLS termination belongs to the consumer. Upstream EPGStation does not
support the fork-only `epgUpdaterMode = "external"` setting. Selecting a package
does not migrate databases or configuration between variants.

## HonomiTV configuration

`services.honomitv.settings` and `encoder` seed `config.yaml` only when it does not
exist. Changes saved by HonomiTV survive restarts and NixOS rebuilds. After the
first start, edit the application configuration directly. Nix still manages
firewall ports, directory access and service dependencies; keep their settings
aligned if you change ports or storage paths in the application.

## recisdb capture contract

PT3/PX4/TBS6812 capture uses recisdb 1.3.0 (`83e8068`). `dtv.packages.recisdb` replaces the former
`dtv.packages.recpt1` option. Custom `args` must use recisdb options (for example,
`--lnb 15v`); explicit `command` values remain caller-owned.
The generated adapter accepts existing numeric terrestrial channels and prefixes
`T`; BS/CS/C-prefixed channels pass through unchanged. Both Mirakurun and Hirakud
use this adapter. Decoding and stripping stay enabled by default; `b25 = false`
and `strip = false` generate `--no-decode` and `--no-strip` respectively.
TBS6812 BS/CS/BS4K capture uses recisdb. Numeric device IDs map to
`/dev/dvb/adapterN/frontend0`; BS4K adds `--b61` and passes `argsBS4K`
(including `--cas-proxy`). Other DVB drivers continue to use recdvb.

The package disables upstream default features and enables `bg-runtime`, `b61`
and Linux `dvb` support. Both `libaribb25` and `libaribb61` are package arguments
resolved through pkg-config, with no bundled fallback. The B25 library must provide
the upstream ABI (including SIMD support). `recisdb.override { libaribb61 = myB61Library; }`
replaces B61 independently. The CLI provides `decode --b61` and experimental DVB
ISDB-S3 tuning; decoder defaults stay unchanged.
The upstream prioritized-card-reader extension is disabled; `--card` selection
is therefore unavailable. Private library implementations remain consumer-owned.

`recpt1` remains available as a standalone package and overlay attribute for DIY
setups, including external `libaribb25` injection. To use it in a tuner, supply
an explicit `dtv.tuners[].command` with recpt1 arguments and add `pkgs.recpt1`
to that entry's `packages`. Generated PT3/PX4 commands use recisdb by default.

## recdvb

`recdvb` supports B25 TS and B61 MMT/TLV recording in one package. Both features
are enabled by default; select `--b25` or `--b61` when recording, or omit both
for raw output. `--cas-proxy host:port` selects a B61 card proxy.
The installed tools are `recdvb`, `recpt1ctl`, `chkdvbsignal` and `tssplitter_lite`.
Generated DVB commands use `dtv.packages.recdvb` for both ordinary and BS4K
capture, preserving `b25`, `b61`, `args` and `argsBS4K` selection.

Both libraries are independent package arguments. `withB25 = false` and
`withB61 = false` omit the corresponding feature and dependency. Consumers
requiring different PC/SC implementations must keep those implementations in
separate recorder processes; build isolated instances from this same definition.

```nix
recdvb.override {
  libaribb25 = myB25Library;
  libaribb61 = myB61Library;
}
```

Validation covers dependency replacement, feature configuration, installed CLI
names/options, and generated Mirakurun/Hirakud command arguments. Linux builds
and actual tuning/descrambling are separate checks.

```sh
nix build --no-link .#checks.x86_64-linux.recdvb-configure \
  .#checks.x86_64-linux.recdvb-capture .#recdvb
```

## libaribb61

`libaribb61` is an independent streaming MMT/TLV ACAS descrambler library,
exported through the package set and overlay on Linux and macOS. It installs
`aribb61/arib_std_b61.h`, the shared library and `libaribb61.pc` for pkg-config
consumers. Build it with `nix build .#libaribb61`. Its C API resembles B25 but is
not ABI compatible. `recdvb` links this library for `--b61`. The library can be
replaced by a consumer overlay:

```nix
final: prev: {
  recdvb = prev.recdvb.override { libaribb61 = final.myB61Library; };
}
```

The build runs the upstream core/C API tests and an installed C API consumer;
card/proxy and real broadcast descrambling require separate runtime verification.

For each TBS6812 physical tuner, `mode` must select either `[ "GR" ]` or a
subset of `[ "BS" "CS" "BS4K" ]`. Mixing GR with satellite modes is rejected.
The two tuners can select different modes independently.

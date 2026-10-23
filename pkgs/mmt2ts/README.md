# mmt2ts packaging

`mmt2ts` packages the upstream stable release from
<https://github.com/Till0196/mmt2ts> with Go 1.26 or later. It installs all three
commands: `mmt2ts` (MMT/TLV to MPEG-2 TS, inspection and verification), `ts2mmt`
(MPEG-2 TS to MMT/TLV), and `mmtcut` (time-range extraction from seekable MMT/TLV
files). The package is exported through the overlay and flake packages on
x86_64-linux, aarch64-linux and aarch64-darwin.

Source and Go module dependencies have fixed hashes. Release updates use the
existing dependency updater, including the Go vendor hash. The build runs the
complete upstream Go test suite; installation checks exercise each installed
command's version and help output. License and NOTICE files are retained under
`share/doc/mmt2ts`.

```sh
nix build .#mmt2ts
./result/bin/mmt2ts -version
./result/bin/mmt2ts -i input.mmts -o output.ts
./result/bin/mmt2ts verify -i output.ts
./result/bin/ts2mmt -i output.ts -o restored.mmts
./result/bin/mmtcut -i input.mmts -o clip.mmts -from 4:30 -to 5:15
python3 scripts/bump-deps.py mmt2ts
```

Acceptance requires a native build, upstream tests and installed-command checks.
Evaluation on another platform is recorded separately from a native build.
Broadcast-stream conversion and player compatibility require a suitable media
sample; synthetic upstream tests do not establish those results. This standalone
package does not change tuner commands, services or the existing BS4K converter.

Validated on 2026-10-24: v0.1.5 built natively on aarch64-darwin with Go 1.26.10;
the complete upstream test suite and all three installed-command checks passed.
The x86_64-linux and aarch64-linux package derivations evaluated successfully;
Linux native builds and broadcast-media conversion were not run in this session.

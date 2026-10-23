{ self, nixpkgs, pkgs }:
let
  lib = nixpkgs.lib;
  linux = import nixpkgs { system = "x86_64-linux"; };
  # Inspect actual Linux ELF fixups using native tools, even on Darwin. This
  # intentionally does not execute Linux programs or claim GPU/runtime proof.
  inspect = name:
    (pkgs.callPackage ../pkgs/${name}/package.nix { }).overrideAttrs (old: {
      pname = "${name}-elf-inspection";
      buildInputs = if name == "nvencc" then [ linux.stdenv.cc.cc.lib ] else [ ];
      preFixup = ''
        export NIX_BINTOOLS=${linux.stdenv.cc.bintools}
      '';
      meta = old.meta // {
        platforms = [ pkgs.stdenv.hostPlatform.system ];
        # Test-only derivative; retain the original bundle's unfree provenance.
      };
    });
  amatsukaze = inspect "amatsukaze";
  nvencc = inspect "nvencc";
in
{
  transcoder-bundles = pkgs.runCommand "transcoder-bundles" {
    nativeBuildInputs = [ pkgs.patchelf pkgs.python3 ];
  } ''
    test -s ${amatsukaze}/share/amatsukaze/exe_files/wwwroot/index.html
    test -s ${amatsukaze}/share/amatsukaze/exe_files/plugins64/AvsCUDA.so
    test -s ${amatsukaze}/share/amatsukaze/exe_files/lib/libavisynth.so.11
    ${amatsukaze}/bin/amatsukaze --help > help.txt
    grep -q 'add-task' help.txt
    test "$(patchelf --print-interpreter ${amatsukaze}/share/amatsukaze/exe_files/AmatsukazeServerCLI)" = ${linux.glibc}/lib/ld-linux-x86-64.so.2
    test "$(patchelf --print-interpreter ${nvencc}/bin/.nvencc-wrapped)" = ${linux.glibc}/lib/ld-linux-x86-64.so.2
    patchelf --print-rpath ${nvencc}/bin/.nvencc-wrapped | grep -q '/run/opengl-driver/lib'
    # patchelf must preserve .NET single-file bundle header offsets and payloads.
    python ${../scripts/check_amatsukaze_bundle.py} ${amatsukaze.src} ${amatsukaze}/share/amatsukaze
    touch "$out"
  '';
}

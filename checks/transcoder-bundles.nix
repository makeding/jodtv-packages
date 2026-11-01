{
  self,
  nixpkgs,
  pkgs,
}:
let
  linux = import nixpkgs { system = "x86_64-linux"; };
  # Inspect actual Linux ELF fixups using native tools, even on Darwin. This
  # intentionally does not execute Linux programs or claim GPU/runtime proof.
  inspect =
    name:
    (pkgs.callPackage ../pkgs/${name}/package.nix { }).overrideAttrs (old: {
      pname = "${name}-elf-inspection";
      nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.patchelf ];
      buildInputs = if name == "nvencc" then [ linux.stdenv.cc.cc.lib ] else [ ];
      preFixup = ''
        export NIX_BINTOOLS=${linux.stdenv.cc.bintools}
      '';
      meta = old.meta // {
        platforms = [ pkgs.stdenv.hostPlatform.system ];
        # Test-only derivative; retain the original bundle's unfree provenance.
      };
    });
  nvencc = inspect "nvencc";
in
{
  transcoder-bundles =
    pkgs.runCommand "transcoder-bundles"
      {
        nativeBuildInputs = [
          pkgs.patchelf
        ];
      }
      ''
        test "$(patchelf --print-interpreter ${nvencc}/bin/.nvencc-wrapped)" = ${linux.glibc}/lib/ld-linux-x86-64.so.2
        patchelf --print-rpath ${nvencc}/bin/.nvencc-wrapped | grep -q '/run/opengl-driver/lib'
        touch "$out"
      '';
}

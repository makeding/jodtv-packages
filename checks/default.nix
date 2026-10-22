{
  self,
  nixpkgs,
  pkgs,
}:
let
  lib = nixpkgs.lib;
  public = import ../pkgs {
    inherit (pkgs) callPackage;
    inputs = self.inputs;
  };
  marker = pkgs.emptyDirectory;
  recorderInputs = p: map (input: input.outPath) (p.nativeBuildInputs ++ (p.buildInputs or [ ]));
  hasInput = p: input: builtins.elem input.outPath (recorderInputs p);
  injectable =
    builtins.all
      (
        name:
        hasInput public.${name} pkgs.libaribb25
        && hasInput (public.${name}.override { libaribb25 = marker; }) marker
        && !(hasInput (public.${name}.override { libaribb25 = marker; }) pkgs.libaribb25)
      )
      [
        "recisdb"
        "recpt1"
        "recdvb"
      ];
in
{
  # The release archive must report its version without a Git checkout.
  qsvencc-source-version = public.qsvencc.overrideAttrs (old: {
    pname = "qsvencc-source-version";
    nativeBuildInputs = builtins.filter (
      input:
      builtins.elem (lib.getName input) [
        "cmake"
        "meson"
        "ninja"
      ]
    ) old.nativeBuildInputs;
    buildInputs = [ ];
    phases = [
      "unpackPhase"
      "patchPhase"
      "checkPhase"
      "installPhase"
    ];
    doCheck = true;
    checkPhase = ''
      test "$configurePhase" = mesonConfigurePhase
      test "$(sh scripts/get-version.sh)" = "${old.version}"
    '';
    installPhase = "touch $out";
    meta = old.meta // {
      platforms = lib.platforms.unix;
    };
  });
  dependency-injection =
    assert injectable;
    assert public.recisdb.buildNoDefaultFeatures;
    assert public.recisdb.buildFeatures == [ "bg-runtime" ];
    assert !(public.recisdb.src.fetchSubmodules or false);
    pkgs.runCommand "jodtv-packages-dependency-injection" { } "touch $out";
}
// import ./dtv.nix { inherit self nixpkgs pkgs; }
// import ./honomitv.nix { inherit pkgs; }

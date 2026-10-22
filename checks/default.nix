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
  # Validate the real upstream B61 configure path on the check host, without DVB hardware.
  recdvb4k-b61-configure = pkgs.stdenv.mkDerivation {
    pname = "recdvb4k-b61-configure";
    inherit (public.recdvb4k) version src;
    nativeBuildInputs = [
      pkgs.autoreconfHook
      pkgs.pkg-config
    ];
    buildInputs = [ pkgs.libaribb61 ];
    configureFlags = [ "--enable-b61" ];
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      grep -q '^#define HAVE_B61 1$' config.h
      grep -q -- '-laribb61' Makefile
      # Missing B61 must be a hard configure failure, never a silent feature downgrade.
      if ./configure --enable-b61 PKG_CONFIG=false > missing-b61.log 2>&1; then
        cat missing-b61.log
        exit 1
      fi
      grep -q 'libaribb61 is required for B61 support' missing-b61.log
      touch "$out"
      runHook postInstall
    '';
  };
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
    assert hasInput public.recdvb4k pkgs.libaribb61;
    assert hasInput (public.recdvb4k.override { libaribb61 = marker; }) marker;
    assert !(hasInput (public.recdvb4k.override { libaribb61 = marker; }) pkgs.libaribb61);
    assert public.recisdb.buildNoDefaultFeatures;
    assert public.recisdb.buildFeatures == [ "bg-runtime" ];
    assert !(public.recisdb.src.fetchSubmodules or false);
    pkgs.runCommand "jodtv-packages-dependency-injection" { } "touch $out";
}
// import ./dtv.nix { inherit self nixpkgs pkgs; }
// import ./honomitv.nix { inherit pkgs; }

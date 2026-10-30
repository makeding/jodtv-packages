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
      ];
in
{
  recisdb-dvb-if = pkgs.callPackage ../pkgs/recisdb/test-dvb-if.nix {
    inherit (public.recisdb) libdvbv5;
  };
  # Run the Rust B61 stream wrapper against the packaged external C library.
  recisdb-b61 = public.recisdb.overrideAttrs (old: {
    pname = "recisdb-b61-wrapper";
    cargoBuildFeatures = [ ];
    cargoCheckFeatures = [ ];
    buildAndTestSubdir = "b61-sys";
    buildInputs = [ pkgs.libaribb61 ];
    installPhase = "touch $out";
    meta = old.meta // {
      platforms = lib.platforms.unix;
    };
  });
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
    assert !(hasInput public.recisdb pkgs.pcsclite);
    assert hasInput public.recisdb pkgs.libaribb61;
    assert hasInput (public.recisdb.override { libaribb61 = marker; }) marker;
    assert !(hasInput (public.recisdb.override { libaribb61 = marker; }) pkgs.libaribb61);
    assert
      !pkgs.stdenv.hostPlatform.isLinux || hasInput public.recisdb (lib.getDev public.recisdb.libdvbv5);
    assert public.recisdb.buildNoDefaultFeatures;
    assert
      public.recisdb.buildFeatures == (
        [
          "bg-runtime"
          "b61"
        ]
        ++ lib.optional pkgs.stdenv.hostPlatform.isLinux "dvb"
      );
    assert !(public.recisdb.src.fetchSubmodules or false);
    pkgs.runCommand "jodtv-packages-dependency-injection" { } "touch $out";
}
// import ./dtv.nix { inherit self nixpkgs pkgs; }
// import ./honomitv.nix { inherit pkgs; }
// import ./honomitv-encoders.nix { inherit self nixpkgs pkgs; }
// import ./upstream.nix { inherit self nixpkgs pkgs; }
// import ./edcb-wine.nix { inherit self nixpkgs pkgs; }
// import ./casproxyserver.nix { inherit self nixpkgs pkgs; }
// import ./epgstation.nix { inherit self nixpkgs pkgs; }
// import ./amatsukaze.nix { inherit self nixpkgs pkgs; }
// import ./transcoder-bundles.nix { inherit self nixpkgs pkgs; }
// import ./bs4k.nix { inherit self nixpkgs pkgs; }

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
  # Keep B25 configure checks on Linux; its PC/SC dependency does not build on Darwin.
  configureRecorder = public.recdvb.override { withB25 = pkgs.stdenv.hostPlatform.isLinux; };
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
  # Exercise the packaged configure path on the check host, without DVB hardware.
  recdvb-configure = pkgs.stdenv.mkDerivation {
    pname = "recdvb-configure";
    inherit (configureRecorder)
      version
      src
      nativeBuildInputs
      buildInputs
      postPatch
      configureFlags
      postConfigure
      ;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      grep -q '^TARGET = recdvb$' Makefile
      grep -q '^TARGET2 = recpt1ctl$' Makefile
      grep -q '^TARGET3 = chkdvbsignal$' Makefile
      grep -q '^TARGET4 = tssplitter_lite$' Makefile
      grep -q -- '-laribb61' Makefile
      ./configure
      ! grep -q '^#define HAVE_LIBARIB25 1$' config.h
      ! grep -q '^#define HAVE_B61 1$' config.h
      ${lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
        ./configure --enable-b25
        grep -q '^#define HAVE_LIBARIB25 1$' config.h
        ! grep -q '^#define HAVE_B61 1$' config.h
      ''}
      ./configure --enable-b61
      ! grep -q '^#define HAVE_LIBARIB25 1$' config.h
      grep -q '^#define HAVE_B61 1$' config.h
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
    assert !(hasInput public.recisdb pkgs.pcsclite);
    assert hasInput public.recisdb pkgs.libaribb61;
    assert hasInput (public.recisdb.override { libaribb61 = marker; }) marker;
    assert !(hasInput (public.recisdb.override { libaribb61 = marker; }) pkgs.libaribb61);
    assert hasInput public.recdvb pkgs.libaribb61;
    assert hasInput (public.recdvb.override { libaribb61 = marker; }) marker;
    assert !(hasInput (public.recdvb.override { libaribb61 = marker; }) pkgs.libaribb61);
    assert hasInput (public.recdvb.override { libaribb25 = marker; }) pkgs.libaribb61;
    assert hasInput (public.recdvb.override { libaribb61 = marker; }) pkgs.libaribb25;
    assert !(hasInput (public.recdvb.override { withB25 = false; }) pkgs.libaribb25);
    assert !(hasInput (public.recdvb.override { withB61 = false; }) pkgs.libaribb61);
    assert
      (public.recdvb.override {
        withB25 = false;
        withB61 = false;
      }).buildInputs == [ ];
    assert (public.recdvb.override { withB25 = false; }).configureFlags == [ "--enable-b61" ];
    assert (public.recdvb.override { withB61 = false; }).configureFlags == [ "--enable-b25" ];
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
// import ./upstream.nix { inherit self nixpkgs pkgs; }
// import ./edcb-wine.nix { inherit self nixpkgs pkgs; }
// import ./casproxyserver.nix { inherit self nixpkgs pkgs; }
// import ./epgstation.nix { inherit self nixpkgs pkgs; }
// import ./amatsukaze.nix { inherit self nixpkgs pkgs; }
// import ./transcoder-bundles.nix { inherit self nixpkgs pkgs; }
// import ./bs4k.nix { inherit self nixpkgs pkgs; }

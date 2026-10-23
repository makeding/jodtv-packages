{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ninja,
  autoconf,
  automake,
  libtool,
  pkg-config,
  dos2unix,
}:

stdenv.mkDerivation rec {
  pname = "mirakc-arib";
  version = "0.24.40";

  src = fetchFromGitHub {
    owner = "mirakc";
    repo = "mirakc-arib";
    tag = version;
    fetchSubmodules = true;
    hash = "sha256-8WaDdn23tJETEDsYpNHaQEVAlRSh9BQQWAeCh4b12Vg=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    autoconf
    automake
    libtool
    pkg-config
    dos2unix
  ];
  # Select the upstream CI branch, patched below to honor Nix's worker count.
  MIRAKC_ARIB_CI = "1";
  cmakeFlags = [ "-DCMAKE_POLICY_VERSION_MINIMUM=3.5" ];

  postPatch = ''
    # The fetched tree has no .git directories; its vendored sources are pristine.
    substituteInPlace CMakeLists.txt --replace-fail 'git checkout -f && ' ""
    substituteInPlace CMakeLists.txt \
      --replace-fail 'set(NPROC 1)' 'set(NPROC "$ENV{NIX_BUILD_CORES}")'
    printf '#!/bin/sh\nprintf "source-archive\\n"\n' > scripts/tag-or-hash
    # TSDuck's recursive make uses this shell for recipes and $(shell ...).
    substituteInPlace vendor/tsduck-arib/Makefile.common \
      --replace-fail '/bin/bash' '${stdenv.shell}'
    patchShebangs scripts vendor/aribb24 vendor/tsduck-arib
  '';

  buildPhase = ''
    runHook preBuild
    # Each vendor project has its own worker pool; do not multiply those pools.
    cmake --build . --target vendor --parallel 1
    cmake --build . --parallel "$NIX_BUILD_CORES"
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    install -Dm755 bin/mirakc-arib $out/bin/mirakc-arib
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    $out/bin/mirakc-arib --version | grep -F '${version}'
    $out/bin/mirakc-arib --help >/dev/null
  '';

  meta = {
    description = "ARIB transport stream tools for mirakc";
    homepage = "https://github.com/mirakc/mirakc-arib";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
    mainProgram = "mirakc-arib";
    maintainers = [ lib.maintainers.huggy ];
  };
}

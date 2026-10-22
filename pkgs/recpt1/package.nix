{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  pkgs,
  libaribb25,
  autoreconfHook,

}:

stdenv.mkDerivation rec {
  pname = "recpt1";
  version = "1.2.0-unstable-2025-07-29";

  src = fetchFromGitHub {
    owner = "stz2012";
    repo = "recpt1";
    rev = "77c7bce2527e1df45cc8667ede753d09de7b3e6c";
    hash = "sha256-1bjAq5zYQ2PTAS+4ydWytfHaPREgjO5he2d9zYMFsvs=";
  };
  sourceRoot = "source/recpt1";
  nativeBuildInputs = [
    pkg-config
    pkgs.openssl
    libaribb25
    pkgs.pcsclite
    autoreconfHook
  ];
  enableParallelBuilding = true;
  configurePhase = ''
    find . -type f | xargs sed -i "s/arib25/aribb25/g"
    find . -type f | xargs sed -i "s/ARIB25/ARIBB25/g"
    ./autogen.sh
    ./configure --enable-b25 --prefix="$out/"
    mkdir -p "$out/bin"
  '';
  meta = {
    description = "Command-line recorder for Japanese ISDB broadcast tuners";
    inherit (src.meta) homepage;
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.all;
    maintainers = [ lib.maintainers.huggy ];
  };
}

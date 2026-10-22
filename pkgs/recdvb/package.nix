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
  pname = "recdvb";
  version = "1.2.1.1-unstable-2026-10-22";

  src = fetchFromGitHub {
    owner = "makeding";
    repo = "recdvb4k";
    rev = "15bf583fa632512993bc76cf55c6ad54d7599e71";
    hash = "sha256-ghi4stNSVmOv1A+WrY3pCSuJH9Z3BEYS9VR/4tXlITo=";
  };
  # sourceRoot = "source/src";
  nativeBuildInputs = [
    pkg-config
    pkgs.openssl
    libaribb25
    pkgs.pcsclite
    autoreconfHook
  ];
  postPatch = ''
    substituteInPlace Makefile.in \
      --replace-fail 'TARGET = recdvb4k' 'TARGET = recdvb' \
      --replace-fail 'TARGET2 = recpt1ctl4k' 'TARGET2 = recpt1ctl' \
      --replace-fail 'TARGET3 = chkdvbsignal4k' 'TARGET3 = chkdvbsignal' \
      --replace-fail 'TARGET4 = tssplitter_lite4k' 'TARGET4 = tssplitter_lite'
  '';
  enableParallelBuilding = true;
  configurePhase = ''
    chmod +x autogen.sh
    ./autogen.sh
    ./configure --enable-b25 --prefix="$out/"
    mkdir -p "$out/bin"
  '';
  makePhase = ''
    make
    make install
  '';
  meta = {
    description = "Command-line recorder for Japanese ISDB broadcast tuners";
    inherit (src.meta) homepage;
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.all;
    maintainers = [ lib.maintainers.huggy ];
  };
}

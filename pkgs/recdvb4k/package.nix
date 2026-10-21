{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  pkgs,
  autoreconfHook,

}:

stdenv.mkDerivation rec {
  pname = "recdvb4k";
  version = "4fcda7ee22446556f0539996148bc6c94a0fd3d6";

  src = fetchFromGitHub {
    owner = "makeding";
    repo = "recdvb4k";
    rev = version;
    hash = "sha256-t+6QDnbevk21Yp9nEajmLHVxw1kfnrerBwJUS5aBbl4=";
  };

  # sourceRoot = "source/src";

  nativeBuildInputs = [
    pkg-config
    autoreconfHook
  ];

  buildInputs = [
    pkgs.openssl
    pkgs.libaribb25
    pkgs.pcsclite.dev
    pkgs.pcsclite.lib
    pkgs.asio
  ];

  # patches = [
  #   ./tuning-debug.patch
  # ];

  enableParallelBuilding = true;
  configurePhase = ''
    runHook preConfigure

    chmod +x autogen.sh
    ./autogen.sh
    ./configure \
      --enable-b25 \
      --enable-b61 \
      --with-asio-include=${pkgs.asio}/include \
      --prefix="$out/"
    mkdir -p "$out/bin"

    runHook postConfigure
  '';

  meta = {
    description = "ISDB recorder with 4K/8K DVB-S3 and ACAS support";
    inherit (src.meta) homepage;
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.all;
    maintainers = [ lib.maintainers.huggy ];
  };
}

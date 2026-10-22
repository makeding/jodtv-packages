{
  lib,
  stdenv,
  fetchzip,
  cmake,
  pkg-config,
  librw5100,
  pcsclite,
}:
stdenv.mkDerivation {
  pname = "pcsc-rw5100";
  version = "0.1.0-unstable-2026-09-14";
  src = fetchzip {
    url = "https://git.huggy.moe/rw5100/pcsc-rw5100/archive/43dc44c045adb1c2daa80c35c0a0982a6cebf1a8.tar.gz";
    hash = "sha256-+KlxK6nQjoc/oeu3rzr0R6jXtyHlGRRFh0SALeTt2o0=";
  };
  nativeBuildInputs = [
    cmake
    pkg-config
  ];
  buildInputs = [
    librw5100
    pcsclite
  ];
  cmakeFlags = [ "-DPCSC_DRIVER_DIR=${placeholder "out"}/pcsc/drivers" ];
  postConfigure = ''
    pkg-config --print-errors --cflags --libs librw5100 >/dev/null
  '';
  doCheck = true;
  postInstall = ''
    install -Dm644 ../src/ifdhandler.h "$out/share/doc/pcsc-rw5100/ifdhandler.h"
    install -Dm755 rw5100-pcsc-check "$out/bin/rw5100-pcsc-check"
  '';
  meta = {
    description = "PC/SC IFD handler for RW5100 USB smart-card readers";
    homepage = "https://git.huggy.moe/rw5100/pcsc-rw5100";
    license = lib.licenses.unfree;
    platforms = lib.platforms.linux;
    maintainers = [ lib.maintainers.huggy ];
  };
}

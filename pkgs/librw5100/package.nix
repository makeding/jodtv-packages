{
  lib,
  stdenv,
  fetchzip,
  cmake,
  pkg-config,
  libusb1,
}:
stdenv.mkDerivation {
  pname = "librw5100";
  version = "0.1.0-unstable-2026-09-13";
  src = fetchzip {
    url = "https://git.huggy.moe/rw5100/librw5100/archive/191172deabe0599a8403f9a0cc75206ddb5376fd.tar.gz";
    hash = "sha256-2XChxcPrPESmUFXNhf02Mtg1RSidYrgCqp8EJFIbvZ4=";
  };
  nativeBuildInputs = [
    cmake
    pkg-config
  ];
  # librw5100.pc declares libusb-1.0 in Requires.private. Consumers need its
  # pkg-config metadata even when linking the shared library.
  propagatedBuildInputs = [ libusb1 ];
  cmakeFlags = [ "-DBUILD_SHARED_LIBS=ON" ];
  doCheck = true;
  meta = {
    description = "RW5100 smart-card reader library using libusb";
    homepage = "https://git.huggy.moe/rw5100/librw5100";
    license = lib.licenses.unfree;
    platforms = lib.platforms.linux;
    maintainers = [ lib.maintainers.huggy ];
  };
}

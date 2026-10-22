{
  lib,
  stdenv,
  fetchFromGitHub,
  pkg-config,
  pkgs,
  libaribb61,
  autoreconfHook,
}:

stdenv.mkDerivation rec {
  pname = "recdvb4k";
  version = "15bf583fa632512993bc76cf55c6ad54d7599e71";

  src = fetchFromGitHub {
    owner = "makeding";
    repo = "recdvb4k";
    rev = version;
    hash = "sha256-ghi4stNSVmOv1A+WrY3pCSuJH9Z3BEYS9VR/4tXlITo=";
  };

  nativeBuildInputs = [
    pkg-config
    autoreconfHook
  ];
  buildInputs = [
    pkgs.libaribb25
    libaribb61
  ];
  enableParallelBuilding = true;
  configureFlags = [
    "--enable-b25"
    "--enable-b61"
  ];
  postConfigure = ''
    grep -q '^#define HAVE_LIBARIB25 1$' config.h
    grep -q '^#define HAVE_B61 1$' config.h
  '';
  preInstall = ''
    mkdir -p "$out/bin"
  '';

  meta = {
    description = "ISDB recorder with 4K/8K DVB-S3 and external libaribb61 support";
    inherit (src.meta) homepage;
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.all;
    mainProgram = "recdvb4k";
    maintainers = [ lib.maintainers.huggy ];
  };
}

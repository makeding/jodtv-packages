{
  lib,
  stdenv,
  fetchFromGitHub,
  pkg-config,
  libaribb25,
  libaribb61,
  autoreconfHook,
  withB25 ? true,
  withB61 ? true,
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
  nativeBuildInputs = [
    pkg-config
    autoreconfHook
  ];
  buildInputs = lib.optional withB25 libaribb25 ++ lib.optional withB61 libaribb61;
  postPatch = ''
    substituteInPlace Makefile.in \
      --replace-fail 'TARGET = recdvb4k' 'TARGET = recdvb' \
      --replace-fail 'TARGET2 = recpt1ctl4k' 'TARGET2 = recpt1ctl' \
      --replace-fail 'TARGET3 = chkdvbsignal4k' 'TARGET3 = chkdvbsignal' \
      --replace-fail 'TARGET4 = tssplitter_lite4k' 'TARGET4 = tssplitter_lite'
  '';
  enableParallelBuilding = true;
  configureFlags = lib.optional withB25 "--enable-b25" ++ lib.optional withB61 "--enable-b61";
  postConfigure = ''
    ${
      if withB25 then
        "grep -q '^#define HAVE_LIBARIB25 1$' config.h"
      else
        "! grep -q '^#define HAVE_LIBARIB25 1$' config.h"
    }
    ${
      if withB61 then
        "grep -q '^#define HAVE_B61 1$' config.h"
      else
        "! grep -q '^#define HAVE_B61 1$' config.h"
    }
  '';
  preInstall = ''
    mkdir -p "$out/bin"
  '';
  doInstallCheck = stdenv.buildPlatform.canExecute stdenv.hostPlatform;
  installCheckPhase = ''
    runHook preInstallCheck
    for command in recdvb recpt1ctl chkdvbsignal tssplitter_lite; do
      test -x "$out/bin/$command"
    done
    "$out/bin/recdvb" --help > help.log 2>&1
    ${if withB25 then "grep -q -- '--b25:' help.log" else "! grep -q -- '--b25:' help.log"}
    ${if withB61 then "grep -q -- '--b61:' help.log" else "! grep -q -- '--b61:' help.log"}
    runHook postInstallCheck
  '';
  meta = {
    description = "ISDB recorder with optional B25 TS and B61 MMT/TLV descrambling";
    inherit (src.meta) homepage;
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
    mainProgram = "recdvb";
    maintainers = [ lib.maintainers.huggy ];
  };
}

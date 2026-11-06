{
  lib,
  stdenvNoCC,
  fetchurl,
  dpkg,
}:

stdenvNoCC.mkDerivation {
  pname = "magicvision-firmware";
  version = "0.1.1";
  src = fetchurl {
    url = "https://github.com/makeding/mAgicVISION/releases/download/v2/magicvision-firmware_0.1.1_all.deb";
    hash = "sha256-pReuBxvAF1X/+2ikn+aLtiNvGit772mYxx1zYGE4CyY=";
  };
  nativeBuildInputs = [ dpkg ];
  dontUnpack = true;
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/firmware/magicvision"
    dpkg-deb --fsys-tarfile "$src" \
      | tar -xOf - ./usr/lib/firmware/magicvision/firmware.bin \
      > "$out/lib/firmware/magicvision/firmware.bin"
    test -s "$out/lib/firmware/magicvision/firmware.bin"
    runHook postInstall
  '';
  meta = {
    description = "Release firmware for mb86H Series USB receivers";
    homepage = "https://github.com/makeding/mAgicVISION";
    license = lib.licenses.unfree;
    platforms = lib.platforms.unix;
    maintainers = [ lib.maintainers.huggy ];
  };
}

{
  lib,
  stdenvNoCC,
  fetchurl,
  dpkg,
}:

stdenvNoCC.mkDerivation {
  pname = "magicvision-firmware";
  version = "0.1.0+20261104.160644";
  src = fetchurl {
    url = "https://github.com/makeding/mAgicVISION/releases/download/v1/magicvision-firmware_0.1.0+20261104.160644_all.deb";
    hash = "sha256-xa0H2m04QoKsHz6LwRWznF4hGlApiEw0ZqJpeRdKNfc=";
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

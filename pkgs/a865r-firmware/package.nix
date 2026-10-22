{ lib, stdenvNoCC, fetchurl, p7zip }:
stdenvNoCC.mkDerivation {
  pname = "a865r-firmware";
  version = "12.6.64.12";
  src = fetchurl {
    url = "https://github.com/makeding/a865r/releases/download/initial/Win8_x64_V12.6.64.12_Install.exe";
    hash = "sha256-J6UDkKcuZy8o39MkwABtb6kh5zuQlN9HJ7RgWjgOPxA=";
  };
  nativeBuildInputs = [ p7zip ];
  dontUnpack = true;
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/firmware/a865r"
    7z e -so "$src" AVer857BDA.sys > "$out/lib/firmware/a865r/AVer857BDA.sys"
    echo "80dfe4cde9d5e06fc8663b68ef351404138443a0f11606caf963f038f0534b30  $out/lib/firmware/a865r/AVer857BDA.sys" | sha256sum -c -
    runHook postInstall
  '';
  meta = {
    description = "A865R firmware-bearing SYS extracted from the Windows installer";
    homepage = "https://github.com/makeding/a865r";
    license = lib.licenses.unfree;
    platforms = lib.platforms.unix;
  };
}

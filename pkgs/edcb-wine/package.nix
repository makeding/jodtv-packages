{
  lib,
  stdenvNoCC,
  fetchurl,
  fetchFromGitHub,
  unzip,
  callPackage,
  wineWow64Packages,
  winePackage ? wineWow64Packages.stable,
}:
let
  edcbZip = fetchurl {
    url = "https://raw.githubusercontent.com/tsukumijima/DTV-Builds/519295fd2ce9dea8c0aa84aa92a525cd9d14263c/EDCB-260921.zip";
    hash = "sha256-GIXj6lUPy3Ryk4PPV0mvoGMMYjfsHrhlFWP68LV6qSA=";
  };
  edcbWineSrc = fetchFromGitHub {
    owner = "tsukumijima";
    repo = "EDCB-Wine";
    rev = "c41c6aa0c038caa57131f00c746cc23367b86b5d";
    hash = "sha256-Luv82DGMrvZMClmV3+wkvS5EgbyWXhtXj+Ix02NQLcA=";
  };
  launcher = callPackage ./launcher.nix {
    wine = winePackage;
  };
in
stdenvNoCC.mkDerivation rec {
  pname = "edcb-wine";
  version = "260921";
  dontUnpack = true;
  nativeBuildInputs = [ unzip ];
  installPhase = ''
    mkdir -p "$out"
    work="$TMPDIR/edcb"
    mkdir -p "$work"

    unzip -q ${edcbZip} -d "$work/"
    mv "$work/EDCB-${version}/EDCB_64bit/"* "$work/EDCB-${version}/"
    rm -rf "$work/EDCB-${version}/EDCB_32bit" "$work/EDCB-${version}/EDCB_64bit"

    rm -rf "$work/EDCB-${version}/EdcbPlugIn"
    rm -rf "$work/EDCB-${version}/PostBatExamples"
    rm -f "$work/EDCB-${version}/Setting/HttpPublic.ini"
    rm -f "$work/EDCB-${version}/Tools/asyncbuf.exe"
    rm -f "$work/EDCB-${version}/Tools/edcbnosuspend.exe"
    rm -f "$work/EDCB-${version}/Tools/ffmpeg.exe"
    rm -f "$work/EDCB-${version}/Tools/ffprobe.exe"
    rm -f "$work/EDCB-${version}/Tools/psisiarc.exe"
    rm -f "$work/EDCB-${version}/Tools/psisimux.exe"
    rm -f "$work/EDCB-${version}/Tools/relayread.exe"
    rm -f "$work/EDCB-${version}/Tools/tsmemseg.exe"
    rm -f "$work/EDCB-${version}/Tools/"*.bat
    rm -f "$work/EDCB-${version}/Tools/"*.dll
    rm -f "$work/EDCB-${version}/Tools/"*.ps1
    rm -f "$work/EDCB-${version}/B1Decoder.dll"
    rm -f "$work/EDCB-${version}/B25Decoder.dll"
    rm -f "$work/EDCB-${version}/EpgTimer.exe"
    rm -f "$work/EDCB-${version}/EpgTimer.exe.rd.xaml"
    rm -f "$work/EDCB-${version}/EpgTimerAdminProxy.exe"
    rm -f "$work/EDCB-${version}/EpgTimerNW.exe"
    rm -f "$work/EDCB-${version}/EpgTimerPlugIn.tvtp"
    rm -f "$work/EDCB-${version}/"*.bat

    cp -a "$work/EDCB-${version}/." "$out/"
    cp ${edcbWineSrc}/EDCB/Common.example.ini "$out/Common.example.ini"
    cp ${edcbWineSrc}/EDCB/EpgDataCap_Bon.example.ini "$out/EpgDataCap_Bon.example.ini"
    cp ${edcbWineSrc}/EDCB/EpgTimerSrv.example.ini "$out/EpgTimerSrv.example.ini"
    cp -a ${edcbWineSrc}/EDCB/BonDriver/. "$out/BonDriver/"
    chmod -R a+rX "$out"
    install -Dm755 ${launcher} "$out/bin/edcb-wine"
  '';

  passthru = { inherit edcbZip edcbWineSrc launcher; };
  meta = {
    description = "EDCB x64 with BonDriver_mirakc for Wine";
    homepage = "https://github.com/tsukumijima/EDCB-Wine";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    maintainers = [ lib.maintainers.huggy ];
    mainProgram = "edcb-wine";
  };
}

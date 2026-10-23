{
  stdenv,
  python3,
  libdvbv5,
}:
stdenv.mkDerivation {
  pname = "recisdb-libdvbv5-if-check";
  inherit (libdvbv5) version src patches;
  nativeBuildInputs = [ python3 ];
  phases = [
    "unpackPhase"
    "patchPhase"
    "checkPhase"
    "installPhase"
  ];
  prePatch = ''
    cp lib/libdvbv5/dvb-sat.c dvb-sat.original.c
  '';
  doCheck = true;
  checkPhase = ''
    python3 ${./test-dvb-if.py} dvb-sat.original.c "$CC" --expect-failure
    python3 ${./test-dvb-if.py} lib/libdvbv5/dvb-sat.c "$CC"
  '';
  installPhase = "touch $out";
}

{
  lib,
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation rec {
  pname = "tsreadex";
  version = "master-260428";

  src = fetchFromGitHub {
    owner = "xtne6f";
    repo = "tsreadex";
    rev = "master-260428";
    hash = "sha256-jszkLID4J0ECs688bj9qlntjZ7NHYi6fPRB1HR2acos=";
  };

  enableParallelBuilding = true;

  makeFlags = [
    "CC=${stdenv.cc.targetPrefix}cc"
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    install -Dm755 tsreadex $out/bin/tsreadex

    runHook postInstall
  '';

  meta = with lib; {
    description = "MPEG-TS stream selector and stabilizer";
    homepage = "https://github.com/xtne6f/tsreadex";
    license = licenses.mit;
    platforms = platforms.unix;
    mainProgram = "tsreadex";
    maintainers = [ lib.maintainers.huggy ];
  };
}

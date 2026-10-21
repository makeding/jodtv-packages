{
  lib,
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation rec {
  pname = "psisimux";
  version = "unstable-2026-04-22";

  src = fetchFromGitHub {
    owner = "xtne6f";
    repo = "psisimux";
    rev = "master-260422";
    hash = "sha256-A8GPEZNqUGZaQ4p+WhUQYjhEoHNfoXPkxBZ+C/I9dj0=";
  };

  enableParallelBuilding = true;

  makeFlags = [
    "CC=${stdenv.cc.targetPrefix}cc"
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    install -Dm755 psisimux $out/bin/psisimux

    runHook postInstall
  '';

  meta = with lib; {
    description = "MPEG-TS section (PSI/SI etc.) multiplexer";
    homepage = "https://github.com/xtne6f/psisimux";
    license = licenses.mit;
    platforms = platforms.unix;
    mainProgram = "psisimux";
    maintainers = [ lib.maintainers.huggy ];
  };
}

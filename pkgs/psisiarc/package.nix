{
  lib,
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation rec {
  pname = "psisiarc";
  version = "unstable-2023-03-24";

  src = fetchFromGitHub {
    owner = "xtne6f";
    repo = "psisiarc";
    rev = "6593a0f63aedaaecfac7682b51e267874a8ec549";
    hash = "sha256-ToSB+6NQLQQseE7sOQXs7uoNJMIZAZTkpuJpMb8dFqg=";
  };

  enableParallelBuilding = true;

  makeFlags = [
    "CC=${stdenv.cc.targetPrefix}cc"
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    install -Dm755 psisiarc $out/bin/psisiarc

    runHook postInstall
  '';

  meta = with lib; {
    description = "MPEG-TS section (PSI/SI etc.) archiver";
    homepage = "https://github.com/xtne6f/psisiarc";
    license = licenses.mit;
    platforms = platforms.unix;
    mainProgram = "psisiarc";
    maintainers = [ lib.maintainers.huggy ];
  };
}

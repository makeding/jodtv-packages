{
  lib,
  stdenv,
  fetchFromGitHub,
  pkg-config,
  openssl,
  pcsclite,
  tsduck,
}:

stdenv.mkDerivation rec {
  pname = "dantto4k";
  version = "unstable-2026-10-25";

  src = fetchFromGitHub {
    owner = "nekohkr";
    repo = "dantto4k";
    rev = "bb425bfe5b987207e984e9e021fa5b04ed168372";
    hash = "sha256-5wmQ2DwCvbNUpKncHi7V8+upC36SYbCgPKykIpVTm20=";
  };

  asioSrc = fetchFromGitHub {
    owner = "chriskohlhoff";
    repo = "asio";
    rev = "03ae834edbace31a96157b89bf50e5ee464e5ef9";
    hash = "sha256-PBoa4OAOOmHas9wCutjz80rWXc3zGONntb9vTQk3FNY=";
  };

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    openssl
    pcsclite
    tsduck
  ];

  postPatch = ''
    substituteInPlace Makefile \
      --replace-fail 'TSDUCK_INC = $(shell pkg-config --cflags-only-I tsduck)' \
                    'TSDUCK_INC = -I${tsduck}/include/tsduck -I${tsduck}/include/tscore' \
      --replace-fail 'TSDUCK_LIB = $(shell pkg-config --libs tsduck)' \
                    'TSDUCK_LIB = -L${tsduck}/lib -L${lib.getLib openssl}/lib -ltsduck -ltscore -lcrypto' \
      --replace-fail "-Ithirdparty/asio/asio/include" "-I${asioSrc}/asio/include"
  '';

  enableParallelBuilding = true;

  doCheck = true;

  checkPhase = ''
    runHook preCheck

    $CXX -std=c++20 -I src ${./aes-ctr-test.cpp} src/aes.cpp -o aes-ctr-test
    ./aes-ctr-test

    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall

    install -D -m 0755 build/dantto4k $out/bin/dantto4k

    runHook postInstall
  '';

  meta = {
    description = "MMT/TLV to MPEG-2 TS Converter";
    homepage = "https://github.com/nekohkr/dantto4k";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
    maintainers = [ lib.maintainers.huggy ];
  };
}

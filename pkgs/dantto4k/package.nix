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
  version = "unstable-2026-10-20";

  src = fetchFromGitHub {
    owner = "nekohkr";
    repo = "dantto4k";
    rev = "cc43dd2b486eb6a6f6318bb9debb33dc3ccf694d";
    hash = "sha256-6ZWrfaugRAw5gUt29PSoryVMQkSvQxxafClSNWukkuI=";
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
    # gcc15 では mmtTableFactory.h が <cstdint> を include せずに uint8_t を使っており
    # 宣言のパラメータ型が int として回復され定義と不一致になるため、全 TU に事前 include させる
    substituteInPlace Makefile \
      --replace-fail "-maes -msse4.1" "-maes -msse4.1 -include cstdint"
  '';

  enableParallelBuilding = true;

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

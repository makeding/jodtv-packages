{
  lib,
  stdenv,
  fetchFromGitHub,
  pkg-config,
  asio,
  pcsclite,
  yaml-cpp,
}:

stdenv.mkDerivation {
  pname = "casproxyserver";
  version = "1.1.0";

  src = fetchFromGitHub {
    owner = "nekohkr";
    repo = "casproxyserver";
    rev = "ec3b62df8f9b7a3da3a8fd85fe17bae04dca6ac7";
    hash = "sha256-h9JLxh1gBItDKTGHtFo5eoyVnXZq42nLgdfW+V234Ck=";
  };

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    asio
    pcsclite
    yaml-cpp
  ];

  postPatch = ''
    substituteInPlace Makefile \
      --replace-fail 'YAML_CPP_INC = -Ithirdparty/yaml-cpp/include' \
                     'YAML_CPP_INC = $(shell pkg-config --cflags yaml-cpp)' \
      --replace-fail 'YAML_CPP_LIB = thirdparty/yaml-cpp/build/libyaml-cpp.a' \
                     'YAML_CPP_LIB = $(shell pkg-config --libs yaml-cpp)' \
      --replace-fail '-Ithirdparty/asio/asio/include' '-I${asio}/include' \
      --replace-fail 'CXXFLAGS = -std=c++17' 'CXXFLAGS = -O2 -std=c++17 -pthread' \
      --replace-fail 'LDFLAGS = $(PCSC_LIB) $(YAML_CPP_LIB)' \
                     'LDFLAGS = $(PCSC_LIB) $(YAML_CPP_LIB) -pthread'
  '';

  enableParallelBuilding = true;

  installPhase = ''
    runHook preInstall

    install -D -m 0755 build/casproxyserver $out/bin/casproxyserver

    runHook postInstall
  '';

  meta = {
    description = "Smartcard proxy server";
    homepage = "https://github.com/nekohkr/casproxyserver";
    license = lib.licenses.asl20;
    mainProgram = "casproxyserver";
    platforms = lib.platforms.unix;
    maintainers = [ lib.maintainers.huggy ];
  };
}

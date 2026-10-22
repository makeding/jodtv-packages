{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  pcsclite,
}:

stdenv.mkDerivation {
  pname = "libaribb25";
  version = "0.2.10-unstable-2026-10-22";

  src = fetchFromGitHub {
    owner = "tsukumijima";
    repo = "libaribb25";
    rev = "0676da1cb1e43792555e127a6c062363af7d35c7";
    hash = "sha256-1Ro9quedX3aSnIhPhxlGbNw4wZyWyhoJmhaWjXDJEO4=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
  ];
  buildInputs = [
    pcsclite
  ];

  enableParallelBuilding = true;
  CXXFLAGS = "-std=c++20";
  meta = {
    description = "Cross-platform ARIB STD-B1 and ARIB STD-B25 decoder library";
    homepage = "https://github.com/tsukumijima/libaribb25";
    license = lib.licenses.asl20;
    platforms = lib.platforms.all;
    maintainers = [ lib.maintainers.huggy ];
    replace = [ "aribb25" ];
  };
}
